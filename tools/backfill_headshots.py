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
# BBR rate-limits to ~20 req/min on HTML pages. 3.5s between page fetches
# keeps us at ~17 req/min, under the wall.
REQ_DELAY = 3.5
# Seconds to sleep on 429 before retry, capped at MAX_BACKOFF.
INITIAL_BACKOFF = 60
MAX_BACKOFF = 300
MAX_RETRIES = 3


def get_with_backoff(session: "requests.Session", url: str, *, method: str = "GET") -> "requests.Response | None":
    """GET/HEAD with exponential backoff on 429. Returns None if all retries 429."""
    backoff = INITIAL_BACKOFF
    for attempt in range(MAX_RETRIES + 1):
        try:
            r = session.request(method, url, timeout=20, allow_redirects=True)
        except requests.RequestException:
            return None
        if r.status_code != 429:
            return r
        if attempt == MAX_RETRIES:
            return r
        print(f"  [429] backing off {backoff}s…", flush=True)
        time.sleep(backoff)
        backoff = min(backoff * 2, MAX_BACKOFF)
    return None


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
        r = get_with_backoff(session, url, method="HEAD")
        if r is None:
            continue
        if r.status_code == 200:
            # Confirm this slug actually belongs to this player (name collisions exist).
            letter = slug[0]
            page = f"{BBR_PAGE}/{letter}/{slug}.html"
            time.sleep(REQ_DELAY)
            pr = get_with_backoff(session, page, method="GET")
            if pr is None:
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
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    })

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
