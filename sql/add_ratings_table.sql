-- NETR: Ratings table + aggregation trigger
-- Run this in Supabase SQL Editor after base_schema.sql

-- ─── RATINGS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    rater_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rated_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_self_rating BOOLEAN NOT NULL DEFAULT false,

    -- Skill categories (1–5)
    cat_shooting      INT,
    cat_finishing     INT,
    cat_dribbling     INT,
    cat_passing       INT,
    cat_defense       INT,
    cat_rebounding    INT,
    cat_basketball_iq INT,

    -- Vibe: single "run again?" question (4=Definitely, 3=Yeah, 2=Probably Not, 1=No Thanks)
    vibe_run_again INT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(game_id, rater_id, rated_id)
);

ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Raters can insert ratings"
    ON ratings FOR INSERT WITH CHECK (auth.uid() = rater_id);

CREATE POLICY "Anyone can read ratings for aggregation"
    ON ratings FOR SELECT USING (true);

CREATE INDEX IF NOT EXISTS idx_ratings_rated_id   ON ratings(rated_id);
CREATE INDEX IF NOT EXISTS idx_ratings_rater_id   ON ratings(rater_id);
CREATE INDEX IF NOT EXISTS idx_ratings_game_id    ON ratings(game_id);
CREATE INDEX IF NOT EXISTS idx_ratings_created_at ON ratings(created_at DESC);

-- ─── TRIGGER: update vibe_score + total_ratings on profile after each new peer rating ──
CREATE OR REPLACE FUNCTION update_player_peer_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE profiles
    SET
        -- Scale vibe_run_again (1–4) to 1.25–5.0 so it maps into the existing 1–5 vibe display
        vibe_score = (
            SELECT AVG(r.vibe_run_again) * 1.25
            FROM ratings r
            WHERE r.rated_id = NEW.rated_id
              AND r.is_self_rating = false
              AND r.vibe_run_again IS NOT NULL
        ),
        total_ratings = (
            SELECT COUNT(*)
            FROM ratings r
            WHERE r.rated_id = NEW.rated_id
              AND r.is_self_rating = false
        )
    WHERE id = NEW.rated_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_player_stats ON ratings;

CREATE TRIGGER trigger_update_player_stats
    AFTER INSERT ON ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_player_peer_stats();
