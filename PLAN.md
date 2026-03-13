# NETR — Basketball Peer Rating App for NYC Pickup Players


## Features

**Onboarding (6 steps)**
- Cinematic welcome screen with the NETR neon logo on a dark brick-wall background
- Location permission request to find nearby courts
- Account setup: name, username (@handle), date of birth with auto-detect for Prospect (age ≤15)
- Position picker: PG, SG, SF, PF, C, "I Play It All", "I Don't Know Yet"
- Self-assessment across 6 skill categories (Shooting, Ball Handling, Playmaking, Defense, Hustle, Basketball IQ) with 4-option cards
- "You're In" confirmation with neon glow animation

**Courts Tab (Map + List)**
- Apple Maps with dark styling showing all 12 NYC courts as custom pins
- Green-glowing pins for courts with live games, gold dots for pending/unverified courts
- Blue pulsing dot for user location
- Search bar filtering courts by name, neighborhood, or borough
- Horizontal filter chips: All, Live Now, Full Court, Lights, Indoor, Verified
- Court cards showing name, live badge, verified/pending status, surface, distance, average NETR score
- "+ Court" and "+ Game" buttons in the header
- Court Detail Sheet (bottom sheet with 3 tabs: Info, Players, Times)

**Rate Tab (Peer Review)**
- Swipe-style player cards showing avatar, name, username, NETR score, position
- Rate each player across 6 skill categories on a 1–10 scale
- Progress bar for categories completed
- Skip or Submit with confirmation and updated NETR preview

**Feed Tab (Social)**
- Twitter/X-style scrollable feed with post cards
- Posts show avatar with rating-colored ring, name, handle, verified badge, time, content, hashtags, court tags
- Like, Comment, Repost, Bookmark interactions with toggle states and counts
- Game posts show court name + join code + "Join" button
- Floating compose button opening a bottom sheet

**Profile Tab**
- Large avatar with NETR badge ring (dashed = provisional, solid = verified, purple = Prospect)
- NETR score (color-coded), tier label, trend arrow
- Name, @username, position badge, city, games played, reviews received
- Skill bars for all 6 categories (color-coded horizontal bars)
- Recent games section

**Create Game Flow**
- Select court → format (3v3/4v4/5v5/Run) → skill level → generates join code

**Game Lobby**
- Join code displayed prominently, QR code placeholder, player list with NETR scores
- Start/End game controls

**Add Court Flow**
- Similar courts check to prevent duplicates
- Court submission form: name, address, neighborhood dropdown, surface type, lights toggle
- New courts marked as "Pending" with gold badge

---

## Design

- **Dark, cinematic, neon-lit aesthetic** — near-black background (#040406), electric lime green (#39FF14) as primary accent
- Cards use dark surface colors (#0F0F14) with subtle green-tinted borders
- SF Pro with compressed/bold weights for headings (mimicking Barlow Condensed energy), regular weights for body
- Neon green glow effects on badges, active states, and the logo
- Rating-colored rings around avatars: green for high, yellow for mid, red for low, purple for Prospect, dashed gray for provisional
- Snappy micro-animations: scale-down on press, fade-up on card entry, glow pulse on badges
- Haptic feedback on rating submissions, likes, and game actions
- Custom tab bar with neon green active indicator dot

---

## Screens

1. **Welcome / Splash** — Full-bleed dark brick background with neon NETR logo, tagline, "Get Started" button
2. **Location Permission** — "Find Courts Near You" with explanation and Allow/Skip buttons
3. **Account Setup** — Name, username, DOB fields with Prospect auto-detection
4. **Position Picker** — Grid of position cards with abbreviation, name, and description
5. **Self-Assessment** — 6 skill category cards with 4 options each
6. **Onboarding Complete** — "You're In" celebration screen with neon glow
7. **Courts (Map)** — Apple Maps with court pins, search, filters, court list cards
8. **Court Detail Sheet** — Bottom sheet with Info/Players/Times tabs and Join Game CTA
9. **Rate (Peer Review)** — Swipeable player cards with 6-category rating sliders
10. **Feed (Social)** — Scrollable post feed with compose button
11. **Profile** — Player stats, skill bars, NETR score badge, recent games
12. **Create Game** — Multi-step flow: court → format → skill level → join code
13. **Game Lobby** — Live session with player list and join code
14. **Add Court** — Similar court check + submission form

---

## App Icon

- Neon green basketball net/hoop symbol on a near-black (#040406) background
- Electric lime glow effect radiating from the hoop
- Matches the cinematic streetball aesthetic of the app

---

## Data

- All data is mock/hardcoded for this version: 12 NYC courts, 9 sample players, sample feed posts
- No backend or authentication — everything runs locally with in-memory data
- Onboarding state saved locally so it only shows once
