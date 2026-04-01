-- ============================================================
-- Migration: Rework Vibe Score System
-- Date: 2026-04-01
-- Description:
--   1. Add vibe_rating_count and vibe_last_rated_at to profiles
--   2. Replace trigger with new Bayesian formula:
--      20 phantom ratings at 4.0 (Green-anchored)
--   3. Provisional period: < 5 ratings = 4.0 (Great Vibe)
--   4. Red floor: < 7 ratings = min 2.0 (Mixed at worst)
--   5. Coordinated attack dampening: 3+ reds from same game = 0.5 weight
--   6. Reset all users to Green default
-- ============================================================

-- 1. Add new vibe tracking columns to profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS vibe_rating_count INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS vibe_last_rated_at TIMESTAMPTZ;

-- 2. Drop and recreate the trigger function with new formula
DROP TRIGGER IF EXISTS trigger_recalculate_netr_and_vibe ON ratings;
DROP FUNCTION IF EXISTS recalculate_netr_and_vibe();

CREATE OR REPLACE FUNCTION recalculate_netr_and_vibe()
RETURNS TRIGGER AS $$
DECLARE
  v_rated_user_id UUID;
  v_netr          NUMERIC;
  v_vibe          NUMERIC;
  v_real_avg      NUMERIC;
  v_real_count    INT;
  v_vibe_count    INT;
  v_vibe_weighted_sum NUMERIC;
  -- NETR: same Bayesian as before (3 phantom at 4.0)
  v_netr_phantom_count CONSTANT INT     := 3;
  v_netr_prior         CONSTANT NUMERIC := 4.0;
  -- VIBE: 20 phantom ratings at 4.0 (Green-anchored, sticky)
  v_vibe_phantom_count CONSTANT NUMERIC := 20.0;
  v_vibe_prior         CONSTANT NUMERIC := 4.0;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_rated_user_id := OLD.rated_id;
  ELSE
    v_rated_user_id := NEW.rated_id;
  END IF;

  -- ── NETR SCORE (unchanged) ──────────────────────────────
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

  v_netr := ROUND(
    ((v_netr_phantom_count * v_netr_prior) + (v_real_count * COALESCE(v_real_avg, v_netr_prior)))
    / (v_netr_phantom_count + v_real_count)
  ::NUMERIC, 2);

  -- ── VIBE SCORE (new formula) ────────────────────────────
  -- Coordinated attack dampening: if 3+ ratings of 1 from the same game,
  -- weight each at 0.5 instead of 1.0
  SELECT
    SUM(
      CASE
        WHEN vibe_run_again = 1 AND game_reds >= 3 THEN vibe_run_again * 0.5
        ELSE vibe_run_again
      END
    ),
    SUM(
      CASE
        WHEN vibe_run_again = 1 AND game_reds >= 3 THEN 0.5
        ELSE 1.0
      END
    )::INT
  INTO v_vibe_weighted_sum, v_vibe_count
  FROM (
    SELECT
      r.vibe_run_again,
      r.game_id,
      COUNT(*) FILTER (WHERE r2.vibe_run_again = 1) AS game_reds
    FROM ratings r
    LEFT JOIN ratings r2
      ON r2.rated_id = r.rated_id
      AND r2.game_id = r.game_id
      AND r2.is_self_rating = false
      AND r2.vibe_run_again = 1
    WHERE r.rated_id = v_rated_user_id
      AND r.is_self_rating = false
      AND r.vibe_run_again IS NOT NULL
    GROUP BY r.id, r.vibe_run_again, r.game_id
  ) sub;

  IF v_vibe_count IS NULL OR v_vibe_count = 0 THEN
    v_vibe := v_vibe_prior;
    v_vibe_count := 0;
  ELSIF v_vibe_count < 5 THEN
    -- Provisional: store real calculation but display will show 4.0
    v_vibe := ROUND(
      ((v_vibe_phantom_count * v_vibe_prior) + v_vibe_weighted_sum)
      / (v_vibe_phantom_count + v_vibe_count)
    ::NUMERIC, 2);
  ELSE
    v_vibe := ROUND(
      ((v_vibe_phantom_count * v_vibe_prior) + v_vibe_weighted_sum)
      / (v_vibe_phantom_count + v_vibe_count)
    ::NUMERIC, 2);
    -- Red floor protection: < 7 ratings → min 2.0
    IF v_vibe_count < 7 AND v_vibe < 2.0 THEN
      v_vibe := 2.0;
    END IF;
  END IF;

  -- ── UPDATE PROFILE ──────────────────────────────────────
  UPDATE profiles
  SET
    netr_score        = v_netr,
    vibe_score        = v_vibe,
    vibe_rating_count = v_vibe_count,
    vibe_last_rated_at = NOW(),
    total_ratings     = v_real_count,
    updated_at        = NOW()
  WHERE id = v_rated_user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Reattach trigger
CREATE TRIGGER trigger_recalculate_netr_and_vibe
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW EXECUTE FUNCTION recalculate_netr_and_vibe();

-- 4. Reset all existing users to Green default (4.0)
UPDATE profiles
SET vibe_score = 4.0,
    vibe_rating_count = COALESCE(vibe_rating_count, 0)
WHERE vibe_score < 3.5 OR vibe_score IS NULL;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
