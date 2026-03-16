-- NETR Base Schema
-- Run this first in Supabase SQL Editor before any other migrations

-- ─── PROFILES ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    username TEXT UNIQUE,
    position TEXT,
    date_of_birth DATE,
    bio TEXT,
    avatar_url TEXT,
    is_prospect BOOLEAN DEFAULT false,
    total_ratings INT DEFAULT 0,
    total_games INT DEFAULT 0,
    netr_score DOUBLE PRECISION,
    cat_shooting DOUBLE PRECISION,
    cat_finishing DOUBLE PRECISION,
    cat_dribbling DOUBLE PRECISION,
    cat_passing DOUBLE PRECISION,
    cat_defense DOUBLE PRECISION,
    cat_rebounding DOUBLE PRECISION,
    cat_basketball_iq DOUBLE PRECISION,
    vibe_score DOUBLE PRECISION,
    vibe_communication DOUBLE PRECISION,
    vibe_unselfishness DOUBLE PRECISION,
    vibe_effort DOUBLE PRECISION,
    vibe_attitude DOUBLE PRECISION,
    vibe_inclusion DOUBLE PRECISION,
    is_verified_pro BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone"
    ON profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile"
    ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE USING (auth.uid() = id);

-- ─── COURTS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS courts (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name TEXT NOT NULL,
    address TEXT,
    city TEXT,
    state TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    indoor BOOLEAN DEFAULT false,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE courts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view courts"
    ON courts FOR SELECT USING (true);

CREATE POLICY "Authenticated users can add courts"
    ON courts FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ─── GAMES ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS games (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    court_id TEXT REFERENCES courts(id),
    host_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    join_code TEXT NOT NULL UNIQUE,
    format TEXT NOT NULL,
    skill_level TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'waiting',
    max_players INT NOT NULL DEFAULT 10,
    scheduled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE games ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view games"
    ON games FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create games"
    ON games FOR INSERT WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Host can update game"
    ON games FOR UPDATE USING (auth.uid() = host_id);

-- ─── GAME PLAYERS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS game_players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    checked_out_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(game_id, user_id)
);

ALTER TABLE game_players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view game players"
    ON game_players FOR SELECT USING (true);

CREATE POLICY "Authenticated users can join games"
    ON game_players FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Players can update their own record"
    ON game_players FOR UPDATE USING (auth.uid() = user_id);

-- ─── FEED POSTS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS feed_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT,
    photo_url TEXT,
    likes INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE feed_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view feed posts"
    ON feed_posts FOR SELECT USING (true);

CREATE POLICY "Authenticated users can post"
    ON feed_posts FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own posts"
    ON feed_posts FOR DELETE USING (auth.uid() = user_id);

-- ─── INDEXES ─────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_netr_score ON profiles(netr_score DESC);
CREATE INDEX IF NOT EXISTS idx_games_status ON games(status);
CREATE INDEX IF NOT EXISTS idx_games_join_code ON games(join_code);
CREATE INDEX IF NOT EXISTS idx_game_players_game_id ON game_players(game_id);
CREATE INDEX IF NOT EXISTS idx_feed_posts_user_id ON feed_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_feed_posts_created_at ON feed_posts(created_at DESC);
