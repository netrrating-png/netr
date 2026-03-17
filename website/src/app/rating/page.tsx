import { TIERS, type NETRTier } from '@/lib/tiers'

export const metadata = {
  title: 'The NETR Scale — How It Works',
  description:
    'Every tier explained: what your NETR score means, how it\'s calculated, and where you fit among NYC pickup players.',
}

export default function RatingPage() {
  return (
    <div style={{ backgroundColor: '#040406', minHeight: '100vh' }}>
      <div style={{ maxWidth: 760, margin: '0 auto', padding: '0 20px 80px' }}>

        {/* ── Header ─────────────────────────────────────────────── */}
        <div style={{ paddingTop: 48, paddingBottom: 40 }}>
          <p
            style={{
              fontSize: 11,
              fontWeight: 700,
              letterSpacing: 1.4,
              color: '#39FF14',
              textTransform: 'uppercase',
              marginBottom: 12,
            }}
          >
            The NETR Scale
          </p>
          <h1
            style={{
              fontSize: 'clamp(36px, 8vw, 56px)',
              fontWeight: 900,
              lineHeight: 1.05,
              color: '#ffffff',
              marginBottom: 16,
            }}
          >
            Know Your
            <br />
            Level.
          </h1>
          <p style={{ color: '#6A6A82', fontSize: 14, lineHeight: 1.6, maxWidth: 520 }}>
            NETR scores range from{' '}
            <span style={{ color: '#9B8BFF', fontWeight: 600 }}>2.0</span> to{' '}
            <span style={{ color: '#C40010', fontWeight: 600 }}>9.9</span>. Your
            score is calculated using a Bayesian average of peer ratings across 7
            skill categories. The starting prior is{' '}
            <strong style={{ color: '#fff' }}>3.2</strong> — the real average
            pickup player.
          </p>

          {/* Stats callout */}
          <div
            style={{
              display: 'flex',
              gap: 16,
              marginTop: 28,
              flexWrap: 'wrap',
            }}
          >
            <CalloutChip label="3.0–3.9" sub="Where most players land" color="#7B9FFF" />
            <CalloutChip label="6.0+" sub="Top 20–25%" color="#39FF14" />
            <CalloutChip label="9.5–9.9" sub="Verified pros only" color="#C40010" />
          </div>
        </div>

        {/* ── How It Works ───────────────────────────────────────── */}
        <section style={{ marginBottom: 48 }}>
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
            How Scores Are Calculated
          </h2>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
              gap: 12,
            }}
          >
            <InfoCard
              number="1"
              title="Self-Assessment"
              body="You rate yourself in 7 skill categories during onboarding. This seeds your starting NETR score."
            />
            <InfoCard
              number="2"
              title="Peer Ratings"
              body="Every game you play, teammates and opponents rate you across all 7 skill categories (1–5 scale)."
            />
            <InfoCard
              number="3"
              title="Bayesian Average"
              body="Your score is a weighted average using 8 prior ratings at 3.2, so early scores are stable and improve as more reviews come in."
            />
          </div>
        </section>

        {/* ── Skill Categories ───────────────────────────────────── */}
        <section style={{ marginBottom: 48 }}>
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
            7 Skill Categories
          </h2>
          <div
            style={{
              display: 'flex',
              flexWrap: 'wrap',
              gap: 8,
            }}
          >
            {SKILL_LABELS.map((s) => (
              <span
                key={s.label}
                style={{
                  fontSize: 12,
                  fontWeight: 600,
                  color: s.color,
                  background: `${s.color}18`,
                  border: `1px solid ${s.color}40`,
                  borderRadius: 99,
                  padding: '4px 12px',
                }}
              >
                {s.label}
              </span>
            ))}
          </div>
          <p style={{ color: '#6A6A82', fontSize: 13, marginTop: 12 }}>
            Plus a separate{' '}
            <strong style={{ color: '#fff' }}>Vibe score</strong> — based on the
            &ldquo;Would you run with them again?&rdquo; question.
          </p>
        </section>

        {/* ── Tier Cards ─────────────────────────────────────────── */}
        <section>
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
            All 9 Tiers
          </h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {TIERS.map((tier, i) => (
              <TierCard
                key={tier.name}
                tier={tier}
                isAverage={tier.name === 'On The Come Up'}
                animDelay={i * 60}
              />
            ))}
          </div>
        </section>

        {/* ── Prospect Note ──────────────────────────────────────── */}
        <div
          style={{
            marginTop: 32,
            padding: '16px 20px',
            background: '#2DA8FF12',
            border: '1px solid #2DA8FF30',
            borderRadius: 14,
          }}
        >
          <p style={{ fontSize: 13, color: '#2DA8FF', fontWeight: 600, marginBottom: 4 }}>
            About &ldquo;Prospect&rdquo;
          </p>
          <p style={{ fontSize: 13, color: '#6A6A82', lineHeight: 1.6 }}>
            The Prospect tier (4.0–4.9) is also used for players age ≤15, shown with a purple ring in the app.
            Young players are rated on a separate development scale — their scores don&apos;t directly compare
            to adult pickup ratings.
          </p>
        </div>
      </div>
    </div>
  )
}

// ── Sub-components ────────────────────────────────────────────────────────────

function CalloutChip({ label, sub, color }: { label: string; sub: string; color: string }) {
  return (
    <div
      style={{
        background: '#111116',
        border: `1px solid #1E1E26`,
        borderRadius: 12,
        padding: '12px 16px',
        minWidth: 140,
      }}
    >
      <div style={{ fontSize: 22, fontWeight: 900, color, marginBottom: 2 }}>{label}</div>
      <div style={{ fontSize: 12, color: '#6A6A82' }}>{sub}</div>
    </div>
  )
}

