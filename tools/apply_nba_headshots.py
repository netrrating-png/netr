#!/usr/bin/env python3
"""
Reads .tmp/nba_id_matches.json (produced by fetch_nba_ids.py) and updates
nba_game_players in Supabase so headshot_url points at the official NBA CDN.

Steps:
  1. Ensure the nba_id column exists on nba_game_players. If it doesn't, the
     accompanying SQL migration `supabase/migrations/20260427_add_nba_id_to_game_players.sql`
     must be applied via the Supabase dashboard's SQL editor (or `supabase db push`).
     This script will detect the column and print clear instructions if missing.
  2. PATCH each matched row with `nba_id` and `headshot_url` (the new CDN URL).
  3. Print a final report: rows updated, rows skipped (no match), HTTP errors.

Usage:
    python3 tools/apply_nba_headshots.py             # patches every matched row
    python3 tools/apply_nba_headshots.py --dry-run   # prints what would change

Credentials come from .env (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY).
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
INPUT_PATH = ROOT / ".tmp" / "nba_id_matches.json"
MIGRATION_PATH = ROOT / "supabase" / "migrations" / "20260427_add_nba_id_to_game_players.sql"


def load_env(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def column_exists(supabase_url: str, key: str, column: str) -> bool:
    """Probe by selecting just that column with limit=1; PostgREST returns
    400 if the column doesn't exist."""
    hdrs = {"apikey": key, "Authorization": f"Bearer {key}"}
    r = requests.get(
        f"{supabase_url}/rest/v1/nba_game_players",
        params={"select": column, "limit": "1"},
        headers=hdrs,
        timeout=15,
    )
    return r.status_code == 200


def patch_player(
    supabase_url: str,
    key: str,
    pk: int,
    nba_id: int,
    headshot_url: str,
    has_nba_id_col: bool,
) -> tuple[bool, int, str]:
    body: dict = {"headshot_url": headshot_url}
    if has_nba_id_col:
        body["nba_id"] = nba_id
    hdrs = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }
    r = requests.patch(
        f"{supabase_url}/rest/v1/nba_game_players",
        params={"id": f"eq.{pk}"},
        headers=hdrs,
        json=body,
        timeout=20,
    )
    ok = r.status_code in (200, 204)
    return ok, r.status_code, r.text[:200] if not ok else ""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true",
                    help="don't actually patch, just print summary")
    args = ap.parse_args()

    load_env(ROOT / ".env")
    supabase_url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not supabase_url or not key:
        sys.exit("SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY required (set in .env)")

    if not INPUT_PATH.exists():
        sys.exit(f"missing {INPUT_PATH} — run tools/fetch_nba_ids.py first")

    matches = json.loads(INPUT_PATH.read_text())
    matched_rows = [m for m in matches if m.get("matched")]
    skipped = [m for m in matches if not m.get("matched")]
    print(f"[input] {len(matched_rows)} matched, {len(skipped)} skipped")

    has_col = column_exists(supabase_url, key, "nba_id")
    if not has_col:
        print(
            "[schema] nba_game_players.nba_id column does NOT exist. The script\n"
            "         will still update headshot_url for matched rows, but to\n"
            "         persist the NBA person ID column you must apply the migration:\n\n"
            f"           {MIGRATION_PATH.relative_to(ROOT)}\n\n"
            "         Open Supabase Dashboard → SQL Editor → New query, paste the\n"
            "         contents of that file, and click Run. Then re-run this script\n"
            "         with --dry-run to confirm the column is detected.\n"
        )

    if args.dry_run:
        sample = matched_rows[:5]
        for m in sample:
            print(f"  would PATCH id={m['id']:>8}  {m['name']:<28}  → {m['headshot_url']}")
        if len(matched_rows) > len(sample):
            print(f"  …+{len(matched_rows) - len(sample)} more")
        for s in skipped:
            print(f"  SKIP id={s['id']:>8}  {s['name']:<28}  ({s.get('source','no-match')})")
        return

    ok = fail = 0
    fail_details: list[str] = []
    for i, m in enumerate(matched_rows, 1):
        success, status, err = patch_player(
            supabase_url, key, m["id"], m["nba_id"], m["headshot_url"], has_col
        )
        if success:
            ok += 1
        else:
            fail += 1
            fail_details.append(f"id={m['id']} {m['name']!r} -> HTTP {status}: {err}")
        if i % 50 == 0:
            print(f"  …{i}/{len(matched_rows)} — {ok} ok, {fail} failed")

    print(f"\n[done] updated {ok}/{len(matched_rows)} rows, "
          f"{fail} HTTP errors, {len(skipped)} unmatched skipped")
    if fail_details:
        print("\nFailures:")
        for line in fail_details:
            print(f"  {line}")
    if skipped:
        print("\nSkipped (no NBA CDN match):")
        for s in skipped:
            print(f"  id={s['id']:>8}  {s['name']}")


if __name__ == "__main__":
    main()
