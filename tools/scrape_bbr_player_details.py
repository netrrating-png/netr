#!/usr/bin/env python3
"""
Scrapes Basketball Reference player pages to enrich our existing NBA player pool
with richer biographical + award data for the Connections daily game.

Input:   .tmp/nba_players_active.csv           (columns: id, name — exported from Supabase)
Output:  .tmp/bbr_enrichment.json              (one object per successfully-scraped player)
Log:     .tmp/bbr_enrichment_missed.csv        (players we couldn't find on BBR)

Fields captured per player:
    id (int) — nba.com PERSON_ID, passed through from the input CSV
    name, bbr_url
    college, country,
    draft_year, draft_round, draft_pick,
    championships, all_star_count,
    mvp_count, finals_mvp_count, dpoy_count, sixmoy_count, mip_count,
    roy (bool), hall_of_fame (bool)

NOT scraped:
    signature_shoe_brand — not on BBR; curate by hand later

Rate limiting:
    BBR rate-limits aggressively — more than ~30 req/min trips their WAF.
    We sleep 2.5s between requests and 60s on any 429 response.

Usage:
    python3 tools/scrape_bbr_player_details.py
    python3 tools/scrape_bbr_player_details.py --resume     # skip players already in output
    python3 tools/scrape_bbr_player_details.py --limit 20   # smoke test
"""
from __future__ import annotations

import argparse
import csv
import json
import random
import re
import sys
import time
import unicodedata
from pathlib import Path
from typing import Optional

try:
    import requests
    from bs4 import BeautifulSoup, Comment
except ImportError:
    sys.exit("Missing deps. Run: pip install requests beautifulsoup4 lxml")

ROOT = Path(__file__).resolve().parent.parent
IN_CSV = ROOT / ".tmp" / "nba_players_active.csv"
OUT_JSON = ROOT / ".tmp" / "bbr_enrichment.json"
MISSED_CSV = ROOT / ".tmp" / "bbr_enrichment_missed.csv"

BBR_ROOT = "https://www.basketball-reference.com"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122 Safari/537.36"

REQ_DELAY = 2.5   # seconds between requests
RETRY_DELAY = 60  # on 429


