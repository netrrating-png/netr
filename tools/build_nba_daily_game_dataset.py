"""
Build the NBA daily-game player dataset.

Pulls every NBA player from 1990 onward via the `nba_api` community library,
filters out obscure/short-lived careers, ranks the rest by a simple fame
proxy (career minutes played), picks ~550 across three fame tiers, and
writes the result to .tmp/nba_daily_players.json.

Output JSON (one object per player):
    {
        "id": <nba_person_id>,
        "name": "Stephen Curry",
        "retired": false,
        "yearsActive": "2009-present",
        "fromYear": 2009,
        "toYear": null,
        "draftTeam": "Golden State Warriors",
        "teams": ["Golden State Warriors"],
        "position": "PG",
        "height": "6-2",
        "jerseys": ["30"],
        "tier": "superstar",   // "superstar" | "solid" | "deep_cut"
        "careerGames": 1030,
        "careerMinutes": 36500,
        "funFact": null        // hand-curated later for top ~150
    }

Usage:
    python tools/build_nba_daily_game_dataset.py
    python tools/build_nba_daily_game_dataset.py --limit 50      # quick test
    python tools/build_nba_daily_game_dataset.py --skip-enrich   # skip CommonPlayerInfo calls

Notes / learned behavior (keep this in sync with the workflow doc):
- `nba_api` talks to stats.nba.com, which has a courtesy rate limit.
  We sleep ~0.6s between calls. Full run takes roughly 30-60 minutes
  depending on how many players survive the filters.
- If a call 429s or times out, the script backs off exponentially and
  retries up to 3 times before skipping that player.
- Draft team is approximated as the first team in the player's career
  stats (close enough for a Wordle-style hint; doesn't matter if they
  were traded on draft night).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Optional

try:
    from nba_api.stats.endpoints import (
        commonallplayers,
        commonplayerinfo,
        playercareerstats,
    )
    from nba_api.stats.static import teams as static_teams
except ImportError:
    print(
        "nba_api is not installed. Install with:\n"
        "    pip install nba_api\n"
        "See workflows/build_nba_daily_game_dataset.md for full setup.",
        file=sys.stderr,
    )
    sys.exit(1)


# -----------------------------------------------------------------------------
# Constants — tune these to change pool size / difficulty
# -----------------------------------------------------------------------------

MIN_FROM_YEAR = 1990          # Only players who debuted in 1990 or later
MIN_SEASONS = 2               # Must have played at least 2 seasons
MIN_CAREER_GAMES = 100        # Must have played at least 100 career games

TIER_SIZES = {
    "superstar": 100,         # Top 100 by career minutes
    "solid":     250,         # Ranks 101-350
    "deep_cut":  200,         # Ranks 351-550
}
TOTAL_POOL = sum(TIER_SIZES.values())  # 550

REQUEST_SLEEP_SECONDS = 4.0   # Courtesy throttle between stats.nba.com calls
MAX_RETRIES = 3
RETRY_BACKOFF_BASE = 3.0      # 3s, 9s, 27s
REQUEST_TIMEOUT = 60          # seconds per HTTP call

# Adaptive cooldown: if we see this many consecutive failures, assume the IP
# is soft-blocked and sleep for COOLDOWN_SECONDS before trying again. Resets
# to zero on the next successful call.
COOLDOWN_THRESHOLD = 2
COOLDOWN_SECONDS = 300  # 5 minutes — stats.nba.com blocks are stubborn

# Save partial progress every N players so a mid-run crash/block doesn't
# destroy everything we've collected.
CHECKPOINT_EVERY = 50

OUTPUT_PATH = Path(".tmp") / "nba_daily_players.json"
CHECKPOINT_PATH = Path(".tmp") / "nba_daily_players.checkpoint.json"


# -----------------------------------------------------------------------------
# Data classes
# -----------------------------------------------------------------------------


@dataclass
class CandidatePlayer:
    id: int
    name: str
    from_year: int
    to_year: int
    is_active: bool

    # Populated during career-stats pass
    career_games: int = 0
    career_minutes: int = 0
    teams: list[str] = field(default_factory=list)
    draft_team: Optional[str] = None

    # Populated during enrich pass (CommonPlayerInfo)
    position: Optional[str] = None
    height: Optional[str] = None
    jerseys: list[str] = field(default_factory=list)


# -----------------------------------------------------------------------------
# Network helpers (retry + throttle)
# -----------------------------------------------------------------------------


# Global counter of consecutive failures across calls. Reset on success.
_consecutive_failures = 0


def _call_with_retry(fn, *args, **kwargs):
    """Call an nba_api endpoint with exponential backoff on failure.

    Always passes `timeout=REQUEST_TIMEOUT` to the endpoint so we aren't
    stuck on nba_api's default 30s for the initial slow calls.

    After COOLDOWN_THRESHOLD consecutive failures, sleep COOLDOWN_SECONDS
    before the next attempt (the stats.nba.com IP block typically clears
    within 60-120s).
    """
    global _consecutive_failures
    kwargs.setdefault("timeout", REQUEST_TIMEOUT)

    if _consecutive_failures >= COOLDOWN_THRESHOLD:
        print(
            f"    cooldown: {_consecutive_failures} consecutive failures, "
            f"sleeping {COOLDOWN_SECONDS}s before next call",
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
        except Exception as err:  # noqa: BLE001 - nba_api raises many types
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
# Checkpointing — partial-progress persistence
# -----------------------------------------------------------------------------


def save_checkpoint(survivors: list[CandidatePlayer], path: Path = CHECKPOINT_PATH) -> None:
    """Serialize the career-stats-enriched survivors so we can resume later."""
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = [asdict(p) for p in survivors]
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload))
    tmp.replace(path)


def load_checkpoint(path: Path = CHECKPOINT_PATH) -> list[CandidatePlayer]:
    """Load previously-enriched survivors. Returns empty list if none."""
    if not path.exists():
        return []
    try:
        rows = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError) as err:
        print(f"  warning: could not read checkpoint: {err}", file=sys.stderr)
        return []
    restored: list[CandidatePlayer] = []
    for row in rows:
        try:
            restored.append(CandidatePlayer(**row))
        except TypeError as err:
            print(f"  warning: skipping malformed checkpoint row: {err}", file=sys.stderr)
    return restored


# -----------------------------------------------------------------------------
# Pipeline steps
# -----------------------------------------------------------------------------


def fetch_all_players() -> list[CandidatePlayer]:
    """Step 1: Pull every NBA player ever and filter to debut >= 1990, 2+ seasons."""
    print("Fetching all-time player list...")
    resp = _call_with_retry(commonallplayers.CommonAllPlayers, is_only_current_season=0)
    rows = resp.get_normalized_dict()["CommonAllPlayers"]
    print(f"  Total players in NBA history: {len(rows)}")

    candidates: list[CandidatePlayer] = []
    for row in rows:
        try:
            from_year = int(row["FROM_YEAR"])
            to_year = int(row["TO_YEAR"])
        except (KeyError, ValueError, TypeError):
            continue

        if from_year < MIN_FROM_YEAR:
            continue
        if (to_year - from_year) < (MIN_SEASONS - 1):
            continue

        candidates.append(
            CandidatePlayer(
                id=int(row["PERSON_ID"]),
                name=row["DISPLAY_FIRST_LAST"],
                from_year=from_year,
                to_year=to_year,
                # ROSTERSTATUS == 1 means currently on a roster
                is_active=bool(int(row.get("ROSTERSTATUS") or 0) == 1),
            )
        )

    print(f"  After year/season filter (>= {MIN_FROM_YEAR}, {MIN_SEASONS}+ seasons): {len(candidates)}")
    return candidates


def enrich_with_career_stats(
    candidates: list[CandidatePlayer],
    team_id_to_name: dict[int, str],
) -> list[CandidatePlayer]:
    """Step 2: For each candidate, pull career totals + team list. Filter on games played.

    Supports resume-from-checkpoint: if `.tmp/nba_daily_players.checkpoint.json`
    exists from a prior run, those players are restored and their IDs are
    skipped on this pass. Checkpoint is re-saved every CHECKPOINT_EVERY new
    enrichments so a mid-run crash doesn't destroy progress.
    """
    print(f"\nFetching career stats for {len(candidates)} players (this is the slow step)...")

    survivors: list[CandidatePlayer] = list(load_checkpoint())
    processed_ids: set[int] = {p.id for p in survivors}
    if survivors:
        print(f"  Resumed from checkpoint: {len(survivors)} players already enriched")

    new_this_run = 0
    for i, player in enumerate(candidates, 1):
        if i % 25 == 0 or i == len(candidates):
            print(f"  [{i}/{len(candidates)}] {player.name}", flush=True)

        if player.id in processed_ids:
            continue

        try:
            resp = _call_with_retry(playercareerstats.PlayerCareerStats, player_id=player.id)
        except Exception as err:  # noqa: BLE001
            print(f"  skip {player.name}: career stats failed ({err})", file=sys.stderr)
            continue

        data = resp.get_normalized_dict()
        totals = data.get("CareerTotalsRegularSeason", [])
        if not totals:
            continue

        total = totals[0]
        career_games = int(total.get("GP") or 0)
        career_minutes = int(total.get("MIN") or 0)

        if career_games < MIN_CAREER_GAMES:
            continue

        # Walk season-by-season to collect unique teams (in chronological order)
        seasons = data.get("SeasonTotalsRegularSeason", [])
        seen_team_ids: set[int] = set()
        teams_ordered: list[str] = []
        first_team: Optional[str] = None
        for season in seasons:
            team_id = season.get("TEAM_ID")
            if not team_id or team_id in seen_team_ids:
                continue
            # TEAM_ID 0 means "Total" line for traded-mid-season players; skip
            if int(team_id) == 0:
                continue
            seen_team_ids.add(team_id)
            team_name = team_id_to_name.get(int(team_id)) or season.get("TEAM_ABBREVIATION") or "Unknown"
            teams_ordered.append(team_name)
            if first_team is None:
                first_team = team_name

        player.career_games = career_games
        player.career_minutes = career_minutes
        player.teams = teams_ordered
        player.draft_team = first_team  # approximation: first team they played for
        survivors.append(player)
        processed_ids.add(player.id)
        new_this_run += 1

        if new_this_run % CHECKPOINT_EVERY == 0:
            save_checkpoint(survivors)
            print(f"    checkpoint: {len(survivors)} total, +{new_this_run} this run", flush=True)

    # Final checkpoint write so the completed run is persisted
    save_checkpoint(survivors)
    print(f"  After games-played filter (>= {MIN_CAREER_GAMES}): {len(survivors)}")
    return survivors


def pick_pool(enriched: list[CandidatePlayer]) -> list[CandidatePlayer]:
    """Step 3: Rank by career minutes and pick tiered slices."""
    ranked = sorted(enriched, key=lambda p: p.career_minutes, reverse=True)

    pool: list[tuple[str, CandidatePlayer]] = []

    start = 0
    for tier_name in ("superstar", "solid", "deep_cut"):
        size = TIER_SIZES[tier_name]
        end = start + size
        slice_ = ranked[start:end]
        for p in slice_:
            pool.append((tier_name, p))
        start = end

    print(f"\nPicked {len(pool)} players across tiers:")
    for tier_name, size in TIER_SIZES.items():
        actual = sum(1 for t, _ in pool if t == tier_name)
        print(f"  {tier_name}: {actual}/{size}")

    return pool  # type: ignore[return-value]


def enrich_with_bio(
    pool: list[tuple[str, CandidatePlayer]],
    skip: bool,
) -> list[tuple[str, CandidatePlayer]]:
    """Step 4: For picked players, pull CommonPlayerInfo for position, height, jersey."""
    if skip:
        print("\nSkipping bio enrichment (--skip-enrich).")
        return pool

    print(f"\nFetching bio info for {len(pool)} picked players...")
    for i, (tier, player) in enumerate(pool, 1):
        if i % 25 == 0 or i == len(pool):
            print(f"  [{i}/{len(pool)}] {player.name}")

        try:
            resp = _call_with_retry(commonplayerinfo.CommonPlayerInfo, player_id=player.id)
        except Exception as err:  # noqa: BLE001
            print(f"  skip bio for {player.name}: {err}", file=sys.stderr)
            continue

        data = resp.get_normalized_dict()
        rows = data.get("CommonPlayerInfo", [])
        if not rows:
            continue
        info = rows[0]

        player.position = info.get("POSITION") or None
        player.height = info.get("HEIGHT") or None  # format: "6-3"
        jersey_raw = info.get("JERSEY") or ""
        player.jerseys = [j.strip() for j in jersey_raw.split(",") if j.strip()]

    return pool


# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------


def to_dict(tier: str, player: CandidatePlayer) -> dict:
    years_active = (
        f"{player.from_year}-present"
        if player.is_active
        else f"{player.from_year}-{player.to_year}"
    )
    return {
        "id": player.id,
        "name": player.name,
        "retired": not player.is_active,
        "yearsActive": years_active,
        "fromYear": player.from_year,
        "toYear": None if player.is_active else player.to_year,
        "draftTeam": player.draft_team,
        "teams": player.teams,
        "position": player.position,
        "height": player.height,
        "jerseys": player.jerseys,
        "tier": tier,
        "careerGames": player.career_games,
        "careerMinutes": player.career_minutes,
        "funFact": None,
        "headshotUrl": f"https://cdn.nba.com/headshots/nba/latest/1040x760/{player.id}.png",
    }


def write_output(pool: list[tuple[str, CandidatePlayer]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = [to_dict(tier, p) for tier, p in pool]
    path.write_text(json.dumps(payload, indent=2))
    print(f"\nWrote {len(payload)} players to {path}")


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Only process the first N candidates (for quick tests).",
    )
    parser.add_argument(
        "--skip-enrich",
        action="store_true",
        help="Skip the CommonPlayerInfo bio enrichment pass.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=OUTPUT_PATH,
        help=f"Output JSON path (default: {OUTPUT_PATH})",
    )
    parser.add_argument(
        "--letters",
        type=str,
        default=None,
        help=(
            "Only include players whose last name starts with letters in this range. "
            "Examples: 'I-Z' (I through Z), 'A-H', 'M-M' (only M). "
            "Case-insensitive."
        ),
    )
    parser.add_argument(
        "--from-checkpoint",
        action="store_true",
        help=(
            "Finalize from .tmp/nba_daily_players.checkpoint.json without hitting "
            "stats.nba.com. Use this when the API is rate-limited and you want to "
            "ship a partial dataset. Implies --skip-enrich."
        ),
    )
    args = parser.parse_args()

    # --from-checkpoint path: skip all network calls, load checkpoint, rank, write.
    if args.from_checkpoint:
        enriched = load_checkpoint()
        if not enriched:
            print("ERROR: no checkpoint found at", CHECKPOINT_PATH, file=sys.stderr)
            return 1
        print(f"Loaded {len(enriched)} players from checkpoint")
        if len(enriched) < TOTAL_POOL:
            print(
                f"\nWARNING: only {len(enriched)} survivors, less than target pool "
                f"({TOTAL_POOL}). Writing everything we have."
            )
            pool = [
                ("superstar" if p.career_minutes > 25000 else ("solid" if p.career_minutes > 10000 else "deep_cut"), p)
                for p in sorted(enriched, key=lambda x: x.career_minutes, reverse=True)
            ]
        else:
            pool = pick_pool(enriched)
        write_output(pool, args.output)
        return 0

    # Build team_id -> full name map once
    team_id_to_name = {t["id"]: t["full_name"] for t in static_teams.get_teams()}

    # Step 1: candidate list
    candidates = fetch_all_players()

    # Filter by last-name letter range (e.g. --letters I-Z)
    if args.letters:
        lo, hi = args.letters.upper().split("-")
        before = len(candidates)
        candidates = [
            c for c in candidates
            if c.name.split()[-1][0].upper() >= lo and c.name.split()[-1][0].upper() <= hi
        ]
        print(f"  Filtered to last names {lo}–{hi}: {len(candidates)} (was {before})")

    if args.limit:
        candidates = candidates[: args.limit]
        print(f"  (limited to first {args.limit} for test run)")

    # Step 2: career stats + filter by games played
    enriched = enrich_with_career_stats(candidates, team_id_to_name)

    # If the pool is thinner than expected (test runs), shrink the tiers
    if len(enriched) < TOTAL_POOL:
        print(
            f"\nWARNING: only {len(enriched)} survivors, less than target pool "
            f"({TOTAL_POOL}). Writing everything we have."
        )
        pool = [("superstar" if p.career_minutes > 25000 else "solid", p) for p in enriched]
    else:
        pool = pick_pool(enriched)

    # Step 3: bio enrichment
    pool = enrich_with_bio(pool, skip=args.skip_enrich)

    # Step 4: write
    write_output(pool, args.output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
