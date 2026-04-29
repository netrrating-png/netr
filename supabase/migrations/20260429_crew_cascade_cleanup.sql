-- ============================================================
-- Migration: Crew membership cascade cleanup
-- Date: 2026-04-29
-- Description:
--   Fixes orphaned "Player" ghost entries in crew groups caused
--   by account deletions that didn't remove crew membership rows.
--
--   Steps:
--     1. One-time cleanup of existing orphaned crew_members rows
--     2. One-time cleanup of orphaned crew_messages rows
--     3. Delete crews that have zero members after cleanup
--     4. Create a trigger on profiles so future account deletions
--        automatically clean up crew memberships, transfer admin
--        rights to the next member (or delete the crew if empty),
--        and purge the deleted user's messages
-- ============================================================


-- ── 1. Remove existing orphaned crew members ─────────────────
-- Targets rows whose user_id no longer maps to any profile.
-- lower() + ::text cast handles both UUID and TEXT column types,
-- and the mixed-case IDs stored by early app versions.

DELETE FROM crew_members cm
WHERE NOT EXISTS (
    SELECT 1 FROM profiles p
    WHERE lower(p.id::text) = lower(cm.user_id::text)
);


-- ── 2. Remove orphaned crew messages ─────────────────────────

DELETE FROM crew_messages msg
WHERE NOT EXISTS (
    SELECT 1 FROM profiles p
    WHERE lower(p.id::text) = lower(msg.sender_id::text)
);


-- ── 3. Delete crews that are now empty ───────────────────────

DELETE FROM crews
WHERE id NOT IN (SELECT DISTINCT crew_id FROM crew_members);


-- ── 4. Trigger: auto-cleanup when a profile is deleted ───────

CREATE OR REPLACE FUNCTION cleanup_crew_on_profile_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_crew_id  TEXT;
    v_next_admin TEXT;
BEGIN
    -- For every crew where the deleted user is the admin:
    -- promote the next member, or let the crew fall through
    -- to the empty-crew delete below.
    FOR v_crew_id IN
        SELECT id FROM crews
        WHERE lower(admin_id::text) = lower(OLD.id::text)
    LOOP
        SELECT user_id INTO v_next_admin
        FROM crew_members
        WHERE crew_id = v_crew_id
          AND lower(user_id::text) != lower(OLD.id::text)
        ORDER BY joined_at ASC
        LIMIT 1;

        IF v_next_admin IS NOT NULL THEN
            UPDATE crews SET admin_id = v_next_admin WHERE id = v_crew_id;
        END IF;
        -- If v_next_admin IS NULL the crew had only this user;
        -- it will be deleted in the empty-crew step below.
    END LOOP;

    -- Remove all crew memberships for the deleted user
    DELETE FROM crew_members
    WHERE lower(user_id::text) = lower(OLD.id::text);

    -- Remove all crew messages sent by the deleted user
    DELETE FROM crew_messages
    WHERE lower(sender_id::text) = lower(OLD.id::text);

    -- Delete any crews that are now memberless
    DELETE FROM crews
    WHERE id NOT IN (SELECT DISTINCT crew_id FROM crew_members);

    RETURN OLD;
END;
$$;


DROP TRIGGER IF EXISTS on_profile_delete_clean_crews ON profiles;

CREATE TRIGGER on_profile_delete_clean_crews
    BEFORE DELETE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_crew_on_profile_delete();
