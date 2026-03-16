-- ============================================================
-- Migration: Rating Schema + Peer Score Trigger
-- Date: 2026-03-14
-- Description:
--   1. Add new skill category columns to ratings table
--   2. Add vibe_run_again + is_self_rating columns
--   3. Add total_ratings to profiles
--   4. Drop old conflicting triggers/functions
--   5. Create new recalculate_netr_and_vibe() trigger
--      using Bayesian averaging (phantom_count=3, prior=4.0)
-- ============================================================

-- 1. Add new columns to ratings
ALTER TABLE ratings
  ADD COLUMN IF NOT EXISTS is_self_rating    BOOLEAN,
  ADD COLUMN IF NOT EXISTS cat_shooting      INT,
  ADD COLUMN IF NOT EXISTS cat_finishing     INT,
  ADD COLUMN IF NOT EXISTS cat_dribbling     INT,
  ADD COLUMN IF NOT EXISTS cat_passing       INT,
  ADD COLUMN IF NOT EXISTS cat_defense       INT,
  ADD COLUMN IF NOT EXISTS cat_rebounding    INT,
  ADD COLUMN IF NOT EXISTS cat_basketball_iq INT,
  ADD COLUMN IF NOT EXISTS vibe_run_again    INT;

-- 2. Add total_ratings to profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS total_ratings INT DEFAULT 0;

-- 3. Drop old conflicting triggers and functions
DROP TRIGGER IF EXISTS on_rating_inserted        ON ratings;
DROP TRIGGER IF EXISTS trigger_update_player_stats ON ratings;
DROP TRIGGER IF EXISTS trigger_recalculate_netr_and_vibe ON ratings;

DROP FUNCTION IF EXISTS recalculate_netr_score();
DROP FUNCTION IF EXISTS update_player_peer_stats();
DROP FUNCTION IF EXISTS recalculate_netr_and_vibe();

-- 4. Create updated trigger function with Bayesian averaging
CREATE OR REPLACE FUNCTION recalculate_netr_and_vibe()
RETURNS TRIGGER AS $$
DECLARE
  v_rated_user_id UUID;
  v_netr          NUMERIC;
  v_vibe          NUMERIC;
  v_real_avg      NUMERIC;
  v_real_count    INT;
  -- Bayesian dampening: 3 phantom ratings at 4.0 stabilize early scores
  -- Without this, a single bad rating tanks a new player's score
  v_phantom_count CONSTANT INT     := 3;
  v_prior         CONSTANT NUMERIC := 4.0;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_rated_user_id := OLD.rated_id;
  ELSE
    v_rated_user_id := NEW.rated_id;
  END IF;

  -- Average all 7 skill categories per rating row, then average those across all peer ratings
  SELECT
    AVG(
      (COALESCE(cat_shooting, 0) + COALESCE(cat_finishing, 0) +
       COALESCE(cat_dribbling, 0) + COALESCE(cat_passing, 0) +
       COALESCE(cat_defense, 0) + COALESCE(cat_rebounding, 0) +
       COALESCE(cat_basketball_iq, 0))::NUMERIC /
      NULLIF(
        (CASE WHEN cat_shooting      IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_finishing     IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_dribbling     IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_passing       IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_defense       IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_rebounding    IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_basketball_iq IS NOT NULL THEN 1 ELSE 0 END
        ), 0
      )
    ),
    COUNT(*)
  INTO v_real_avg, v_real_count
  FROM ratings
  WHERE rated_id = v_rated_user_id
    AND is_self_rating = false;

  -- Bayesian NETR: phantom ratings prevent wild swings with few reviews
  v_netr := ROUND(
    ((v_phantom_count * v_prior) + (v_real_count * COALESCE(v_real_avg, v_prior)))
    / (v_phantom_count + v_real_count)
  ::NUMERIC, 2);

  -- Vibe score: Bayesian avg of vibe_run_again (1–4 scale, prior = 2.5)
  SELECT ROUND(
    ((v_phantom_count * 2.5) + (COUNT(*) * COALESCE(AVG(vibe_run_again::NUMERIC), 2.5)))
    / (v_phantom_count + COUNT(*))
  ::NUMERIC, 2)
  INTO v_vibe
  FROM ratings
  WHERE rated_id = v_rated_user_id
    AND is_self_rating = false
    AND vibe_run_again IS NOT NULL;

  -- Update profile with new scores + peer rating count
  UPDATE profiles
  SET
    netr_score    = v_netr,
    vibe_score    = v_vibe,
    total_ratings = v_real_count,
    updated_at    = NOW()
  WHERE id = v_rated_user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Attach trigger to ratings table
CREATE TRIGGER trigger_recalculate_netr_and_vibe
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW EXECUTE FUNCTION recalculate_netr_and_vibe();

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
