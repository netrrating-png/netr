-- Nuclear option: drop ALL policies on game_players (by any name) and recreate.
-- The previous migration dropped policies by guessed names; this catches any
-- remaining policies that may still be blocking cross-user reads/inserts.

DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'game_players' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.game_players', pol.policyname);
  END LOOP;
END;
$$;

-- Anyone signed in can read all game_players rows (lobby is public knowledge)
CREATE POLICY "game_players_select_all"
  ON public.game_players FOR SELECT
  TO authenticated
  USING (true);

-- Users can only insert a row for themselves
CREATE POLICY "game_players_insert_own"
  ON public.game_players FOR INSERT
  TO authenticated
  WITH CHECK (user_id::text = auth.uid()::text);

-- Users can only update their own row
CREATE POLICY "game_players_update_own"
  ON public.game_players FOR UPDATE
  TO authenticated
  USING (user_id::text = auth.uid()::text);

-- Users can only delete their own row
CREATE POLICY "game_players_delete_own"
  ON public.game_players FOR DELETE
  TO authenticated
  USING (user_id::text = auth.uid()::text);

ALTER TABLE public.game_players ENABLE ROW LEVEL SECURITY;
