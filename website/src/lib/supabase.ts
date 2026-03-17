import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// ── Types matching the profiles table schema (base_schema.sql) ──────────────

export interface Profile {
  id: string
  full_name: string | null
  username: string | null
  position: string | null
  date_of_birth: string | null
  bio: string | null
  avatar_url: string | null
  is_prospect: boolean
  total_ratings: number
  total_games: number
  netr_score: number | null
  cat_shooting: number | null
  cat_finishing: number | null
  cat_dribbling: number | null
  cat_passing: number | null
  cat_defense: number | null
  cat_rebounding: number | null
  cat_basketball_iq: number | null
  vibe_score: number | null
  is_verified_pro: boolean
  created_at: string
}

// Fetch a single player profile by username (read-only, public)
export async function getProfileByUsername(username: string): Promise<Profile | null> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('username', username)
    .single()

  if (error) {
    console.error('[NETR] getProfileByUsername error:', error.message)
    return null
  }
  return data as Profile
}

// Fetch top players by NETR score (leaderboard / home page)
export async function getTopPlayers(limit = 20): Promise<Profile[]> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .not('netr_score', 'is', null)
    .order('netr_score', { ascending: false })
    .limit(limit)

  if (error) {
    console.error('[NETR] getTopPlayers error:', error.message)
    return []
  }
  return (data ?? []) as Profile[]
}
