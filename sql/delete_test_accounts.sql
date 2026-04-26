-- ─────────────────────────────────────────────────────────────
-- Remove test/demo accounts from production
--
-- Run this in the Supabase SQL Editor.
-- Deleting from auth.users cascades to profiles via FK.
--
-- Accounts targeted:
--   - Nolan Carter  (nolan123@gmail.com / @nolan_c)
--   - Marcus T.     (@marc_t)
--   - Dre Williams  (@dre_w)
-- ─────────────────────────────────────────────────────────────

DO $$
DECLARE
    nolan_id  UUID;
    marcus_id UUID;
    dre_id    UUID;
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

    -- ── Marcus T. (@marc_t) ───────────────────────────────────
    SELECT id INTO marcus_id
    FROM profiles
    WHERE username = '@marc_t'
    LIMIT 1;

    IF marcus_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = marcus_id;
        RAISE NOTICE 'Deleted Marcus T. (%)', marcus_id;
    ELSE
        RAISE NOTICE 'Marcus T. (@marc_t) not found';
    END IF;

    -- ── Dre Williams (@dre_w) ────────────────────────────────
    SELECT id INTO dre_id
    FROM profiles
    WHERE username = '@dre_w'
    LIMIT 1;

    IF dre_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = dre_id;
        RAISE NOTICE 'Deleted Dre Williams (%)', dre_id;
    ELSE
        RAISE NOTICE 'Dre Williams (@dre_w) not found';
    END IF;

END $$;
