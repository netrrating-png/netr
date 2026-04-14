-- NBA Connections Game (NYT Connections-style) schema
--
-- Creates:
--   1. Adds enrichment columns to nba_game_players (college, country, draft_pick, awards, etc.)
--   2. nba_connections_categories  - curated pool of 4-player groups (label + difficulty + player_ids[])
--   3. nba_connections_puzzles     - one row per day, 4 chosen categories
--   4. nba_connections_results     - per-user play history (mistakes, win/loss, solved groups)
--   5. pick_next_connections_puzzle() RPC — picks 4 non-overlapping categories for each upcoming day
--   6. nba_connections_today view  - convenience read joining puzzle + category rows
--   7. pg_cron job at 23:35 UTC (5 min after the mystery-player cron) to keep 7 days stocked
--
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE throughout.
--
-- Prereqs:
--   - 20260410_daily_game_schema.sql must already be applied (this depends on nba_game_players)
--   - Enrichment data must be loaded into nba_game_players before calling pick_next_connections_puzzle()

-- ─── PLAYER ENRICHMENT COLUMNS ─────────────────────────────
-- These columns are populated by tools/scrape_bbr_player_details.py →
-- tools/upsert_bbr_enrichment.py. All are nullable so enrichment can roll out gradually.
ALTER TABLE nba_game_players
    ADD COLUMN IF NOT EXISTS college              TEXT,
    ADD COLUMN IF NOT EXISTS country              TEXT,        -- "USA", "Serbia", "France"
    ADD COLUMN IF NOT EXISTS draft_year           INT,
    ADD COLUMN IF NOT EXISTS draft_round          INT,         -- 1, 2, or NULL (undrafted)
    ADD COLUMN IF NOT EXISTS draft_pick           INT,         -- overall pick number (1..60), NULL if undrafted
    ADD COLUMN IF NOT EXISTS championships        INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS all_star_count       INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS mvp_count            INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS finals_mvp_count     INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS dpoy_count           INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS roy                  BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS sixmoy_count         INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS mip_count            INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS hall_of_fame         BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS signature_shoe_brand TEXT;        -- "Nike", "Jordan", "Adidas", "Puma", "Under Armour", "New Balance", "Li-Ning", NULL

CREATE INDEX IF NOT EXISTS nba_game_players_college_idx    ON nba_game_players (college)     WHERE active;
CREATE INDEX IF NOT EXISTS nba_game_players_country_idx    ON nba_game_players (country)     WHERE active;
CREATE INDEX IF NOT EXISTS nba_game_players_draft_pick_idx ON nba_game_players (draft_pick)  WHERE active;

-- ─── CATEGORIES TABLE ──────────────────────────────────────
-- Curated pool of possible Connections groups. Each row is one "group of 4"
-- the RPC can pick from. Rebuilt periodically by tools/build_connections_categories.py
-- after enrichment refreshes, or edited by hand for hand-crafted themes.
CREATE TABLE IF NOT EXISTS nba_connections_categories (
    id              BIGSERIAL PRIMARY KEY,
    label           TEXT NOT NULL,                -- "Kentucky Wildcats", "Undrafted"
    difficulty      TEXT NOT NULL CHECK (difficulty IN ('easy','medium','hard','tricky')),
    kind            TEXT NOT NULL,                -- "college" / "country" / "draft_pick" / "awards" / "team" / "manual"
    kind_value      TEXT,                         -- e.g. "Kentucky", "Serbia", "1", NULL for manual
    player_ids      BIGINT[] NOT NULL,            -- all players matching this category (the RPC picks 4)
    active          BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (array_length(player_ids, 1) >= 4)
);

CREATE INDEX IF NOT EXISTS nba_connections_categories_active_idx ON nba_connections_categories (active, difficulty);

ALTER TABLE nba_connections_categories ENABLE ROW LEVEL SECURITY;

