-- Add lat/lng to profiles for Discover tab (nearby players within 5 miles)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS lat float8,
  ADD COLUMN IF NOT EXISTS lng float8;

-- Index for bounding box queries used by the Discover tab
CREATE INDEX IF NOT EXISTS profiles_lat_lng_idx ON profiles (lat, lng)
  WHERE lat IS NOT NULL AND lng IS NOT NULL;
