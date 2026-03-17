import Link from 'next/link'
import { getTopPlayers, type Profile } from '@/lib/supabase'
import {
  getColorForScore,
  getTierNameForScore,
  formatScore,
} from '@/lib/tiers'

export const revalidate = 60

export default async function HomePage() {
  const players = await getTopPlayers(20)

  return (
    <div style={{ backgroundColor: '#040406', minHeight: '100vh' }}>
      <div style={{ maxWidth: 760, margin: '0 auto', padding: '0 20px 80px' }}>

        {/* ── Hero ───────────────────────────────────────────────── */}
        <div style={{ paddingTop: 64, paddingBottom: 48, textAlign: 'center' }}>
          <p
            style={{
              fontSize: 11,
              fontWeight: 700,
              letterSpacing: 1.6,
              color: '#39FF14',
              textTransform: 'uppercase',
              marginBottom: 14,
            }}
          >
            NYC Pickup Basketball
          </p>
          <h1
            style={{
              fontSize: 'clamp(42px, 10vw, 72px)',
              fontWeight: 900,
              lineHeight: 1,
              color: '#ffffff',
              marginBottom: 16,
              textShadow: '0 0 40px rgba(57,255,20,0.12)',
            }}
          >
            NETR
          </h1>
          <p style={{ color: '#6A6A82', fontSize: 15, lineHeight: 1.6, maxWidth: 420, margin: '0 auto 32px' }}>
            Peer ratings for NYC pickup players. Know your level. Find your tier.
          </p>
          <div style={{ display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link
              href="/rating"
              style={{
                fontSize: 13,
                fontWeight: 700,
                color: '#000',
                background: '#39FF14',
                borderRadius: 99,
                padding: '10px 24px',
                boxShadow: '0 0 16px rgba(57,255,20,0.4)',
              }}
            >
              Explore the Rating Scale →
            </Link>
          </div>
        </div>

        {/* ── Leaderboard ────────────────────────────────────────── */}
        <section>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              marginBottom: 16,
            }}
          >
            <h2
              style={{
                fontSize: 13,
                fontWeight: 700,
                letterSpacing: 1,
                color: '#6A6A82',
                textTransform: 'uppercase',
              }}
            >
              Top Players
            </h2>
            <span style={{ fontSize: 11, color: '#2A2A35' }}>
              Updated every 60s
            </span>
          </div>

          {players.length === 0 ? (
            <EmptyLeaderboard />
          ) : (
            <div
              style={{
                background: '#111116',
                border: '1px solid #1E1E26',
                borderRadius: 16,
                overflow: 'hidden',
              }}
            >
              {players.map((player, i) => (
                <PlayerRow
                  key={player.id}
                  player={player}
                  rank={i + 1}
                  isLast={i === players.length - 1}
                />
              ))}
            </div>
          )}
        </section>

        {/* ── Quick tier preview ─────────────────────────────────── */}
        <section style={{ marginTop: 48 }}>
          <h2
            style={{
              fontSize: 13,
              fontWeight: 700,
              letterSpacing: 1,
              color: '#6A6A82',
              textTransform: 'uppercase',
              marginBottom: 16,
            }}
          >
            Rating Tiers
          </h2>
          <div
            style={{
              background: '#111116',
              border: '1px solid #1E1E26',
              borderRadius: 16,
              padding: '20px',
              display: 'flex',
              flexDirection: 'column',
              gap: 10,
            }}
          >
            {TIER_PREVIEW.map((t) => (
              <TierPreviewRow key={t.name} {...t} />
            ))}
          </div>
          <div style={{ textAlign: 'center', marginTop: 16 }}>
            <Link
              href="/rating"
              style={{ fontSize: 13, fontWeight: 600, color: '#39FF14' }}
            >
              See all 9 tiers with full descriptions →
            </Link>
          </div>
        </section>
      </div>
    </div>
  )
}

// ── Sub-components ────────────────────────────────────────────────────────────

