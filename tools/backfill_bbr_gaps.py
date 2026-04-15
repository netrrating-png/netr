#!/usr/bin/env python3
"""
Gap-fill script: replaces silhouette placeholders for older retired players
with real Basketball Reference headshots.

Strategy:
  1. Find players whose NBA CDN photo is the generic silhouette (by MD5).
  2. Fetch BBR's letter-index pages (/players/a/, /players/b/, …) — one per
     letter, spaced to respect BBR's ~20 req/min HTML limit.
  3. Parse each page into a canonical {name: slug} map. BBR disambiguates
     namesakes ("Gary Payton" vs "Gary Payton II") so there's no mismatch
     risk.
  4. For each placeholder player, look up slug, HEAD the image URL to
     confirm it exists (image CDN has its own rate-limit bucket, not shared
     with HTML pages — verified).
  5. Download, run through the same background-transparency pipeline as
     process_headshots.py, upload to player-headshots/{id}.png, PATCH DB.

If BBR is still rate-limiting (429) on the first letter-index fetch, we
abort cleanly so the script can be retried later.

Usage:
    export SUPABASE_URL="..."
    export SUPABASE_SERVICE_ROLE_KEY="..."
    python3 tools/backfill_bbr_gaps.py
"""
from __future__ import annotations

import hashlib
import os
import re
import sys
import time
import unicodedata
from pathlib import Path

import requests

# Reuse the background-transparency pipeline
sys.path.insert(0, str(Path(__file__).parent))
from process_headshots import make_bg_transparent, upload_to_storage  # noqa: E402

PLACEHOLDER_MD5 = "e7f284977a4931dedd1cb6ba4c32283e"
NBA_CDN = "https://cdn.nba.com/headshots/nba/latest/1040x760/{id}.png"
BBR_BASE = "https://www.basketball-reference.com"
BBR_HEADSHOT = f"{BBR_BASE}/req/202106291/images/headshots/{{slug}}.jpg"
LETTER_DELAY = 15  # seconds between BBR letter-index page fetches

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")


def strip_accents(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def norm(name: str) -> str:
    """Normalize a player name for matching: lowercase, ASCII, drop suffixes/punct."""
    s = strip_accents(name).lower()
    s = re.sub(r"[.']", "", s)
    parts = [p for p in re.split(r"[ \-]+", s)
             if p and p.rstrip(".") not in {"jr", "sr"}]
    return " ".join(parts)


def find_placeholder_players(supabase_url: str, key: str) -> list[dict]:
    """Return players whose NBA CDN image is the silhouette placeholder."""
    hdrs = {"apikey": key, "Authorization": f"Bearer {key}"}
    r = requests.get(
        f"{supabase_url}/rest/v1/nba_game_players",
        params={"select": "id,name", "active": "eq.true", "order": "id"},
        headers=hdrs,
        timeout=60,
    )
    r.raise_for_status()
    players = r.json()

    out = []
    print(f"Scanning {len(players)} players for placeholders…", flush=True)
    for p in players:
        rr = requests.get(NBA_CDN.format(id=p["id"]), timeout=10)
        if rr.status_code == 200 and hashlib.md5(rr.content).hexdigest() == PLACEHOLDER_MD5:
            out.append(p)
    print(f"Found {len(out)} placeholder players.", flush=True)
    return out


def fetch_letter_index(session: requests.Session, letter: str) -> dict[str, str] | None:
    """Fetch BBR /players/{letter}/ and return {normalized_name: slug}.

    Returns None on 429 (rate-limited) — caller should abort.
    """
    url = f"{BBR_BASE}/players/{letter}/"
    r = session.get(url, timeout=20)
    if r.status_code == 429 or "error code: 1015" in r.text:
        return None
    if r.status_code != 200:
        print(f"  [{letter}] HTTP {r.status_code} — skipping", flush=True)
        return {}

    # BBR player rows look like:
    # <th ... data-append-csv="slug"><a href="/players/a/slug.html">Player Name</a></th>
    # Extract (slug, display name) pairs.
    rows = re.findall(
        r'data-append-csv="([^"]+)"[^>]*>\s*<a[^>]*>([^<]+)</a>',
        r.text,
    )
    mapping = {}
    for slug, display in rows:
        mapping[norm(display)] = slug
    print(f"  [{letter}] {len(mapping)} players indexed", flush=True)
    return mapping


def main() -> None:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        sys.exit("SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY required")

    placeholders = find_placeholder_players(url, key)
    if not placeholders:
        print("No placeholders — nothing to do.")
        return

    # Only fetch letter pages for letters we actually need
    needed_letters = sorted({p["name"][0].lower() for p in placeholders
                             if p["name"] and p["name"][0].isalpha()})
    print(f"\nFetching BBR letter indexes for: {needed_letters}", flush=True)

    session = requests.Session()
    session.headers.update({"User-Agent": UA})

    name_to_slug: dict[str, str] = {}
    for i, letter in enumerate(needed_letters):
        if i > 0:
            time.sleep(LETTER_DELAY)
        page = fetch_letter_index(session, letter)
        if page is None:
            print(f"\n[{letter}] BBR rate-limit (429). Aborting — try again later.",
                  flush=True, file=sys.stderr)
            sys.exit(2)
        name_to_slug.update(page)

    print(f"\nBBR index total: {len(name_to_slug)} name→slug entries.\n", flush=True)

    # Now resolve each placeholder player
    hdrs = {"apikey": key, "Authorization": f"Bearer {key}"}
    patch_hdrs = {**hdrs, "Content-Type": "application/json", "Prefer": "return=minimal"}

    ok = miss = fail = 0
    for i, p in enumerate(placeholders, 1):
        slug = name_to_slug.get(norm(p["name"]))
        if not slug:
            miss += 1
            print(f"  [{i}/{len(placeholders)}] {p['name']}: no BBR entry", flush=True)
            continue

        # HEAD the image (image CDN = different bucket from HTML, not rate-limited)
        img_url = BBR_HEADSHOT.format(slug=slug)
        hr = session.head(img_url, timeout=15, allow_redirects=True)
        if hr.status_code != 200:
            miss += 1
            print(f"  [{i}/{len(placeholders)}] {p['name']}: image {hr.status_code}",
                  flush=True)
            continue

        # Download the image
        ir = session.get(img_url, timeout=20)
        if ir.status_code != 200:
            fail += 1
            continue

        # Run through our standard processing pipeline
        try:
            processed = make_bg_transparent(ir.content)
        except Exception as e:
            fail += 1
            print(f"  [{i}] {p['name']}: process error {e}", file=sys.stderr, flush=True)
            continue

        # Upload + patch
        public_url = upload_to_storage(url, key, p["id"], processed)
        if public_url is None:
            fail += 1
            continue
        pr = requests.patch(
            f"{url}/rest/v1/nba_game_players",
            params={"id": f"eq.{p['id']}"},
            headers=patch_hdrs,
            json={"headshot_url": public_url},
            timeout=15,
        )
        if pr.status_code in (200, 204):
            ok += 1
            print(f"  [{i}/{len(placeholders)}] {p['name']}: ok ({slug})", flush=True)
        else:
            fail += 1

    print(f"\nDone: {ok} filled, {miss} missing, {fail} failed.")


if __name__ == "__main__":
    main()
