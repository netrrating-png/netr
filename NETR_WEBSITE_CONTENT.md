# NETR — Website Content & Feature Reference

> **Instructions for Claude (website session):** This file contains the full, accurate feature set for the NETR iOS app. Use this as the source of truth to update the website. All feature names, numbers, copy, and system logic should match exactly what's written here.

---

## WHAT IS NETR?

NETR is a **peer-review basketball app** for pickup players. It lets you find courts, create and join games, and get rated by the people you actually played with — building a real, verified score based on how you play, not how you think you play.

Built for NYC pickup culture. No self-rating. No fake stats. Just honest feedback from your runs.

---

## THE NETR SCORE

**Scale: 2.0 – 9.9**

Every player gets a NETR Score — a number that reflects their real skill level based on peer reviews. No self-rating inflation. Your score comes from the players who shared the court with you.

- New players start with a provisional score based on a self-assessment
- Once you have 5+ reviews, your score locks in as **Verified**
- Scores are calculated using a Bayesian model to prevent gaming or inflation
- The NBA/Pro ceiling (9.5–9.9) is locked — reserved for verified professional athletes only

---

## PLAYER TIERS (9 LEVELS)

| Score | Tier Name | Who It's For |
|-------|-----------|-------------|
| 9.5 – 9.9 | **In The League** | NBA / WNBA / Pro athletes only. Locked. |
| 9.0 – 9.4 | **Certified** | Top 1% of players |
| 8.0 – 8.9 | **Elite** | Top 3% |
| 7.0 – 7.9 | **Built Different** | Top 10% |
| 6.0 – 6.9 | **Hooper** | Top 20% |
| 5.0 – 5.9 | **Got Game** | Top 35% |
| 4.0 – 4.9 | **Prospect** | Above average |
| 3.0 – 3.9 | **On The Come Up** | Average — where most players start |
| 2.0 – 2.9 | **Fresh Laces** | Just getting started |

Each tier has a distinct color in the app (purple → blue → green → gold → orange → red).

---

## THE 7 SKILLS RATED

After every game, players rate each other on 7 categories (each scored 1–10):

1. **Shooting** — Shot creation and consistency
2. **Finishing** — At the rim, through contact
3. **Handles** — Ball handling and shot creation off the dribble
4. **Playmaking** — Vision, passing, court reads
5. **Defense** — On-ball, help defense, intensity
6. **Rebounding** — Boxing out, crashing the glass
7. **Basketball IQ** — Spacing, decision-making, game sense

Each skill is displayed visually on the player's profile via a **7-point radar chart** and individual color-coded bars.

---

## THE VIBE SYSTEM

Separate from skill. Measures sportsmanship, energy, and chemistry.

**After every game, one question:**
> "Would you run again with this player?"

**4 Responses:**
| Response | Meaning |
|----------|---------|
| **Locked In** 🔥 | Great energy, easy to play with |
| **Solid** 👍 | No issues, decent teammate |
| **It's Whatever** 😐 | Neutral — wouldn't seek out |
| **No Thanks** 🚫 | Made the run harder |

**Your Vibe shows on your profile once you have 5+ responses:**

| Vibe Label | What It Means |
|-----------|--------------|
| **LOCKED IN** | People consistently want to run with you |
| **SOLID** | Generally good to be around |
| **MIXED** | Some concerns from teammates |
| **AVOID** | Frequently makes runs harder |

---

## HOW RATINGS WORK

1. Play a game through NETR
2. After the game ends, a **24-hour rating window** opens
3. Rate each player on the 7 skill categories + the Vibe question
4. Ratings are anonymous — players see their scores, not who gave them
5. Your NETR Score updates automatically

**No self-rating. No pay-to-win. Just your peers.**

---

## PLAYER VERIFICATION STATUS

| Badge | What It Means |
|-------|--------------|
| **Provisional** (dashed ring) | New player, fewer than 5 reviews |
| **Verified** (solid ring + checkmark) | 5+ peer reviews, score is locked in |
| **Prospect** (purple badge) | Young player (under 16), separate scoring ceiling |
| **Pro** (red badge) | Verified professional athlete |

---

## SELF-ASSESSMENT (NEW PLAYERS)

First time on NETR? We ask you a series of questions to place you in the right starting range before your peers weigh in:

1. **Age group** — Under 18, 18-24, 25-34, 35-44, 45+
2. **Playing level** — Park Regular, Rec League, HS JV/Varsity, JUCO/D3, D1, Semi-Pro, etc.
3. **How often you play** — From "less than once a month" to "daily"
4. **Your position** — PG, SG, SF, PF, C, or "Not sure yet"
5. **Skill questions** — 10–15 scenario-based questions (4 options each)

