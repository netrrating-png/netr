import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'NETR — NYC Pickup Basketball Rating',
  description:
    'NETR is the peer rating system for NYC pickup basketball players. Check your NETR score, explore the tier system, and find your level.',
  openGraph: {
    title: 'NETR — NYC Pickup Basketball Rating',
    description: 'Peer rating for NYC pickup players. Know your level.',
    siteName: 'NETR',
  },
  themeColor: '#040406',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body style={{ backgroundColor: '#040406' }}>
        <Nav />
        <main>{children}</main>
        <Footer />
      </body>
    </html>
  )
}

function Nav() {
  return (
    <header
      style={{
        borderBottom: '1px solid #1E1E26',
        backgroundColor: 'rgba(4,4,6,0.92)',
        backdropFilter: 'blur(12px)',
        position: 'sticky',
        top: 0,
        zIndex: 50,
      }}
    >
      <div
        style={{
          maxWidth: 1100,
          margin: '0 auto',
          padding: '0 20px',
          height: 56,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        {/* Logo */}
        <a href="/" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span
            style={{
              fontWeight: 900,
              fontSize: 22,
              letterSpacing: '-0.5px',
              color: '#39FF14',
              textShadow: '0 0 10px rgba(57,255,20,0.5)',
            }}
          >
            NETR
          </span>
          <span
            style={{
              fontSize: 11,
              fontWeight: 600,
              letterSpacing: 1.5,
              color: '#6A6A82',
              textTransform: 'uppercase',
            }}
          >
            NYC Pickup
          </span>
        </a>

        {/* Nav links */}
        <nav style={{ display: 'flex', gap: 24, alignItems: 'center' }}>
          <a
            href="/rating"
            style={{ fontSize: 13, fontWeight: 500, color: '#6A6A82' }}
          >
            Rating Scale
          </a>
          <a
            href="/"
            style={{ fontSize: 13, fontWeight: 500, color: '#6A6A82' }}
          >
            Leaderboard
          </a>
        </nav>
      </div>
    </header>
  )
}

function Footer() {
  return (
    <footer
      style={{
        borderTop: '1px solid #1E1E26',
        padding: '32px 20px',
        textAlign: 'center',
        color: '#6A6A82',
        fontSize: 12,
      }}
    >
      <p>© {new Date().getFullYear()} NETR — NYC Pickup Basketball</p>
      <p style={{ marginTop: 4 }}>
        Scale: 2.0–9.9 · Bayesian prior: 3.2 · Regular ceiling: 9.5
      </p>
    </footer>
  )
}
