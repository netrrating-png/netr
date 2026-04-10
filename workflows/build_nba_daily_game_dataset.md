# Workflow: Build the NBA Daily Game Dataset

## Objective

Produce a curated JSON file of ~550 NBA players that powers the in-app
daily-guessing game (Wordle-style). Output is a one-time deliverable that
feeds the Supabase `nba_game_players` table. This workflow is re-runnable
whenever we want to refresh the pool (add rookies, remove retired players
that nobody remembers, etc.).

Output path: `.tmp/nba_daily_players.json`

## Required inputs

None — the data source is public and unauthenticated.

## Tool to use

`tools/build_nba_daily_game_dataset.py`

## Dependencies

This script depends on the `nba_api` Python library:

```bash
pip install nba_api
```

Python 3.9+ recommended. If the user has a virtualenv, activate it first.
If they don't have one, it's safe to install globally — `nba_api` has no
heavy dependencies.

## Data source: why `nba_api`

- **Free, no key, no account.** The `nba_api` community library wraps
  `stats.nba.com` (the same API NBA.com uses). GitHub: swar/nba_api.
- **Most comprehensive historical coverage** of any free NBA source —
  every player ever, career stats, bio, draft info.
- **One-time job.** We don't need live data at runtime; the game uses a
  fixed pool and a daily picker. If the pool goes stale, we re-run this.

### Fallbacks if `nba_api` is down

1. `balldontlie.io` — free public API, simpler schema, no draft info.
2. Kaggle "NBA Players" CSV datasets — fully static, no API.

Document any fallback use in a comment at the top of the output JSON
so future runs know which source generated it.

## How the script works

Four passes:

1. **Candidate pass** — `CommonAllPlayers(is_only_current_season=0)` returns
   every player in NBA history (~5000 rows). We filter to:
   - `FROM_YEAR >= 1990`
   - `TO_YEAR - FROM_YEAR >= 1` (min 2 seasons)

2. **Career-stats pass (slow)** — For each candidate, call
   `PlayerCareerStats(player_id=...)`. We extract:
   - Career total games played → used to filter out `< 100 games`.
   - Career total minutes → used to rank by fame.
   - Season-by-season team list → the "teams played for" hint.
   - First team chronologically → the "draft team" hint (close enough
     for game purposes; doesn't matter if they were traded on draft night).

3. **Tier selection** — Rank surviving players by career minutes, then slice:
   - **Superstars** (top 100): your LeBrons, Currys, KDs. Immediately recognizable.
   - **Solid names** (ranks 101–350): rotation players fans will recognize
     but not instantly (e.g., Boris Diaw, Mo Williams).
   - **Deep cuts** (ranks 351–550): reward basketball nerds (e.g., Kirk Hinrich,
     Jared Dudley).
   - Total pool: 550.

4. **Bio pass (slow)** — For the 550 picked players, call
   `CommonPlayerInfo(player_id=...)` to get position, height, and jersey numbers.
   These power the final "fun fact / obvious" hint.

Each endpoint call is throttled by `REQUEST_SLEEP_SECONDS` (~0.6s) with
exponential backoff on failure. Total run time: **30–60 minutes** depending
on how many candidates survive step 1.

## Usage

```bash
# Quick smoke test (first 50 candidates, skip bio pass)
python tools/build_nba_daily_game_dataset.py --limit 50 --skip-enrich

# Full production run
python tools/build_nba_daily_game_dataset.py

# Custom output path
python tools/build_nba_daily_game_dataset.py --output .tmp/test.json
```

## Expected output

`.tmp/nba_daily_players.json` — an array of 550 player objects:

```json
{
  "id": 201939,
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
  "tier": "superstar",
  "careerGames": 1030,
  "careerMinutes": 36500,
  "funFact": null
}
```

`funFact` is null by default — we hand-curate this for the top ~150 players
after the run (see "Post-run curation" below).

## Edge cases and known quirks

- **Traded mid-season players** show up as a `TEAM_ID = 0` "TOT" row in
  season stats. The script skips these.
- **Teams that changed names** (Seattle SuperSonics → OKC Thunder, Charlotte
  Bobcats → Hornets) will show up as the name at the time the player played
  there. That's historically correct and good for the hint.
- **Two-way / G-League players** are filtered out by the 100-games floor.
- **Still-active but injured players** (Kawhi's missed seasons, etc.) are
  fine — we use `FROM_YEAR` / `TO_YEAR` which the NBA updates at season end.
- If `nba_api` rate-limits us aggressively, the script backs off (2s, 4s, 8s)
  and retries up to 3 times before skipping a player. Skipped players are
  logged to stderr. Re-run the script if too many are skipped — the data will
  be mostly cached server-side so the second run is often cleaner.

## Post-run curation (human step)

Two things the human should do after the script finishes:

1. **Sanity-check the list.** Open `.tmp/nba_daily_players.json` and skim
   the `superstar` and `solid` tiers. If a household name is missing (e.g.,
   Kobe, Dirk), investigate whether they failed a filter (e.g., debuted
   before 1990). Adjust the script or hand-add them.

2. **Fill in `funFact` for the top ~150 players.** The fun fact is the
   final, nearly-obvious hint in the game (e.g., "Has made more 3-pointers
   than anyone in NBA history" for Steph). Two strategies:
   - Hand-write them — most accurate, slow.
   - Use a separate script to pull ESPN / Basketball-Reference summaries.
     (Future work — not part of this workflow.)

For the first ship, hand-writing 150 fun facts is fine. Players without a
fun fact fall back to a programmatic one at runtime (e.g.,
`"Stands {height}, wore jersey #{jersey}, played {position}"`).

## Self-improvement log

Update this section when you learn something new while running the workflow.

- *(none yet — first run pending)*
