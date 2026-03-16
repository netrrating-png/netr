-- Game integrity: checked_in_at, removed flag, no-show reports
ALTER TABLE game_players ADD COLUMN IF NOT EXISTS checked_in_at timestamptz DEFAULT now();
ALTER TABLE game_players ADD COLUMN IF NOT EXISTS removed boolean DEFAULT false;

CREATE TABLE IF NOT EXISTS no_show_reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    game_id uuid REFERENCES games(id) ON DELETE CASCADE,
    reported_user_id uuid REFERENCES profiles(id),
    reported_by_user_id uuid REFERENCES profiles(id),
    created_at timestamptz DEFAULT now()
);
