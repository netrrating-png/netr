# CTO Handoff: Daily Game — Finish the Player Dataset

> **Last updated:** 2026-04-10
> **Branch:** merged to `main`. Everything below lives in the main branch.

## TL;DR

The Daily Game feature is **fully shipped** — UI, ViewModel, Supabase schema,
pg_cron rotation, first 7 daily puzzles, and the A–H slice of the player pool
(550 rows) are all live. Angelica verified today's puzzle renders as
Aaron Gordon in the iOS app.

**The only thing left is filling the I–Z gap** in the player pool so that
the `pick_next_daily_puzzle()` RPC has a complete roster to draw from when
it rotates at 23:30 UTC each night. stats.nba.com rate-limited/blocked our
IP mid-run and would not clear even after 30+ minute cooldowns.

**Your job (one-time, ~90 min):**
1. Run the builder from your machine (fresh IP) to collect I–Z players
2. Merge with the existing A–H JSON
3. Upsert the merged rows into Supabase
4. (Optional) hand-curate `fun_fact` strings for the top ~150 superstars

---

## What's already done and live

### iOS (merged to main)

- `ios/NETR/Views/DailyGameView.swift` — gamified UI with hero "mystery
  player" card, progressive clue reveal (clues only appear **after** a
  guess unlocks them), neon-green theme, segmented guess-track, and
  a `ShareLink` that exports a result string without spoiling the answer.
- `ios/NETR/ViewModels/DailyGameViewModel.swift` — 6-guess limit,
  streak persistence via `UserDefaults`, stats sheet with guess
  distribution.
- `ios/NETR/Models/DailyGameModels.swift` — `HintStage` enum
  (`.retiredStatus`, `.yearsActive`, `.draftTeam`, `.allTeams`, `.funFact`),
  `DailyGamePlayer`, puzzle decoder.
- `ios/NETR/ContentView.swift` — tab bar: `.dm` replaced with `.dailyGame`
  (calendar icon, label "Daily Game"). `DMHeaderButton` added to Courts,
  Rate, Feed, and Profile headers so DMs are still one tap away.
- `ios/NETR/Views/DMInboxView.swift` — back button wired to
  `@Environment(\.dismiss)`.

### Supabase (already applied to prod)

- Migration `supabase/migrations/20260410_daily_game_schema.sql` is applied.
  Tables: `nba_game_players`, `nba_game_daily_puzzle`, `nba_game_results`.
- RPC `pick_next_daily_puzzle()` with 70/25/5 tier weighting and a
  90-day avoidance window.
- pg_cron job rotating the puzzle at `30 23 * * *` UTC.
- View `nba_game_today`.
- RLS policies locked down (read-public, write-service-role-only for
  players/puzzles; per-user write for results).
- **550 A–H players loaded**, 7 days of puzzles pre-seeded.

### Data builder (committed)

- `tools/build_nba_daily_game_dataset.py` — loops nba_api
  `CommonAllPlayers` for every player who debuted ≥ 1990 with 2+
  seasons. Checkpoints every 50 players to
  `.tmp/nba_daily_players.checkpoint.json`. Adaptive cooldown when
  stats.nba.com starts refusing. Supports `--from-checkpoint` to
  finalize without network, and `--skip-enrich` to skip the slow
  `CommonPlayerInfo` bio pass.

### Working files (gitignored, in `.tmp/`)

- `.tmp/nba_daily_players.checkpoint.json` — raw checkpoint, 600 A–H
  players. **Keep this** — your run will resume from it automatically.
- `.tmp/nba_daily_players.json` — final tiered A–H slice (550 rows).
- `.tmp/nba_game_players_inserts.sql` — the bulk upsert SQL already
  run against Supabase.

---

## What's missing

### 1. I–Z players (the blocker)

The script crashed/got rate-limited around the "H" surnames. Notables
currently **missing** from `nba_game_players`:

**Must-have superstars:** LeBron James, Michael Jordan, Magic Johnson,
Allen Iverson, Kyrie Irving, Kawhi Leonard, Damian Lillard, Karl Malone,
Reggie Miller, Steve Nash, Dirk Nowitzki, Shaquille O'Neal, Hakeem
Olajuwon, Tony Parker, Chris Paul, Scottie Pippen, David Robinson,
Derrick Rose, John Stockton, Jayson Tatum, Dwyane Wade, Russell Westbrook,
Nikola Jokic, Giannis Antetokounmpo, Zion Williamson, Luka Doncic.

Plus several hundred solid/deep-cut I–Z players.

### 2. Bio enrichment (`position`, `height`, `jerseys`)

Never ran for anyone — IP was already blocked when we reached that step.
The `position`, `height`, `jerseys` fields are null for every current row.
**The 5 hints don't use those fields**, so the game works fine without
them. You can run with `--skip-enrich` and still ship.

### 3. `fun_fact` curation (optional, post-launch)

The final hint stage (`HintStage.funFact`) falls back to a generic
"No fun fact available" placeholder when null. For the top ~150
superstars it'd be nice to hand-write a one-line hook (e.g. "Only
player with 30K points, 10K rebounds, 10K assists" for LeBron).
Not a blocker.

---

## How to finish it — step by step

### Step 1: Pull main and set up

```bash
git checkout main
git pull

# Install the nba_api Python library if you haven't
pip install nba_api
```

