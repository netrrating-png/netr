#!/usr/bin/env python3
"""
Upserts the I-Z player dataset into Supabase nba_game_players via PostgREST.

Reads .tmp/nba_daily_players_i_z.json (produced by nba_daily_players_i_z.py),
converts camelCase keys to snake_case column names, and upserts in a single
batch with `Prefer: resolution=merge-duplicates`.

Usage:
    export SUPABASE_URL="..."
    export SUPABASE_SERVICE_ROLE_KEY="..."
    python3 tools/upsert_i_z_players.py
"""
import json
import os
import sys
from pathlib import Path

import requests

JSON_PATH = Path(".tmp/nba_daily_players_i_z.json")

# camelCase → snake_case mapping (matches the SQL INSERT column list in
# nba_daily_players_i_z.py).
KEY_MAP = {
    "yearsActive": "years_active",
    "fromYear": "from_year",
    "toYear": "to_year",
    "draftTeam": "draft_team",
    "careerGames": "career_games",
    "careerMinutes": "career_minutes",
    "funFact": "fun_fact",
    "headshotUrl": "headshot_url",
    "draftYear": "draft_year",
    "draftRound": "draft_round",
    "draftPick": "draft_pick",
    "allStarCount": "all_star_count",
    "mvpCount": "mvp_count",
    "finalsMvpCount": "finals_mvp_count",
    "dpoyCount": "dpoy_count",
    "sixmoyCount": "sixmoy_count",
    "mipCount": "mip_count",
    "hallOfFame": "hall_of_fame",
    "signatureShoeBrand": "signature_shoe_brand",
}


def to_snake(row: dict) -> dict:
    return {KEY_MAP.get(k, k): v for k, v in row.items()}


def main() -> None:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        sys.exit("SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY required")

    if not JSON_PATH.exists():
        sys.exit(f"Missing {JSON_PATH}. Run tools/nba_daily_players_i_z.py first.")

    players = json.loads(JSON_PATH.read_text())
    rows = [to_snake(p) for p in players]
    print(f"Upserting {len(rows)} I-Z players…")

    r = requests.post(
        f"{url}/rest/v1/nba_game_players",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=representation",
        },
        json=rows,
        timeout=60,
    )
    if r.status_code not in (200, 201):
        print(f"FAILED [{r.status_code}]: {r.text[:500]}", file=sys.stderr)
        sys.exit(1)

    returned = r.json()
    print(f"OK — Supabase returned {len(returned)} rows.")


if __name__ == "__main__":
    main()
