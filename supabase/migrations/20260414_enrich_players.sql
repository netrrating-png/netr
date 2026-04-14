-- Enrich nba_game_players with additional fields for NBA Connections game categories.
--
-- These fields are already returned by the CommonPlayerInfo endpoint but were
-- previously discarded during the build_nba_daily_game_dataset.py bio pass.
-- The enrich_connections_data.py tool reads existing player IDs from this table,
-- fetches the missing info, and UPSERTs these columns back.
--
-- Safe to re-run: all ADD COLUMNs use IF NOT EXISTS.
--
-- How to apply:
--   Paste into the Supabase SQL Editor and click RUN.

ALTER TABLE nba_game_players
    ADD COLUMN IF NOT EXISTS country      TEXT,   -- e.g. "USA", "France", "Spain"
    ADD COLUMN IF NOT EXISTS college      TEXT,   -- e.g. "Duke"; null if high-school draft or no college
    ADD COLUMN IF NOT EXISTS draft_year   INT,    -- e.g. 2003; null if undrafted
    ADD COLUMN IF NOT EXISTS draft_round  INT,    -- 1 or 2; null if undrafted
    ADD COLUMN IF NOT EXISTS draft_number INT;    -- pick # within the round (1-60); null if undrafted

-- Indexes used by the Connections puzzle generator
CREATE INDEX IF NOT EXISTS nba_game_players_college_idx     ON nba_game_players (college)     WHERE active AND college IS NOT NULL;
CREATE INDEX IF NOT EXISTS nba_game_players_country_idx     ON nba_game_players (country)     WHERE active AND country IS NOT NULL;
CREATE INDEX IF NOT EXISTS nba_game_players_draft_year_idx  ON nba_game_players (draft_year)  WHERE active AND draft_year IS NOT NULL;
CREATE INDEX IF NOT EXISTS nba_game_players_draft_num_idx   ON nba_game_players (draft_number) WHERE active AND draft_number IS NOT NULL;