Your initial score is calculated immediately and reveals at the end of onboarding.

---

## PLAYER POSITIONS

| Position | Full Name | Role |
|----------|-----------|------|
| **PG** | Point Guard | Floor general, runs offense |
| **SG** | Shooting Guard | Scorer, wings, handles ball |
| **SF** | Small Forward | Versatile, attacks from anywhere |
| **PF** | Power Forward | Physical, interior & stretch |
| **C** | Center | Paint presence, rebounds, rim protection |

---

## GAME FORMATS

| Format | Max Players |
|--------|------------|
| 1v1 | 2 |
| 2v2 | 4 |
| 3v3 | 6 |
| 4v4 | 8 |
| 5v5 | 10 |
| Run (open run) | Up to 50 |

**Skill Filters for Games:**
Any Level · Beginner · Recreational · Competitive · Advanced · Elite

---

## COURTS

- Find pickup courts near you on a map (Apple Maps integration)
- Live games shown with glowing pins
- Filter by: **All · Favorites · Live Now · Lights · Indoor · Verified**
- Court cards show: name, surface type, distance, average rating
- Court detail shows: info, weather, player leaderboard, game schedule
- **Court attributes tracked:** Surface (Asphalt / Concrete / Rubber / Hardwood) · Lights (Yes/No) · Indoor (Yes/No) · Full Court (Yes/No) · Verified status

**Anyone can submit a new court.** New courts appear as "Pending" until verified by the team.

**NYC neighborhoods supported** (initial launch): Prospect Park, Central Park, West Village, Williamsburg, Astoria, Long Island City, and more.

---

## SOCIAL FEATURES

- **Feed** — Twitter/X-style posts from players and courts you follow
- **Profiles** — Public player profiles with NETR score, tier, skill radar, vibe aura
- **Direct Messages** — 1-on-1 conversations with players
- **Follow System** — Follow players, see their games and activity
- **Invite Friends** — Import contacts, send SMS invites, share app link
- **Game Posts** — Post about your game with court name and join code so others can find and join
- **Like, Comment, Repost, Bookmark** — Full social interaction on posts

---

## RATING WINDOW

After a game ends, you have **24 hours** to rate the players you ran with. After that, the window closes. This keeps ratings fresh and tied to real, recent memory.

---

## JOIN A GAME

Every game has a **6-character join code** (e.g., A7FK9M). Share it with friends or post it on the feed. Players can also browse live games nearby and join in one tap.

---

## PROFILE AT A GLANCE

Every player's profile shows:
- **NETR Score** with tier color and label
- **Score ring** (dashed = provisional, solid = verified)
- **Skill radar chart** (7 categories)
- **Vibe aura** (once 5+ responses)
- Position, city, home court
- Games played + total reviews received
- Recent activity
- Followers / Following

---

## DESIGN LANGUAGE

- **Dark, cinematic aesthetic** — near-black backgrounds, subtle borders
- **Neon green accent** (#39FF14) — active states, key actions, your score
- **Color-coded tiers** — each tier has its own glow color (purple → blue → green → gold → orange → red)
- **Custom typography** — Barlow Condensed Black for headings, SF Pro for body
- **Haptic feedback** — on ratings, likes, game actions
- **Animations** — spring-based transitions, radar chart fills, score ring animations, glow pulse on badges

---

## PLATFORM

- **iOS native** (SwiftUI)
- **Backend:** Supabase (real-time database, auth, storage)
- **Real-time updates:** Feed, messages, game lobbies, court leaderboards
- **Authentication:** Email/password + Face ID / Touch ID

---

## KEY NUMBERS TO KNOW

| Stat | Value |
|------|-------|
| Score Range | 2.0 – 9.9 |
| Starting average (Bayesian prior) | 3.2 |
| Regular player ceiling | 9.5 |
| Pro ceiling | 9.9 |
| Number of skill categories | 7 |
| Vibe response options | 4 |
| Reviews needed to become Verified | 5 |
| Rating window after game | 24 hours |
| Tiers | 9 |
| Game formats | 6 |

---

## TAGLINES & COPY (for website use)

- "Your rep, earned on the court."
- "No self-rating. No fake stats. Just your peers."
- "Find runs. Get rated. Build your rep."
- "The score that actually means something."
- "Pickup basketball with receipts."
- "How you play. How you're seen. All in one number."

---

*This file was generated on 2026-03-26 as a source-of-truth snapshot of the NETR iOS app for website content purposes.*