function InfoCard({ number, title, body }: { number: string; title: string; body: string }) {
  return (
    <div
      style={{
        background: '#111116',
        border: '1px solid #1E1E26',
        borderRadius: 14,
        padding: '16px 18px',
      }}
    >
      <div
        style={{
          width: 28,
          height: 28,
          borderRadius: '50%',
          background: '#39FF1418',
          border: '1px solid #39FF1440',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 12,
          fontWeight: 800,
          color: '#39FF14',
          marginBottom: 10,
        }}
      >
        {number}
      </div>
      <p style={{ fontSize: 14, fontWeight: 700, color: '#fff', marginBottom: 6 }}>{title}</p>
      <p style={{ fontSize: 12, color: '#6A6A82', lineHeight: 1.6 }}>{body}</p>
    </div>
  )
}

function TierCard({
  tier,
  isAverage,
  animDelay,
}: {
  tier: NETRTier
  isAverage: boolean
  animDelay: number
}) {
  const c = tier.hexColor
  const rangeLabel = `${tier.min.toFixed(1)}–${tier.max.toFixed(1)}`

  return (
    <div
      style={{
        position: 'relative',
        background: isAverage ? 'linear-gradient(135deg, #0D0D18, #111116)' : '#111116',
        border: `1px solid ${isAverage ? `${c}50` : '#1E1E26'}`,
        borderRadius: 18,
        overflow: 'hidden',
        boxShadow: tier.isLocked ? `0 0 20px ${c}30` : 'none',
        display: 'flex',
        alignItems: 'center',
        gap: 16,
        padding: '16px 18px',
        animationDelay: `${animDelay}ms`,
      }}
      className="fade-up"
    >
      {/* Left accent stripe */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 8,
          bottom: 8,
          width: 4,
          borderRadius: 2,
          background: c,
          boxShadow: `0 0 8px ${c}80`,
        }}
      />

      {/* Score badge */}
      <div
        style={{
          flexShrink: 0,
          width: 64,
          height: 64,
          borderRadius: '50%',
          background: `${c}18`,
          border: `2px solid ${c}`,
          boxShadow: `0 0 12px ${c}40`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 1,
          marginLeft: 8,
        }}
      >
        <span style={{ fontSize: 11, fontWeight: 900, color: c, lineHeight: 1 }}>
          {rangeLabel}
        </span>
        <span
          style={{
            fontSize: 7,
            fontWeight: 700,
            color: `${c}99`,
            letterSpacing: 1,
            textTransform: 'uppercase',
          }}
        >
          NETR
        </span>
      </div>

      {/* Info */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
          {tier.isLocked && <span style={{ fontSize: 14 }}>⭐</span>}
          <h3 style={{ fontSize: 20, fontWeight: 900, color: '#ffffff', lineHeight: 1 }}>
            {tier.name}
          </h3>
        </div>
        <p style={{ fontSize: 12, color: '#6A6A82', lineHeight: 1.5, marginBottom: 8 }}>
          {tier.description}
        </p>
        {/* Progress bar */}
        <div
          style={{
            height: 3,
            borderRadius: 99,
            background: '#2A2A35',
            overflow: 'hidden',
          }}
        >
          <div
            style={{
              height: '100%',
              width: `${tier.barWidth * 100}%`,
              borderRadius: 99,
              background: `linear-gradient(90deg, ${c}80, ${c})`,
              transition: 'width 0.8s cubic-bezier(0.34, 1.56, 0.64, 1)',
            }}
          />
        </div>
      </div>

      {/* Right badges */}
      <div
        style={{
          flexShrink: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-end',
          gap: 6,
          minWidth: 90,
        }}
      >
        {tier.isLocked ? (
          <span
            style={{
              fontSize: 9,
              fontWeight: 800,
              letterSpacing: 0.5,
              color: '#C40010',
              background: '#C4001018',
              border: '1px solid #C4001040',
              borderRadius: 99,
              padding: '3px 8px',
              textTransform: 'uppercase',
            }}
          >
            🔒 Pros Only
          </span>
        ) : (
          <span
            style={{
              fontSize: 10,
              fontWeight: 800,
              letterSpacing: 0.5,
              color: c,
              background: `${c}18`,
              border: `1px solid ${c}40`,
              borderRadius: 99,
              padding: '3px 8px',
            }}
          >
            {tier.percentile}
          </span>
        )}
        <span style={{ fontSize: 11, color: '#6A6A82' }}>{tier.stat}</span>
      </div>

      {/* "Most players" banner */}
      {isAverage && (
        <div
          style={{
            position: 'absolute',
            top: 0,
            right: 0,
            background: c,
            color: '#000',
            fontSize: 8,
            fontWeight: 800,
            letterSpacing: 0.8,
            textTransform: 'uppercase',
            padding: '4px 10px',
            borderBottomLeftRadius: 8,
            borderTopRightRadius: 18,
          }}
        >
          Most players land here
        </div>
      )}
    </div>
  )
}

const SKILL_LABELS = [
  { label: 'Scoring',    color: '#39FF14' },
  { label: 'Finishing',  color: '#FF7A00' },
  { label: 'Handles',    color: '#FFC247' },
  { label: 'Playmaking', color: '#2ECC71' },
  { label: 'Defense',    color: '#FF3B30' },
  { label: 'Rebounding', color: '#2DA8FF' },
  { label: 'IQ',         color: '#9B8BFF' },
]