function PlayerRow({
  player,
  rank,
  isLast,
}: {
  player: Profile
  rank: number
  isLast: boolean
}) {
  const color = getColorForScore(player.netr_score)
  const tierName = getTierNameForScore(player.netr_score)

  return (
    <Link
      href={`/player/${player.username}`}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 14,
        padding: '14px 18px',
        borderBottom: isLast ? 'none' : '1px solid #1E1E26',
        transition: 'background 0.15s',
        textDecoration: 'none',
      }}
    >
      {/* Rank */}
      <span
        style={{
          fontSize: rank <= 3 ? 16 : 13,
          fontWeight: 900,
          color: rank === 1 ? '#FFD700' : rank === 2 ? '#C0C0C0' : rank === 3 ? '#CD7F32' : '#2A2A35',
          minWidth: 24,
          textAlign: 'center',
        }}
      >
        {rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : rank}
      </span>

      {/* Avatar */}
      <div
        style={{
          width: 40,
          height: 40,
          borderRadius: '50%',
          background: '#0F0F14',
          border: `2px solid ${color}60`,
          boxShadow: `0 0 8px ${color}30`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
          overflow: 'hidden',
          fontSize: 18,
          fontWeight: 900,
          color,
        }}
      >
        {player.full_name?.[0]?.toUpperCase() ?? '?'}
      </div>

      {/* Name + tier */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 700, color: '#fff', marginBottom: 1 }}>
          {player.full_name ?? `@${player.username}`}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 11, color: '#6A6A82' }}>@{player.username}</span>
          {player.position && (
            <span
              style={{
                fontSize: 10,
                fontWeight: 600,
                color: '#6A6A82',
                background: '#1E1E26',
                borderRadius: 4,
                padding: '1px 5px',
              }}
            >
              {player.position}
            </span>
          )}
        </div>
      </div>

      {/* Score + tier */}
      <div style={{ textAlign: 'right' }}>
        <div style={{ fontSize: 20, fontWeight: 900, color, marginBottom: 1 }}>
          {formatScore(player.netr_score)}
        </div>
        <div style={{ fontSize: 10, color: `${color}aa`, fontWeight: 600 }}>{tierName}</div>
      </div>
    </Link>
  )
}

function EmptyLeaderboard() {
  return (
    <div
      style={{
        background: '#111116',
        border: '1px solid #1E1E26',
        borderRadius: 16,
        padding: '48px 24px',
        textAlign: 'center',
      }}
    >
      <div style={{ fontSize: 32, marginBottom: 12 }}>🏀</div>
      <p style={{ fontSize: 14, fontWeight: 700, color: '#fff', marginBottom: 6 }}>
        No players yet
      </p>
      <p style={{ fontSize: 12, color: '#6A6A82' }}>
        Connect Supabase and start playing to see the leaderboard.
      </p>
    </div>
  )
}

function TierPreviewRow({
  name,
  range,
  color,
  note,
}: {
  name: string
  range: string
  color: string
  note?: string
}) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <div
        style={{
          width: 8,
          height: 8,
          borderRadius: '50%',
          background: color,
          flexShrink: 0,
          boxShadow: `0 0 6px ${color}80`,
        }}
      />
      <span style={{ fontSize: 13, fontWeight: 700, color: '#fff', minWidth: 140 }}>{name}</span>
      <span style={{ fontSize: 12, color: `${color}cc`, fontFamily: 'monospace' }}>{range}</span>
      {note && (
        <span style={{ fontSize: 11, color: '#6A6A82', marginLeft: 'auto' }}>{note}</span>
      )}
    </div>
  )
}

const TIER_PREVIEW = [
  { name: 'In The League', range: '9.5–9.9', color: '#C40010', note: 'Pros only 🔒' },
  { name: 'Certified',     range: '9.0–9.4', color: '#FF3B30', note: 'Top 1%' },
  { name: 'Elite',         range: '8.0–8.9', color: '#FF7A00', note: 'Top 3%' },
  { name: 'Built Different', range: '7.0–7.9', color: '#FFC247', note: 'Top 10%' },
  { name: 'Hooper',        range: '6.0–6.9', color: '#39FF14', note: 'Top 20%' },
  { name: 'Got Game',      range: '5.0–5.9', color: '#2ECC71', note: 'Top 35%' },
  { name: 'Prospect',      range: '4.0–4.9', color: '#2DA8FF' },
  { name: 'On The Come Up', range: '3.0–3.9', color: '#7B9FFF', note: 'Most players' },
  { name: 'Fresh Laces',   range: '2.0–2.9', color: '#9B8BFF' },
]
