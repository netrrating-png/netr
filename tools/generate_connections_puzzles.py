"""
Generate daily NBA Connections puzzles and upsert them into nba_connections_daily.

Each puzzle consists of 4 categories × 3 players = 12 tiles. Users group the
player tiles into the 4 correct categories. Categories are drawn from a rotating
pool of types so consecutive days feel different:

  team          All played for [Team]
  draft_team    All drafted by [Team]
  jersey        All wore #[N]
  era_debut     All debuted in the [decade]s
  college       All went to [School]
  country       All from [Country]
  draft_class   All drafted in [Year]
  lottery_pick  All were lottery picks (top 14)
  first_overall All were #1 overall picks
  undrafted     All went undrafted
  height_tall   All at least 7 feet tall
  height_short  All 6\'2" or shorter

Prerequisites:
  1. Apply supabase/migrations/20260414_enrich_players.sql
  2. Run tools/enrich_connections_data.py to fill college/country/draft fields
  3. Apply supabase/migrations/20260414_connections_game.sql
  4. Set env vars (or .env file):
       SUPABASE_URL=https://<project>.supabase.co
       SUPABASE_SERVICE_ROLE_KEY=<service-role-key>

Usage:
    python tools/generate_connections_puzzles.py              # next 7 days
    python tools/generate_connections_puzzles.py --days 30
    python tools/generate_connections_puzzles.py --dry-run    # print only, no insert
    python tools/generate_connections_puzzles.py --date 2026-04-20  # one specific date
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
from collections import defaultdict
from datetime import date, timedelta
from typing import Optional

# -- optional .env loading -----------------------------------------------------
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

try:
    import requests
except ImportError:
    print("requests is not installed: pip install requests", file=sys.stderr)
    sys.exit(1)


# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

PLAYERS_PER_GROUP = 3

# Well-known teams that reliably have ≥5 players in the pool
FAMOUS_TEAMS = [
    "Los Angeles Lakers", "Boston Celtics", "Chicago Bulls",
    "Miami Heat", "Golden State Warriors", "San Antonio Spurs",
    "New York Knicks", "Los Angeles Clippers", "Oklahoma City Thunder",
    "Phoenix Suns", "Houston Rockets", "Dallas Mavericks",
    "Portland Trail Blazers", "Utah Jazz", "Denver Nuggets",
    "Philadelphia 76ers", "Orlando Magic", "Indiana Pacers",
    "Detroit Pistons", "Milwaukee Bucks", "Toronto Raptors",
    "Cleveland Cavaliers", "Atlanta Hawks", "Memphis Grizzlies",
    "New Orleans Pelicans", "Sacramento Kings", "Minnesota Timberwolves",
    "Brooklyn Nets", "Charlotte Hornets", "Washington Wizards",
]

# Famous jersey numbers that appear on multiple players
FAMOUS_JERSEYS = [
    "23", "3", "6", "7", "24", "8", "32", "33", "34", "11",
    "0", "1", "2", "4", "5", "10", "12", "13", "15", "21",
    "25", "30", "35",
]

# Well-attended college programs that produce many NBA players
POWER_COLLEGES = [
    "Duke", "Kentucky", "North Carolina", "Kansas", "UCLA",
    "Michigan", "Syracuse", "Arizona", "Connecticut", "Florida",
    "Michigan State", "Indiana", "Georgetown", "Maryland",
    "Texas", "Ohio State", "Villanova", "Louisville", "Georgia Tech",
    "Providence", "Pittsburgh", "Arkansas", "St. John's",
]

# Countries with multiple NBA players in the pool
BASKETBALL_COUNTRIES = [
    "France", "Spain", "Germany", "Nigeria", "Australia",
    "Canada", "Serbia", "Greece", "Argentina", "Brazil",
    "Slovenia", "Latvia", "Lithuania", "Cameroon", "Croatia",
    "Montenegro", "Turkey", "Czech Republic", "Congo",
]

# Famous draft classes
NOTABLE_DRAFT_CLASSES = list(range(1992, 2023))

# Difficulty assignment per category type (1=Yellow, 4=Purple)
DIFFICULTY_MAP = {
    "team":          1,
    "era_debut":     2,
    "college":       2,
    "draft_class":   2,
    "draft_team":    3,
    "jersey":        3,
    "country":       3,
    "lottery_pick":  3,
    "height_tall":   4,
    "height_short":  4,
    "first_overall": 4,
    "undrafted":     4,
    "active_year":   3,
}

# When building a puzzle, try types in a shuffled order from this list.
# Types later in the list tend to be harder / more niche.
ALL_CATEGORY_TYPES = list(DIFFICULTY_MAP.keys())


# -----------------------------------------------------------------------------
# Supabase helpers
# -----------------------------------------------------------------------------

def _headers(key: str) -> dict:
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates",
    }


def fetch_players(url: str, key: str) -> list[dict]:
    """Fetch all active players with the fields needed for puzzle generation."""
    resp = requests.get(
        f"{url}/rest/v1/nba_game_players",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
        params={
            "select": ",".join([
                "id", "name", "headshot_url", "teams", "draft_team",
                "jerseys", "from_year", "to_year", "height",
                "college", "country", "draft_year", "draft_round", "draft_number",
            ]),
            "active": "eq.true",
            "limit": "10000",
        },
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def fetch_existing_puzzle_dates(url: str, key: str) -> set[str]:
    """Return puzzle dates already in nba_connections_daily."""
    resp = requests.get(
        f"{url}/rest/v1/nba_connections_daily",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
        params={"select": "puzzle_date", "limit": "500"},
        timeout=30,
    )
    resp.raise_for_status()
    return {row["puzzle_date"] for row in resp.json()}


def upsert_puzzles(url: str, key: str, rows: list[dict]) -> None:
    resp = requests.post(
        f"{url}/rest/v1/nba_connections_daily",
        headers=_headers(key),
        json=rows,
        timeout=30,
    )
    if resp.status_code >= 300:
        print(f"  Supabase upsert error {resp.status_code}: {resp.text[:300]}", file=sys.stderr)
        resp.raise_for_status()


# -----------------------------------------------------------------------------
# Height parsing helpers
# -----------------------------------------------------------------------------

def _height_to_inches(h: Optional[str]) -> Optional[int]:
    """Convert '7-2' → 86 inches, or None if unparseable."""
    if not h:
        return None
    parts = h.split("-")
    if len(parts) != 2:
        return None
    try:
        return int(parts[0]) * 12 + int(parts[1])
    except ValueError:
        return None


# -----------------------------------------------------------------------------
# Category candidate builders
# Each returns a list of matching player dicts from the pool.
# -----------------------------------------------------------------------------

def _candidates_team(players: list[dict], team: str) -> list[dict]:
    return [p for p in players if team in (p.get("teams") or [])]


def _candidates_draft_team(players: list[dict], team: str) -> list[dict]:
    return [p for p in players if p.get("draft_team") == team]


def _candidates_jersey(players: list[dict], number: str) -> list[dict]:
    return [p for p in players if number in (p.get("jerseys") or [])]


def _candidates_era_debut(players: list[dict], decade_start: int) -> list[dict]:
    decade_end = decade_start + 9
    return [p for p in players if decade_start <= (p.get("from_year") or 0) <= decade_end]


def _candidates_college(players: list[dict], school: str) -> list[dict]:
    return [p for p in players if (p.get("college") or "").lower() == school.lower()]


def _candidates_country(players: list[dict], country: str) -> list[dict]:
    return [p for p in players if (p.get("country") or "").lower() == country.lower()]


def _candidates_draft_class(players: list[dict], year: int) -> list[dict]:
    return [p for p in players if p.get("draft_year") == year]


def _candidates_lottery_pick(players: list[dict]) -> list[dict]:
    return [
        p for p in players
        if p.get("draft_number") is not None and p["draft_number"] <= 14
    ]


def _candidates_first_overall(players: list[dict]) -> list[dict]:
    return [p for p in players if p.get("draft_number") == 1]


def _candidates_undrafted(players: list[dict]) -> list[dict]:
    return [p for p in players if p.get("draft_round") is None and p.get("draft_year") is None]


def _candidates_height_tall(players: list[dict]) -> list[dict]:
    return [p for p in players if (_height_to_inches(p.get("height")) or 0) >= 84]  # 7-0+


def _candidates_height_short(players: list[dict]) -> list[dict]:
    return [p for p in players if 0 < (_height_to_inches(p.get("height")) or 999) <= 74]  # ≤6-2


def _candidates_active_year(players: list[dict], year: int) -> list[dict]:
    return [
        p for p in players
        if (p.get("from_year") or 9999) <= year <= (p.get("to_year") or 9999)
    ]


# -----------------------------------------------------------------------------
# Puzzle builder
# -----------------------------------------------------------------------------

def _make_group(players: list[dict], label: str, category_type: str) -> dict:
    """Pick PLAYERS_PER_GROUP random players from candidates and format a group dict."""
    chosen = random.sample(players, PLAYERS_PER_GROUP)
    return {
        "label": label,
        "type": category_type,
        "difficulty": DIFFICULTY_MAP[category_type],
        "player_ids": [p["id"] for p in chosen],
        "player_names": [p["name"] for p in chosen],
        "headshot_urls": [p.get("headshot_url") or "" for p in chosen],
    }


def _available(players: list[dict], used_ids: set[int]) -> list[dict]:
    return [p for p in players if p["id"] not in used_ids]


def build_puzzle(all_players: list[dict]) -> Optional[list[dict]]:
    """
    Try to build a 4-category Connections puzzle from the player pool.
    Returns a list of 4 group dicts, or None if it can't be assembled.
    """
    # Precompute lookup structures
    by_team: dict[str, list[dict]] = defaultdict(list)
    by_draft_team: dict[str, list[dict]] = defaultdict(list)
    by_jersey: dict[str, list[dict]] = defaultdict(list)
    by_decade: dict[int, list[dict]] = defaultdict(list)
    by_college: dict[str, list[dict]] = defaultdict(list)
    by_country: dict[str, list[dict]] = defaultdict(list)
    by_draft_year: dict[int, list[dict]] = defaultdict(list)

    for p in all_players:
        for t in (p.get("teams") or []):
            by_team[t].append(p)
        if p.get("draft_team"):
            by_draft_team[p["draft_team"]].append(p)
        for j in (p.get("jerseys") or []):
            by_jersey[j].append(p)
        fy = p.get("from_year")
        if fy:
            decade = (fy // 10) * 10
            by_decade[decade].append(p)
        col = (p.get("college") or "").strip()
        if col:
            by_college[col.lower()].append(p)
        ctr = (p.get("country") or "").strip()
        if ctr:
            by_country[ctr.lower()].append(p)
        dy = p.get("draft_year")
        if dy:
            by_draft_year[dy].append(p)

    lottery_players = _candidates_lottery_pick(all_players)
    first_overall_players = _candidates_first_overall(all_players)
    undrafted_players = _candidates_undrafted(all_players)
    tall_players = _candidates_height_tall(all_players)
    short_players = _candidates_height_short(all_players)

    groups: list[dict] = []
    used_ids: set[int] = set()
    used_types: set[str] = set()

    # Shuffle the type order so each day uses different types
    type_order = ALL_CATEGORY_TYPES.copy()
    random.shuffle(type_order)

    for cat_type in type_order:
        if len(groups) == 4:
            break
        if cat_type in used_types:
            continue

        group = None

        if cat_type == "team":
            candidates_list = list(FAMOUS_TEAMS)
            random.shuffle(candidates_list)
            for team in candidates_list:
                avail = _available(by_team.get(team, []), used_ids)
                if len(avail) >= PLAYERS_PER_GROUP:
                    group = _make_group(avail, f"All played for the {team}", cat_type)
                    break

        elif cat_type == "draft_team":
            teams = list(by_draft_team.keys())
            random.shuffle(teams)
            for team in teams:
                avail = _available(by_draft_team[team], used_ids)
                if len(avail) >= PLAYERS_PER_GROUP:
                    group = _make_group(avail, f"All drafted by the {team}", cat_type)
                    break

        elif cat_type == "jersey":
            jerseys = list(FAMOUS_JERSEYS)
            random.shuffle(jerseys)
            for num in jerseys:
                avail = _available(by_jersey.get(num, []), used_ids)
                if len(avail) >= PLAYERS_PER_GROUP:
                    group = _make_group(avail, f"All wore #{num}", cat_type)
                    break

        elif cat_type == "era_debut":
            decades = list(by_decade.keys())
            random.shuffle(decades)
            for decade in decades:
                avail = _available(by_decade[decade], used_ids)
                if len(avail) >= PLAYERS_PER_GROUP:
                    label = f"All debuted in the {decade}s"
                    group = _make_group(avail, label, cat_type)
                    break

        elif cat_type == "college":
            colleges = list(POWER_COLLEGES)
            random.shuffle(colleges)
            for school in colleges:
                avail = _available(by_college.get(school.lower(), []), used_ids)
                if len(avail) >= PLAYERS_PER_GROUP:
                    group = _make_group(avail, f"All went to {school}", cat_type)
                    break

        elif cat_type == "country":
            countries = list(BASKETBALL_COUNTRIES)
            random.shuffle(countries)
            for ctr in countries:
                avail = _available(by_country.get(ctr.lower(), []), used_ids)
                if len(avail) >= PLAYERS_PER_GROUP:
                    group = _make_group(avail, f"All from {ctr}", cat_type)
                    break

        elif cat_type == "draft_class":
            years = list(NOTABLE_DRAFT_CLASSES)
            random.shuffle(years)
            for yr in years:
                avail = _available(by_draft_year.get(yr, []), used_ids)
                if len(avail) >= PLAYERS_PER_GROUP:
                    group = _make_group(avail, f"All drafted in {yr}", cat_type)
                    break

        elif cat_type == "lottery_pick":
            avail = _available(lottery_players, used_ids)
            if len(avail) >= PLAYERS_PER_GROUP:
                group = _make_group(avail, "All were lottery picks (top 14)", cat_type)

        elif cat_type == "first_overall":
            avail = _available(first_overall_players, used_ids)
            if len(avail) >= PLAYERS_PER_GROUP:
                group = _make_group(avail, "All were #1 overall draft picks", cat_type)

        elif cat_type == "undrafted":
            avail = _available(undrafted_players, used_ids)
            if len(avail) >= PLAYERS_PER_GROUP:
                group = _make_group(avail, "All went undrafted", cat_type)

        elif cat_type == "height_tall":
            avail = _available(tall_players, used_ids)
            if len(avail) >= PLAYERS_PER_GROUP:
                group = _make_group(avail, "All are at least 7 feet tall", cat_type)

        elif cat_type == "height_short":
            avail = _available(short_players, used_ids)
            if len(avail) >= PLAYERS_PER_GROUP:
                group = _make_group(avail, 'All are 6\'2" or shorter', cat_type)

        elif cat_type == "active_year":
            # Pick a year where multiple players overlapped
            year_counts: dict[int, int] = defaultdict(int)
            for p in all_players:
                fy = p.get("from_year") or 0
                ty = p.get("to_year") or date.today().year
                for yr in range(max(fy, 1990), min(ty, 2024) + 1):
                    year_counts[yr] += 1
            candidate_years = [yr for yr, cnt in year_counts.items() if cnt >= PLAYERS_PER_GROUP + 5]
            random.shuffle(candidate_years)
            for yr in candidate_years:
                pool_for_year = _candidates_active_year(all_players, yr)
                avail = _available(pool_for_year, used_ids)
                if len(avail) >= PLAYERS_PER_GROUP:
                    group = _make_group(avail, f"All were active during the {yr}-{yr+1} season", cat_type)
                    break

        if group is not None:
            groups.append(group)
            used_ids.update(group["player_ids"])
            used_types.add(cat_type)

    if len(groups) < 4:
        return None

    # Sort by difficulty (Yellow → Purple) so the client can display in order
    groups.sort(key=lambda g: g["difficulty"])

    return groups


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--days",
        type=int,
        default=7,
        metavar="N",
        help="Generate puzzles for the next N days (default: 7).",
    )
    parser.add_argument(
        "--date",
        type=str,
        default=None,
        metavar="YYYY-MM-DD",
        help="Generate a puzzle for one specific date only.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print generated puzzles to stdout; do not write to Supabase.",
    )
    args = parser.parse_args()

    supabase_url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

    if not args.dry_run and (not supabase_url or not supabase_key):
        print(
            "ERROR: Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars "
            "(or put them in a .env file).",
            file=sys.stderr,
        )
        return 1

    # -- determine which dates to generate ------------------------------------
    if args.date:
        try:
            target_dates = [date.fromisoformat(args.date)]
        except ValueError:
            print(f"ERROR: invalid date '{args.date}' — use YYYY-MM-DD", file=sys.stderr)
            return 1
    else:
        today = date.today()
        target_dates = [today + timedelta(days=i) for i in range(args.days)]

    # -- fetch existing puzzle dates (to skip already-generated ones) ----------
    existing_dates: set[str] = set()
    if not args.dry_run:
        print("Fetching existing puzzle dates from Supabase...")
        try:
            existing_dates = fetch_existing_puzzle_dates(supabase_url, supabase_key)
            print(f"  {len(existing_dates)} dates already have puzzles")
        except Exception as err:  # noqa: BLE001
            print(f"  WARNING: could not fetch existing dates: {err}", file=sys.stderr)

    dates_to_generate = [
        d for d in target_dates
        if d.isoformat() not in existing_dates
    ]

    if not dates_to_generate:
        print("All requested dates already have puzzles. Nothing to do.")
        return 0

    print(f"Generating puzzles for {len(dates_to_generate)} date(s)...")

    # -- fetch player pool from Supabase --------------------------------------
    if not args.dry_run:
        print("Fetching player pool from Supabase...")
        try:
            players = fetch_players(supabase_url, supabase_key)
        except Exception as err:  # noqa: BLE001
            print(f"ERROR fetching players: {err}", file=sys.stderr)
            return 1
        print(f"  {len(players)} active players loaded")
    else:
        # In dry-run mode, still need players — fetch if creds available
        if supabase_url and supabase_key:
            try:
                players = fetch_players(supabase_url, supabase_key)
                print(f"  {len(players)} active players loaded")
            except Exception as err:  # noqa: BLE001
                print(f"  WARNING: could not fetch players ({err}); using empty pool", file=sys.stderr)
                players = []
        else:
            print("  (dry-run without Supabase creds — player pool will be empty)")
            players = []

    if not players:
        print("ERROR: no players available to generate puzzles from.", file=sys.stderr)
        return 1

    # -- generate puzzles ------------------------------------------------------
    rows_to_upsert: list[dict] = []
    failed_dates: list[str] = []

    for puzzle_date in dates_to_generate:
        date_str = puzzle_date.isoformat()
        # Use the date as random seed so a --dry-run is reproducible for the same date
        random.seed(int(puzzle_date.strftime("%Y%m%d")))

        groups = build_puzzle(players)
        if groups is None:
            print(f"  {date_str}: FAILED — could not assemble 4 groups. Skipping.")
            failed_dates.append(date_str)
            continue

        # Shuffle tile order within each group so difficulty order isn't revealed
        for g in groups:
            combined = list(zip(g["player_ids"], g["player_names"], g["headshot_urls"]))
            random.shuffle(combined)
            g["player_ids"], g["player_names"], g["headshot_urls"] = map(list, zip(*combined))

        types_used = [g["type"] for g in groups]
        print(f"  {date_str}: {types_used}")

        if args.dry_run:
            print(json.dumps({"puzzle_date": date_str, "categories": groups}, indent=2))
        else:
            rows_to_upsert.append({"puzzle_date": date_str, "categories": groups})

    # -- upsert to Supabase ---------------------------------------------------
    if rows_to_upsert:
        print(f"\nUpserting {len(rows_to_upsert)} puzzle(s) to Supabase...")
        try:
            upsert_puzzles(supabase_url, supabase_key, rows_to_upsert)
            print("  Done.")
        except Exception as err:  # noqa: BLE001
            print(f"  ERROR: {err}", file=sys.stderr)
            return 1

    if failed_dates:
        print(f"\nWARNING: {len(failed_dates)} date(s) failed and were skipped: {failed_dates}")

    print(f"\nGenerated {len(rows_to_upsert)} puzzle(s) successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
