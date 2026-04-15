#!/usr/bin/env python3
"""
Downloads NBA CDN headshots, makes the white background transparent,
and uploads to Supabase Storage (`player-headshots/{id}.png`).

Then patches nba_game_players.headshot_url with the public URL.

NBA CDN URL pattern:
    https://cdn.nba.com/headshots/nba/latest/1040x760/{nba_player_id}.png

We key on the player's `id` column (which matches NBA's player ID for
active players) — zero risk of name-mismatch.

White-bg removal: flood-fill from the four corners, replacing near-white
pixels (all channels > THRESH) with transparent alpha. Conservative
threshold keeps white jerseys intact.

Usage:
    export SUPABASE_URL="..."
    export SUPABASE_SERVICE_ROLE_KEY="..."

    # Preview mode — processes first N players, saves locally, no upload.
    python3 tools/process_headshots.py --preview 5

    # Full run — processes all active players and uploads.
    python3 tools/process_headshots.py
"""
from __future__ import annotations

import argparse
import io
import os
import sys
from collections import deque
from pathlib import Path

import requests
from PIL import Image

NBA_CDN = "https://cdn.nba.com/headshots/nba/latest/1040x760/{id}.png"
BUCKET = "player-headshots"
# Near-white threshold. A pixel is "background" if R,G,B all >= THRESH.
THRESH = 240
PREVIEW_DIR = Path(".tmp/headshot_preview")


def make_bg_transparent(png_bytes: bytes) -> bytes:
    """Flood-fill near-white from the four corners, turn those pixels transparent."""
    img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    w, h = img.size
    px = img.load()

    def is_bg(c):
        return c[0] >= THRESH and c[1] >= THRESH and c[2] >= THRESH

    visited = [[False] * h for _ in range(w)]
    queue = deque()
    for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if is_bg(px[x, y]):
            queue.append((x, y))
            visited[x][y] = True

    while queue:
        x, y = queue.popleft()
        px[x, y] = (0, 0, 0, 0)
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[nx][ny]:
                if is_bg(px[nx, ny]):
                    visited[nx][ny] = True
                    queue.append((nx, ny))

    out = io.BytesIO()
    img.save(out, format="PNG", optimize=True)
    return out.getvalue()


def download_headshot(pid: int) -> bytes | None:
    r = requests.get(NBA_CDN.format(id=pid), timeout=15)
    if r.status_code == 200 and r.headers.get("content-type", "").startswith("image/"):
        return r.content
    return None


def upload_to_storage(url: str, key: str, pid: int, png: bytes) -> str | None:
    """Upload PNG to player-headshots bucket. Returns public URL on success."""
    r = requests.post(
        f"{url}/storage/v1/object/{BUCKET}/{pid}.png",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "image/png",
            "x-upsert": "true",
        },
        data=png,
        timeout=30,
    )
    if r.status_code not in (200, 201):
        print(f"    upload failed [{r.status_code}]: {r.text[:200]}", file=sys.stderr)
        return None
    return f"{url}/storage/v1/object/public/{BUCKET}/{pid}.png"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", type=int, default=0,
                    help="Preview N players locally (no upload)")
    ap.add_argument("--only-cdn", action="store_true",
                    help="Only process players whose headshot_url points to cdn.nba.com "
                         "(skip already-processed and BBR-URL players)")
    ap.add_argument("--only-unprocessed", action="store_true",
                    help="Process any player whose headshot_url isn't already in "
                         "our player-headshots bucket (resume-safe).")
    args = ap.parse_args()

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        sys.exit("SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY required")

    hdrs = {"apikey": key, "Authorization": f"Bearer {key}"}

    params = {"select": "id,name,headshot_url", "active": "eq.true", "order": "id"}
    r = requests.get(f"{url}/rest/v1/nba_game_players", params=params, headers=hdrs, timeout=60)
    r.raise_for_status()
    players = r.json()

    if args.only_cdn:
        players = [p for p in players
                   if p.get("headshot_url") and "cdn.nba.com" in p["headshot_url"]]
    elif args.only_unprocessed:
        players = [p for p in players
                   if not p.get("headshot_url")
                   or "player-headshots" not in p["headshot_url"]]

    if args.preview:
        PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
        players = players[:args.preview]
        print(f"Preview mode: processing {len(players)} players to {PREVIEW_DIR}/")
    else:
        print(f"Processing {len(players)} players → Supabase Storage")

    ok = miss = fail = 0
    patch_hdrs = {**hdrs, "Content-Type": "application/json", "Prefer": "return=minimal"}

    for i, p in enumerate(players, 1):
        pid = p["id"]
        name = p["name"]
        raw = download_headshot(pid)
        if raw is None:
            miss += 1
            print(f"  [{i}/{len(players)}] {name} (id={pid}): NBA CDN 404", flush=True)
            continue

        try:
            processed = make_bg_transparent(raw)
        except Exception as e:
            fail += 1
            print(f"  [{i}/{len(players)}] {name}: process error {e}", file=sys.stderr, flush=True)
            continue

        if args.preview:
            out = PREVIEW_DIR / f"{pid}_{name.replace(' ', '_')}.png"
            out.write_bytes(processed)
            print(f"  [{i}/{len(players)}] {name} → {out}", flush=True)
            ok += 1
            continue

        public_url = upload_to_storage(url, key, pid, processed)
        if public_url is None:
            fail += 1
            continue

        # Don't let transient Supabase timeouts crash the whole run.
        try:
            pr = requests.patch(
                f"{url}/rest/v1/nba_game_players",
                params={"id": f"eq.{pid}"},
                headers=patch_hdrs,
                json={"headshot_url": public_url},
                timeout=30,
            )
            if pr.status_code in (200, 204):
                ok += 1
            else:
                fail += 1
                print(f"  [{i}/{len(players)}] {name}: PATCH failed [{pr.status_code}]",
                      file=sys.stderr, flush=True)
        except requests.RequestException as e:
            fail += 1
            print(f"  [{i}/{len(players)}] {name}: PATCH error {e}",
                  file=sys.stderr, flush=True)

        if i % 25 == 0:
            print(f"  …{i}/{len(players)} — {ok} ok, {miss} no-cdn, {fail} failed", flush=True)

    print(f"\nDone: {ok} processed, {miss} no CDN photo, {fail} failed.")


if __name__ == "__main__":
    main()
