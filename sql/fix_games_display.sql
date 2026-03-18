-- ============================================================
-- NETR: Fix games not showing under court Games tab
-- Run this in Supabase SQL Editor → New query → Run
-- ============================================================

-- ─── 1. Ensure courts has all columns the app needs ─────────
ALTER TABLE courts ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS neighborhood TEXT;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS surface TEXT;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS full_court BOOLEAN DEFAULT true;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT false;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS lights BOOLEAN DEFAULT false;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS tags TEXT[];
ALTER TABLE courts ADD COLUMN IF NOT EXISTS zip_code TEXT;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS court_rating DOUBLE PRECISION;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS submitted_by TEXT;

-- Migrate latitude/longitude → lat/lng if old columns exist
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'courts' AND column_name = 'latitude'
    ) THEN
        UPDATE courts SET lat = latitude WHERE lat IS NULL AND latitude IS NOT NULL;
    END IF;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'courts' AND column_name = 'longitude'
    ) THEN
        UPDATE courts SET lng = longitude WHERE lng IS NULL AND longitude IS NOT NULL;
    END IF;
END $$;

-- ─── 2. Ensure games has all columns ────────────────────────
ALTER TABLE games ADD COLUMN IF NOT EXISTS skill_level TEXT NOT NULL DEFAULT 'Any';
ALTER TABLE games ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;

-- ─── 3. Ensure game_players has all columns ─────────────────
ALTER TABLE game_players ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE game_players ADD COLUMN IF NOT EXISTS checked_out_at TIMESTAMPTZ;
ALTER TABLE game_players ADD COLUMN IF NOT EXISTS removed BOOLEAN DEFAULT false;

-- ─── 4. Fix court_id type (must be TEXT to match courts.id TEXT) ──
DO $$
BEGIN
    IF (SELECT data_type FROM information_schema.columns
        WHERE table_name = 'games' AND column_name = 'court_id') = 'uuid' THEN
        ALTER TABLE games ALTER COLUMN court_id TYPE TEXT USING court_id::text;
    END IF;
END $$;

-- ─── 5. Rebuild all FK constraints for PostgREST joins ──────

-- games.host_id → profiles(id)  (needed for host embed in queries)
ALTER TABLE games DROP CONSTRAINT IF EXISTS games_host_id_fkey;
ALTER TABLE games
    ADD CONSTRAINT games_host_id_fkey
    FOREIGN KEY (host_id) REFERENCES profiles(id) ON DELETE CASCADE
    NOT VALID;

-- games.court_id → courts(id)  (needed for courts embed in queries)
ALTER TABLE games DROP CONSTRAINT IF EXISTS games_court_id_fkey;
ALTER TABLE games
    ADD CONSTRAINT games_court_id_fkey
    FOREIGN KEY (court_id) REFERENCES courts(id)
    NOT VALID;

-- game_players.user_id → profiles(id)  (needed for profiles embed)
ALTER TABLE game_players DROP CONSTRAINT IF EXISTS game_players_user_id_fkey;
ALTER TABLE game_players
    ADD CONSTRAINT game_players_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
    NOT VALID;

-- ─── 6. Fix RLS: UPDATE policy used wrong column name ────────
DROP POLICY IF EXISTS "Host can update game" ON games;
DROP POLICY IF EXISTS "Game creator can update their game" ON games;
CREATE POLICY "Host can update game"
    ON games FOR UPDATE USING (auth.uid() = host_id);

-- ─── 7. Ensure no_show_reports table exists ──────────────────
CREATE TABLE IF NOT EXISTS no_show_reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    game_id uuid REFERENCES games(id) ON DELETE CASCADE,
    reported_user_id uuid REFERENCES profiles(id),
    reported_by_user_id uuid REFERENCES profiles(id),
    created_at timestamptz DEFAULT now()
);

-- ─── 8. Reload PostgREST schema cache ────────────────────────
-- This tells PostgREST to pick up all new FK constraints immediately.
-- Without this, the join queries (host, courts) silently fail.
NOTIFY pgrst, 'reload schema';

-- ─── 9. Diagnostic: verify recent games exist ────────────────
-- After running the above, run this separately to confirm data:
--
-- SELECT
--   id,
--   court_id,
--   status,
--   created_at,
--   scheduled_at
-- FROM games
-- ORDER BY created_at DESC
-- LIMIT 20;
--
-- If court_id is NULL for your games, that is the problem.
-- If the list is empty, games are not being created at all.
