-- ============================================================
-- NETR: Add missing game_format enum values (1v1, 2v2, 3v3, 4v4)
-- The enum was created with only certain values; this adds the rest.
-- Run this in Supabase SQL Editor → New query → Run
-- ============================================================

-- Add each missing value only if it doesn't already exist.
-- ALTER TYPE … ADD VALUE is safe to run multiple times when wrapped
-- in a DO block with a check.

DO $$
BEGIN
    -- 1v1
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = '1v1'
          AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'game_format')
    ) THEN
        ALTER TYPE game_format ADD VALUE '1v1';
    END IF;

    -- 2v2
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = '2v2'
          AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'game_format')
    ) THEN
        ALTER TYPE game_format ADD VALUE '2v2';
    END IF;

    -- 3v3
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = '3v3'
          AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'game_format')
    ) THEN
        ALTER TYPE game_format ADD VALUE '3v3';
    END IF;

    -- 4v4
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = '4v4'
          AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'game_format')
    ) THEN
        ALTER TYPE game_format ADD VALUE '4v4';
    END IF;

    -- 5v5 (likely already exists, but guard anyway)
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = '5v5'
          AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'game_format')
    ) THEN
        ALTER TYPE game_format ADD VALUE '5v5';
    END IF;

    -- Run (already exists per codebase comment, but guard anyway)
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = 'Run'
          AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'game_format')
    ) THEN
        ALTER TYPE game_format ADD VALUE 'Run';
    END IF;
END $$;

-- Reload PostgREST schema cache so changes are live immediately
NOTIFY pgrst, 'reload schema';
