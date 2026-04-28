-- ============================================================
-- Migration: NETR Rating Algorithm v2
-- Date: 2026-04-28
-- Description:
--   Replaces the Bayesian batch NETR aggregator with an
--   incremental Elo-style update that produces correct scores
--   on the 2.0–9.9 NETR scale (the prior trigger averaged 1–5
--   slider values directly into netr_score, which broke the scale).
--
--   Key properties:
--     • Comparative slider conversion: implied_abs = rater_anchor + (avg_cat − 3) × 1.0
--     • Asymmetric calibration weight (lower-rated raters discounted)
--     • Provisional exception (ratees with <5 peer ratings get full weight from anyone)
--     • Tier-dependent learning rate K and per-rating cap
--     • Coordinated dampening (3+ same-direction ratings on same game = 0.5x)
--     • Outlier dampening for Established+ players (|implied − current| ≥ 1.5 = 0.6x)
--     • Per-rating audit columns (rater_netr_snapshot, implied_abs, applied_delta)
--     • Vibe trigger preserved separately, unchanged behavior
--
--   Tiers (by peer_rating_count):
--     Provisional 0–4   K=0.15  cap=±0.5
--     Building    5–19  K=0.10  cap=±0.3
--     Established 20–99 K=0.04  cap=±0.1
--     Verified    100+  K=0.01  cap=±0.03
--
--   Backfill: snapshots existing netr_score → self_assessed_netr,
--   resets profiles, replays all peer ratings chronologically.
-- ============================================================


-- ─── 1. SCHEMA CHANGES ─────────────────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS self_assessed_netr NUMERIC,
  ADD COLUMN IF NOT EXISTS tier               TEXT;

ALTER TABLE ratings
  ADD COLUMN IF NOT EXISTS rater_netr_snapshot NUMERIC,
  ADD COLUMN IF NOT EXISTS avg_cat_value       NUMERIC,
  ADD COLUMN IF NOT EXISTS implied_abs         NUMERIC,
  ADD COLUMN IF NOT EXISTS effective_weight    NUMERIC,
  ADD COLUMN IF NOT EXISTS tier_at_submission  TEXT,
  ADD COLUMN IF NOT EXISTS applied_delta       NUMERIC;


-- ─── 2. PURE HELPER FUNCTIONS ──────────────────────────────────

CREATE OR REPLACE FUNCTION netr_compute_tier(p_count INT) RETURNS TEXT AS $$
BEGIN
  IF p_count >= 100 THEN RETURN 'verified';
  ELSIF p_count >= 20 THEN RETURN 'established';
  ELSIF p_count >= 5  THEN RETURN 'building';
  ELSE                     RETURN 'provisional';
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION netr_tier_k(p_tier TEXT) RETURNS NUMERIC AS $$
BEGIN
  RETURN CASE p_tier
    WHEN 'provisional' THEN 0.15
    WHEN 'building'    THEN 0.10
    WHEN 'established' THEN 0.04
    WHEN 'verified'    THEN 0.01
    ELSE 0.10
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION netr_tier_cap(p_tier TEXT) RETURNS NUMERIC AS $$
BEGIN
  RETURN CASE p_tier
    WHEN 'provisional' THEN 0.50
    WHEN 'building'    THEN 0.30
    WHEN 'established' THEN 0.10
    WHEN 'verified'    THEN 0.03
    ELSE 0.30
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION netr_clamp(p_score NUMERIC) RETURNS NUMERIC AS $$
BEGIN
  RETURN GREATEST(2.0, LEAST(9.5, p_score));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calibration weight. Provisional ratees get full weight (peers correct lies fast).
