-- Migration: Add is_verified_pro to profiles
-- Run this against your Supabase project

-- 1. Add is_verified_pro boolean column to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_verified_pro BOOLEAN NOT NULL DEFAULT false;

-- 2. Create index for quick lookups of verified pros
CREATE INDEX IF NOT EXISTS idx_profiles_is_verified_pro ON profiles(is_verified_pro) WHERE is_verified_pro = true;
