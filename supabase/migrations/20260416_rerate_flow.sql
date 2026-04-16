-- ============================================================
-- Migration: Re-rate Flow
-- Date: 2026-04-16
-- Description:
--   Adds re-rate support to the ratings table so that a user who
--   has previously rated a given player can update their assessment
--   after additional co-play sessions.
--
--   1. Add columns to ratings:
--        is_rerate         BOOLEAN  — true when this is not the first rating
--        previous_values   JSONB    — snapshot of the prior skill values
--        co_play_count     INT      — # of shared sessions at submission time
--        rating_weight     NUMERIC  — 1.0 first-time; lower for re-rates
--
--   2. RLS: existing "Anyone can read ratings for aggregation" policy
--      (USING true) already allows raters to SELECT their own rows.
--      No change needed.
--
--   3. Replace recalculate_netr_and_vibe() with a version that uses
--      weighted averaging so re-rates from long-time co-players move
--      a player's score gradually instead of spiking it.
--
--   Weight rules (applied by iOS client at insert time):
--     First-time rating              → 1.0
--     Re-rate, co_play_count  1–9   → 0.6
--     Re-rate, co_play_count 10+    → 0.3
-- ============================================================

-- ─── 1. ADD COLUMNS ────────────────────────────────────────────
ALTER TABLE ratings
    ADD COLUMN IF NOT EXISTS is_rerate      BOOLEAN  NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS previous_values JSONB,
    ADD COLUMN IF NOT EXISTS co_play_count  INT      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS rating_weight  NUMERIC  NOT NULL DEFAULT 1.0;

-- ─── 2. REPLACE TRIGGER WITH WEIGHTED SCORING ──────────────────
DROP TRIGGER   IF EXISTS trigger_recalculate_netr_and_vibe ON ratings;
DROP FUNCTION  IF EXISTS recalculate_netr_and_vibe();

CREATE OR REPLACE FUNCTION recalculate_netr_and_vibe()
RETURNS TRIGGER AS $$
DECLARE
  v_rated_user_id      UUID;
  v_netr               NUMERIC;
  v_vibe               NUMERIC;
  v_netr_avg           NUMERIC;   -- weighted average skill score (0–5)
  v_netr_weight_sum    NUMERIC;   -- effective denominator for Bayesian
  v_vibe_weighted_sum  NUMERIC;
  v_vibe_weight_sum    NUMERIC;

  -- NETR: 3 phantom ratings at 4.0 (unchanged)
  v_netr_phantom  CONSTANT NUMERIC := 3.0;
  v_netr_prior    CONSTANT NUMERIC := 4.0;

  -- VIBE: 20 phantom ratings at 4.0 — sticky green (unchanged)
  v_vibe_phantom  CONSTANT NUMERIC := 20.0;
  v_vibe_prior    CONSTANT NUMERIC := 4.0;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_rated_user_id := OLD.rated_id;
  ELSE
    v_rated_user_id := NEW.rated_id;
  END IF;

  -- ── NETR SCORE (weighted) ─────────────────────────────────────
  -- Compute a per-row skill average across the 7 categories, then
  -- weight it by rating_weight.  Re-rates from high-coplay raters
  -- contribute less to the final score, preventing score spikes.
  SELECT
    SUM(skill_per_row * w) / NULLIF(SUM(w), 0),
    SUM(w)
  INTO v_netr_avg, v_netr_weight_sum
  FROM (
    SELECT
      (
        COALESCE(cat_shooting, 0) + COALESCE(cat_finishing, 0) +
        COALESCE(cat_dribbling, 0) + COALESCE(cat_passing, 0) +
        COALESCE(cat_defense, 0) + COALESCE(cat_rebounding, 0) +
        COALESCE(cat_basketball_iq, 0)
      )::NUMERIC /
      NULLIF(
        (CASE WHEN cat_shooting      IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_finishing     IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_dribbling     IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_passing       IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_defense       IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_rebounding    IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN cat_basketball_iq IS NOT NULL THEN 1 ELSE 0 END
        ), 0
      ) AS skill_per_row,
      COALESCE(rating_weight, 1.0) AS w
    FROM ratings
    WHERE rated_id     = v_rated_user_id
      AND is_self_rating = false
  ) sub
  WHERE skill_per_row IS NOT NULL;

  -- Bayesian NETR: phantom ratings stabilise early scores.
  -- v_netr_weight_sum is the effective count (fractional for re-rates).
  v_netr := ROUND(
    ((v_netr_phantom * v_netr_prior) +
     (COALESCE(v_netr_weight_sum, 0) * COALESCE(v_netr_avg, v_netr_prior)))
    / (v_netr_phantom + COALESCE(v_netr_weight_sum, 0))
  ::NUMERIC, 2);

  -- ── VIBE SCORE (coordinated-attack dampening × re-rate weight) ─
  -- Layer 1: coordinated attack — 3+ reds from same game → 0.5
  -- Layer 2: re-rate weight    — multiplied on top of layer 1
  SELECT
    SUM(
      vibe_run_again::NUMERIC *
      (CASE WHEN vibe_run_again = 1 AND game_reds >= 3 THEN 0.5 ELSE 1.0 END) *
      COALESCE(r_weight, 1.0)
    ),
    SUM(
      (CASE WHEN vibe_run_again = 1 AND game_reds >= 3 THEN 0.5 ELSE 1.0 END) *
      COALESCE(r_weight, 1.0)
    )
  INTO v_vibe_weighted_sum, v_vibe_weight_sum
  FROM (
    SELECT
      r.vibe_run_again,
      COALESCE(r.rating_weight, 1.0) AS r_weight,
      COUNT(*) FILTER (
        WHERE r2.vibe_run_again = 1
      ) AS game_reds
    FROM ratings r
    LEFT JOIN ratings r2
      ON r2.rated_id      = r.rated_id
     AND r2.game_id       = r.game_id
     AND r2.is_self_rating = false
     AND r2.vibe_run_again = 1
    WHERE r.rated_id       = v_rated_user_id
      AND r.is_self_rating = false
      AND r.vibe_run_again IS NOT NULL
    GROUP BY r.id, r.vibe_run_again, r.game_id, r.rating_weight
  ) sub;

  IF v_vibe_weight_sum IS NULL OR v_vibe_weight_sum = 0 THEN
    v_vibe := v_vibe_prior;
    v_vibe_weight_sum := 0;
  ELSE
    v_vibe := ROUND(
      ((v_vibe_phantom * v_vibe_prior) + COALESCE(v_vibe_weighted_sum, 0))
      / (v_vibe_phantom + v_vibe_weight_sum)
    ::NUMERIC, 2);

    -- Red floor: fewer than 7 effective ratings → Mixed at worst (2.0)
    IF v_vibe_weight_sum < 7 AND v_vibe < 2.0 THEN
      v_vibe := 2.0;
    END IF;
  END IF;

  -- ── UPDATE PROFILE ────────────────────────────────────────────
  UPDATE profiles
  SET
    netr_score         = v_netr,
    vibe_score         = v_vibe,
    vibe_rating_count  = COALESCE(v_vibe_weight_sum::INT, 0),
    vibe_last_rated_at = NOW(),
    total_ratings      = COALESCE(v_netr_weight_sum::INT, 0),
    updated_at         = NOW()
  WHERE id = v_rated_user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reattach trigger
CREATE TRIGGER trigger_recalculate_netr_and_vibe
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW EXECUTE FUNCTION recalculate_netr_and_vibe();

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