CREATE OR REPLACE FUNCTION netr_calibration(
  p_rater_netr  NUMERIC,
  p_ratee_netr  NUMERIC,
  p_ratee_count INT
) RETURNS NUMERIC AS $$
BEGIN
  IF p_ratee_count < 5 THEN RETURN 1.0; END IF;
  IF (p_rater_netr - p_ratee_netr) >= 2.0 THEN RETURN 1.2; END IF;
  IF p_rater_netr >= p_ratee_netr THEN RETURN 1.0; END IF;
  RETURN GREATEST(0.1, 1.0 - (p_ratee_netr - p_rater_netr) * 0.2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ─── 3. CORE APPLY FUNCTION (used by trigger AND backfill) ─────
-- Mutates audit fields on the rating row and applies delta to ratee profile.
-- Operates on an existing rating row; for live INSERT path, the trigger
-- writes audit fields onto NEW first then this function is *not* called —
-- instead the trigger does the same logic inline (see below). For backfill
-- we call this against persisted rows.

CREATE OR REPLACE FUNCTION netr_apply_existing_rating(p_rating_id UUID) RETURNS VOID AS $$
DECLARE
  r                 ratings%ROWTYPE;
  v_rater_netr      NUMERIC;
  v_rater_count     INT;
  v_ratee_netr      NUMERIC;
  v_ratee_count     INT;
  v_ratee_tier      TEXT;
  v_avg_cat         NUMERIC;
  v_cat_count       INT;
  v_implied_abs     NUMERIC;
  v_cal             NUMERIC;
  v_cred            NUMERIC;
  v_outlier         NUMERIC;
  v_coord           NUMERIC;
  v_same_dir        INT;
  v_weight          NUMERIC;
  v_k               NUMERIC;
  v_cap             NUMERIC;
  v_raw_delta       NUMERIC;
  v_capped_delta    NUMERIC;
  v_new_netr        NUMERIC;
BEGIN
  SELECT * INTO r FROM ratings WHERE id = p_rating_id;
  IF NOT FOUND OR r.is_self_rating = TRUE THEN RETURN; END IF;

  -- avg of rated cat sliders (skip NULL categories)
  v_cat_count :=
    (CASE WHEN r.cat_shooting      IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN r.cat_finishing     IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN r.cat_dribbling     IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN r.cat_passing       IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN r.cat_defense       IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN r.cat_rebounding    IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN r.cat_basketball_iq IS NOT NULL THEN 1 ELSE 0 END);

  IF v_cat_count = 0 THEN RETURN; END IF;

  v_avg_cat := (
    COALESCE(r.cat_shooting, 0) + COALESCE(r.cat_finishing, 0) +
    COALESCE(r.cat_dribbling, 0) + COALESCE(r.cat_passing, 0) +
    COALESCE(r.cat_defense, 0) + COALESCE(r.cat_rebounding, 0) +
    COALESCE(r.cat_basketball_iq, 0)
  )::NUMERIC / v_cat_count;

  -- Rater anchor: prefer existing snapshot (for backfill consistency),
  -- else current profile state, else fall back to prior 4.0.
  SELECT
    COALESCE(p.netr_score, p.self_assessed_netr, 4.0),
    COALESCE(p.total_ratings, 0)
  INTO v_rater_netr, v_rater_count
  FROM profiles p WHERE p.id = r.rater_id;

  IF v_rater_netr IS NULL THEN
    v_rater_netr := 4.0;
    v_rater_count := 0;
  END IF;

  IF r.rater_netr_snapshot IS NOT NULL THEN
    v_rater_netr := r.rater_netr_snapshot;
  END IF;

  -- Ratee state
  SELECT
    COALESCE(p.netr_score, p.self_assessed_netr, 4.0),
    COALESCE(p.total_ratings, 0)
  INTO v_ratee_netr, v_ratee_count
  FROM profiles p WHERE p.id = r.rated_id;

  IF v_ratee_netr IS NULL THEN
    v_ratee_netr := 4.0;
    v_ratee_count := 0;
  END IF;

  v_ratee_tier := netr_compute_tier(v_ratee_count);

  -- implied_abs from comparative slider
  v_implied_abs := netr_clamp(v_rater_netr + (v_avg_cat - 3.0) * 1.0);

  -- weights
  v_cal     := netr_calibration(v_rater_netr, v_ratee_netr, v_ratee_count);
  v_cred    := GREATEST(0.1, LEAST(1.0, v_rater_count::NUMERIC / 5.0));

  IF v_ratee_tier IN ('established', 'verified')
     AND ABS(v_implied_abs - v_ratee_netr) >= 1.5 THEN
    v_outlier := 0.6;
  ELSE
    v_outlier := 1.0;
  END IF;

  -- Coordinated dampening: 2+ prior same-direction ratings from same game
  SELECT COUNT(*)
  INTO v_same_dir
  FROM ratings r2
  WHERE r2.rated_id = r.rated_id
    AND r2.game_id  = r.game_id
    AND r2.id      <> r.id
    AND r2.is_self_rating = FALSE
    AND r2.implied_abs IS NOT NULL
    AND SIGN(r2.implied_abs - v_ratee_netr) = SIGN(v_implied_abs - v_ratee_netr)
    AND SIGN(v_implied_abs - v_ratee_netr) <> 0;

  v_coord := CASE WHEN v_same_dir >= 2 THEN 0.5 ELSE 1.0 END;

  v_weight := v_cal * v_cred * v_outlier * v_coord;

  v_k   := netr_tier_k(v_ratee_tier);
  v_cap := netr_tier_cap(v_ratee_tier);

  v_raw_delta    := v_k * v_weight * (v_implied_abs - v_ratee_netr);
  v_capped_delta := GREATEST(-v_cap, LEAST(v_cap, v_raw_delta));

  v_new_netr := netr_clamp(v_ratee_netr + v_capped_delta);

  -- Persist audit fields on rating row
  UPDATE ratings
  SET rater_netr_snapshot = v_rater_netr,
      avg_cat_value       = ROUND(v_avg_cat, 4),
      implied_abs         = ROUND(v_implied_abs, 4),
      effective_weight    = ROUND(v_weight, 4),
      tier_at_submission  = v_ratee_tier,
      applied_delta       = ROUND(v_capped_delta, 4)
  WHERE id = r.id;

  -- Apply to ratee profile
  UPDATE profiles
  SET netr_score    = ROUND(v_new_netr, 2),
      total_ratings = COALESCE(total_ratings, 0) + 1,
      tier          = netr_compute_tier(COALESCE(total_ratings, 0) + 1),
      updated_at    = NOW()
  WHERE id = r.rated_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 4. INSERT TRIGGER (live path) ─────────────────────────────
-- BEFORE INSERT so we can mutate NEW with audit fields cleanly.

DROP TRIGGER  IF EXISTS trigger_recalculate_netr_and_vibe ON ratings;
DROP FUNCTION IF EXISTS recalculate_netr_and_vibe();

CREATE OR REPLACE FUNCTION rating_v2_apply_netr() RETURNS TRIGGER AS $$
DECLARE
  v_rater_netr      NUMERIC;
  v_rater_count     INT;
  v_ratee_netr      NUMERIC;
  v_ratee_count     INT;
  v_ratee_tier      TEXT;
  v_avg_cat         NUMERIC;
  v_cat_count       INT;
  v_implied_abs     NUMERIC;
  v_cal             NUMERIC;
  v_cred            NUMERIC;
  v_outlier         NUMERIC;
  v_coord           NUMERIC;
  v_same_dir        INT;
  v_weight          NUMERIC;
  v_k               NUMERIC;
  v_cap             NUMERIC;
  v_raw_delta       NUMERIC;
  v_capped_delta    NUMERIC;
  v_new_netr        NUMERIC;
BEGIN
  IF NEW.is_self_rating = TRUE THEN RETURN NEW; END IF;

  v_cat_count :=
    (CASE WHEN NEW.cat_shooting      IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN NEW.cat_finishing     IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN NEW.cat_dribbling     IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN NEW.cat_passing       IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN NEW.cat_defense       IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN NEW.cat_rebounding    IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN NEW.cat_basketball_iq IS NOT NULL THEN 1 ELSE 0 END);

  IF v_cat_count = 0 THEN RETURN NEW; END IF;

  v_avg_cat := (
    COALESCE(NEW.cat_shooting, 0) + COALESCE(NEW.cat_finishing, 0) +
    COALESCE(NEW.cat_dribbling, 0) + COALESCE(NEW.cat_passing, 0) +
    COALESCE(NEW.cat_defense, 0) + COALESCE(NEW.cat_rebounding, 0) +
    COALESCE(NEW.cat_basketball_iq, 0)
  )::NUMERIC / v_cat_count;

  SELECT
    COALESCE(p.netr_score, p.self_assessed_netr, 4.0),
    COALESCE(p.total_ratings, 0)
  INTO v_rater_netr, v_rater_count
  FROM profiles p WHERE p.id = NEW.rater_id;

  IF v_rater_netr IS NULL THEN
    v_rater_netr := 4.0;
    v_rater_count := 0;
  END IF;

  -- Snapshot now (immutable for audit + future replays)
  NEW.rater_netr_snapshot := v_rater_netr;

  SELECT
    COALESCE(p.netr_score, p.self_assessed_netr, 4.0),
    COALESCE(p.total_ratings, 0)
  INTO v_ratee_netr, v_ratee_count
  FROM profiles p WHERE p.id = NEW.rated_id;

  IF v_ratee_netr IS NULL THEN
    v_ratee_netr := 4.0;
    v_ratee_count := 0;
  END IF;

  v_ratee_tier := netr_compute_tier(v_ratee_count);

  v_implied_abs := netr_clamp(v_rater_netr + (v_avg_cat - 3.0) * 1.0);

  v_cal  := netr_calibration(v_rater_netr, v_ratee_netr, v_ratee_count);
  v_cred := GREATEST(0.1, LEAST(1.0, v_rater_count::NUMERIC / 5.0));

  IF v_ratee_tier IN ('established', 'verified')
     AND ABS(v_implied_abs - v_ratee_netr) >= 1.5 THEN
    v_outlier := 0.6;
  ELSE
    v_outlier := 1.0;
  END IF;

  SELECT COUNT(*)
  INTO v_same_dir
  FROM ratings r2
  WHERE r2.rated_id = NEW.rated_id
    AND r2.game_id  = NEW.game_id
    AND r2.is_self_rating = FALSE
    AND r2.implied_abs IS NOT NULL
    AND SIGN(r2.implied_abs - v_ratee_netr) = SIGN(v_implied_abs - v_ratee_netr)
    AND SIGN(v_implied_abs - v_ratee_netr) <> 0;

  v_coord := CASE WHEN v_same_dir >= 2 THEN 0.5 ELSE 1.0 END;

  v_weight := v_cal * v_cred * v_outlier * v_coord;
  v_k      := netr_tier_k(v_ratee_tier);
  v_cap    := netr_tier_cap(v_ratee_tier);

  v_raw_delta    := v_k * v_weight * (v_implied_abs - v_ratee_netr);
  v_capped_delta := GREATEST(-v_cap, LEAST(v_cap, v_raw_delta));
  v_new_netr     := netr_clamp(v_ratee_netr + v_capped_delta);

  -- Audit fields onto NEW (mutated before INSERT writes)
  NEW.avg_cat_value      := ROUND(v_avg_cat, 4);
  NEW.implied_abs        := ROUND(v_implied_abs, 4);
  NEW.effective_weight   := ROUND(v_weight, 4);
  NEW.tier_at_submission := v_ratee_tier;
  NEW.applied_delta      := ROUND(v_capped_delta, 4);

  -- Apply to ratee profile
  UPDATE profiles
  SET netr_score    = ROUND(v_new_netr, 2),
      total_ratings = COALESCE(total_ratings, 0) + 1,
      tier          = netr_compute_tier(COALESCE(total_ratings, 0) + 1),
      updated_at    = NOW()
  WHERE id = NEW.rated_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_rating_v2_apply_netr
BEFORE INSERT ON ratings
FOR EACH ROW EXECUTE FUNCTION rating_v2_apply_netr();


-- ─── 5. VIBE TRIGGER (preserved from prior migration) ──────────
-- Same Bayesian batch logic as 20260416_rerate_flow.sql, isolated.

CREATE OR REPLACE FUNCTION rating_v2_apply_vibe() RETURNS TRIGGER AS $$
DECLARE
  v_rated_user_id      UUID;
  v_vibe               NUMERIC;
  v_vibe_weighted_sum  NUMERIC;
  v_vibe_weight_sum    NUMERIC;
  v_vibe_phantom CONSTANT NUMERIC := 20.0;
  v_vibe_prior   CONSTANT NUMERIC := 4.0;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_rated_user_id := OLD.rated_id;
  ELSE
    v_rated_user_id := NEW.rated_id;
  END IF;

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
      COUNT(*) FILTER (WHERE r2.vibe_run_again = 1) AS game_reds
    FROM ratings r
    LEFT JOIN ratings r2
      ON r2.rated_id      = r.rated_id
     AND r2.game_id       = r.game_id
     AND r2.is_self_rating = FALSE
     AND r2.vibe_run_again = 1
    WHERE r.rated_id       = v_rated_user_id
      AND r.is_self_rating = FALSE
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

    IF v_vibe_weight_sum < 7 AND v_vibe < 2.0 THEN
      v_vibe := 2.0;
    END IF;
  END IF;

  UPDATE profiles
  SET vibe_score         = v_vibe,
      vibe_rating_count  = COALESCE(v_vibe_weight_sum::INT, 0),
      vibe_last_rated_at = NOW(),
      updated_at         = NOW()
  WHERE id = v_rated_user_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Only fire on vibe-relevant changes — keeps backfill fast since the
-- audit-field UPDATEs in step 6 don't touch vibe inputs.
CREATE TRIGGER trigger_rating_v2_apply_vibe
AFTER INSERT OR DELETE ON ratings
FOR EACH ROW EXECUTE FUNCTION rating_v2_apply_vibe();

CREATE TRIGGER trigger_rating_v2_apply_vibe_update
AFTER UPDATE OF vibe_run_again, rating_weight, game_id, is_self_rating ON ratings
FOR EACH ROW EXECUTE FUNCTION rating_v2_apply_vibe();


-- ─── 6. BACKFILL ───────────────────────────────────────────────
-- 1. Snapshot current netr_score → self_assessed_netr (preserves
--    self-assessment values for users who haven't been peer-rated).
-- 2. Reset all profiles to their self-assessed starting point.
-- 3. Replay every peer rating chronologically through the new algo.

DO $$
DECLARE
  rec RECORD;
BEGIN
  -- Step 1: preserve self-assessment values
  UPDATE profiles
  SET self_assessed_netr = COALESCE(netr_score, 4.0)
  WHERE self_assessed_netr IS NULL;

  -- Step 2: reset to starting point
  UPDATE profiles
  SET netr_score    = COALESCE(self_assessed_netr, 4.0),
      total_ratings = 0,
      tier          = 'provisional';

  -- Step 3: clear prior audit fields and replay chronologically
  UPDATE ratings
  SET rater_netr_snapshot = NULL,
      avg_cat_value       = NULL,
      implied_abs         = NULL,
      effective_weight    = NULL,
      tier_at_submission  = NULL,
      applied_delta       = NULL
  WHERE is_self_rating = FALSE;

  FOR rec IN
    SELECT id FROM ratings
    WHERE is_self_rating = FALSE
    ORDER BY created_at ASC, id ASC
  LOOP
    PERFORM netr_apply_existing_rating(rec.id);
  END LOOP;
END $$;


-- ─── 7. POSTGREST SCHEMA RELOAD ────────────────────────────────
NOTIFY pgrst, 'reload schema';
