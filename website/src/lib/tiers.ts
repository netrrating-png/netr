// Ported from ios/NETR/Models/NETRRatingScale.swift
// Source of truth for tier definitions, colors, and helpers

export interface NETRTier {
  name: string
  min: number
  max: number
  hexColor: string
  description: string
  percentile: string
  stat: string
  isLocked: boolean
  barWidth: number
}

// Ordered highest → lowest (matching Swift source)
export const TIERS: NETRTier[] = [
  {
    name: 'In The League',
    min: 9.5,
    max: 9.9,
    hexColor: '#C40010',
    description:
      'Reserved exclusively for verified NBA, WNBA, G-League, and professional players. There is no amount of pickup games that gets you here.',
    percentile: 'Verified Only',
    stat: 'Pros exclusively',
    isLocked: true,
    barWidth: 1.0,
  },
  {
    name: 'Certified',
    min: 9.0,
    max: 9.4,
    hexColor: '#FF3B30',
    description:
      'The highest reachable tier for pickup players. Everyone at the court knows your name before you touch the ball. Semi-pro talent. Undeniable presence.',
    percentile: 'Top 1%',
    stat: 'Extremely rare',
    isLocked: false,
    barWidth: 0.88,
  },
  {
    name: 'Elite',
    min: 8.0,
    max: 8.9,
    hexColor: '#FF7A00',
    description:
      'You dominate most runs you step into. Whether it\'s organized ball or years of grinding — the result is the same. You can hoop.',
    percentile: 'Top 3%',
    stat: 'Rare',
    isLocked: false,
    barWidth: 0.76,
  },
  {
    name: 'Built Different',
    min: 7.0,
    max: 7.9,
    hexColor: '#FFC247',
    description:
      "Something in your game stands out. Doesn't matter if it was the weight room, the gym, or thousands of hours at the park — people feel it when they guard you.",
    percentile: 'Top 10%',
    stat: 'Serious hoopers',
    isLocked: false,
    barWidth: 0.62,
  },
  {
    name: 'Hooper',
    min: 6.0,
    max: 6.9,
    hexColor: '#39FF14',
    description:
      "Nobody questions if you belong. You make plays, understand the game, hold your own in any run. Top quarter of all pickup players.",
    percentile: 'Top 20%',
    stat: 'Park regular',
    isLocked: false,
    barWidth: 0.5,
  },
  {
    name: 'Got Game',
    min: 5.0,
    max: 5.9,
    hexColor: '#2ECC71',
    description:
      'You contribute, you compete, you make your team better. Better than most people who lace up. The ceiling is right there.',
    percentile: 'Top 35%',
    stat: 'Above average',
    isLocked: false,
    barWidth: 0.39,
  },
  {
    name: 'Prospect',
    min: 4.0,
    max: 4.9,
    hexColor: '#2DA8FF',
    description:
      'The foundation is there. Whether you built it at organized practice, the rec center, or grinding at the park every weekend — you can play.',
    percentile: 'Above Avg',
    stat: 'Developing',
    isLocked: false,
    barWidth: 0.28,
  },
  {
    name: 'On The Come Up',
    min: 3.0,
    max: 3.9,
    hexColor: '#7B9FFF',
    description:
      'The real average — the majority of people who show up to a pickup game land right here. You showed up, you ran, you\'re putting in reps.',
    percentile: 'Average',
    stat: 'Most players',
    isLocked: false,
    barWidth: 0.18,
  },
  {
    name: 'Fresh Laces',
    min: 2.0,
    max: 2.9,
    hexColor: '#9B8BFF',
    description:
      "Everybody started here. You laced up, you showed up — that's the whole thing. Your score will move as your game does.",
    percentile: 'Just Starting',
    stat: 'The beginning',
    isLocked: false,
    barWidth: 0.08,
  },
]

export function getTierForScore(score: number | null | undefined): NETRTier | null {
  if (score == null) return null
  return TIERS.find((t) => score >= t.min && score <= t.max) ?? null
}

export function getColorForScore(score: number | null | undefined): string {
  const tier = getTierForScore(score)
  return tier?.hexColor ?? '#444444'
}

export function getTierNameForScore(score: number | null | undefined): string {
  const tier = getTierForScore(score)
  return tier?.name ?? 'Unrated'
}

export function formatScore(score: number | null | undefined): string {
  if (score == null) return '—'
  return score.toFixed(1)
}

// Normalized 0–1 progress for score ring (scale 2.0–9.9)
export function scoreProgress(score: number | null | undefined): number {
  if (score == null) return 0
  return Math.max(0, Math.min(1, (score - 2.0) / 7.9))
}

// ── Skill categories (7) — ported from RatingModels.swift ──────────────────

export interface SkillCategory {
  id: string
  label: string
  description: string
  colorHex: string
}

export const SKILL_CATEGORIES: SkillCategory[] = [
  { id: 'cat_shooting',      label: 'Scoring',    description: 'Shot creation & consistency',      colorHex: '#39FF14' },
  { id: 'cat_finishing',     label: 'Finishing',  description: 'At the rim through contact',       colorHex: '#FF7A00' },
  { id: 'cat_dribbling',     label: 'Handles',    description: 'Ball handling & shot creation',    colorHex: '#FFC247' },
  { id: 'cat_passing',       label: 'Playmaking', description: 'Vision, passing & court reads',    colorHex: '#2ECC71' },
  { id: 'cat_defense',       label: 'Defense',    description: 'On-ball, help & intensity',        colorHex: '#FF3B30' },
  { id: 'cat_rebounding',    label: 'Rebounding', description: 'Boxing out & crashing the boards', colorHex: '#2DA8FF' },
  { id: 'cat_basketball_iq', label: 'IQ',         description: 'Spacing, reads & decision-making', colorHex: '#9B8BFF' },
]

// ── Vibe tier helper ────────────────────────────────────────────────────────

export interface VibeTier {
  label: string
  emoji: string
  colorHex: string
}

export function getVibeTier(score: number | null | undefined): VibeTier {
  if (score == null) return { label: 'No Vibe Yet', emoji: '⚪', colorHex: '#6A6A82' }
  if (score >= 4.5) return { label: 'Great Vibe', emoji: '🟢', colorHex: '#39FF14' }
  if (score >= 3.5) return { label: 'Solid', emoji: '🟡', colorHex: '#FFD700' }
  if (score >= 2.5) return { label: 'Mixed', emoji: '🟠', colorHex: '#FF7A00' }
  return { label: 'Bad Vibe', emoji: '🔴', colorHex: '#FF3B30' }
}
