import { notFound } from 'next/navigation'
import Image from 'next/image'
import {
  getProfileByUsername,
  type Profile,
} from '@/lib/supabase'
import {
  getTierForScore,
  getColorForScore,
  getTierNameForScore,
  formatScore,
  scoreProgress,
  getVibeTier,
  SKILL_CATEGORIES,
} from '@/lib/tiers'

export const revalidate = 60 // revalidate every 60s (ISR)

export async function generateMetadata({
  params,
}: {
  params: { username: string }
}) {
  const profile = await getProfileByUsername(params.username)
  if (!profile) return { title: 'Player Not Found — NETR' }
  return {
    title: `${profile.full_name ?? params.username} (@${params.username}) — NETR`,
    description: `${profile.full_name}'s NETR score is ${formatScore(profile.netr_score)} — ${getTierNameForScore(profile.netr_score)}. View their skill breakdown on NETR.`,
  }
}

export default async function PlayerPage({
  params,
}: {
  params: { username: string }
}) {
  const profile = await getProfileByUsername(params.username)

  if (!profile) {
    notFound()
  }

  return <PlayerProfile profile={profile} />
}

// ── Profile Display ───────────────────────────────────────────────────────────

function PlayerProfile({ profile }: { profile: Profile }) {
  const score = profile.netr_score
  const tier = getTierForScore(score)
  const color = getColorForScore(score)
  const tierName = getTierNameForScore(score)
  const vibeTier = getVibeTier(profile.vibe_score)
  const progress = scoreProgress(score)

  // Ring circumference: r=52 → C = 2π*52 ≈ 326.7
  const CIRCUMFERENCE = 326.7
  const dashOffset = CIRCUMFERENCE * (1 - progress)

  // Avatar ring: dashed for provisional (<5 ratings), purple for prospect, else tier color
  const isProvisional = (profile.total_ratings ?? 0) < 5
  const ringColor = profile.is_prospect ? '#A855F7' : isProvisional ? '#2A2A35' : color
  const ringStyle = isProvisional ? '8 4' : undefined

  return (
    <div style={{ backgroundColor: '#040406', minHeight: '100vh' }}>
      <div style={{ maxWidth: 680, margin: '0 auto', padding: '0 20px 80px' }}>

        {/* ── Hero ───────────────────────────────────────────────── */}
        <div
          style={{
            paddingTop: 48,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 20,
            marginBottom: 36,
          }}
        >
          {/* Avatar with ring */}
          <div style={{ position: 'relative', width: 120, height: 120 }}>
            {/* SVG ring */}
            <svg
              width={120}
              height={120}
              style={{ position: 'absolute', top: 0, left: 0, transform: 'rotate(-90deg)' }}
            >
              {/* Track */}
              <circle cx={60} cy={60} r={52} fill="none" stroke="#2A2A35" strokeWidth={4} />
              {/* Progress */}
              {score != null && (
                <circle
                  cx={60}
                  cy={60}
                  r={52}
                  fill="none"
                  stroke={ringColor}
                  strokeWidth={4}
                  strokeLinecap="round"
                  strokeDasharray={ringStyle ?? `${CIRCUMFERENCE}`}
                  strokeDashoffset={ringStyle ? undefined : dashOffset}
                  style={{
                    filter: `drop-shadow(0 0 6px ${ringColor}80)`,
                  }}
                />
              )}
              {score == null && (
                <circle
                  cx={60}
                  cy={60}
                  r={52}
                  fill="none"
                  stroke="#2A2A35"
                  strokeWidth={4}
                  strokeDasharray="8 4"
                />
              )}
            </svg>

            {/* Avatar */}
            <div
              style={{
                position: 'absolute',
                inset: 8,
                borderRadius: '50%',
                overflow: 'hidden',
                background: '#0F0F14',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              {profile.avatar_url ? (
                <Image
                  src={profile.avatar_url}
                  alt={profile.full_name ?? 'Player'}
                  fill
                  style={{ objectFit: 'cover' }}
                />
              ) : (
                <span
                  style={{
                    fontSize: 40,
                    fontWeight: 900,
                    color: color,
                  }}
                >
                  {(profile.full_name ?? '?')[0].toUpperCase()}
                </span>
              )}
            </div>
          </div>

          {/* Name + meta */}
          <div style={{ textAlign: 'center' }}>
            <h1 style={{ fontSize: 28, fontWeight: 900, color: '#fff', marginBottom: 4 }}>
              {profile.full_name ?? `@${profile.username}`}
            </h1>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
              <span style={{ fontSize: 14, color: '#6A6A82' }}>@{profile.username}</span>
              {profile.is_verified_pro && (
                <span
                  style={{
                    fontSize: 10,
                    fontWeight: 800,
                    color: '#C40010',
                    background: '#C4001018',
                    border: '1px solid #C4001040',
                    borderRadius: 99,
                    padding: '2px 8px',
                    letterSpacing: 0.5,
                  }}
                >
                  ⭐ PRO
                </span>
              )}
              {profile.is_prospect && (
                <span
                  style={{
                    fontSize: 10,
                    fontWeight: 700,
                    color: '#A855F7',
                    background: '#A855F718',
                    border: '1px solid #A855F740',
                    borderRadius: 99,
                    padding: '2px 8px',
                  }}
                >
                  Prospect
                </span>
              )}
            </div>

            {/* Position + stats row */}
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 12,
                marginTop: 12,
                flexWrap: 'wrap',
              }}
            >
              {profile.position && (
                <Chip label={profile.position} color="#6A6A82" />
              )}
              <Chip label={`${profile.total_games ?? 0} games`} color="#6A6A82" />
              <Chip label={`${profile.total_ratings ?? 0} reviews`} color="#6A6A82" />
            </div>
          </div>

          {/* NETR Score badge */}
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 8,
            }}
          >
            <div
              style={{
                width: 100,
                height: 100,
                borderRadius: '50%',
                background: `radial-gradient(circle, ${color}20 0%, ${color}06 70%)`,
                border: `3px solid ${color}`,
                boxShadow: `0 0 24px ${color}50`,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 2,
              }}
            >
              <span style={{ fontSize: 32, fontWeight: 900, color, lineHeight: 1 }}>
                {formatScore(score)}
              </span>
              <span
                style={{
                  fontSize: 9,
                  fontWeight: 700,
                  color: `${color}aa`,
                  letterSpacing: 1.5,
                  textTransform: 'uppercase',
                }}
              >
                NETR
              </span>
            </div>

            {/* Tier pill */}
            <span
              style={{
                fontSize: 12,
                fontWeight: 700,
                color: color,
                background: `${color}18`,
                border: `1px solid ${color}40`,
                borderRadius: 99,
                padding: '4px 14px',
              }}
            >
              {tier?.isLocked && '⭐ '}
              {tierName}
            </span>

            {isProvisional && score != null && (
              <span style={{ fontSize: 11, color: '#6A6A82' }}>
                Provisional · needs more ratings
              </span>
            )}
          </div>
        </div>

        {/* ── Skill Breakdown ────────────────────────────────────── */}
        <section style={{ marginBottom: 32 }}>
          <SectionHeader title="Skill Breakdown" />
          <div
            style={{
              background: '#111116',
              border: '1px solid #1E1E26',
              borderRadius: 16,
              overflow: 'hidden',
            }}
          >
            {SKILL_CATEGORIES.map((cat, i) => {
              const val = profile[cat.id as keyof Profile] as number | null
              return (
                <SkillRow
                  key={cat.id}
                  label={cat.label}
                  description={cat.description}
                  value={val}
                  colorHex={cat.colorHex}
                  isLast={i === SKILL_CATEGORIES.length - 1}
                />
              )
            })}
          </div>
        </section>

        {/* ── Vibe Score ─────────────────────────────────────────── */}
        <section style={{ marginBottom: 32 }}>
          <SectionHeader title="Vibe Score" />
          <div
            style={{
              background: '#111116',
              border: '1px solid #1E1E26',
              borderRadius: 16,
              padding: '20px 20px',
              display: 'flex',
              alignItems: 'center',
              gap: 16,
            }}
          >
            <span style={{ fontSize: 32 }}>{vibeTier.emoji}</span>
            <div>
              <div
                style={{
                  fontSize: 20,
                  fontWeight: 800,
                  color: vibeTier.colorHex,
                  marginBottom: 2,
                }}
              >
                {vibeTier.label}
              </div>
              <div style={{ fontSize: 12, color: '#6A6A82' }}>
                {profile.vibe_score != null
                  ? `${profile.vibe_score.toFixed(1)} / 4.0 — Based on "Would you run with them again?"`
                  : 'No vibe ratings yet'}
              </div>
            </div>
            {profile.vibe_score != null && (
              <div
                style={{
                  marginLeft: 'auto',
                  fontSize: 28,
                  fontWeight: 900,
                  color: vibeTier.colorHex,
                }}
              >
                {profile.vibe_score.toFixed(1)}
              </div>
            )}
          </div>
          <p style={{ fontSize: 11, color: '#6A6A82', marginTop: 8, paddingLeft: 4 }}>
            Vibe is separate from the NETR skill score.
          </p>
        </section>

        {/* ── About NETR link ────────────────────────────────────── */}
        <div
          style={{
            background: '#111116',
            border: '1px solid #1E1E26',
            borderRadius: 14,
            padding: '16px 20px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <div>
            <p style={{ fontSize: 13, fontWeight: 600, color: '#fff', marginBottom: 2 }}>
              What does this score mean?
            </p>
            <p style={{ fontSize: 12, color: '#6A6A82' }}>
              See all 9 tiers explained
            </p>
          </div>
          <a
            href="/rating"
            style={{
              fontSize: 12,
              fontWeight: 700,
              color: '#39FF14',
              background: '#39FF1418',
              border: '1px solid #39FF1440',
              borderRadius: 99,
              padding: '6px 14px',
              whiteSpace: 'nowrap',
            }}
          >
            View Scale →
          </a>
        </div>
      </div>
    </div>
  )
}

