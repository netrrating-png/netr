-- Adds the daily_games toggle so users can disable the local Mystery
-- Player + Connections reminders without disabling all push notifications.
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS daily_games boolean NOT NULL DEFAULT true;
