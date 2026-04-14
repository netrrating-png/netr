#!/usr/bin/env python3
"""
Backfills nba_game_players.headshot_url with Basketball Reference headshot URLs.

BBR has a photo for every player, unlike the NBA CDN. URL pattern:
    https://www.basketball-reference.com/req/202106291/images/headshots/{slug}.jpg

We find each player's BBR slug via the same logic as scrape_bbr_player_details.py,
then do a HEAD on the headshot URL to confirm it exists before writing. Fast —
typically one HEAD per player.

Usage:
    export SUPABASE_URL="..."
    export SUPABASE_SERVICE_ROLE_KEY="..."
    python3 tools/backfill_headshots.py

    # only backfill rows where headshot_url IS NULL
    python3 tools/backfill_headshots.py --only-missing
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import time
import unicodedata

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

BBR_HEAD = "https://www.basketball-reference.com/req/202106291/images/headshots"
BBR_PAGE = "https://www.basketball-reference.com/players"
REQ_DELAY = 0.25


def strip_accents(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def slug_candidates(name: str) -> list[str]:
    """BBR slug = first5(last) + first2(first) + 01..05."""
    parts = [p for p in re.split(r"[ \-.']+", strip_accents(name).lower())
             if p and p.rstrip(".") not in {"jr", "sr", "ii", "iii", "iv"}]
    if len(parts) < 2:
        return []
    first = re.sub(r"[^a-z]", "", parts[0])
    last  = re.sub(r"[^a-z]", "", parts[-1])
    if not first or not last:
        return []
    base = (last[:5] + first[:2])
    return [f"{base}{n:02d}" for n in range(1, 6)]


def find_headshot_url(session: requests.Session, name: str) -> str | None:
    for slug in slug_candidates(name):
        url = f"{BBR_HEAD}/{slug}.jpg"
        time.sleep(REQ_DELAY)
        try:
            r = session.head(url, timeout=10, allow_redirects=True)
        except requests.RequestException:
            continue
        if r.status_code == 200:
            # Confirm this slug actually belongs to this player (name collisions exist).
            letter = slug[0]
            page = f"{BBR_PAGE}/{letter}/{slug}.html"
            try:
                pr = session.get(page, timeout=15)
            except requests.RequestException:
                continue
            if pr.status_code == 200 and _page_matches(pr.text, name):
                return url
    return None


def _page_matches(html: str, name: str) -> bool:
    m = re.search(r"<h1[^>]*>\s*<span>([^<]+)</span>", html)
    if not m:
        return False
    page_squash = re.sub(r"[^a-z]", "", strip_accents(m.group(1)).lower())
    want = [tok for tok in re.split(r"[ \-.']+", strip_accents(name).lower())
            if tok and tok.rstrip(".") not in {"jr", "sr", "ii", "iii", "iv"}]
    return all(re.sub(r"[^a-z]", "", tok) in page_squash for tok in want)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only-missing", action="store_true",
                    help="skip rows that already have a headshot_url")
    args = ap.parse_args()

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        sys.exit("SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY required")

    hdrs = {"apikey": key, "Authorization": f"Bearer {key}"}

    # Fetch players
    params = {"select": "id,name,headshot_url", "active": "eq.true"}
    if args.only_missing:
        params["headshot_url"] = "is.null"
    r = requests.get(f"{url}/rest/v1/nba_game_players", params=params, headers=hdrs, timeout=60)
    r.raise_for_status()
    players = r.json()
    print(f"Processing {len(players)} players…")

    session = requests.Session()
    session.headers.update({"User-Agent": "NETR-headshot-backfill/1.0"})

    ok = miss = fail = 0
    patch_hdrs = {**hdrs, "Content-Type": "application/json", "Prefer": "return=minimal"}

    for i, p in enumerate(players, 1):
        photo = find_headshot_url(session, p["name"])
        if photo is None:
            miss += 1
            print(f"  [{i}/{len(players)}] {p['name']}: no BBR photo")
            continue
        pr = requests.patch(
            f"{url}/rest/v1/nba_game_players",
            params={"id": f"eq.{p['id']}"},
            headers=patch_hdrs,
            json={"headshot_url": photo},
            timeout=15,
        )
        if pr.status_code in (200, 204):
            ok += 1
        else:
            fail += 1
            print(f"  [{i}/{len(players)}] {p['name']}: PATCH failed [{pr.status_code}]",
                  file=sys.stderr)
        if i % 25 == 0:
            print(f"  …{i}/{len(players)} — {ok} ok, {miss} no-photo, {fail} failed")

    print(f"\nDone: {ok} updated, {miss} no photo found, {fail} failed.")


if __name__ == "__main__":
    main()
