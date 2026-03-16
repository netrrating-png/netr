-- Add photo and court attachment columns to post_comments
ALTER TABLE post_comments
  ADD COLUMN IF NOT EXISTS photo_url TEXT,
  ADD COLUMN IF NOT EXISTS court_id TEXT REFERENCES courts(id);
