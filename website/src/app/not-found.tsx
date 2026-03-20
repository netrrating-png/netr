import Link from 'next/link'

export default function NotFound() {
  return (
    <div
      style={{
        backgroundColor: '#040406',
        minHeight: '80vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
        padding: '0 20px',
      }}
    >
      <div style={{ fontSize: 48, marginBottom: 16 }}>🏀</div>
      <h1 style={{ fontSize: 28, fontWeight: 900, color: '#fff', marginBottom: 8 }}>
        Player Not Found
      </h1>
      <p style={{ fontSize: 14, color: '#6A6A82', marginBottom: 28, maxWidth: 360 }}>
        That username doesn&apos;t exist in NETR yet. Make sure you&apos;re using the correct
        handle.
      </p>
      <Link
        href="/"
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
        Back to Leaderboard
      </Link>
    </div>
  )
}
