-- Add show_age column to profiles for the "Show Age on Profile" toggle
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS show_age boolean NOT NULL DEFAULT false;
