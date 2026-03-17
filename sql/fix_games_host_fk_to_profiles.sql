-- Fix games.host_id and game_players.user_id FK references
--
-- SAFE VERSION: uses IF EXISTS + NOT VALID so this works even if:
--   - the constraint doesn't exist yet
--   - some game/player rows have host_id/user_id not yet in profiles
--
-- NOT VALID means: "create the FK for future inserts/updates but
-- don't scan existing rows" — prevents the migration from failing
-- on pre-existing data.

-- 1. games.host_id → profiles(id)
ALTER TABLE games DROP CONSTRAINT IF EXISTS games_host_id_fkey;
ALTER TABLE games
    ADD CONSTRAINT games_host_id_fkey
    FOREIGN KEY (host_id) REFERENCES profiles(id) ON DELETE CASCADE
    NOT VALID;

-- 2. game_players.user_id → profiles(id)
ALTER TABLE game_players DROP CONSTRAINT IF EXISTS game_players_user_id_fkey;
ALTER TABLE game_players
    ADD CONSTRAINT game_players_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
    NOT VALID;
