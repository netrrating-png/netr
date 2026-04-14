# Workflow: Generate NBA Connections Puzzles

## Objective

Populate `nba_connections_daily` with daily Connections puzzles for the next N days.
Each puzzle has 4 categories × 3 players = 12 tiles. Category types rotate daily so
users can't learn a fixed pattern.

## Prerequisites

Run this workflow in order. Steps 1–3 are one-time setup; step 4 runs weekly.

### Step 1 (one-time) — Apply the enrichment migration

Paste `supabase/migrations/20260414_enrich_players.sql` into the Supabase SQL Editor
and run it. This adds `country`, `college`, `draft_year`, `draft_round`, `draft_number`
columns to `nba_game_players`.

### Step 2 (one-time) — Enrich existing players

```bash
export SUPABASE_URL="https://<project>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"

# Smoke test first (20 players)
python tools/enrich_connections_data.py --limit 20

# Full run (~40 min — throttled at 4 s/call)
python tools/enrich_connections_data.py
```

Use `--resume` to skip already-processed players if the run is interrupted:

```bash
python tools/enrich_connections_data.py --resume
```

Progress is checkpointed to `.tmp/enrich_connections.checkpoint.json` every 50 players.

> **Note:** The same stats.nba.com rate limits apply here as for the player
> dataset builder. If you hit a block, wait 5–10 minutes and re-run with `--resume`.

### Step 3 (one-time) — Apply the Connections game migration

Paste `supabase/migrations/20260414_connections_game.sql` into the Supabase SQL Editor.
This creates `nba_connections_daily`, `nba_connections_results`, and the `nba_connections_today` view.

### Step 4 (weekly) — Generate puzzles

```bash
export SUPABASE_URL="https://<project>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"

# Dry run — print puzzles to stdout without writing to Supabase
python tools/generate_connections_puzzles.py --dry-run

# Generate next 7 days (idempotent — skips dates already populated)
python tools/generate_connections_puzzles.py

# Generate further ahead
python tools/generate_connections_puzzles.py --days 30
```

## How the generator works

1. Loads all active players from `nba_game_players` (all fields including enriched ones).
2. For each date, shuffles the list of category types and greedily picks the first 4 that
   can be filled with ≥3 non-overlapping players.
3. Assigns difficulty 1–4 (Yellow → Purple) based on category type.
4. Sorts groups by difficulty so Yellow is first (the client can display in any order).
5. Upserts into `nba_connections_daily` using `Prefer: resolution=merge-duplicates`.

### Category types

| Type           | Example label                              | Data field       |
|----------------|--------------------------------------------|------------------|
| team           | "All played for the Miami Heat"            | teams[]          |
| draft_team     | "All drafted by the San Antonio Spurs"     | draft_team       |
| jersey         | "All wore #23"                             | jerseys[]        |
| era_debut      | "All debuted in the 1990s"                 | from_year        |
| college        | "All went to Duke"                         | college          |
| country        | "All from France"                          | country          |
| draft_class    | "All drafted in 2003"                      | draft_year       |
| lottery_pick   | "All were lottery picks (top 14)"          | draft_number ≤14 |
| first_overall  | "All were #1 overall draft picks"          | draft_number = 1 |
| undrafted      | "All went undrafted"                       | draft_round null |
| height_tall    | "All are at least 7 feet tall"             | height ≥ 7-0     |
| height_short   | "All are 6'2\" or shorter"                 | height ≤ 6-2     |
| active_year    | "All were active during the 2010-11 season"| from/to_year     |

## Edge cases and known quirks

- **College data is sparse.** Not every player has a college on record
  (international players, high-school draftees). The enrichment script sets `college = null`
  for these — they won't appear in `college` category groups, which is correct.
- **Height data may be null** for players whose bio enrichment was skipped. The
  `height_tall` and `height_short` types are only used when ≥5 qualifying players exist
  in the available (non-overlapping) pool.
- **First overall picks** is a rare category — there are ~30 players in a 550-player pool.
  If fewer than 3 are available (due to overlaps with earlier groups), this type is skipped.
- **If the generator can't assemble 4 groups** for a date, it prints a warning and skips
  that date. Re-run with a different random seed by changing the date or shuffling the
  pool manually.
- **Supabase upsert is idempotent.** Running the generator multiple times for the same
  date replaces the existing puzzle with a new one. Avoid re-running for past dates once
  users have started playing them.

## Self-improvement log

*(Update this section when you discover new constraints or better approaches.)*

- *(none yet — first run pending)*
