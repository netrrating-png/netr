-- ============================================================
-- NETR: Player Milestones
-- Stores real-world basketball achievements (school teams, leagues, etc.)
-- Does NOT affect NETR score — purely profile/social display
-- ============================================================

CREATE TABLE IF NOT EXISTS player_milestones (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    milestone_type TEXT NOT NULL,   -- e.g. 'hs_jv', 'hs_varsity', 'college_d1'
    team_name    TEXT,              -- e.g. "Jefferson HS", "City College"
    season       TEXT,              -- e.g. "2025-26", "Fall 2025"
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast profile lookups
CREATE INDEX IF NOT EXISTS player_milestones_user_id_idx ON player_milestones(user_id);

-- RLS
ALTER TABLE player_milestones ENABLE ROW LEVEL SECURITY;

-- Anyone can view milestones (public profiles)
CREATE POLICY "Public read milestones"
    ON player_milestones FOR SELECT
    USING (true);

-- Users can only insert/update/delete their own milestones
CREATE POLICY "Own milestones insert"
    ON player_milestones FOR INSERT
    WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Own milestones update"
    ON player_milestones FOR UPDATE
    USING (auth.uid()::text = user_id::text);

CREATE POLICY "Own milestones delete"
    ON player_milestones FOR DELETE
    USING (auth.uid()::text = user_id::text);

NOTIFY pgrst, 'reload schema';
