-- Auto-create a profiles row whenever a new user signs up via any method
-- (email, Google, Apple, etc.). Without this, OAuth users have no profile
-- row and the app breaks after sign-in.
--
-- Metadata sources:
--   Google:  raw_user_meta_data->>'name', 'avatar_url', 'email'
--   Apple:   raw_user_meta_data->>'full_name'  (only sent on first sign-in)
--   Email:   raw_user_meta_data->>'full_name', 'username'  (set during signUp)

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  base_username TEXT;
  final_username TEXT;
  counter       INT := 0;
  display_name  TEXT;
  avatar        TEXT;
BEGIN
  -- Resolve display name: prefer explicit full_name, fall back to Google's "name", then email prefix
  display_name := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
    NULLIF(NEW.raw_user_meta_data->>'name', ''),
    split_part(COALESCE(NEW.email, ''), '@', 1)
  );

  -- Avatar from OAuth providers (Google supplies this; Apple/email do not)
  avatar := NULLIF(NEW.raw_user_meta_data->>'avatar_url', '');

  -- Build a base username: use pre-set username from metadata if available,
  -- otherwise derive from email prefix, lowercased and non-alphanumeric → '_'
  base_username := lower(regexp_replace(
    COALESCE(
      NULLIF(NEW.raw_user_meta_data->>'username', ''),
      split_part(COALESCE(NEW.email, 'user'), '@', 1)
    ),
    '[^a-z0-9_]', '_', 'g'
  ));

  -- Guarantee uniqueness by appending an incrementing suffix
  final_username := base_username;
  WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = final_username) LOOP
    counter        := counter + 1;
    final_username := base_username || counter::TEXT;
  END LOOP;

  INSERT INTO public.profiles (id, full_name, username, avatar_url)
  VALUES (NEW.id, display_name, final_username, avatar)
  ON CONFLICT (id) DO NOTHING;  -- email sign-up already inserts its own row

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