// ── Sub-components ────────────────────────────────────────────────────────────

function SectionHeader({ title }: { title: string }) {
  return (
    <h2
      style={{
        fontSize: 13,
        fontWeight: 700,
        letterSpacing: 1,
        color: '#6A6A82',
        textTransform: 'uppercase',
        marginBottom: 12,
      }}
    >
      {title}
    </h2>
  )
}

function Chip({ label, color }: { label: string; color: string }) {
  return (
    <span
      style={{
        fontSize: 11,
        fontWeight: 600,
        color,
        background: `${color}18`,
        border: `1px solid ${color}40`,
        borderRadius: 99,
        padding: '3px 10px',
      }}
    >
      {label}
    </span>
  )
}

function SkillRow({
  label,
  description,
  value,
  colorHex,
  isLast,
}: {
  label: string
  description: string
  value: number | null
  colorHex: string
  isLast: boolean
}) {
  // value is 1–10 scale
  const pct = value != null ? (value / 10) * 100 : 0

  return (
    <div
      style={{
        padding: '14px 18px',
        borderBottom: isLast ? 'none' : '1px solid #1E1E26',
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: 8,
        }}
      >
        <div>
          <span style={{ fontSize: 14, fontWeight: 700, color: '#fff' }}>{label}</span>
          <span style={{ fontSize: 11, color: '#6A6A82', marginLeft: 8 }}>{description}</span>
        </div>
        <span
          style={{
            fontSize: 16,
            fontWeight: 900,
            color: value != null ? colorHex : '#2A2A35',
            minWidth: 32,
            textAlign: 'right',
          }}
        >
          {value != null ? value.toFixed(1) : '—'}
        </span>
      </div>
      {/* Bar */}
      <div
        style={{
          height: 4,
          borderRadius: 99,
          background: '#2A2A35',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            height: '100%',
            width: `${pct}%`,
            borderRadius: 99,
            background: `linear-gradient(90deg, ${colorHex}80, ${colorHex})`,
            boxShadow: value != null ? `0 0 6px ${colorHex}60` : 'none',
            transition: 'width 0.8s cubic-bezier(0.34, 1.56, 0.64, 1)',
          }}
        />
      </div>
    </div>
  )
}
