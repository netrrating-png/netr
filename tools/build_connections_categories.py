#!/usr/bin/env python3
"""
Builds the nba_connections_categories table from enriched player data in Supabase.

For each "category template" below, finds all eligible players and inserts one
`nba_connections_categories` row per template whose eligibility pool has 4+ players.

Difficulty tiers are assigned heuristically:
    easy    — obvious groupings (Lakers, MVPs, #1 overall picks)
    medium  — recognizable-but-requires-thought (Kentucky, French players)
    hard    — niche shared attributes (Iowa State, undrafted, DPOY club)
    tricky  — wordplay / non-obvious (same draft year + lottery pick, etc.)

Idempotent: deletes and recreates all auto-generated rows (kind != 'manual') on
each run so you can re-run after enrichment refreshes. Hand-curated `kind='manual'`
rows are left alone.

Usage:
    export SUPABASE_URL="https://YOUR-PROJECT.supabase.co"
    export SUPABASE_SERVICE_ROLE_KEY="..."
    python3 tools/build_connections_categories.py

    # Dump what would be inserted without hitting Supabase
    python3 tools/build_connections_categories.py --dry-run
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict
from pathlib import Path

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

ROOT = Path(__file__).resolve().parent.parent


# ─── category definitions ─────────────────────────────────────────
# Each builder returns: list of {label, difficulty, kind, kind_value, player_ids}

def by_team(players: list[dict]) -> list[dict]:
    """Group by draft_team. Easy difficulty for original-franchise classics."""
    groups: dict[str, list[int]] = defaultdict(list)
    for p in players:
        if p.get("draft_team"):
            groups[p["draft_team"]].append(p["id"])
    out = []
    for team, ids in groups.items():
        if len(ids) >= 4:
            out.append({
                "label": f"Drafted by the {team}",
                "difficulty": "easy",
                "kind": "draft_team",
                "kind_value": team,
                "player_ids": ids,
            })
    return out


def by_college(players: list[dict]) -> list[dict]:
    groups: dict[str, list[int]] = defaultdict(list)
    for p in players:
        if p.get("college"):
            groups[p["college"]].append(p["id"])

    # College prestige drives difficulty: Duke/UNC/Kentucky/Kansas/UCLA are instantly
    # recognizable; mid-majors are harder.
    blueblood = {"Duke", "Kentucky", "North Carolina", "UCLA", "Kansas",
                 "Michigan", "Michigan State", "Arizona", "Indiana", "Connecticut", "UConn"}
    out = []
    for college, ids in groups.items():
        if len(ids) < 4:
            continue
        diff = "medium" if college in blueblood else "hard"
        out.append({
            "label": f"{college} alumni",
            "difficulty": diff,
            "kind": "college",
            "kind_value": college,
            "player_ids": ids,
        })
    return out


def by_country(players: list[dict]) -> list[dict]:
    groups: dict[str, list[int]] = defaultdict(list)
    for p in players:
        if p.get("country") and p["country"] != "USA":
            groups[p["country"]].append(p["id"])
    out = []
    for country, ids in groups.items():
        if len(ids) >= 4:
            out.append({
                "label": f"Born in {country}",
                "difficulty": "medium",
                "kind": "country",
                "kind_value": country,
                "player_ids": ids,
            })
    return out


def by_draft_status(players: list[dict]) -> list[dict]:
    out = []
    first_overall = [p["id"] for p in players if p.get("draft_pick") == 1]
    if len(first_overall) >= 4:
        out.append({"label": "#1 overall picks", "difficulty": "easy",
                    "kind": "draft_pick", "kind_value": "1", "player_ids": first_overall})

    top3 = [p["id"] for p in players if p.get("draft_pick") in (2, 3)]
    if len(top3) >= 4:
        out.append({"label": "Drafted #2 or #3 overall", "difficulty": "medium",
                    "kind": "draft_pick", "kind_value": "2-3", "player_ids": top3})

    lottery = [p["id"] for p in players if p.get("draft_pick") and 4 <= p["draft_pick"] <= 14]
    if len(lottery) >= 4:
        out.append({"label": "Lottery picks (4–14)", "difficulty": "hard",
                    "kind": "draft_pick", "kind_value": "lottery", "player_ids": lottery})

    second_round = [p["id"] for p in players if p.get("draft_round") == 2]
    if len(second_round) >= 4:
        out.append({"label": "2nd round picks", "difficulty": "hard",
                    "kind": "draft_round", "kind_value": "2", "player_ids": second_round})

    undrafted = [p["id"] for p in players
                 if p.get("draft_pick") is None and p.get("draft_round") is None]
    if len(undrafted) >= 4:
        out.append({"label": "Undrafted", "difficulty": "tricky",
                    "kind": "draft_status", "kind_value": "undrafted", "player_ids": undrafted})

    # Late-second-round picks (51+) — easy to miss even for die-hards
    late_second = [p["id"] for p in players if p.get("draft_pick") and p["draft_pick"] >= 51]
    if len(late_second) >= 4:
        out.append({"label": "Picked 51st or later", "difficulty": "tricky",
                    "kind": "draft_pick", "kind_value": "51+", "player_ids": late_second})

    return out


def by_tricky_groupings(players: list[dict]) -> list[dict]:
    """Extra tricky-tier categories built from combinations of attributes."""
    out = []

    # Champion + MVP: very rare club
    champ_mvp = [p["id"] for p in players
                 if (p.get("championships") or 0) >= 1 and (p.get("mvp_count") or 0) >= 1]
    if len(champ_mvp) >= 4:
        out.append({"label": "NBA champion AND MVP", "difficulty": "tricky",
                    "kind": "combo", "kind_value": "champ_mvp", "player_ids": champ_mvp})

    # Born outside USA AND All-Star — international stars
    intl_stars = [p["id"] for p in players
                  if p.get("country") and p["country"] != "USA"
                  and (p.get("all_star_count") or 0) >= 1]
    if len(intl_stars) >= 4:
        out.append({"label": "International All-Stars", "difficulty": "tricky",
                    "kind": "combo", "kind_value": "intl_as", "player_ids": intl_stars})

    # Never went to college (prep-to-pro / international / G-League)
    no_college = [p["id"] for p in players if not p.get("college")]
    if len(no_college) >= 4:
        out.append({"label": "No college (prep/international)", "difficulty": "tricky",
                    "kind": "college", "kind_value": "none", "player_ids": no_college})

    # Top-5 pick who never made an All-Star
    top5_no_as = [p["id"] for p in players
                  if p.get("draft_pick") and p["draft_pick"] <= 5
                  and (p.get("all_star_count") or 0) == 0]
    if len(top5_no_as) >= 4:
        out.append({"label": "Top-5 pick, no All-Star", "difficulty": "tricky",
                    "kind": "combo", "kind_value": "top5_no_as", "player_ids": top5_no_as})

    # Second-round pick who DID make an All-Star
    second_round_as = [p["id"] for p in players
                       if p.get("draft_round") == 2 and (p.get("all_star_count") or 0) >= 1]
    if len(second_round_as) >= 4:
        out.append({"label": "2nd-round pick → All-Star", "difficulty": "tricky",
                    "kind": "combo", "kind_value": "2nd_as", "player_ids": second_round_as})

    return out


def by_awards(players: list[dict]) -> list[dict]:
    out = []

    mvps = [p["id"] for p in players if (p.get("mvp_count") or 0) >= 1]
    if len(mvps) >= 4:
        out.append({"label": "MVP winners", "difficulty": "easy",
                    "kind": "award", "kind_value": "mvp", "player_ids": mvps})

    fmvps = [p["id"] for p in players if (p.get("finals_mvp_count") or 0) >= 1]
    if len(fmvps) >= 4:
        out.append({"label": "Finals MVP winners", "difficulty": "medium",
                    "kind": "award", "kind_value": "finals_mvp", "player_ids": fmvps})

    dpoys = [p["id"] for p in players if (p.get("dpoy_count") or 0) >= 1]
    if len(dpoys) >= 4:
        out.append({"label": "Defensive Player of the Year", "difficulty": "medium",
                    "kind": "award", "kind_value": "dpoy", "player_ids": dpoys})

    sixmoy = [p["id"] for p in players if (p.get("sixmoy_count") or 0) >= 1]
    if len(sixmoy) >= 4:
        out.append({"label": "Sixth Man of the Year", "difficulty": "hard",
                    "kind": "award", "kind_value": "sixmoy", "player_ids": sixmoy})

    mip = [p["id"] for p in players if (p.get("mip_count") or 0) >= 1]
    if len(mip) >= 4:
        out.append({"label": "Most Improved Player", "difficulty": "hard",
                    "kind": "award", "kind_value": "mip", "player_ids": mip})

    roy = [p["id"] for p in players if p.get("roy")]
    if len(roy) >= 4:
        out.append({"label": "Rookie of the Year", "difficulty": "medium",
                    "kind": "award", "kind_value": "roy", "player_ids": roy})

    multi_champs = [p["id"] for p in players if (p.get("championships") or 0) >= 2]
    if len(multi_champs) >= 4:
        out.append({"label": "Multi-time NBA champions", "difficulty": "medium",
                    "kind": "championships", "kind_value": "2+", "player_ids": multi_champs})

    many_as = [p["id"] for p in players if (p.get("all_star_count") or 0) >= 5]
    if len(many_as) >= 4:
        out.append({"label": "5× All-Star or more", "difficulty": "easy",
                    "kind": "all_stars", "kind_value": "5+", "player_ids": many_as})

    elite_as = [p["id"] for p in players if (p.get("all_star_count") or 0) >= 10]
    if len(elite_as) >= 4:
        out.append({"label": "10× All-Star club", "difficulty": "medium",
                    "kind": "all_stars", "kind_value": "10+", "player_ids": elite_as})

    hof = [p["id"] for p in players if p.get("hall_of_fame")]
    if len(hof) >= 4:
        out.append({"label": "Hall of Fame", "difficulty": "medium",
                    "kind": "hof", "kind_value": "1", "player_ids": hof})

    return out


def by_era(players: list[dict]) -> list[dict]:
    out = []
    for decade_start in (1990, 2000, 2010, 2020):
        ids = [p["id"] for p in players if p.get("from_year")
               and decade_start <= p["from_year"] < decade_start + 10]
        if len(ids) >= 4:
            out.append({"label": f"Drafted in the {decade_start}s",
                        "difficulty": "hard",
                        "kind": "era",
                        "kind_value": str(decade_start),
                        "player_ids": ids})
    return out


BUILDERS = [by_team, by_college, by_country, by_draft_status, by_awards, by_era, by_tricky_groupings]


# ─── supabase i/o ─────────────────────────────────────────────────
def fetch_players(url: str, key: str) -> list[dict]:
    cols = ("id,name,draft_team,from_year,career_games,"
            "college,country,draft_year,draft_round,draft_pick,"
            "championships,all_star_count,mvp_count,finals_mvp_count,"
            "dpoy_count,sixmoy_count,mip_count,roy,hall_of_fame")
    r = requests.get(
        f"{url}/rest/v1/nba_game_players",
        params={"select": cols, "active": "eq.true"},
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()


def replace_auto_categories(url: str, key: str, rows: list[dict]) -> None:
    # Delete all auto-generated rows (leaves kind='manual' alone)
    r = requests.delete(
        f"{url}/rest/v1/nba_connections_categories",
        params={"kind": "neq.manual"},
        headers={"apikey": key, "Authorization": f"Bearer {key}",
                 "Prefer": "return=minimal"},
        timeout=30,
    )
    if r.status_code not in (200, 204):
        raise SystemExit(f"Delete failed [{r.status_code}] {r.text[:200]}")

    # Insert fresh rows
    if not rows:
        print("No rows to insert.")
        return
    r = requests.post(
        f"{url}/rest/v1/nba_connections_categories",
        headers={"apikey": key, "Authorization": f"Bearer {key}",
                 "Content-Type": "application/json",
                 "Prefer": "return=minimal"},
        json=rows,
        timeout=60,
    )
    if r.status_code not in (200, 201, 204):
        raise SystemExit(f"Insert failed [{r.status_code}] {r.text[:400]}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

    if args.dry_run:
        # Dry run reads from local scrape json (doesn't need Supabase creds)
        src = ROOT / ".tmp" / "bbr_enrichment.json"
        enriched = json.loads(src.read_text()) if src.exists() else []
        # Best-effort merge with whatever from_year data we have — None is fine here
        for p in enriched:
            p.setdefault("from_year", None)
            p.setdefault("draft_team", None)
            p.setdefault("career_games", 0)
        players = enriched
    else:
        if not url or not key:
            sys.exit("SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY required")
        players = fetch_players(url, key)
        print(f"Fetched {len(players)} players from Supabase")

    all_rows: list[dict] = []
    for build in BUILDERS:
        all_rows.extend(build(players))

    # Summary
    by_diff = defaultdict(int)
    for r in all_rows:
        by_diff[r["difficulty"]] += 1
    print(f"\n{len(all_rows)} categories built:")
    for d in ("easy", "medium", "hard", "tricky"):
        print(f"  {d:<7s} {by_diff[d]}")
    print()
    for r in all_rows[:25]:
        print(f"  [{r['difficulty']:<6s}] {r['label']:<40s} ({len(r['player_ids'])} players)")
    if len(all_rows) > 25:
        print(f"  … and {len(all_rows) - 25} more")

    if args.dry_run:
        print("\n(dry run — no Supabase writes)")
        return

    replace_auto_categories(url, key, all_rows)
    print(f"\n✓ Replaced auto-generated rows in nba_connections_categories")
    print("\nNext: SELECT pick_next_connections_puzzle(); in the Supabase SQL editor.")


if __name__ == "__main__":
    main()