-- Read-only for clients (category labels are not secret; answers for today's puzzle
-- are indirected via nba_connections_puzzles which restricts by date).
DROP POLICY IF EXISTS "nba_connections_categories_select_all" ON nba_connections_categories;
CREATE POLICY "nba_connections_categories_select_all"
    ON nba_connections_categories FOR SELECT
    TO authenticated
    USING (true);

-- ─── PUZZLES TABLE ─────────────────────────────────────────
-- One row per calendar day (UTC). Holds the 4 chosen category IDs plus the exact
-- 4 player IDs picked from each (so the puzzle is stable even if the category pool
-- changes later).
CREATE TABLE IF NOT EXISTS nba_connections_puzzles (
    puzzle_date   DATE PRIMARY KEY,
    groups        JSONB NOT NULL,
    -- Shape: [{"category_id": 12, "label": "Kentucky Wildcats", "difficulty": "easy",
    --         "player_ids": [123, 456, 789, 101]}, ... x4]
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE nba_connections_puzzles ENABLE ROW LEVEL SECURITY;

-- Only today and past are readable — prevents spoilers.
DROP POLICY IF EXISTS "nba_connections_puzzles_select_today" ON nba_connections_puzzles;
CREATE POLICY "nba_connections_puzzles_select_today"
    ON nba_connections_puzzles FOR SELECT
    TO authenticated
    USING (puzzle_date <= CURRENT_DATE);

-- ─── RESULTS TABLE ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS nba_connections_results (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    puzzle_date     DATE NOT NULL,
    mistakes_used   INT NOT NULL CHECK (mistakes_used BETWEEN 0 AND 4),
    solved_groups   INT NOT NULL CHECK (solved_groups BETWEEN 0 AND 4),
    won             BOOLEAN NOT NULL,
    completed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, puzzle_date)
);

CREATE INDEX IF NOT EXISTS nba_connections_results_user_idx
    ON nba_connections_results (user_id, puzzle_date DESC);

