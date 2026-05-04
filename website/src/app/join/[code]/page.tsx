import { notFound } from 'next/navigation'
import { supabase } from '@/lib/supabase'

export const revalidate = 0 // always fresh — game state changes rapidly

interface GameRow {
  id: string
  join_code: string
  format: string | null
  status: string
  max_players: number | null
  scheduled_at: string | null
  is_private: boolean
  courts: { name: string; neighborhood: string | null } | null
  host: { full_name: string | null; username: string | null } | null
  player_count: number
}

async function getGame(code: string): Promise<GameRow | null> {
  const { data, error } = await supabase
    .from('games')
    .select(`
      id, join_code, format, status, max_players, scheduled_at, is_private,
      courts(name, neighborhood),
      host:profiles!host_id(full_name, username)
    `)
    .eq('join_code', code.toUpperCase())
    .single()

  if (error || !data) return null

  const { count } = await supabase
    .from('game_players')
    .select('id', { count: 'exact', head: true })
    .eq('game_id', data.id)

  return { ...data, player_count: count ?? 0 } as GameRow
}

function formatScheduled(iso: string): string {
  const d = new Date(iso)
  return d.toLocaleString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric',
    hour: 'numeric', minute: '2-digit',
  })
}

export async function generateMetadata({ params }: { params: { code: string } }) {
  const game = await getGame(params.code)
  if (!game) return { title: 'Game Not Found — NETR' }
  const court = (game.courts as any)?.name ?? 'Unknown Court'
  return {
    title: `${game.format ?? 'Run'} at ${court} — NETR`,
    description: `Join the run on NETR. ${game.player_count}/${game.max_players ?? '?'} players confirmed.`,
  }
}

export default async function JoinGamePage({ params }: { params: { code: string } }) {
  const game = await getGame(params.code)

  if (!game) notFound()

  const court = (game.courts as any)?.name ?? 'Unknown Court'
  const neighborhood = (game.courts as any)?.neighborhood ?? ''
  const host = (game.host as any)?.full_name ?? (game.host as any)?.username ?? 'Unknown'
  const isOver = game.status === 'completed'
  const deepLink = `netr://join/${game.join_code}`
  const appStoreUrl = 'https://apps.apple.com/us/app/netr-rating/id6761962317'

  return (
    <main style={{
      minHeight: '100vh', background: '#000', display: 'flex',
      alignItems: 'center', justifyContent: 'center', padding: '24px',
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    }}>
      <div style={{
        width: '100%', maxWidth: 400,
        background: '#0F0F14', borderRadius: 20,
        border: '1px solid #1A1A24', padding: '32px 24px',
        boxShadow: '0 24px 64px rgba(0,0,0,0.6)',
      }}>
        {/* Header */}
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div style={{
            width: 64, height: 64, borderRadius: '50%',
            background: 'rgba(57,255,20,0.12)', border: '1px solid rgba(57,255,20,0.3)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            margin: '0 auto 16px', fontSize: 28,
          }}>🏀</div>
          <div style={{ fontSize: 11, letterSpacing: 2, color: '#6A6A82', fontWeight: 700, marginBottom: 4 }}>
            NETR · BASKETBALL
          </div>
          <h1 style={{ color: '#EEEEEF', fontSize: 22, fontWeight: 900, margin: 0 }}>
            {game.format ?? 'Run'} at {court}
          </h1>
          {neighborhood && (
            <p style={{ color: '#6A6A82', fontSize: 14, margin: '4px 0 0' }}>{neighborhood}</p>
          )}
        </div>

        {/* Game details */}
        <div style={{
          background: '#0A0A0D', borderRadius: 12, padding: '16px',
          border: '1px solid #1A1A24', marginBottom: 20,
        }}>
          {[
            { label: 'Host', value: host },
            { label: 'Players', value: `${game.player_count}/${game.max_players ?? '?'}` },
            game.scheduled_at ? { label: 'Time', value: formatScheduled(game.scheduled_at) } : null,
            { label: 'Join Code', value: game.join_code },
            game.is_private ? { label: 'Access', value: '🔒 Private — passcode required' } : null,
            { label: 'Status', value: isOver ? '✅ Completed' : game.status === 'active' ? '🟢 In progress' : '⏳ Waiting' },
          ].filter(Boolean).map((row) => (
            <div key={row!.label} style={{
              display: 'flex', justifyContent: 'space-between',
              padding: '8px 0', borderBottom: '1px solid #1A1A24',
            }}>
              <span style={{ color: '#6A6A82', fontSize: 13 }}>{row!.label}</span>
              <span style={{ color: '#EEEEEF', fontSize: 13, fontWeight: 600 }}>{row!.value}</span>
            </div>
          ))}
        </div>

        {/* CTA buttons */}
        {!isOver ? (
          <>
            <a href={deepLink} style={{
              display: 'block', background: '#39FF14', color: '#000',
              textAlign: 'center', padding: '14px', borderRadius: 12,
              fontWeight: 900, fontSize: 15, textDecoration: 'none',
              marginBottom: 10, letterSpacing: 0.5,
            }}>
              Open in NETR
            </a>
            <a href={appStoreUrl} style={{
              display: 'block', background: '#0F0F14', color: '#6A6A82',
              textAlign: 'center', padding: '14px', borderRadius: 12,
              fontWeight: 600, fontSize: 14, textDecoration: 'none',
              border: '1px solid #1A1A24',
            }}>
              Download NETR on the App Store
            </a>
          </>
        ) : (
          <p style={{ color: '#6A6A82', textAlign: 'center', fontSize: 14 }}>
            This run has ended. Download NETR to find the next one.
          </p>
        )}
      </div>
    </main>
  )
}