### Step 2: Resume the build

The checkpoint at `.tmp/nba_daily_players.checkpoint.json` is gitignored,
so you won't have the A–H progress on your machine. That's fine — the
script will just start from scratch and re-fetch A–Z from nba_api.
Budget ~90 minutes.

```bash
# Skip the slow bio enrichment — we don't use those fields anyway
python3 -u tools/build_nba_daily_game_dataset.py \
  --output .tmp/nba_daily_players_full.json \
  --skip-enrich
```

The script checkpoints every 50 players. If it dies, **just re-run the
exact same command** — it resumes from the checkpoint automatically.

### If stats.nba.com blocks you too

This is a soft IP block that seems to trigger after ~500 rapid requests.
Symptoms: `ReadTimeout` errors, or `PlayerCareerStats` hanging.

1. **Wait 30+ minutes with zero traffic to stats.nba.com.**
2. Bump `REQUEST_SLEEP_SECONDS` in the script from `4.0` → `6.0`.
3. Re-run — the checkpoint picks up where you left off.
4. Worst case, run it on a cloud VM / Colab cell for a fresh IP.

### Step 3: Upsert to Supabase

Once you have `.tmp/nba_daily_players_full.json` with ~500–700 rows
spanning the full alphabet, upsert via the REST API. Set the env vars
first:

```bash
export SUPABASE_URL="https://<your-project>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"  # NOT anon key
```

Then run:

```bash
python3 -c "
import json, os, requests
players = json.load(open('.tmp/nba_daily_players_full.json'))
rows = [{
  'id': p['id'],
  'name': p['name'],
  'retired': p['retired'],
  'years_active': p['yearsActive'],
  'from_year': p['fromYear'],
  'to_year': p['toYear'],
  'draft_team': p['draftTeam'],
  'teams': p['teams'],
  'position': p.get('position'),
  'height': p.get('height'),
  'jerseys': p.get('jerseys'),
  'tier': p['tier'],
  'career_games': p['careerGames'],
  'career_minutes': p['careerMinutes'],
  'fun_fact': p.get('funFact'),
} for p in players]

# Batch in chunks of 200 to stay under PostgREST payload limits
for i in range(0, len(rows), 200):
    chunk = rows[i:i+200]
    r = requests.post(
      f'{os.environ[\"SUPABASE_URL\"]}/rest/v1/nba_game_players',
      headers={
        'apikey': os.environ['SUPABASE_SERVICE_ROLE_KEY'],
        'Authorization': f'Bearer {os.environ[\"SUPABASE_SERVICE_ROLE_KEY\"]}',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      },
      json=chunk,
    )
    print(f'chunk {i}-{i+len(chunk)}: {r.status_code}')
    if r.status_code >= 300:
        print(r.text[:500]); break
"
```

`Prefer: resolution=merge-duplicates` makes this an idempotent upsert
keyed on `id` — safe to re-run, and it will overwrite the existing
A–H rows with any updates.

### Step 4: (Optional) Pre-seed more daily puzzles

The pg_cron job picks a new puzzle every night at 23:30 UTC, but if you
want to be safe you can manually pre-seed the next 30 days right after
upserting:

```sql
-- Run in the Supabase SQL editor
SELECT pick_next_daily_puzzle() FROM generate_series(1, 30);
```

### Step 5: Verify in the app

Open the iOS app → Daily Game tab. The mystery player for today should
still be Aaron Gordon (unless the cron already rotated). Try guessing a
few I–Z players — they should now appear in the autocomplete search
results.

---

## Things we learned (so you don't repeat our mistakes)

- **stats.nba.com soft-blocks IPs after ~500 rapid requests.** The block
  lasts 10–60+ minutes of zero traffic to clear. A 90-second cooldown is
  not enough. 4+ second base throttle is safer.
- The script's adaptive cooldown works but isn't aggressive enough for
  stubborn blocks. When in doubt, bump `COOLDOWN_SECONDS` higher.
- **Checkpointing every 50 players saved us** — without it, two hours of
  work would have been lost twice. Keep this pattern for any nba_api work.
- `--skip-enrich` is your friend. The bio enrichment pass doubles runtime
  and we don't actually use any of those fields in the game.
- Supabase bulk upsert via REST API works great with
  `Prefer: resolution=merge-duplicates` — no need to truncate first.

---

## File map (for reference)

| File | Purpose |
|------|---------|
| `ios/NETR/Views/DailyGameView.swift` | Main game UI (redesigned, gamified) |
| `ios/NETR/ViewModels/DailyGameViewModel.swift` | Game state, search, streaks |
| `ios/NETR/Models/DailyGameModels.swift` | Player + puzzle structs, HintStage |
| `ios/NETR/ContentView.swift` | Tab bar wiring |
| `supabase/migrations/20260410_daily_game_schema.sql` | Schema (applied) |
| `tools/build_nba_daily_game_dataset.py` | The scraper you'll re-run |
| `workflows/CTO_HANDOFF_daily_game_dataset.md` | This doc |
| `.tmp/nba_daily_players.checkpoint.json` | Raw resume checkpoint (gitignored) |
| `.tmp/nba_daily_players.json` | A–H final tiered slice (gitignored) |
| `.tmp/nba_game_players_inserts.sql` | The SQL that was already run (gitignored) |

Ping if anything is unclear.
