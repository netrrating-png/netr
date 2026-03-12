-- Migration: Feed photos, court photos, and follows
-- Run this against your Supabase project

-- 1. Add photo_url column to feed_posts
ALTER TABLE feed_posts ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- 2. Create court_photos table
CREATE TABLE IF NOT EXISTS court_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    court_id TEXT NOT NULL REFERENCES courts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_court_photos_court_id ON court_photos(court_id);
CREATE INDEX IF NOT EXISTS idx_court_photos_created_at ON court_photos(created_at DESC);

-- 3. Create follows table (if not exists)
CREATE TABLE IF NOT EXISTS follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(follower_id, following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

-- 4. RLS policies for court_photos
ALTER TABLE court_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view court photos"
    ON court_photos FOR SELECT
    USING (true);

CREATE POLICY "Authenticated users can upload court photos"
    ON court_photos FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own court photos"
    ON court_photos FOR DELETE
    USING (auth.uid() = user_id);

-- 5. RLS policies for follows
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view follows"
    ON follows FOR SELECT
    USING (true);

CREATE POLICY "Authenticated users can follow"
    ON follows FOR INSERT
    WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can unfollow"
    ON follows FOR DELETE
    USING (auth.uid() = follower_id);

-- 6. Storage buckets
-- Run these via Supabase Dashboard or supabase CLI:
--
-- INSERT INTO storage.buckets (id, name, public) VALUES ('feed-photos', 'feed-photos', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('court-photos', 'court-photos', true);
--
-- Storage policies for feed-photos:
-- CREATE POLICY "Anyone can view feed photos" ON storage.objects FOR SELECT USING (bucket_id = 'feed-photos');
-- CREATE POLICY "Auth users can upload feed photos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'feed-photos' AND auth.role() = 'authenticated');
-- CREATE POLICY "Users can delete own feed photos" ON storage.objects FOR DELETE USING (bucket_id = 'feed-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
--
-- Storage policies for court-photos:
-- CREATE POLICY "Anyone can view court photos" ON storage.objects FOR SELECT USING (bucket_id = 'court-photos');
-- CREATE POLICY "Auth users can upload court photos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'court-photos' AND auth.role() = 'authenticated');
-- CREATE POLICY "Users can delete own court photos" ON storage.objects FOR DELETE USING (bucket_id = 'court-photos' AND auth.uid()::text = (storage.foldername(name))[2]);

-- 7. Enable realtime for court_photos
ALTER PUBLICATION supabase_realtime ADD TABLE court_photos;
