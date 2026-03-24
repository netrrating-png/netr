-- ============================================================
-- NETR: Add completed_at column to games table
-- Tracks exactly when the host pressed "End Game" so the
-- Rate tab can show a 24-hour window from game completion
-- rather than from game creation.
-- ============================================================

ALTER TABLE games ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Index for the Rate tab query (completed_at >= 24h ago)
CREATE INDEX IF NOT EXISTS idx_games_completed_at
    ON games (completed_at DESC)
    WHERE completed_at IS NOT NULL;

-- Backfill old completed games that don't have completed_at yet.
-- Use created_at as a conservative stand-in so they still appear.
UPDATE games
    SET completed_at = created_at
    WHERE status = 'completed'
      AND completed_at IS NULL;

NOTIFY pgrst, 'reload schema';
