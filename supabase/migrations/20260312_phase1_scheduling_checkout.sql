-- Phase 1: Game Scheduling + Check-in/Check-out
-- Adds scheduled_at to games and checked_out_at to game_players

-- 1. Game Scheduling: nullable timestamp for when the game is scheduled to start
ALTER TABLE games ADD COLUMN IF NOT EXISTS scheduled_at timestamptz;

-- 2. Check-out tracking: nullable timestamp for when a player checks out of a game
ALTER TABLE game_players ADD COLUMN IF NOT EXISTS checked_out_at timestamptz;

-- Index for querying upcoming scheduled games
CREATE INDEX IF NOT EXISTS idx_games_scheduled_at ON games (scheduled_at)
  WHERE scheduled_at IS NOT NULL AND status IN ('waiting', 'active');

-- Index for finding players who haven't checked out
CREATE INDEX IF NOT EXISTS idx_game_players_not_checked_out ON game_players (game_id)
  WHERE checked_out_at IS NULL;
