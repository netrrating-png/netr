-- Add privacy controls to games table
ALTER TABLE games
  ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS passcode   VARCHAR(4);
