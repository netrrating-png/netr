-- ─────────────────────────────────────────────────────────────
-- Remove test/demo accounts from production
--
-- Run this in the Supabase SQL Editor.
-- Deleting from auth.users cascades to profiles via FK.
--
-- Accounts targeted:
--   - Nolan Carter  (nolan123@gmail.com / @nolan_c)
--   - Marcus        (match by name — confirm email before running)
-- ─────────────────────────────────────────────────────────────

DO $$
DECLARE
    nolan_id   UUID;
    marcus_id  UUID;
BEGIN

    -- ── Nolan Carter ──────────────────────────────────────────
    SELECT id INTO nolan_id
    FROM auth.users
    WHERE email = 'nolan123@gmail.com'
    LIMIT 1;

    IF nolan_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = nolan_id;
        RAISE NOTICE 'Deleted Nolan Carter (%)', nolan_id;
    ELSE
        RAISE NOTICE 'Nolan Carter not found — already removed or never seeded';
    END IF;

    -- ── Marcus ────────────────────────────────────────────────
    -- Update the name/email below to match the exact account.
    -- Check first with: SELECT id, full_name, username FROM profiles WHERE full_name ILIKE '%marcus%';
    SELECT p.id INTO marcus_id
    FROM profiles p
    WHERE p.full_name ILIKE '%marcus%'
    LIMIT 1;

    IF marcus_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = marcus_id;
        RAISE NOTICE 'Deleted Marcus account (%)', marcus_id;
    ELSE
        RAISE NOTICE 'Marcus account not found';
    END IF;

END $$;
