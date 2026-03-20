-- ─────────────────────────────────────────────────────────────
-- NETR Demo Seed: Nolan (nolan123@gmail.com)
--
-- BEFORE running this script:
--   1. Open the app and sign up a new account using nolan123@gmail.com
--   2. Complete onboarding for that account (any position/answers)
--   3. Sign back into YOUR account on the app
--   4. Then run this script in the Supabase SQL Editor
-- ─────────────────────────────────────────────────────────────

DO $$
DECLARE
    nolan_id    UUID;
    my_id       UUID;
    game_id     UUID := gen_random_uuid();
    court_id    TEXT;
BEGIN

    -- ── Get Nolan's auth UUID ──────────────────────────────────
    SELECT id INTO nolan_id
    FROM auth.users
    WHERE email = 'nolan123@gmail.com'
    LIMIT 1;

    IF nolan_id IS NULL THEN
        RAISE EXCEPTION 'nolan123@gmail.com not found in auth.users. Sign up via the app first.';
    END IF;

    -- ── Get YOUR auth UUID (most recently created user that isn't Nolan) ──
    -- Replace the email below with YOUR login email if needed
    SELECT id INTO my_id
    FROM auth.users
    WHERE email != 'nolan123@gmail.com'
    ORDER BY created_at DESC
    LIMIT 1;

    IF my_id IS NULL THEN
        RAISE EXCEPTION 'Could not find your user account.';
    END IF;

    -- ── Get a court ID (Rucker Park preferred, else any) ──────
    SELECT id INTO court_id
    FROM courts
    WHERE name ILIKE '%rucker%'
    LIMIT 1;

    IF court_id IS NULL THEN
        SELECT id INTO court_id FROM courts LIMIT 1;
    END IF;

    -- ── Update Nolan's profile with demo stats ─────────────────
    UPDATE profiles SET
        full_name        = 'Nolan Carter',
        username         = '@nolan_c',
        position         = 'SG',
        bio              = 'Shooter from NYC. Rain man.',
        netr_score       = 6.8,
        cat_shooting     = 8.2,
        cat_finishing    = 6.5,
        cat_dribbling    = 6.0,
        cat_passing      = 6.4,
        cat_defense      = 6.5,
        cat_rebounding   = 5.8,
        cat_basketball_iq = 7.1,
        vibe_score       = 4.2,
        total_ratings    = 14,
        total_games      = 22,
        is_prospect      = false,
        is_verified_pro  = false
    WHERE id = nolan_id;

    -- ── Create a completed game ────────────────────────────────
    INSERT INTO games (id, host_id, court_id, format, skill_level, join_code, status, created_at)
    VALUES (
        game_id,
        my_id,
        court_id,
        '5v5',
        'competitive',
        'DEMO01',
        'completed',
        NOW() - INTERVAL '30 minutes'
    )
    ON CONFLICT (id) DO NOTHING;

    -- ── Add YOU to the game ────────────────────────────────────
    INSERT INTO game_players (id, game_id, user_id, checked_in_at, removed, created_at)
    VALUES (
        gen_random_uuid(),
        game_id,
        my_id,
        NOW() - INTERVAL '90 minutes',
        false,
        NOW() - INTERVAL '90 minutes'
    )
    ON CONFLICT (game_id, user_id) DO NOTHING;

    -- ── Add Nolan to the game ──────────────────────────────────
    INSERT INTO game_players (id, game_id, user_id, checked_in_at, removed, created_at)
    VALUES (
        gen_random_uuid(),
        game_id,
        nolan_id,
        NOW() - INTERVAL '90 minutes',
        false,
        NOW() - INTERVAL '90 minutes'
    )
    ON CONFLICT (game_id, user_id) DO NOTHING;

    RAISE NOTICE 'Done! Nolan (%) added to game (%) with you (%).', nolan_id, game_id, my_id;
END $$;
