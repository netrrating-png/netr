-- ─────────────────────────────────────────────────────────────
-- Remove test/demo accounts from production
--
-- Run this in the Supabase SQL Editor (service role).
-- Step 1: deletes profile + all related data via cascade.
-- Step 2: removes auth users so they can't log back in.
--
-- Accounts targeted:
--   - Nolan Carter  (nolan123@gmail.com / nolan_c)
--   - Marcus T.     (marc_t)
--   - Dre Williams  (dre_w)
-- ─────────────────────────────────────────────────────────────

-- ── Step 1: preview what will be deleted (run this first) ───
-- SELECT id, full_name, username FROM profiles
-- WHERE username IN ('nolan_c', 'marc_t', 'dre_w');

-- ── Step 2: delete profiles (cascades to ratings, game_players, etc.) ──
DELETE FROM profiles
WHERE username IN ('nolan_c', 'marc_t', 'dre_w');

-- ── Step 3: delete auth users ────────────────────────────────
DELETE FROM auth.users
WHERE id IN (
    -- Nolan by email
    SELECT id FROM auth.users WHERE email = 'nolan123@gmail.com'
);

-- NOTE: If Step 3 fails or auth.users rows persist, delete Marcus and Dre
-- manually via: Supabase Dashboard → Authentication → Users → search by name → Delete
