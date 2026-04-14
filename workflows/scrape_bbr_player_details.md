# Scrape Basketball Reference for Connections-game enrichment

## Objective
Enrich the existing `nba_game_players` Supabase table with richer biographical and
awards data (college, country, draft pick, championships, MVP/FMVP/DPOY/ROY/6MOY/MIP
counts, All-Star count, Hall of Fame flag) so the daily Connections puzzle can form
meaningful 4-player categories.

## Inputs
1. `.tmp/nba_players_active.csv` — two columns (`id`, `name`), one row per active player.
   Export this from Supabase SQL Editor:
   ```sql
   select id, name from nba_game_players where active = true order by name;
   ```
   Click **Export → CSV**, save to the path above.

## Tool
`tools/scrape_bbr_player_details.py`

## Run
```bash
# Smoke test on 10 players first to verify parsing
python3 tools/scrape_bbr_player_details.py --limit 10

# Full run (~20-25 min at 2.5s/req for 549 players)
python3 tools/scrape_bbr_player_details.py

# Resume after a crash / rate limit
python3 tools/scrape_bbr_player_details.py --resume
```

## Outputs
- `.tmp/bbr_enrichment.json` — list of enriched player records, written
  after every successful scrape so nothing is lost on crash.
- `.tmp/bbr_enrichment_missed.csv` — players whose BBR page we couldn't find.
  Expect a handful (common causes: name changes, very new rookies, Europeans
  with a different BBR slug convention). Hand-curate or skip.

## Known edge cases
- **BBR rate limits** trip at ~30 req/min. The tool sleeps 2.5s between requests
  and auto-backs off 60s on HTTP 429. If you see repeated 429s, pause and resume
  from a different IP.
- **Slug collisions**: BBR numbers duplicate-name players `ja01`, `ja02`, etc.
  The tool tries `01..05` and validates the H1 matches the player name. Misses
  get logged to the misses CSV rather than written wrong.
- **Accented names**: stripped via NFKD before slug generation; the validator
  compares NFKD-stripped H1 text so "Nikola Jokić" matches `jokicni01`.
- **Suffixes**: `Jr.`, `Sr.`, `II`, `III` are stripped before slug generation
  (BBR doesn't include them in slugs). The H1 match still works because we do
  a "all target parts appear in H1" check.
- **Awards parsing is notable-awards-block based**, so undocumented players
  (rookies, journeymen) cleanly yield `0` counts rather than crashing.

## After scraping
1. Review the output JSON and misses CSV manually.
2. Apply the migration `supabase/migrations/20260414_connections_game_schema.sql`
   via the Supabase SQL Editor (adds enrichment columns + Connections tables).
3. Run `tools/upsert_bbr_enrichment.py` (TODO in next phase) to push the JSON
   into Supabase via the REST API.
4. Run `tools/build_connections_categories.py` (TODO) to populate
   `nba_connections_categories` from the enriched data.
5. Call `SELECT pick_next_connections_puzzle();` once to seed today's puzzle.
