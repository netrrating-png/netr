-- NBA Connections daily game schema.
--
-- Creates:
--   1. nba_connections_daily   - one row per calendar day with the day's 4-category puzzle
--   2. nba_connections_results - per-user play history (mistakes, win/loss)
--   3. nba_connections_today   - convenience view for the iOS client
--
-- Safe to re-run: all CREATEs use IF NOT EXISTS.
--
-- Prerequisite: 20260414_enrich_players.sql must be applied first so the
-- puzzle generator has college / country / draft fields available.
--
-- How to apply:
--   Paste into the Supabase SQL Editor and click RUN.
--   After applying, run the puzzle generator:
--     python tools/generate_connections_puzzles.py

-- ─── DAILY PUZZLE TABLE ────────────────────────────────────────────────────
-- One row per calendar day (UTC). Pre-populated by the Python generator script.
-- Each row's `categories` column is a JSON array of exactly 4 group objects:
--
--   [
--     {
--       "label":        "All played for the Miami Heat",
--       "type":         "team",
--       "difficulty":   1,
--       "player_ids":   [2544, 1497, 2216],
--       "player_names": ["LeBron James", "Dwyane Wade", "Chris Bosh"],
--       "headshot_urls": ["https://cdn.nba.com/...", ...]
--     },
--     ...
--   ]
--
-- difficulty 1 = Yellow (easiest), 4 = Purple (hardest), matching NYT Connections.

CREATE TABLE IF NOT EXISTS nba_connections_daily (
    puzzle_date  DATE         PRIMARY KEY,
    categories   JSONB        NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE nba_connections_daily ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read today's puzzle and any past puzzle.
-- The categories JSON doesn't contain spoiler info beyond what's visible
-- in the grid tiles, so it's safe to expose to the client.
DROP POLICY IF EXISTS "nba_connections_daily_select" ON nba_connections_daily;
CREATE POLICY "nba_connections_daily_select"
    ON nba_connections_daily FOR SELECT
    TO authenticated
    USING (puzzle_date <= CURRENT_DATE);

-- No client writes — puzzle generator uses the service role.


-- ─── RESULTS TABLE ─────────────────────────────────────────────────────────
-- Per-user game history. Drives streak and stats display.

CREATE TABLE IF NOT EXISTS nba_connections_results (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    puzzle_date  DATE         NOT NULL,
    won          BOOLEAN      NOT NULL,
    mistakes     INT          NOT NULL CHECK (mistakes BETWEEN 0 AND 4),
    completed_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (user_id, puzzle_date)
);

CREATE INDEX IF NOT EXISTS nba_connections_results_user_idx
    ON nba_connections_results (user_id, puzzle_date DESC);

ALTER TABLE nba_connections_results ENABLE ROW LEVEL SECURITY;

-- Users can read their own results
DROP POLICY IF EXISTS "nba_connections_results_select_own" ON nba_connections_results;
CREATE POLICY "nba_connections_results_select_own"
    ON nba_connections_results FOR SELECT
    TO authenticated
    USING (user_id::text = auth.uid()::text);

-- Users can insert their own result once per day (UNIQUE enforces "once")
DROP POLICY IF EXISTS "nba_connections_results_insert_own" ON nba_connections_results;
CREATE POLICY "nba_connections_results_insert_own"
    ON nba_connections_results FOR INSERT
    TO authenticated
    WITH CHECK (user_id::text = auth.uid()::text AND puzzle_date <= CURRENT_DATE);


-- ─── HELPER VIEW ───────────────────────────────────────────────────────────
-- Single-query convenience view for the iOS client to get today's puzzle.

CREATE OR REPLACE VIEW nba_connections_today AS
SELECT
    puzzle_date,
    categories
FROM nba_connections_daily
WHERE puzzle_date = CURRENT_DATE;

GRANT SELECT ON nba_connections_today TO authenticated;
