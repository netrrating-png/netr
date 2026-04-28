#!/usr/bin/env python3
"""
Tests alternate headshot sources (TheSportsDB + Wikipedia) for coverage on
NBA players the NBA CDN only returns silhouette placeholders for.

Outputs a side-by-side sample to .tmp/source_test/ — one folder per source
with the downloaded images for visual inspection. Prints a coverage
summary so we can pick the best source to actually run against.

Usage:
    python3 tools/test_headshot_sources.py            # default 20 players
    python3 tools/test_headshot_sources.py --count 40
"""
from __future__ import annotations

import argparse
import hashlib
import os
import sys
import urllib.parse
from pathlib import Path

import requests

# Wikipedia API requires a descriptive UA per their policy.
UA = "NETR-headshot-source-test/1.0 (contact: netr.app)"
SESSION = requests.Session()
SESSION.headers.update({"User-Agent": UA})

PLACEHOLDER_MD5 = "e7f284977a4931dedd1cb6ba4c32283e"
NBA_CDN = "https://cdn.nba.com/headshots/nba/latest/1040x760/{id}.png"
OUT = Path(".tmp/source_test")

# TheSportsDB free test key
TSDB_KEY = "123"


def fetch_placeholder_players(url: str, key: str, limit: int) -> list[dict]:
    """Return first `limit` active players whose NBA CDN photo is the placeholder."""
    hdrs = {"apikey": key, "Authorization": f"Bearer {key}"}
    r = SESSION.get(
        f"{url}/rest/v1/nba_game_players",
        params={"select": "id,name", "active": "eq.true", "order": "id"},
        headers=hdrs,
        timeout=60,
    )
    r.raise_for_status()
    players = r.json()

    out = []
    print(f"Scanning {len(players)} players for placeholders…")
    for p in players:
        rr = SESSION.get(NBA_CDN.format(id=p["id"]), timeout=10)
        if rr.status_code == 200 and hashlib.md5(rr.content).hexdigest() == PLACEHOLDER_MD5:
            out.append(p)
            print(f"  placeholder: [{p['id']}] {p['name']}")
            if len(out) >= limit:
                break
    return out


def try_thesportsdb(name: str, out_dir: Path) -> bool:
    """Search TheSportsDB for a player, save thumbnail if found."""
    q = urllib.parse.quote(name)
    r = SESSION.get(
        f"https://www.thesportsdb.com/api/v1/json/{TSDB_KEY}/searchplayers.php?p={q}",
        timeout=15,
    )
    if r.status_code != 200:
        return False
    data = r.json().get("player") or []
    # Filter to NBA players
    nba = [p for p in data if (p.get("strSport") == "Basketball"
                               and p.get("strTeam") and "NBA" in (p.get("strLeague") or "NBA"))]
    candidates = nba or data
    if not candidates:
        return False
    thumb = candidates[0].get("strThumb") or candidates[0].get("strCutout")
    if not thumb:
        return False
    ir = SESSION.get(thumb, timeout=15)
    if ir.status_code != 200:
        return False
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{name.replace(' ', '_')}.jpg").write_bytes(ir.content)
    return True


def try_wikipedia(name: str, out_dir: Path) -> bool:
    """Use MediaWiki API to get the main infobox image for a player."""
    # Try exact title, then search
    for title in (name.replace(" ", "_"), None):
        if title is None:
            sr = SESSION.get(
                "https://en.wikipedia.org/w/api.php",
                params={
                    "action": "query", "list": "search",
                    "srsearch": f"{name} NBA basketball",
                    "format": "json", "srlimit": 1,
                },
                timeout=15,
            )
            hits = sr.json().get("query", {}).get("search", [])
            if not hits:
                return False
            title = hits[0]["title"].replace(" ", "_")

        r = SESSION.get(
            "https://en.wikipedia.org/w/api.php",
            params={
                "action": "query", "titles": title,
                "prop": "pageimages", "pithumbsize": 500,
                "format": "json",
            },
            timeout=15,
        )
        pages = r.json().get("query", {}).get("pages", {})
        for pg in pages.values():
            thumb = pg.get("thumbnail", {}).get("source")
            if thumb:
                ir = SESSION.get(thumb, timeout=15)
                if ir.status_code == 200:
                    out_dir.mkdir(parents=True, exist_ok=True)
                    ext = thumb.split(".")[-1].split("?")[0][:4]
                    (out_dir / f"{name.replace(' ', '_')}.{ext}").write_bytes(ir.content)
                    return True
    return False


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=20)
    args = ap.parse_args()

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        sys.exit("SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY required")

    placeholders = fetch_placeholder_players(url, key, args.count)
    print(f"\nFound {len(placeholders)} placeholder players. Testing sources…\n")

    tsdb_dir = OUT / "thesportsdb"
    wiki_dir = OUT / "wikipedia"
    tsdb_ok = wiki_ok = 0

    for p in placeholders:
        tsdb = try_thesportsdb(p["name"], tsdb_dir)
        wiki = try_wikipedia(p["name"], wiki_dir)
        tsdb_ok += int(tsdb)
        wiki_ok += int(wiki)
        print(f"  {p['name']:<30} TSDB={'✓' if tsdb else '✗'}  Wiki={'✓' if wiki else '✗'}")

    n = len(placeholders)
    print(f"\nCoverage of {n} players:")
    print(f"  TheSportsDB: {tsdb_ok}/{n} ({100*tsdb_ok/n:.0f}%)  →  {tsdb_dir}/")
    print(f"  Wikipedia:   {wiki_ok}/{n} ({100*wiki_ok/n:.0f}%)  →  {wiki_dir}/")


if __name__ == "__main__":
    main()
