-- Fix game_players RLS so all authenticated users can see who's in a game.
-- Previously the SELECT policy was restricted to user_id = auth.uid() which
-- caused player counts to show 0/N for other players' rows.

-- Drop any existing overly-restrictive SELECT policy
DROP POLICY IF EXISTS "Users can view their own game player records" ON public.game_players;
DROP POLICY IF EXISTS "game_players_select_own" ON public.game_players;
DROP POLICY IF EXISTS "game_players_select" ON public.game_players;

-- Allow any signed-in user to read all game_players rows.
-- This is intentional: knowing who's in a public game lobby is not sensitive.
CREATE POLICY "Anyone authenticated can read game players"
  ON public.game_players
  FOR SELECT
  TO authenticated
  USING (true);

-- Ensure users can only insert their own row
DROP POLICY IF EXISTS "Users can insert their own game player record" ON public.game_players;
DROP POLICY IF EXISTS "game_players_insert_own" ON public.game_players;
CREATE POLICY "Users can insert their own game player record"
  ON public.game_players
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Ensure users can only update/delete their own row
DROP POLICY IF EXISTS "Users can update their own game player record" ON public.game_players;
DROP POLICY IF EXISTS "game_players_update_own" ON public.game_players;
CREATE POLICY "Users can update their own game player record"
  ON public.game_players
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own game player record" ON public.game_players;
DROP POLICY IF EXISTS "game_players_delete_own" ON public.game_players;
CREATE POLICY "Users can delete their own game player record"
  ON public.game_players
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Make sure RLS is enabled
ALTER TABLE public.game_players ENABLE ROW LEVEL SECURITY;