ALTER TABLE nba_connections_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "nba_connections_results_select_own" ON nba_connections_results;
CREATE POLICY "nba_connections_results_select_own"
    ON nba_connections_results FOR SELECT
    TO authenticated
    USING (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "nba_connections_results_insert_own" ON nba_connections_results;
CREATE POLICY "nba_connections_results_insert_own"
    ON nba_connections_results FOR INSERT
    TO authenticated
    WITH CHECK (user_id::text = auth.uid()::text AND puzzle_date <= CURRENT_DATE);

-- ─── SCHEDULER FUNCTION ────────────────────────────────────
-- Ensures the next 7 days of Connections puzzles are populated.
--
-- Algorithm for each missing day:
--   1. Pick one category from each difficulty tier (easy, medium, hard, tricky)
--   2. Enforce no player appears in two of the four chosen categories
--      (prevents ambiguous puzzles)
--   3. Prefer categories not used in the last 30 days
--   4. From each chosen category, randomly select 4 player_ids
--   5. Store the puzzle as a JSONB groups array
--
-- Retries up to 20 times if a combination fails the overlap check.
CREATE OR REPLACE FUNCTION pick_next_connections_puzzle()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_date DATE;
    attempt_no  INT;
    easy_row    nba_connections_categories%ROWTYPE;
    med_row     nba_connections_categories%ROWTYPE;
    hard_row    nba_connections_categories%ROWTYPE;
    tricky_row  nba_connections_categories%ROWTYPE;
    picked_easy   BIGINT[];
    picked_med    BIGINT[];
    picked_hard   BIGINT[];
    picked_tricky BIGINT[];
    all_picked  BIGINT[];
    groups_json JSONB;
BEGIN
    FOR target_date IN
        SELECT generate_series(
            CURRENT_DATE,
            CURRENT_DATE + INTERVAL '6 days',
            INTERVAL '1 day'
        )::date
    LOOP
        -- Skip days that already have a puzzle
        IF EXISTS (SELECT 1 FROM nba_connections_puzzles WHERE puzzle_date = target_date) THEN
            CONTINUE;
        END IF;

        attempt_no := 0;
        groups_json := NULL;

        WHILE attempt_no < 20 AND groups_json IS NULL LOOP
            attempt_no := attempt_no + 1;

            -- Pick one active category per difficulty, preferring ones unused in the last 30 days
            SELECT * INTO easy_row   FROM nba_connections_categories
                WHERE active AND difficulty = 'easy'
                  AND NOT EXISTS (
                      SELECT 1 FROM nba_connections_puzzles p
                      WHERE p.puzzle_date > target_date - INTERVAL '30 days'
                        AND p.groups @> jsonb_build_array(jsonb_build_object('category_id', nba_connections_categories.id))
                  )
                ORDER BY random() LIMIT 1;

            SELECT * INTO med_row    FROM nba_connections_categories
                WHERE active AND difficulty = 'medium'
                  AND NOT EXISTS (
                      SELECT 1 FROM nba_connections_puzzles p
                      WHERE p.puzzle_date > target_date - INTERVAL '30 days'
                        AND p.groups @> jsonb_build_array(jsonb_build_object('category_id', nba_connections_categories.id))
                  )
                ORDER BY random() LIMIT 1;

            SELECT * INTO hard_row   FROM nba_connections_categories
                WHERE active AND difficulty = 'hard'
                  AND NOT EXISTS (
                      SELECT 1 FROM nba_connections_puzzles p
                      WHERE p.puzzle_date > target_date - INTERVAL '30 days'
                        AND p.groups @> jsonb_build_array(jsonb_build_object('category_id', nba_connections_categories.id))
                  )
                ORDER BY random() LIMIT 1;

            SELECT * INTO tricky_row FROM nba_connections_categories
                WHERE active AND difficulty = 'tricky'
                  AND NOT EXISTS (
                      SELECT 1 FROM nba_connections_puzzles p
                      WHERE p.puzzle_date > target_date - INTERVAL '30 days'
                        AND p.groups @> jsonb_build_array(jsonb_build_object('category_id', nba_connections_categories.id))
                  )
                ORDER BY random() LIMIT 1;

            -- Fallback: if the 30-day filter emptied a tier, pick any active row
            IF easy_row.id   IS NULL THEN SELECT * INTO easy_row   FROM nba_connections_categories WHERE active AND difficulty='easy'   ORDER BY random() LIMIT 1; END IF;
            IF med_row.id    IS NULL THEN SELECT * INTO med_row    FROM nba_connections_categories WHERE active AND difficulty='medium' ORDER BY random() LIMIT 1; END IF;
            IF hard_row.id   IS NULL THEN SELECT * INTO hard_row   FROM nba_connections_categories WHERE active AND difficulty='hard'   ORDER BY random() LIMIT 1; END IF;
            IF tricky_row.id IS NULL THEN SELECT * INTO tricky_row FROM nba_connections_categories WHERE active AND difficulty='tricky' ORDER BY random() LIMIT 1; END IF;

            -- Any tier still empty means the pool is unhealthy; bail
            IF easy_row.id IS NULL OR med_row.id IS NULL OR hard_row.id IS NULL OR tricky_row.id IS NULL THEN
                EXIT;
            END IF;

            -- Randomly pick 4 players from each selected category's pool
            SELECT ARRAY(SELECT unnest(easy_row.player_ids)   ORDER BY random() LIMIT 4) INTO picked_easy;
            SELECT ARRAY(SELECT unnest(med_row.player_ids)    ORDER BY random() LIMIT 4) INTO picked_med;
            SELECT ARRAY(SELECT unnest(hard_row.player_ids)   ORDER BY random() LIMIT 4) INTO picked_hard;
            SELECT ARRAY(SELECT unnest(tricky_row.player_ids) ORDER BY random() LIMIT 4) INTO picked_tricky;

            all_picked := picked_easy || picked_med || picked_hard || picked_tricky;

            -- Overlap check: 16 distinct player IDs required
            IF (SELECT COUNT(DISTINCT x) FROM unnest(all_picked) x) <> 16 THEN
                CONTINUE; -- retry
            END IF;

            -- Also ensure no picked player is ALSO present in a different chosen
            -- category's full eligibility list (prevents "this player fits 2 categories")
            IF EXISTS (
                SELECT 1 FROM unnest(picked_easy) pid
                WHERE pid = ANY(med_row.player_ids) OR pid = ANY(hard_row.player_ids) OR pid = ANY(tricky_row.player_ids)
            ) OR EXISTS (
                SELECT 1 FROM unnest(picked_med) pid
                WHERE pid = ANY(easy_row.player_ids) OR pid = ANY(hard_row.player_ids) OR pid = ANY(tricky_row.player_ids)
            ) OR EXISTS (
                SELECT 1 FROM unnest(picked_hard) pid
                WHERE pid = ANY(easy_row.player_ids) OR pid = ANY(med_row.player_ids) OR pid = ANY(tricky_row.player_ids)
            ) OR EXISTS (
                SELECT 1 FROM unnest(picked_tricky) pid
                WHERE pid = ANY(easy_row.player_ids) OR pid = ANY(med_row.player_ids) OR pid = ANY(hard_row.player_ids)
            ) THEN
                CONTINUE; -- retry
            END IF;

            -- Build the JSONB groups payload
            groups_json := jsonb_build_array(
                jsonb_build_object('category_id', easy_row.id,   'label', easy_row.label,   'difficulty', 'easy',   'player_ids', to_jsonb(picked_easy)),
                jsonb_build_object('category_id', med_row.id,    'label', med_row.label,    'difficulty', 'medium', 'player_ids', to_jsonb(picked_med)),
                jsonb_build_object('category_id', hard_row.id,   'label', hard_row.label,   'difficulty', 'hard',   'player_ids', to_jsonb(picked_hard)),
                jsonb_build_object('category_id', tricky_row.id, 'label', tricky_row.label, 'difficulty', 'tricky', 'player_ids', to_jsonb(picked_tricky))
            );
        END LOOP;

        IF groups_json IS NOT NULL THEN
            INSERT INTO nba_connections_puzzles (puzzle_date, groups)
            VALUES (target_date, groups_json);
        END IF;
    END LOOP;
END;
$$;

-- ─── CRON JOB ──────────────────────────────────────────────
-- Runs at 23:35 UTC nightly (5 min after pick_next_daily_puzzle)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pick_next_connections_puzzle') THEN
        PERFORM cron.unschedule('pick_next_connections_puzzle');
    END IF;

    PERFORM cron.schedule(
        'pick_next_connections_puzzle',
        '35 23 * * *',
        $cron$SELECT pick_next_connections_puzzle();$cron$
    );
END;
$$;

-- ─── HELPER VIEW ───────────────────────────────────────────
-- The iOS app reads this view to load today's puzzle with all 16 players'
-- full details inlined. One network round trip for the whole puzzle.
CREATE OR REPLACE VIEW nba_connections_today AS
SELECT
    p.puzzle_date,
    p.groups,
    (
        SELECT jsonb_object_agg(pl.id::text, jsonb_build_object(
            'id',           pl.id,
            'name',         pl.name,
            'headshot_url', pl.headshot_url,
            'tier',         pl.tier
        ))
        FROM nba_game_players pl
        WHERE pl.id IN (
            SELECT (jsonb_array_elements_text(g->'player_ids'))::bigint
            FROM jsonb_array_elements(p.groups) g
        )
    ) AS players
FROM nba_connections_puzzles p
WHERE p.puzzle_date = CURRENT_DATE;

GRANT SELECT ON nba_connections_today TO authenticated;
