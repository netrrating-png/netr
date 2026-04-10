-- Daily Game (Wordle-style NBA player guessing) schema
--
-- Creates:
--   1. nba_game_players       - the pool of ~550 historical NBA players we draw from
--   2. nba_game_daily_puzzle  - one row per calendar day (UTC) naming that day's mystery player
--   3. nba_game_results       - per-user play history for streaks and stats
--   4. pick_next_daily_puzzle() - RPC that inserts the next 7 days of puzzles if missing
--   5. pg_cron job that runs pick_next_daily_puzzle() nightly at 23:30 UTC
--
-- Safe to re-run: all CREATEs use IF NOT EXISTS; the cron job is unscheduled
-- first to avoid duplicates.
--
-- How to apply:
--   1. Paste this file into the Supabase SQL Editor and click RUN.
--      (Dashboard -> SQL Editor -> New query -> paste -> Run)
--   2. Verify the `pg_cron` extension got enabled (Database -> Extensions).
--      If not, enable it manually, then re-run this migration.
--   3. After your nba_daily_players.json is uploaded to nba_game_players,
--      call SELECT pick_next_daily_puzzle(); once to seed the first week.

-- ─── EXTENSIONS ────────────────────────────────────────────
-- pg_cron ships with Supabase but has to be explicitly enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ─── PLAYERS TABLE ─────────────────────────────────────────
-- The pool of NBA players eligible to be chosen as the daily answer.
-- Populated once (and occasionally refreshed) from the nba_api-built JSON.
CREATE TABLE IF NOT EXISTS nba_game_players (
    id              BIGINT PRIMARY KEY,               -- nba.com PERSON_ID
    name            TEXT NOT NULL,
    retired         BOOLEAN NOT NULL,
    years_active    TEXT NOT NULL,                    -- "2009-present" or "1996-2016"
    from_year       INT NOT NULL,
    to_year         INT,                              -- null if still active
    draft_team      TEXT,
    teams           TEXT[] NOT NULL DEFAULT '{}',     -- full list of teams played for
    position        TEXT,
    height          TEXT,                             -- "6-2"
    jerseys         TEXT[] NOT NULL DEFAULT '{}',
    tier            TEXT NOT NULL CHECK (tier IN ('superstar','solid','deep_cut')),
    career_games    INT NOT NULL DEFAULT 0,
    career_minutes  INT NOT NULL DEFAULT 0,
    fun_fact        TEXT,                             -- hand-curated 5th hint; optional
    active          BOOLEAN NOT NULL DEFAULT true,    -- set false to exclude without deleting
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS nba_game_players_tier_idx     ON nba_game_players (tier) WHERE active;
CREATE INDEX IF NOT EXISTS nba_game_players_name_idx     ON nba_game_players (lower(name));

ALTER TABLE nba_game_players ENABLE ROW LEVEL SECURITY;

-- Everyone signed in can read the full player list (needed for guess autocomplete)
DROP POLICY IF EXISTS "nba_game_players_select_all" ON nba_game_players;
CREATE POLICY "nba_game_players_select_all"
    ON nba_game_players FOR SELECT
    TO authenticated
    USING (true);

-- No client writes. Admins upload via the Supabase dashboard / service role.

-- ─── DAILY PUZZLE TABLE ────────────────────────────────────
-- One row per calendar day (UTC). The scheduler pre-populates the next 7 days
-- so the app always has today's puzzle ready even if cron is briefly down.
CREATE TABLE IF NOT EXISTS nba_game_daily_puzzle (
    puzzle_date     DATE PRIMARY KEY,
    player_id       BIGINT NOT NULL REFERENCES nba_game_players(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE nba_game_daily_puzzle ENABLE ROW LEVEL SECURITY;

-- Everyone signed in can read today's puzzle (and any previously revealed ones).
-- Future puzzles are fine to expose because the pool is public and users can't
-- "cheat ahead" in the app UI; if you want stricter secrecy, add a WHERE clause
-- restricting to puzzle_date <= CURRENT_DATE.
DROP POLICY IF EXISTS "nba_game_daily_puzzle_select_all" ON nba_game_daily_puzzle;
CREATE POLICY "nba_game_daily_puzzle_select_all"
    ON nba_game_daily_puzzle FOR SELECT
    TO authenticated
    USING (puzzle_date <= CURRENT_DATE);  -- users only see today and past

-- ─── RESULTS TABLE ─────────────────────────────────────────
-- Per-user play history. Drives streak + stats + optional leaderboards.
CREATE TABLE IF NOT EXISTS nba_game_results (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    puzzle_date     DATE NOT NULL,
    guess_count     INT NOT NULL CHECK (guess_count BETWEEN 1 AND 6),
    won             BOOLEAN NOT NULL,
    completed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, puzzle_date)
);

CREATE INDEX IF NOT EXISTS nba_game_results_user_idx ON nba_game_results (user_id, puzzle_date DESC);

ALTER TABLE nba_game_results ENABLE ROW LEVEL SECURITY;

-- Users can read their own results
DROP POLICY IF EXISTS "nba_game_results_select_own" ON nba_game_results;
CREATE POLICY "nba_game_results_select_own"
    ON nba_game_results FOR SELECT
    TO authenticated
    USING (user_id::text = auth.uid()::text);

-- Users can insert their own result once per day (UNIQUE constraint enforces "once")
DROP POLICY IF EXISTS "nba_game_results_insert_own" ON nba_game_results;
CREATE POLICY "nba_game_results_insert_own"
    ON nba_game_results FOR INSERT
    TO authenticated
    WITH CHECK (user_id::text = auth.uid()::text);

-- ─── SCHEDULER FUNCTION ────────────────────────────────────
-- Ensures the next 7 days of puzzles are populated. Idempotent.
--
-- Selection logic:
--   - Randomly picks an active player from nba_game_players
--   - Weighted toward superstars > solid > deep_cut (70/25/5 split)
--   - Avoids picking a player used in the last 90 days
--
-- Called nightly by pg_cron, and safe to call manually any time.
CREATE OR REPLACE FUNCTION pick_next_daily_puzzle()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_date DATE;
    chosen_player_id BIGINT;
    tier_roll FLOAT;
    chosen_tier TEXT;
BEGIN
    -- Fill today + next 6 days if missing
    FOR target_date IN
        SELECT generate_series(
            CURRENT_DATE,
            CURRENT_DATE + INTERVAL '6 days',
            INTERVAL '1 day'
        )::date
    LOOP
        -- Skip days that already have a puzzle
        IF EXISTS (SELECT 1 FROM nba_game_daily_puzzle WHERE puzzle_date = target_date) THEN
            CONTINUE;
        END IF;

        -- Pick a tier weighted 70% superstar / 25% solid / 5% deep_cut
        tier_roll := random();
        IF tier_roll < 0.70 THEN
            chosen_tier := 'superstar';
        ELSIF tier_roll < 0.95 THEN
            chosen_tier := 'solid';
        ELSE
            chosen_tier := 'deep_cut';
        END IF;

        -- Pick a random active player from that tier that hasn't been used recently
        SELECT p.id INTO chosen_player_id
        FROM nba_game_players p
        WHERE p.active
          AND p.tier = chosen_tier
          AND NOT EXISTS (
              SELECT 1 FROM nba_game_daily_puzzle d
              WHERE d.player_id = p.id
                AND d.puzzle_date > target_date - INTERVAL '90 days'
          )
        ORDER BY random()
        LIMIT 1;

        -- If that tier has no fresh candidates, fall back to any active non-recent player
        IF chosen_player_id IS NULL THEN
            SELECT p.id INTO chosen_player_id
            FROM nba_game_players p
            WHERE p.active
              AND NOT EXISTS (
                  SELECT 1 FROM nba_game_daily_puzzle d
                  WHERE d.player_id = p.id
                    AND d.puzzle_date > target_date - INTERVAL '90 days'
              )
            ORDER BY random()
            LIMIT 1;
        END IF;

        -- If still null, the table is empty or every player is exhausted - skip
        IF chosen_player_id IS NULL THEN
            CONTINUE;
        END IF;

        INSERT INTO nba_game_daily_puzzle (puzzle_date, player_id)
        VALUES (target_date, chosen_player_id);
    END LOOP;
END;
$$;

-- ─── CRON JOB ──────────────────────────────────────────────
-- Runs every night at 23:30 UTC to ensure tomorrow's puzzle exists before
-- users roll into the new UTC day. Unschedule first for idempotent re-runs.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pick_next_daily_puzzle') THEN
        PERFORM cron.unschedule('pick_next_daily_puzzle');
    END IF;

    PERFORM cron.schedule(
        'pick_next_daily_puzzle',
        '30 23 * * *',
        $cron$SELECT pick_next_daily_puzzle();$cron$
    );
END;
$$;

-- ─── HELPER VIEW ───────────────────────────────────────────
-- Convenience view the iOS app reads to get today's puzzle joined with player info
-- in a single round trip.
CREATE OR REPLACE VIEW nba_game_today AS
SELECT
    d.puzzle_date,
    p.id,
    p.name,
    p.retired,
    p.years_active,
    p.from_year,
    p.to_year,
    p.draft_team,
    p.teams,
    p.position,
    p.height,
    p.jerseys,
    p.tier,
    p.fun_fact
FROM nba_game_daily_puzzle d
JOIN nba_game_players p ON p.id = d.player_id
WHERE d.puzzle_date = CURRENT_DATE;

-- Grant select on the view to authenticated users
GRANT SELECT ON nba_game_today TO authenticated;
