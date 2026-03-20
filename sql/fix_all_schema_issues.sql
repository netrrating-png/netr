-- ============================================================
-- NETR: Complete schema fix — run this in Supabase SQL Editor
-- ============================================================
-- Fixes:
--   1. games.host_id FK → profiles (PostgREST needs this for host embed)
--   2. game_players.user_id FK → profiles (PostgREST needs this for profiles embed)
--   3. games.court_id → courts FK (PostgREST needs this for courts embed)
--      Handles both TEXT and UUID variants of court_id
--   4. games UPDATE policy references wrong column (created_by → host_id)
--   5. courts table: ensure lat/lng/neighborhood/surface/etc columns exist
--      (base_schema used latitude/longitude but app expects lat/lng)
-- ============================================================

-- ─── 1. Fix games.host_id → profiles ────────────────────────
ALTER TABLE games DROP CONSTRAINT IF EXISTS games_host_id_fkey;
ALTER TABLE games
    ADD CONSTRAINT games_host_id_fkey
    FOREIGN KEY (host_id) REFERENCES profiles(id) ON DELETE CASCADE
    NOT VALID;

-- ─── 2. Fix game_players.user_id → profiles ─────────────────
ALTER TABLE game_players DROP CONSTRAINT IF EXISTS game_players_user_id_fkey;
ALTER TABLE game_players
    ADD CONSTRAINT game_players_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
    NOT VALID;

-- ─── 3. Fix games.court_id → courts FK ──────────────────────
-- First ensure court_id is TEXT to match courts.id TEXT
-- (If court_id was accidentally changed to UUID this restores compatibility)
ALTER TABLE games DROP CONSTRAINT IF EXISTS games_court_id_fkey;

-- Convert court_id back to TEXT if it is UUID (safe no-op if already TEXT)
DO $$
BEGIN
    IF (SELECT data_type FROM information_schema.columns
        WHERE table_name = 'games' AND column_name = 'court_id') = 'uuid' THEN
        ALTER TABLE games ALTER COLUMN court_id TYPE TEXT USING court_id::text;
    END IF;
END $$;

ALTER TABLE games
    ADD CONSTRAINT games_court_id_fkey
    FOREIGN KEY (court_id) REFERENCES courts(id)
    NOT VALID;

-- ─── 4. Fix broken UPDATE policy (uses created_by, column is host_id) ──
DROP POLICY IF EXISTS "Host can update game" ON games;
DROP POLICY IF EXISTS "Game creator can update their game" ON games;
CREATE POLICY "Host can update game"
    ON games FOR UPDATE USING (auth.uid() = host_id);

-- ─── 5. Ensure courts has the columns the app expects ────────
-- (base_schema used latitude/longitude; app and later migrations use lat/lng)
ALTER TABLE courts ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS neighborhood TEXT;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS surface TEXT;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS full_court BOOLEAN DEFAULT true;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT false;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS tags TEXT[];
ALTER TABLE courts ADD COLUMN IF NOT EXISTS court_rating DOUBLE PRECISION;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS submitted_by TEXT;
ALTER TABLE courts ADD COLUMN IF NOT EXISTS zip_code TEXT;

-- Migrate latitude/longitude → lat/lng if the old columns exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'courts' AND column_name = 'latitude') THEN
        UPDATE courts SET lat = latitude WHERE lat IS NULL AND latitude IS NOT NULL;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'courts' AND column_name = 'longitude') THEN
        UPDATE courts SET lng = longitude WHERE lng IS NULL AND longitude IS NOT NULL;
    END IF;
END $$;

-- ─── 6. Ensure games has skill_level column ──────────────────
ALTER TABLE games ADD COLUMN IF NOT EXISTS skill_level TEXT NOT NULL DEFAULT 'Any';

-- ─── 7. Reload PostgREST schema cache ───────────────────────
-- In Supabase dashboard this is done via Settings → API → Reload schema
-- Or send a NOTIFY:
NOTIFY pgrst, 'reload schema';
