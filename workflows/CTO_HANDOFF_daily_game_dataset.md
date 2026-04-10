# CTO Handoff: Daily Game Dataset Gap

## TL;DR

The Daily Game feature is **fully built and committed** on `claude/adoring-dijkstra`.
Everything compiles. Everything is wired. The only thing missing is a complete
player dataset — we have **550 players from surnames A–H only** because
stats.nba.com rate-limited/blocked our IP mid-run and would not clear.

**Your job:** run the same builder from your machine (different IP) to get the
missing I–Z players, then upload the merged list to Supabase.

## What's done

- iOS: `Views/DailyGameView.swift`, `ViewModels/DailyGameViewModel.swift`,
  `Models/DailyGameModels.swift` — full Wordle-style UI with 5 progressive
  hints, autocomplete input, 6-guess limit, streak persistence, stats sheet.
- iOS tab bar: `.dm` tab replaced with `.dailyGame` (calendar icon).
  `DMHeaderButton` added to Courts, Rate, Feed, Profile headers so DMs are
  still one tap away.
- Supabase schema: `supabase/migrations/20260410_daily_game_schema.sql`
  creates `nba_game_players`, `nba_game_daily_puzzle`, `nba_game_results`,
  plus `pick_next_daily_puzzle()` and a pg_cron job at 23:30 UTC to rotate
  the puzzle daily. RLS policies included.
- Data builder: `tools/build_nba_daily_game_dataset.py` with checkpoint/resume
  and adaptive cooldown for stats.nba.com's rate limiter. It has been run
  partially — checkpoint is at `.tmp/nba_daily_players.checkpoint.json`
  (gitignored, 600 A–H players).
- Partial final output: `.tmp/nba_daily_players.json` (550 players, A–H only,
  tier-assigned, missing bio fields `position`/`height`/`jerseys`).

## The gap

The script loops alphabetically through every NBA player who debuted ≥ 1990
with 2+ seasons. It crashed/got rate-limited around the "H" surnames.
Notables currently **missing** from the dataset:

- **Superstars (must-have):** LeBron James, Michael Jordan, Magic Johnson,
  Allen Iverson, Kyrie Irving, Kawhi Leonard, Damian Lillard, Karl Malone,
  Reggie Miller, Steve Nash, Dirk Nowitzki, Shaquille O'Neal, Hakeem
  Olajuwon, Tony Parker, Chris Paul, Scottie Pippen, David Robinson,
  Derrick Rose, John Stockton, Jayson Tatum, Dwyane Wade, Russell Westbrook,
  Nikola Jokic, Giannis Antetokounmpo, Zion Williamson, Luka Doncic.
- Plus several hundred solid/deep-cut I–Z players.

Bio enrichment (`CommonPlayerInfo` → position, height, jersey) was **never
run for anyone** because the IP was already blocked when we got to that step.
The `position`, `height`, `jerseys` fields are all null in the current JSON.
The 5 hints don't use those fields, so the game still works without them,
but the UI might render blank.

## How to finish it (from your machine)

```bash
# 1. Check out the branch
git fetch origin
git checkout claude/adoring-dijkstra
cd .claude/worktrees/adoring-dijkstra   # or wherever you keep it

# 2. Install nba_api if you haven't
pip install nba_api

# 3. Resume the build — it picks up from our checkpoint automatically
#    (600 A–H players already done)
python3 -u tools/build_nba_daily_game_dataset.py \
  --output .tmp/nba_daily_players.json

#    This will take ~60-90 minutes. It checkpoints every 50 players to
#    .tmp/nba_daily_players.checkpoint.json. If it dies, just re-run —
#    resume is built in.

#    If you want to skip the slow bio enrichment pass and ship faster:
#    add --skip-enrich (position/height/jerseys stay null; game still works).
```

If stats.nba.com blocks you too (this seems to be a soft IP block that
happens after ~500 requests in a short window):

1. Wait 30+ minutes with zero traffic
2. Bump `REQUEST_SLEEP_SECONDS` in the script from 4.0 → 6.0
3. Re-run — resume will pick up where it left off
4. Worst case, run it on a cloud VM / Colab for a fresh IP

## Uploading to Supabase

Once you have `.tmp/nba_daily_players.json` with ~550 rows spanning the full
alphabet:

```sql
-- 1. Apply the migration in the Supabase SQL editor
-- Paste: supabase/migrations/20260410_daily_game_schema.sql

-- 2. Upload the JSON. Easiest way: Supabase Table Editor → Import CSV,
--    but it needs CSV. Or use the REST API:
```

```bash
# Quick bulk-insert via the REST API (need SUPABASE_SERVICE_ROLE_KEY)
python3 -c "
import json, os, requests
players = json.load(open('.tmp/nba_daily_players.json'))
rows = [{
  'player_id': p['id'],
  'name': p['name'],
  'retired': p['retired'],
  'years_active': p['yearsActive'],
  'from_year': p['fromYear'],
  'to_year': p['toYear'],
  'draft_team': p['draftTeam'],
  'teams': p['teams'],
  'position': p['position'],
  'height': p['height'],
  'jerseys': p['jerseys'],
  'tier': p['tier'],
  'career_games': p['careerGames'],
  'career_minutes': p['careerMinutes'],
  'fun_fact': p['funFact'],
} for p in players]
r = requests.post(
  f'{os.environ[\"SUPABASE_URL\"]}/rest/v1/nba_game_players',
  headers={
    'apikey': os.environ['SUPABASE_SERVICE_ROLE_KEY'],
    'Authorization': f'Bearer {os.environ[\"SUPABASE_SERVICE_ROLE_KEY\"]}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates',
  },
  json=rows,
)
print(r.status_code, r.text[:500])
"

# 3. Seed the first week of puzzles
#    In the Supabase SQL editor:
SELECT pick_next_daily_puzzle();  -- call 7 times, or loop it
```

## Hand-curation todo (optional, post-launch)

The `fun_fact` field is null for everyone. For the top ~150 superstars it
would be nice to hand-write a one-line hook (e.g. "Only player with 30K
points, 10K rebounds, 10K assists" for LeBron). This is the final hint
stage (`HintStage.funFact`) — if it's null, the UI falls back to showing
a generic "No fun fact available" placeholder.

## Things we learned (update the workflow doc)

- stats.nba.com soft-blocks IPs after ~500 rapid requests. The block lasts
  10–60+ minutes of zero traffic to clear. A 90-second cooldown is not
  enough. 4+ second base throttle is safer.
- The script's adaptive cooldown works but isn't aggressive enough for
  stubborn blocks. When in doubt, bump `COOLDOWN_SECONDS` higher.
- Checkpointing every 50 players saved us — without it, two hours of work
  would have been lost twice.
