-- Fix games.host_id and game_players.user_id FK references
-- Previously both pointed to auth.users(id), which breaks PostgREST joins
-- to the profiles table (used in all game list queries).
-- Changing both to reference profiles(id) so that
-- host:profiles!games_host_id_fkey(...) and
-- profiles(...) joins work correctly.

-- 1. games.host_id → profiles(id)
ALTER TABLE games DROP CONSTRAINT games_host_id_fkey;
ALTER TABLE games
    ADD CONSTRAINT games_host_id_fkey
    FOREIGN KEY (host_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 2. game_players.user_id → profiles(id)
ALTER TABLE game_players DROP CONSTRAINT game_players_user_id_fkey;
ALTER TABLE game_players
    ADD CONSTRAINT game_players_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
