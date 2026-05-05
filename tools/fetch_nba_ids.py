#!/usr/bin/env python3
"""
Resolves every nba_game_players row to its NBA.com PERSON_ID and the matching
official CDN headshot URL, then writes .tmp/nba_id_matches.json.

Important schema note (discovered when this tool was authored):
    The `id` column on nba_game_players is ALREADY the NBA.com PERSON_ID
    (see supabase/migrations/20260410_daily_game_schema.sql line 29:
     `id BIGINT PRIMARY KEY -- nba.com PERSON_ID`).

    Verified against famous players:
        LeBron James → 2544, Stephen Curry → 201939, Kobe Bryant → 977,
        Michael Jordan → 893, Tim Duncan → 1495, Shaquille O'Neal → 165.

    So the canonical "lookup" is just `nba_id = id`. We still verify each ID
    actually resolves at the NBA CDN (some retired pre-2003 players have no
    photo there) and fall back to the NBA Stats commonallplayers endpoint for
    fuzzy-name resolution if the direct ID 404s.

Usage:
    # Loads SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY from .env at repo root
    python3 tools/fetch_nba_ids.py

    # Don't query the live Stats API for fallbacks (faster, ID-only check)
    python3 tools/fetch_nba_ids.py --no-stats-fallback

    # Limit row count (useful for smoke tests)
    python3 tools/fetch_nba_ids.py --limit 25

Output:
    .tmp/nba_id_matches.json — list of
        {"id": <pk>, "name": <str>, "nba_id": <int|null>,
         "headshot_url": <str|null>, "matched": <bool>, "source": <str>}
    A summary is printed; every failure is listed by name so they can be
    handled manually.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
from pathlib import Path
from typing import Any

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

ROOT = Path(__file__).resolve().parent.parent
TMP_DIR = ROOT / ".tmp"
OUT_PATH = TMP_DIR / "nba_id_matches.json"

CDN_URL = "https://cdn.nba.com/headshots/nba/latest/260x190/{nba_id}.png"
STATS_URL = (
    "https://stats.nba.com/stats/commonallplayers"
    "?LeagueID=00&Season=2023-24&IsOnlyCurrentSeason=0"
)
STATS_HEADERS = {
    # The Stats API blocks anything that doesn't look like a real browser
    # call coming from nba.com. These headers are required.
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Origin": "https://www.nba.com",
    "Referer": "https://www.nba.com/",
    "x-nba-stats-origin": "stats",
    "x-nba-stats-token": "true",
    "Connection": "keep-alive",
}
CDN_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
}

NAME_SUFFIXES = {"jr", "sr", "ii", "iii", "iv", "v"}
SLEEP_BETWEEN_STATS_CALLS = 0.5
SLEEP_BETWEEN_CDN_CALLS = 0.05  # CDN tolerates fast HEADs


# ── env loader (avoid python-dotenv dep) ─────────────────────────────────────
def load_env(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        k, v = k.strip(), v.strip().strip('"').strip("'")
        os.environ.setdefault(k, v)


# ── name normalization ────────────────────────────────────────────────────────
def normalize_name(name: str) -> str:
    """Strip accents, lowercase, drop suffixes, collapse to alphanum tokens."""
    no_accent = "".join(
        c for c in unicodedata.normalize("NFKD", name) if not unicodedata.combining(c)
    )
    tokens = [
        re.sub(r"[^a-z0-9]", "", t)
        for t in re.split(r"[ \-.'`]+", no_accent.lower())
        if t and t.rstrip(".") not in NAME_SUFFIXES
    ]
    return " ".join(t for t in tokens if t)


# ── Supabase ──────────────────────────────────────────────────────────────────
def fetch_players(supabase_url: str, key: str, limit: int | None) -> list[dict]:
    hdrs = {"apikey": key, "Authorization": f"Bearer {key}"}
    params = {
        "select": "id,name,headshot_url,active",
        "order": "id.asc",
    }
    if limit:
        params["limit"] = str(limit)
    r = requests.get(
        f"{supabase_url}/rest/v1/nba_game_players",
        params=params,
        headers=hdrs,
        timeout=60,
    )
    r.raise_for_status()
    return r.json()


# ── NBA CDN ───────────────────────────────────────────────────────────────────
def cdn_has_photo(_session: requests.Session, nba_id: int) -> bool:
    """A bare HEAD with default keep-alive worked in testing; using a
    persistent session+custom headers triggered intermittent read timeouts
    against cdn.nba.com over HTTP/2. Cheaper to issue a fresh request per
    call and accept the slightly higher per-call cost — this loop is small
    (~660 players)."""
    url = CDN_URL.format(nba_id=nba_id)
    try:
        r = requests.head(url, headers=CDN_HEADERS, timeout=15, allow_redirects=True)
    except requests.RequestException:
        return False
    return r.status_code == 200


# ── NBA Stats fallback ────────────────────────────────────────────────────────
def fetch_stats_directory(session: requests.Session) -> dict[str, list[int]]:
    """Returns {normalized_name: [PERSON_ID, …]} for every player known to the
    Stats API (current + historical when IsOnlyCurrentSeason=0)."""
    print("[stats] fetching commonallplayers directory…", file=sys.stderr)
    r = session.get(STATS_URL, headers=STATS_HEADERS, timeout=30)
    r.raise_for_status()
    payload = r.json()
    rs = payload["resultSets"][0]
    cols = rs["headers"]
    pid_idx = cols.index("PERSON_ID")
    name_idx = cols.index("DISPLAY_FIRST_LAST")
    out: dict[str, list[int]] = {}
    for row in rs["rowSet"]:
        try:
            pid = int(row[pid_idx])
        except (TypeError, ValueError):
            continue
        norm = normalize_name(str(row[name_idx]))
        if not norm:
            continue
        out.setdefault(norm, []).append(pid)
    print(f"[stats] indexed {sum(len(v) for v in out.values())} players "
          f"({len(out)} unique normalized names)", file=sys.stderr)
    return out


def stats_resolve(
    session: requests.Session,
    cdn_session: requests.Session,
    directory: dict[str, list[int]],
    name: str,
) -> int | None:
    """Try to find an NBA PERSON_ID for `name` whose CDN photo exists."""
    norm = normalize_name(name)
    candidates: list[int] = []
    if norm in directory:
        candidates.extend(directory[norm])
    # Also try last-name-only collisions for nicknames / alternate forms
    parts = norm.split()
    if parts:
        last = parts[-1]
        for k, v in directory.items():
            if k != norm and k.endswith(" " + last):
                # keep only same-length (fewer false positives)
                if len(k.split()) == len(parts):
                    candidates.extend(v)
    seen: set[int] = set()
    ordered = [pid for pid in candidates if pid not in seen and not seen.add(pid)]
    for pid in ordered:
        time.sleep(SLEEP_BETWEEN_CDN_CALLS)
        if cdn_has_photo(cdn_session, pid):
            return pid
    return None


# ── main ──────────────────────────────────────────────────────────────────────
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-stats-fallback", action="store_true",
                    help="skip the Stats API fallback for IDs that 404 at the CDN")
    ap.add_argument("--limit", type=int, default=None,
                    help="only resolve the first N rows (smoke testing)")
    args = ap.parse_args()

    load_env(ROOT / ".env")
    supabase_url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not supabase_url or not key:
        sys.exit("SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY required (set in .env)")

    players = fetch_players(supabase_url, key, args.limit)
    print(f"[supabase] {len(players)} players to resolve")

    cdn_session = requests.Session()
    cdn_session.headers.update(CDN_HEADERS)
    stats_session = requests.Session()
    directory: dict[str, list[int]] = {}

    matches: list[dict[str, Any]] = []
    direct_ok = stats_ok = unmatched = 0

    for i, p in enumerate(players, 1):
        pid = int(p["id"])
        # Step 1: assume the row's id is already the NBA PERSON_ID
        time.sleep(SLEEP_BETWEEN_CDN_CALLS)
        if cdn_has_photo(cdn_session, pid):
            matches.append({
                "id": pid,
                "name": p["name"],
                "nba_id": pid,
                "headshot_url": CDN_URL.format(nba_id=pid),
                "matched": True,
                "source": "id_is_nba_id",
            })
            direct_ok += 1
            if i % 50 == 0:
                print(f"  [{i}/{len(players)}] {direct_ok} direct, "
                      f"{stats_ok} via stats, {unmatched} unmatched")
            continue

        # Step 2: fall back to fuzzy match against the Stats API directory
        if args.no_stats_fallback:
            matches.append({
                "id": pid, "name": p["name"], "nba_id": None,
                "headshot_url": None, "matched": False, "source": "no_cdn_photo",
            })
            unmatched += 1
            continue

        if not directory:
            try:
                directory = fetch_stats_directory(stats_session)
            except Exception as e:  # noqa: BLE001
                print(f"[stats] directory fetch failed: {e}", file=sys.stderr)
                directory = {"__failed__": []}

        time.sleep(SLEEP_BETWEEN_STATS_CALLS if not directory.get("__failed__") else 0)
        resolved = (
            None
            if directory.get("__failed__") is not None
            else stats_resolve(stats_session, cdn_session, directory, p["name"])
        )

        if resolved:
            matches.append({
                "id": pid,
                "name": p["name"],
                "nba_id": resolved,
                "headshot_url": CDN_URL.format(nba_id=resolved),
                "matched": True,
                "source": "stats_fuzzy",
            })
            stats_ok += 1
        else:
            matches.append({
                "id": pid, "name": p["name"], "nba_id": None,
                "headshot_url": None, "matched": False,
                "source": "no_cdn_photo+no_stats_match",
            })
            unmatched += 1

    TMP_DIR.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(matches, indent=2))

    matched_total = direct_ok + stats_ok
    print(f"\n[done] {matched_total}/{len(players)} matched "
          f"({direct_ok} direct id, {stats_ok} via stats fallback, "
          f"{unmatched} unmatched)")
    print(f"[done] wrote {OUT_PATH}")
    if unmatched:
        print("\nUnmatched players (manual fix needed):")
        for m in matches:
            if not m["matched"]:
                print(f"  - id={m['id']:>8}  {m['name']}")


if __name__ == "__main__":
    main()