# ─── name → slug helpers ──────────────────────────────────────────
def strip_accents(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def slug_candidates(name: str) -> list[str]:
    """
    BBR slug convention: first 5 letters of last name + first 2 of first name + 01/02/03...
    e.g. "LeBron James" → jamesle01 ; a duplicate would be jamesle02.
    Returns candidates in priority order (01 → 05).
    """
    clean = strip_accents(name).lower()
    clean = re.sub(r"[.'`]", "", clean)               # drop apostrophes and dots
    parts = re.split(r"[ \-]+", clean.strip())
    parts = [p for p in parts if p]                   # drop empty
    if len(parts) < 2:
        return []

    # Ignore Jr/Sr/II/III suffixes — they aren't in the slug
    suffixes = {"jr", "sr", "ii", "iii", "iv"}
    while len(parts) > 1 and parts[-1] in suffixes:
        parts.pop()

    first, last = parts[0], parts[-1]
    slug_base = (last[:5] + first[:2])
    slug_base = re.sub(r"[^a-z]", "", slug_base)      # strip any remaining punct
    return [f"{slug_base}{n:02d}" for n in range(1, 6)]


# ─── HTTP ─────────────────────────────────────────────────────────
def fetch(session: requests.Session, url: str) -> Optional[str]:
    tries = 0
    while tries < 3:
        tries += 1
        r = session.get(url, timeout=20)
        if r.status_code == 200:
            # BBR omits a charset in Content-Type; requests defaults to Latin-1
            # and mangles accented names. Force UTF-8.
            r.encoding = "utf-8"
            return r.text
        if r.status_code == 404:
            return None
        if r.status_code == 429:
            print(f"  [429] backing off {RETRY_DELAY}s…", file=sys.stderr)
            time.sleep(RETRY_DELAY)
            continue
        print(f"  [{r.status_code}] {url}", file=sys.stderr)
        time.sleep(5)
    return None


def _alpha_squash(s: str) -> str:
    """Lowercase, strip accents, drop everything non-alpha (including dots/spaces)."""
    return re.sub(r"[^a-z]", "", strip_accents(s).lower())


def _h1_matches(html: str, name: str) -> bool:
    soup = BeautifulSoup(html, "lxml")
    h1 = soup.select_one("h1")
    if not h1:
        return False
    page_sq = _alpha_squash(h1.get_text(strip=True))
    tokens = [_alpha_squash(t) for t in re.split(r"[\s\-]+", name)
              if t and t.lower().rstrip(".") not in {"jr", "sr", "ii", "iii", "iv"}]
    tokens = [t for t in tokens if t]  # drop empties
    return bool(tokens) and all(tok in page_sq for tok in tokens)


def find_player_page(session: requests.Session, name: str) -> tuple[Optional[str], Optional[str]]:
    """Returns (url, html) for the best match for this player, or (None, None)."""
    # Try deterministic slug candidates first — fastest when they work.
    for slug in slug_candidates(name):
        letter = slug[0]
        url = f"{BBR_ROOT}/players/{letter}/{slug}.html"
        html = fetch(session, url)
        if html is None:
            continue
        if _h1_matches(html, name):
            return url, html
        time.sleep(REQ_DELAY)

    # Fallback: BBR's search endpoint. For exact-ish matches it 302s straight to the
    # player page; for ambiguous queries we parse the "Players" section of the results.
    search_url = f"{BBR_ROOT}/search/search.fcgi?search=" + requests.utils.quote(name)
    time.sleep(REQ_DELAY)
    r = session.get(search_url, timeout=20, allow_redirects=True)
    if r.status_code == 200 and "/players/" in r.url and r.url.endswith(".html"):
        if _h1_matches(r.text, name):
            return r.url, r.text
    if r.status_code == 200:
        # Parse search results, take first /players/ link whose text matches the target
        soup = BeautifulSoup(r.text, "lxml")
        for a in soup.select("div#players a[href*='/players/']"):
            href = a.get("href", "")
            if not href.endswith(".html"):
                continue
            link_text = strip_accents(a.get_text(strip=True)).lower()
            target = strip_accents(name).lower()
            if all(tp in link_text for tp in re.split(r"[ \-.']+", target)
                   if tp and tp not in {"jr", "sr", "ii", "iii", "iv"}):
                full_url = BBR_ROOT + href if href.startswith("/") else href
                html = fetch(session, full_url)
                if html and _h1_matches(html, name):
                    return full_url, html

    return None, None


# ─── parsers ──────────────────────────────────────────────────────
# Many BBR tables/divs are wrapped in HTML comments to defeat naive scrapers.
# This helper digs into the comments and returns a merged soup of real + commented HTML.
def full_soup(html: str) -> BeautifulSoup:
    soup = BeautifulSoup(html, "lxml")
    comments = soup.find_all(string=lambda t: isinstance(t, Comment))
    for c in comments:
        try:
            extra = BeautifulSoup(c, "lxml")
            soup.append(extra)
        except Exception:
            pass
    return soup


# Awards live in the #bling <ul> as short-form <li> texts, e.g.
#   "4x NBA Champ", "22x All Star", "4x MVP", "3x AS MVP", "4x Finals MVP",
#   "2003-04 ROY", "2x Def. POY", "Sixth Man", "Most Improved"
# We match on the exact shapes BBR uses. Order matters: test "Finals MVP" / "AS MVP"
# BEFORE "MVP" so they don't get double-counted as regular-season MVP.


def parse_bio(soup: BeautifulSoup) -> dict:
    """Pulls data from the #meta box (college, country, draft, HOF badge).

    BBR layout: #meta contains a series of <p> tags, each starting with
    <strong>Label:</strong> followed by the value. Country is signaled by a
    `span.f-i.f-XX` flag code (us / rs / gr / fr / ca / ...).
    """
    out = {
        "college": None, "country": None,
        "draft_year": None, "draft_round": None, "draft_pick": None,
        "hall_of_fame": False,
    }

    meta = soup.select_one("#meta")
    if not meta:
        return out

    # Hall of Fame badge (appears in #bling or as an award line)
    bling = soup.select_one("#bling")
    if (bling and "Hall of Fame" in bling.get_text(" ", strip=True)) \
       or "Hall of Fame" in meta.get_text(" ", strip=True):
        out["hall_of_fame"] = True

    # Country from flag code: <span class="f-i f-us">us</span>
    flag = meta.select_one("span.f-i")
    if flag:
        classes = flag.get("class", [])
        code = next((c.removeprefix("f-") for c in classes if c.startswith("f-") and c != "f-i"), None)
        if code:
            out["country"] = COUNTRY_CODES.get(code.lower(), code.upper())

    # Iterate <p> tags; route on the first <strong>'s label text
    for p in meta.find_all("p"):
        strong = p.find("strong")
        if not strong:
            continue
        label = strong.get_text(strip=True).rstrip(":").strip()
        text = p.get_text(" ", strip=True)

        if label == "College":
            a = p.find("a", href=re.compile(r"/friv/colleges\.fcgi"))
            if a:
                name = a.get_text(strip=True)
                # Trim trailing "University"/"College" for consistency
                # ("Virginia Union University" → "Virginia Union", "Boston College" → "Boston College" kept)
                name = re.sub(r"\s+University\s*$", "", name)       # "Virginia Union University" → "Virginia Union"
                name = re.sub(r"^University of\s+", "", name)        # "University of Northern Iowa" → "Northern Iowa"
                out["college"] = name

        elif label == "Draft":
            m_round = re.search(r"(\d+)(?:st|nd|rd|th) round", text)
            m_pick  = re.search(r"(\d+)(?:st|nd|rd|th) overall", text)
            m_year  = re.search(r"(\d{4})\s+NBA Draft", text)
            if m_round: out["draft_round"] = int(m_round.group(1))
            if m_pick:  out["draft_pick"]  = int(m_pick.group(1))
            if m_year:  out["draft_year"]  = int(m_year.group(1))

    # Fallback country via birthplace href (country=US / country=RS / ...)
    if out["country"] is None:
        bp = meta.select_one("a[href*='birthplaces.fcgi?country=']")
        if bp:
            m = re.search(r"country=([A-Z]{2})", bp.get("href", ""))
            if m:
                out["country"] = COUNTRY_CODES.get(m.group(1).lower(), m.group(1))

    return out


# ISO two-letter codes BBR uses on its flag spans → human-readable country names.
# Add to this as the scrape surfaces new codes.
COUNTRY_CODES = {
    "vc": "Saint Vincent and the Grenadines",
    "eg": "Egypt",       "ma": "Morocco",     "ke": "Kenya",
    "us": "USA",         "ca": "Canada",      "fr": "France",      "de": "Germany",
    "es": "Spain",       "it": "Italy",       "rs": "Serbia",      "hr": "Croatia",
    "gr": "Greece",      "tr": "Turkey",      "si": "Slovenia",    "lt": "Lithuania",
    "lv": "Latvia",      "me": "Montenegro",  "mk": "North Macedonia",
    "ba": "Bosnia & Herzegovina",             "ng": "Nigeria",     "sn": "Senegal",
    "cm": "Cameroon",    "sd": "Sudan",       "cd": "DR Congo",    "au": "Australia",
    "br": "Brazil",      "ar": "Argentina",   "do": "Dominican Republic",
    "mx": "Mexico",      "pr": "Puerto Rico", "vi": "US Virgin Islands",
    "jp": "Japan",       "cn": "China",       "kr": "South Korea",
    "uk": "United Kingdom", "gb": "United Kingdom",
    "nl": "Netherlands", "be": "Belgium",     "dk": "Denmark",     "se": "Sweden",
    "fi": "Finland",     "no": "Norway",      "pl": "Poland",      "cz": "Czech Republic",
    "il": "Israel",      "jm": "Jamaica",     "ht": "Haiti",       "bs": "Bahamas",
    "tt": "Trinidad & Tobago",                "vg": "British Virgin Islands",
    "ru": "Russia",      "ua": "Ukraine",     "ba": "Bosnia & Herzegovina",
    "ao": "Angola",      "za": "South Africa",
}


def parse_awards(soup: BeautifulSoup) -> dict:
    """Count championships, All-Star selections, and major awards from the #bling list."""
    counts = {
        "championships": 0, "all_star_count": 0,
        "mvp_count": 0, "finals_mvp_count": 0, "dpoy_count": 0,
        "sixmoy_count": 0, "mip_count": 0, "roy": False,
    }

    bling = soup.select_one("#bling")
    if not bling:
        return counts

    def n_of(text: str) -> int:
        """Parse the leading 'Nx ' multiplier, or 1 if it's a single award like '2003-04 ROY'."""
        m = re.match(r"\s*(\d+)\s*x\s+", text, re.I)
        return int(m.group(1)) if m else 1

    for li in bling.select("li"):
        t = li.get_text(" ", strip=True)

        # Match most-specific labels first to avoid double-counting.
        if re.search(r"\bFinals MVP\b", t, re.I):
            counts["finals_mvp_count"] += n_of(t)
        elif re.search(r"\bAS MVP\b", t, re.I):
            # All-Star Game MVP — we don't track this as a field, skip.
            continue
        elif re.search(r"\bIST MVP\b|In-Season", t, re.I):
            # In-Season Tournament MVP — also skipped.
            continue
        elif re.search(r"(?<!Finals )(?<!AS )(?<!IST )\bMVP\b", t, re.I):
            counts["mvp_count"] += n_of(t)
        elif re.search(r"\bDef\.?\s*POY\b|Defensive Player", t, re.I):
            counts["dpoy_count"] += n_of(t)
        elif re.search(r"\bSixth Man\b|\b6th Man\b", t, re.I):
            counts["sixmoy_count"] += n_of(t)
        elif re.search(r"Most Improved|\bMIP\b", t, re.I):
            counts["mip_count"] += n_of(t)
        elif re.search(r"\bROY\b|Rookie of the Year", t, re.I):
            counts["roy"] = True
        elif re.search(r"NBA Champ\b", t, re.I):
            counts["championships"] += n_of(t)
        elif re.search(r"\bAll[\s-]Star\b", t, re.I) \
             and not re.search(r"All[-\s]NBA|All[-\s]Defensive|All[-\s]Rookie", t, re.I):
            counts["all_star_count"] += n_of(t)

    return counts


US_STATES = {
    "Alabama","Alaska","Arizona","Arkansas","California","Colorado","Connecticut","Delaware","Florida",
    "Georgia","Hawaii","Idaho","Illinois","Indiana","Iowa","Kansas","Kentucky","Louisiana","Maine",
    "Maryland","Massachusetts","Michigan","Minnesota","Mississippi","Missouri","Montana","Nebraska",
    "Nevada","New Hampshire","New Jersey","New Mexico","New York","North Carolina","North Dakota",
    "Ohio","Oklahoma","Oregon","Pennsylvania","Rhode Island","South Carolina","South Dakota",
    "Tennessee","Texas","Utah","Vermont","Virginia","Washington","West Virginia","Wisconsin","Wyoming",
    "Washington, D.C.","District of Columbia",
}


# ─── main ─────────────────────────────────────────────────────────
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--resume", action="store_true",
                    help="skip players already present in the output file")
    ap.add_argument("--limit", type=int, default=None,
                    help="smoke-test: process only N players")
    ap.add_argument("--out", type=str, default=str(OUT_JSON),
                    help="override output path")
    args = ap.parse_args()

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    if not IN_CSV.exists():
        sys.exit(f"Missing input {IN_CSV}. Export from Supabase first.")

    # Load roster
    roster: list[dict] = []
    with IN_CSV.open() as f:
        for row in csv.DictReader(f):
            roster.append({"id": int(row["id"]), "name": row["name"]})

    # Load existing output for resume mode
    done_ids: set[int] = set()
    existing: list[dict] = []
    if args.resume and out_path.exists():
        try:
            existing = json.loads(out_path.read_text())
            done_ids = {e["id"] for e in existing}
            print(f"Resuming: {len(done_ids)} players already scraped.")
        except Exception:
            pass

    if args.limit:
        roster = roster[: args.limit]

    session = requests.Session()
    session.headers["User-Agent"] = UA

    results: list[dict] = list(existing)
    missed: list[dict] = []

    for i, p in enumerate(roster, 1):
        if p["id"] in done_ids:
            continue

        print(f"[{i}/{len(roster)}] {p['name']}")
        url, html = find_player_page(session, p["name"])
        if not html:
            missed.append(p)
            print(f"  not found on BBR", file=sys.stderr)
            time.sleep(REQ_DELAY)
            continue

        soup = full_soup(html)
        record: dict = {"id": p["id"], "name": p["name"], "bbr_url": url}
        record.update(parse_bio(soup))
        record.update(parse_awards(soup))
        results.append(record)

        # Write-as-we-go so crashes don't lose progress
        out_path.write_text(json.dumps(results, indent=2))

        # Polite rate limit + jitter
        time.sleep(REQ_DELAY + random.uniform(0, 0.8))

    # Dump misses
    if missed:
        with MISSED_CSV.open("w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["id", "name"])
            w.writeheader()
            w.writerows(missed)
        print(f"\n{len(missed)} players not found — see {MISSED_CSV}")

    print(f"\nDone. {len(results)} enriched records in {out_path}")


if __name__ == "__main__":
    main()
