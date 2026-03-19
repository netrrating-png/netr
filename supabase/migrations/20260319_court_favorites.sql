-- ─── COURT FAVORITES ────────────────────────────────────────
-- Stores favorited courts and each user's designated home court.

CREATE TABLE IF NOT EXISTS court_favorites (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    court_id    TEXT    NOT NULL REFERENCES courts(id)     ON DELETE CASCADE,
    is_home_court BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT court_favorites_user_court_unique UNIQUE (user_id, court_id)
);

ALTER TABLE court_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own favorites"
    ON court_favorites FOR SELECT
    USING (auth.uid() = user_id);

-- Leaderboard queries need to read other users' home-court rows
CREATE POLICY "Home court entries are publicly viewable"
    ON court_favorites FOR SELECT
    USING (is_home_court = true);

CREATE POLICY "Users can insert their own favorites"
    ON court_favorites FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own favorites"
    ON court_favorites FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorites"
    ON court_favorites FOR DELETE
    USING (auth.uid() = user_id);
