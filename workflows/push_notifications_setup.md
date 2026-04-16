# Push Notifications Setup

The iOS side is fully wired. This doc covers the Apple Developer / Supabase
steps needed to actually send pushes to devices. Local notifications already
work today with zero config.

## What works right now (no setup needed)

Local notifications fire on the user's device once they grant permission:

- **9:00 AM** — "Today's NBA puzzle is live"
- **9:15 AM** — "Connections is ready"
- **8:00 PM** — "Your streak is on the line" (cancelled if they already played)
- **30 min before scheduled game** — "Your game starts in 30 minutes"
- **15 min after game ends** — "Rate your teammates"

These are scheduled in `LocalNotificationScheduler.swift` and fire entirely
on-device. No server, no APNs, no Apple Developer account required.

## What needs setup (to send pushes from the server)

### 1. Xcode — add Push Notifications capability

In Xcode → project → NETR target → **Signing & Capabilities** → **+ Capability**
→ **Push Notifications**. Xcode will add `aps-environment` to the entitlements
file automatically. For local builds this will be `development`.

### 2. Apple Developer — create an APNs key

1. developer.apple.com → Certificates, Identifiers & Profiles → **Keys**
2. Click **+** → name it "NETR Push" → check **Apple Push Notifications service (APNs)**
3. Download the `.p8` file. **You get one download — save it.**
4. Note the 10-character **Key ID** (e.g. `ABC123XYZ9`)
5. Note your **Team ID** (membership page, next to your name)
6. Note your **Bundle ID** (Xcode target → General)

### 3. Supabase — run the migration

Paste `supabase/migrations/20260416_push_notifications.sql` into the SQL Editor
and run it. This adds:
- `profiles.apns_token` column (single-device convenience)
- `devices` table (multi-device, with RLS)

### 4. Supabase — deploy the Edge Function

```bash
# One-time setup
supabase login
supabase link --project-ref obroygzzfpphumsrqtsm

# Set the APNs secrets
supabase secrets set APNS_KEY_ID="ABC123XYZ9"
supabase secrets set APNS_TEAM_ID="YOURTEAMID"
supabase secrets set APNS_BUNDLE_ID="com.yourteam.netr"
supabase secrets set APNS_KEY_P8="$(cat /path/to/AuthKey_ABC123XYZ9.p8)"
supabase secrets set APNS_ENVIRONMENT="development"  # or "production"

# Deploy the function
supabase functions deploy send-push --no-verify-jwt
```

### 5. Test it

From any signed-in user's terminal (or Supabase SQL Editor via `http_post`):

```bash
curl -X POST "https://obroygzzfpphumsrqtsm.supabase.co/functions/v1/send-push" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "RECIPIENT-UUID-HERE",
    "title": "Test Push",
    "body": "If you see this, pushes work 🎉",
    "type": "test"
  }'
```

Response `{"ok":true,"sent":1,"failed":0,"pruned":0}` means success.

## Wiring server-side triggers (future work)

Once the Edge Function is deployed, you can invoke it from Postgres triggers
so events auto-fire pushes. Examples:

- Someone follows you → trigger on `follows` INSERT → call `send-push`
- Someone DMs you → trigger on `direct_messages` INSERT → call `send-push`
- Someone rates your game → trigger on `ratings` INSERT → call `send-push`

Pattern (using `pg_net` or `http` extension):

```sql
CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://obroygzzfpphumsrqtsm.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('supabase.service_role_key', true)
    ),
    body := jsonb_build_object(
      'user_id', NEW.following_id,
      'title', 'New follower',
      'body', 'Someone started following you',
      'type', 'follow',
      'data', jsonb_build_object('follower_id', NEW.follower_id)
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_on_follow
  AFTER INSERT ON follows
  FOR EACH ROW EXECUTE FUNCTION notify_on_follow();
```

## Environments

- Development APNs (`api.sandbox.push.apple.com`) accepts tokens from
  Xcode debug builds only.
- Production APNs (`api.push.apple.com`) accepts tokens from TestFlight
  and App Store builds.

When you ship to TestFlight, set `APNS_ENVIRONMENT="production"` and change
the `aps-environment` entitlement to `production`.
