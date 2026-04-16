-- Push notification infrastructure
-- Adds apns_token column + a devices table for multi-device support.
-- Safe to re-run.

-- ─── PROFILES — APNs token ─────────────────────────────────
-- Single-device convenience column. Current iOS code writes here.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS apns_token TEXT;
CREATE INDEX IF NOT EXISTS idx_profiles_apns_token ON profiles(apns_token) WHERE apns_token IS NOT NULL;

-- ─── DEVICES — multi-device future-proofing ────────────────
-- One row per user+device. When a user signs in on iPad and iPhone, both
-- get pushed. Primary key is (user_id, apns_token) so re-registering the
-- same device upserts cleanly.
CREATE TABLE IF NOT EXISTS devices (
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    apns_token  TEXT NOT NULL,
    platform    TEXT NOT NULL DEFAULT 'ios',
    environment TEXT NOT NULL DEFAULT 'development' CHECK (environment IN ('development', 'production')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, apns_token)
);

CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "devices_select_own" ON devices;
CREATE POLICY "devices_select_own"
    ON devices FOR SELECT
    TO authenticated
    USING (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "devices_upsert_own" ON devices;
CREATE POLICY "devices_upsert_own"
    ON devices FOR INSERT
    TO authenticated
    WITH CHECK (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "devices_update_own" ON devices;
CREATE POLICY "devices_update_own"
    ON devices FOR UPDATE
    TO authenticated
    USING (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "devices_delete_own" ON devices;
CREATE POLICY "devices_delete_own"
    ON devices FOR DELETE
    TO authenticated
    USING (user_id::text = auth.uid()::text);

NOTIFY pgrst, 'reload schema';
