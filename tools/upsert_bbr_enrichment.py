#!/usr/bin/env python3
"""
Pushes .tmp/bbr_enrichment.json into Supabase nba_game_players via the REST API.

Reads credentials from environment:
    SUPABASE_URL                 e.g. https://abc123.supabase.co
    SUPABASE_SERVICE_ROLE_KEY    the secret service_role key (NOT anon!)

The enrichment migration must already be applied (20260414_connections_game_schema.sql)
— the new columns need to exist.

Usage:
    export SUPABASE_URL="https://YOUR-PROJECT.supabase.co"
    export SUPABASE_SERVICE_ROLE_KEY="..."
    python3 tools/upsert_bbr_enrichment.py

    # Dry run — print what would be sent without hitting Supabase
    python3 tools/upsert_bbr_enrichment.py --dry-run
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

ROOT = Path(__file__).resolve().parent.parent
IN_JSON = ROOT / ".tmp" / "bbr_enrichment.json"

# Columns the migration adds. We send only these fields on upsert (plus id as the match key)
# to avoid clobbering existing values in columns we don't own (name, tier, etc.).
ENRICHMENT_COLUMNS = [
    "college", "country",
    "draft_year", "draft_round", "draft_pick",
    "championships", "all_star_count",
    "mvp_count", "finals_mvp_count", "dpoy_count",
    "sixmoy_count", "mip_count",
    "roy", "hall_of_fame",
]

BATCH_SIZE = 50


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--input", default=str(IN_JSON))
    args = ap.parse_args()

    src = Path(args.input)
    if not src.exists():
        sys.exit(f"Missing {src}. Run tools/scrape_bbr_player_details.py first.")

    url  = os.environ.get("SUPABASE_URL")
    key  = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not args.dry_run and (not url or not key):
        sys.exit("SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY required (see script docstring)")

    records = json.loads(src.read_text())
    print(f"Loaded {len(records)} enriched records from {src}")

    # Build payload: id + ENRICHMENT_COLUMNS only
    payload: list[dict] = []
    for r in records:
        row = {"id": r["id"]}
        for c in ENRICHMENT_COLUMNS:
            if c in r:
                row[c] = r[c]
        payload.append(row)

    if args.dry_run:
        print(json.dumps(payload[:3], indent=2))
        print(f"… ({len(payload)} total rows)")
        return

    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type":  "application/json",
        "Prefer": "return=minimal",
    }

    # Fetch all existing player IDs so we only PATCH rows that exist
    # (scraper found some BBR players not in our active roster — skipping them)
    r = requests.get(
        f"{url}/rest/v1/nba_game_players",
        params={"select": "id"},
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
        timeout=30,
    )
    r.raise_for_status()
    existing_ids = {row["id"] for row in r.json()}
    print(f"{len(existing_ids)} existing players in nba_game_players")

    updates   = [row for row in payload if row["id"] in existing_ids]
    skipped   = len(payload) - len(updates)
    print(f"{len(updates)} to update, {skipped} skipped (not in active roster)")

    # PATCH one row at a time (PostgREST requires a filter for UPDATE).
    # Slow but safe — ~548 rows takes <1 min.
    ok, fail = 0, 0
    for i, row in enumerate(updates, 1):
        pid = row.pop("id")
        r = requests.patch(
            f"{url}/rest/v1/nba_game_players",
            params={"id": f"eq.{pid}"},
            headers=headers,
            json=row,
            timeout=30,
        )
        if r.status_code in (200, 204):
            ok += 1
        else:
            fail += 1
            print(f"  id={pid}: FAILED [{r.status_code}] {r.text[:200]}", file=sys.stderr)
        if i % 50 == 0:
            print(f"  …{i}/{len(updates)}")

    print(f"\nDone: {ok} updated, {fail} failed, {skipped} skipped.")


if __name__ == "__main__":
    main()
