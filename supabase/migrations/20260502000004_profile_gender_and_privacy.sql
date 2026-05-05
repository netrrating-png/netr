-- Profile additions for the public-profile work:
-- * gender: captured in onboarding but never persisted; needed so a 6.5 F
--   and a 6.5 M can be told apart and so the women's pickup filter works.
-- * show_milestones / show_crews / show_leagues: privacy toggles that
--   gate sections on PublicPlayerProfileView. Default true so existing
--   users opt in automatically.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS show_milestones boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS show_crews      boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS show_leagues    boolean NOT NULL DEFAULT true;

-- Loose CHECK so future free-text values don't break the app — keep the
-- known set documented but accept anything non-empty.
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_gender_known;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_gender_known
  CHECK (gender IS NULL OR length(trim(gender)) > 0);
