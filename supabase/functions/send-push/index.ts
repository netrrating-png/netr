// Send APNs push notifications from Supabase.
//
// How to deploy:
//   supabase functions deploy send-push --no-verify-jwt
//
// Required Supabase secrets (set via `supabase secrets set`):
//   APNS_KEY_ID         10-char Key ID from developer.apple.com → Keys
//   APNS_TEAM_ID        10-char Team ID from developer.apple.com → Membership
//   APNS_BUNDLE_ID      e.g. com.yourteam.netr (must match the iOS app)
//   APNS_KEY_P8         full contents of the AuthKey_XXXXX.p8 file (PEM text,
//                       literal \n preserved). Store it like:
//                       supabase secrets set APNS_KEY_P8="$(cat AuthKey_XXX.p8)"
//   APNS_ENVIRONMENT    "development" or "production" (default: development)
//
// Invocation (from any signed-in client, server-side code, or a DB trigger):
//   POST /functions/v1/send-push
//   {
//     "user_id": "uuid-of-recipient",
//     "title": "Jayson Tatum wants to run",
//     "body":  "He just created a game at West 4th",
//     "type":  "game_invite",
//     "data":  { "game_id": "abc-123" }
//   }
//
// The function looks up every APNs token registered for that user in the
// devices table (falls back to profiles.apns_token for single-device users),
// mints a JWT signed with the APNs ES256 key, and POSTs to Apple's HTTP/2
// push gateway for each token. Bad tokens are auto-pruned from the DB.

// @ts-expect-error — Supabase edge runtime resolves this
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") ?? "";
const APNS_KEY_P8 = Deno.env.get("APNS_KEY_P8") ?? "";
const APNS_ENVIRONMENT = Deno.env.get("APNS_ENVIRONMENT") ?? "development";

const APNS_HOST = APNS_ENVIRONMENT === "production"
  ? "https://api.push.apple.com"
  : "https://api.sandbox.push.apple.com";

// ─── JWT signing (ES256) ──────────────────────────────────────
function base64urlEncode(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  const bin = atob(body);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

let cachedToken: { jwt: string; exp: number } | null = null;

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp > now + 60) return cachedToken.jwt;

  const header = { alg: "ES256", kid: APNS_KEY_ID };
  const payload = { iss: APNS_TEAM_ID, iat: now };
  const headerB64 = base64urlEncode(JSON.stringify(header));
  const payloadB64 = base64urlEncode(JSON.stringify(payload));
  const signingInput = `${headerB64}.${payloadB64}`;

  const keyData = pemToArrayBuffer(APNS_KEY_P8);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${base64urlEncode(new Uint8Array(sig))}`;
  cachedToken = { jwt, exp: now + 60 * 50 }; // APNs caps at 60 min; refresh at 50
  return jwt;
}

// ─── APNs POST ────────────────────────────────────────────────
async function sendOne(
  token: string,
  title: string,
  body: string,
  type: string,
  data: Record<string, unknown>,
): Promise<{ ok: boolean; status: number; reason?: string }> {
  const jwt = await getApnsJwt();
  const payload = {
    aps: { alert: { title, body }, sound: "default", badge: 1 },
    type,
    ...data,
  };
  const res = await fetch(`${APNS_HOST}/3/device/${token}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (res.ok) return { ok: true, status: res.status };
  const json = await res.json().catch(() => ({ reason: "Unknown" }));
  return { ok: false, status: res.status, reason: (json as any).reason };
}

// ─── Entry point ──────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  let body: {
    user_id?: string;
    title?: string;
    body?: string;
    type?: string;
    data?: Record<string, unknown>;
  };
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const { user_id, title, body: msg, type, data } = body;
  if (!user_id || !title || !msg || !type) {
    return new Response("user_id, title, body, type required", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Collect tokens: devices table + profiles fallback
  const tokens = new Set<string>();
  const { data: devices } = await supabase
    .from("devices")
    .select("apns_token")
    .eq("user_id", user_id);
  for (const d of devices ?? []) if (d.apns_token) tokens.add(d.apns_token);

  if (tokens.size === 0) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("apns_token")
      .eq("id", user_id)
      .maybeSingle();
    if (profile?.apns_token) tokens.add(profile.apns_token);
  }

  if (tokens.size === 0) {
    return Response.json({ ok: true, sent: 0, reason: "no tokens" });
  }

  const results = await Promise.all(
    [...tokens].map((t) => sendOne(t, title, msg, type, data ?? {})),
  );

  // Prune dead tokens (APNs returns 410 for unregistered devices)
  const dead = [...tokens].filter((t, i) => results[i].status === 410);
  if (dead.length > 0) {
    await supabase.from("devices").delete().in("apns_token", dead);
    await supabase.from("profiles").update({ apns_token: null }).in("apns_token", dead);
  }

  const sent = results.filter((r) => r.ok).length;
  return Response.json({ ok: true, sent, failed: results.length - sent, pruned: dead.length });
});
