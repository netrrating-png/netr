-- Add game invite card support to crew messages
ALTER TABLE crew_messages
  ADD COLUMN IF NOT EXISTS message_type TEXT NOT NULL DEFAULT 'text',
  ADD COLUMN IF NOT EXISTS game_id      UUID REFERENCES games(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_pinned    BOOLEAN NOT NULL DEFAULT FALSE;

-- Poll responses for crew game invite cards
CREATE TABLE IF NOT EXISTS crew_poll_responses (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id  UUID        NOT NULL REFERENCES crew_messages(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  response    TEXT        NOT NULL CHECK (response IN ('in', 'out', 'maybe')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(message_id, user_id)
);

ALTER TABLE crew_poll_responses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can manage own poll responses"
  ON crew_poll_responses FOR ALL TO authenticated
  USING (true) WITH CHECK (user_id = auth.uid());
