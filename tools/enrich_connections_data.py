"""
Enrich nba_game_players with college, country, and draft detail fields.

These fields are already returned by the CommonPlayerInfo endpoint but were
previously discarded during the build_nba_daily_game_dataset.py bio pass.
Running this script fills them in so the Connections game generator can use
a wider category pool (college, country, draft class, lottery pick, etc.).

Prerequisites:
  1. Apply supabase/migrations/20260414_enrich_players.sql first.
  2. Set env vars (or create a .env file in the project root):
       SUPABASE_URL=https://<project>.supabase.co
       SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
  3. Install dependencies:
       pip install nba_api requests python-dotenv

Usage:
    python tools/enrich_connections_data.py             # all players (~40 min)
    python tools/enrich_connections_data.py --limit 20  # smoke test
    python tools/enrich_connections_data.py --resume    # skip already-enriched rows

Notes / learned behavior:
- stats.nba.com soft-blocks IPs after ~500 rapid requests.
  Base sleep is 4s. A 5-minute adaptive cooldown kicks in after 2
  consecutive failures.
- Checkpoint saved every 50 players to .tmp/enrich_connections.checkpoint.json.
  Re-running with --resume reads the checkpoint to skip already-done IDs.
- Supabase updates are sent in batches of 50 to stay under payload limits.
- Use the service-role key, NOT the anon key — anon can't write nba_game_players.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Optional

# -- optional .env loading (silently skip if python-dotenv not installed) ------
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# -- nba_api import ------------------------------------------------------------
try:
    from nba_api.stats.endpoints import commonplayerinfo
except ImportError:
    print(
        "nba_api is not installed. Install with:\n"
        "    pip install nba_api\n",
        file=sys.stderr,
    )
    sys.exit(1)

# -- requests import -----------------------------------------------------------
try:
    import requests
except ImportError:
    print("requests is not installed. Install with:\n    pip install requests", file=sys.stderr)
    sys.exit(1)


# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

REQUEST_SLEEP_SECONDS = 4.0   # courtesy throttle between stats.nba.com calls
MAX_RETRIES = 3
RETRY_BACKOFF_BASE = 3.0      # 3s, 9s, 27s
REQUEST_TIMEOUT = 60          # seconds per HTTP call

COOLDOWN_THRESHOLD = 2        # consecutive failures before cooling down
COOLDOWN_SECONDS = 300        # 5 minutes

CHECKPOINT_EVERY = 50
CHECKPOINT_PATH = Path(".tmp") / "enrich_connections.checkpoint.json"
SUPABASE_BATCH_SIZE = 50      # rows per Supabase upsert request

_consecutive_failures = 0


# -----------------------------------------------------------------------------
# Supabase helpers
# -----------------------------------------------------------------------------

def _supabase_headers(key: str) -> dict:
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates",
    }


def fetch_player_ids(url: str, key: str) -> list[dict]:
    """Return all rows from nba_game_players: id + enrichment columns."""
    resp = requests.get(
        f"{url}/rest/v1/nba_game_players",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
        },
        params={
            "select": "id,name,country,college,draft_year,draft_round,draft_number",
            "active": "eq.true",
            "order": "id.asc",
            "limit": "10000",
        },
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def upsert_enrichment_batch(url: str, key: str, rows: list[dict]) -> None:
    """Upsert a batch of enrichment rows into nba_game_players."""
    if not rows:
        return
    resp = requests.post(
        f"{url}/rest/v1/nba_game_players",
        headers=_supabase_headers(key),
        json=rows,
        timeout=30,
    )
    if resp.status_code >= 300:
        print(f"  Supabase upsert error {resp.status_code}: {resp.text[:300]}", file=sys.stderr)
        resp.raise_for_status()


# -----------------------------------------------------------------------------
# nba_api throttle helpers (same pattern as build_nba_daily_game_dataset.py)
# -----------------------------------------------------------------------------

def _call_with_retry(fn, *args, **kwargs):
    """Call an nba_api endpoint with exponential backoff and adaptive cooldown."""
    global _consecutive_failures
    kwargs.setdefault("timeout", REQUEST_TIMEOUT)

    if _consecutive_failures >= COOLDOWN_THRESHOLD:
        print(
            f"    cooldown: {_consecutive_failures} consecutive failures, "
            f"sleeping {COOLDOWN_SECONDS}s...",
            file=sys.stderr,
        )
        time.sleep(COOLDOWN_SECONDS)
        _consecutive_failures = 0

    last_err = None
    for attempt in range(MAX_RETRIES):
        try:
            result = fn(*args, **kwargs)
            time.sleep(REQUEST_SLEEP_SECONDS)
            _consecutive_failures = 0
            return result
        except Exception as err:  # noqa: BLE001
            last_err = err
            backoff = RETRY_BACKOFF_BASE ** attempt
            print(
                f"    retry {attempt + 1}/{MAX_RETRIES} after {backoff:.1f}s "
                f"({type(err).__name__}: {err})",
                file=sys.stderr,
            )
            time.sleep(backoff)
    _consecutive_failures += 1
    raise last_err  # type: ignore[misc]


# -----------------------------------------------------------------------------
# Checkpoint helpers
# -----------------------------------------------------------------------------

def save_checkpoint(done_ids: set[int]) -> None:
    CHECKPOINT_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = CHECKPOINT_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(sorted(done_ids)))
    tmp.replace(CHECKPOINT_PATH)


def load_checkpoint() -> set[int]:
    if not CHECKPOINT_PATH.exists():
        return set()
    try:
        return set(json.loads(CHECKPOINT_PATH.read_text()))
    except (json.JSONDecodeError, OSError) as err:
        print(f"  warning: could not read checkpoint: {err}", file=sys.stderr)
        return set()


# -----------------------------------------------------------------------------
# Extraction helpers
# -----------------------------------------------------------------------------

def _safe_int(val) -> Optional[int]:
    if val is None:
        return None
    s = str(val).strip()
    if s in ("", "Undrafted", "0"):
        return None
    try:
        return int(s)
    except ValueError:
        return None


def extract_enrichment(player_id: int) -> Optional[dict]:
    """Fetch CommonPlayerInfo and return the enrichment dict, or None on failure."""
    try:
        resp = _call_with_retry(commonplayerinfo.CommonPlayerInfo, player_id=player_id)
    except Exception as err:  # noqa: BLE001
        print(f"  skip player {player_id}: {err}", file=sys.stderr)
        return None

    data = resp.get_normalized_dict()
    rows = data.get("CommonPlayerInfo", [])
    if not rows:
        return None
    info = rows[0]

    # Country: normalize empty strings → null
    country = (info.get("COUNTRY") or "").strip() or None

    # College / school: normalize "None" string → null
    college_raw = (info.get("SCHOOL") or "").strip()
    college = None if college_raw.lower() in ("", "none", "n/a") else college_raw

    # Draft fields: "Undrafted" or "0" → null
    draft_year   = _safe_int(info.get("DRAFT_YEAR"))
    draft_round  = _safe_int(info.get("DRAFT_ROUND"))
    draft_number = _safe_int(info.get("DRAFT_NUMBER"))

    return {
        "id":           player_id,
        "country":      country,
        "college":      college,
        "draft_year":   draft_year,
        "draft_round":  draft_round,
        "draft_number": draft_number,
    }


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        metavar="N",
        help="Process at most N players (useful for smoke tests).",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Skip player IDs already recorded in the checkpoint file.",
    )
    args = parser.parse_args()

    supabase_url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not supabase_url or not supabase_key:
        print(
            "ERROR: Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars "
            "(or put them in a .env file).",
            file=sys.stderr,
        )
        return 1

    # -- fetch all active player IDs from Supabase ----------------------------
    print("Fetching player list from Supabase...")
    try:
        players = fetch_player_ids(supabase_url, supabase_key)
    except Exception as err:  # noqa: BLE001
        print(f"ERROR fetching players: {err}", file=sys.stderr)
        return 1

    print(f"  Found {len(players)} active players in nba_game_players")

    # -- resume support -------------------------------------------------------
    done_ids: set[int] = set()
    if args.resume:
        done_ids = load_checkpoint()
        print(f"  Resuming: {len(done_ids)} players already enriched (from checkpoint)")

    # -- filter to players that need enrichment --------------------------------
    todo = [p for p in players if p["id"] not in done_ids]
    if args.limit:
        todo = todo[: args.limit]

    print(f"  Processing {len(todo)} players...")

    # -- main enrichment loop -------------------------------------------------
    pending_upsert: list[dict] = []
    new_this_run = 0

    for i, player in enumerate(todo, 1):
        pid = player["id"]
        name = player.get("name", pid)

        if i % 25 == 0 or i == len(todo):
            print(f"  [{i}/{len(todo)}] {name}", flush=True)

        enrichment = extract_enrichment(pid)
        if enrichment is None:
            # Failed to fetch — count as done so we don't loop on it
            done_ids.add(pid)
            continue

        pending_upsert.append(enrichment)
        done_ids.add(pid)
        new_this_run += 1

        # -- flush to Supabase in batches ------------------------------------
        if len(pending_upsert) >= SUPABASE_BATCH_SIZE:
            print(f"  Upserting batch of {len(pending_upsert)} rows to Supabase...")
            try:
                upsert_enrichment_batch(supabase_url, supabase_key, pending_upsert)
            except Exception as err:  # noqa: BLE001
                print(f"  WARNING: Supabase upsert failed: {err}", file=sys.stderr)
            pending_upsert = []

        # -- checkpoint -------------------------------------------------------
        if new_this_run % CHECKPOINT_EVERY == 0:
            save_checkpoint(done_ids)

    # -- final flush ----------------------------------------------------------
    if pending_upsert:
        print(f"  Upserting final batch of {len(pending_upsert)} rows to Supabase...")
        try:
            upsert_enrichment_batch(supabase_url, supabase_key, pending_upsert)
        except Exception as err:  # noqa: BLE001
            print(f"  WARNING: final Supabase upsert failed: {err}", file=sys.stderr)

    save_checkpoint(done_ids)
    print(f"\nDone. Enriched {new_this_run} players this run.")
    print(f"Checkpoint saved to {CHECKPOINT_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
