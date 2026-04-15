"""
Generate the I–Z slice of the NBA Daily Game player dataset.

Includes all fields needed for both the Daily Game (Wordle) and
Connections game: enrichment columns like college, country, draft
details, awards, and hall of fame status.

Headshot URLs use Basketball Reference (black background) instead of
NBA CDN (white/gray background).

Usage:
    python tools/nba_daily_players_i_z.py
    # Outputs to .tmp/nba_daily_players_i_z.json + SQL upsert
"""

import json
import re
import unicodedata
from pathlib import Path

OUTPUT_PATH = Path(".tmp") / "nba_daily_players_i_z.json"

BBR_HEADSHOT_BASE = "https://www.basketball-reference.com/req/202106291/images/headshots"


def strip_accents(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def bbr_slug(name: str) -> str:
    parts = [p for p in re.split(r"[ \-.']+", strip_accents(name).lower())
             if p and p.rstrip(".") not in {"jr", "sr", "ii", "iii", "iv"}]
    if len(parts) < 2:
        return ""
    first = re.sub(r"[^a-z]", "", parts[0])
    last = re.sub(r"[^a-z]", "", parts[-1])
    return (last[:5] + first[:2] + "01") if first and last else ""


def bbr_headshot(name: str) -> str:
    slug = bbr_slug(name)
    return f"{BBR_HEADSHOT_BASE}/{slug}.jpg" if slug else ""


def P(pid, name, retired, from_year, to_year, draft_team, teams, tier,
      career_games, career_minutes, position=None, height=None, jerseys=None,
      fun_fact=None, college=None, country="USA", draft_year=None,
      draft_round=None, draft_pick=None, championships=0, all_star_count=0,
      mvp_count=0, finals_mvp_count=0, dpoy_count=0, roy=False,
      sixmoy_count=0, mip_count=0, hall_of_fame=False, signature_shoe_brand=None):
    is_active = to_year is None or to_year >= 2025
    years_active = f"{from_year}-present" if is_active else f"{from_year}-{to_year}"
    return {
        "id": pid,
        "name": name,
        "retired": retired,
        "yearsActive": years_active,
        "fromYear": from_year,
        "toYear": None if is_active else to_year,
        "draftTeam": draft_team,
        "teams": teams,
        "position": position,
        "height": height,
        "jerseys": jerseys or [],
        "tier": tier,
        "careerGames": career_games,
        "careerMinutes": career_minutes,
        "funFact": fun_fact,
        "headshotUrl": bbr_headshot(name),
        # Connections enrichment
        "college": college,
        "country": country,
        "draftYear": draft_year,
        "draftRound": draft_round,
        "draftPick": draft_pick,
        "championships": championships,
        "allStarCount": all_star_count,
        "mvpCount": mvp_count,
        "finalsMvpCount": finals_mvp_count,
        "dpoyCount": dpoy_count,
        "roy": roy,
        "sixmoyCount": sixmoy_count,
        "mipCount": mip_count,
        "hallOfFame": hall_of_fame,
        "signatureShoeBrand": signature_shoe_brand,
    }


# fmt: off
PLAYERS = [
    # ════════════════════════════════════════════════
    # I
    # ════════════════════════════════════════════════
    P(2738, "Allen Iverson", True, 1996, 2010, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Denver Nuggets", "Detroit Pistons", "Memphis Grizzlies"],
        "superstar", 914, 33667, "SG", "6-0", ["3"],
        "Smallest player to win MVP at just 6 feet tall",
        college="Georgetown", draft_year=1996, draft_round=1, draft_pick=1,
        all_star_count=11, mvp_count=1, hall_of_fame=True, signature_shoe_brand="Reebok"),
    P(101141, "Andre Iguodala", True, 2004, 2023, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Denver Nuggets", "Golden State Warriors", "Miami Heat"],
        "solid", 1234, 37731, "SF", "6-6", ["9"],
        "Won Finals MVP coming off the bench in 2015",
        college="Arizona", draft_year=2004, draft_round=1, draft_pick=9,
        championships=4, all_star_count=1, finals_mvp_count=1, signature_shoe_brand="Nike"),
    P(101571, "Serge Ibaka", True, 2009, 2022, "Oklahoma City Thunder",
        ["Oklahoma City Thunder", "Orlando Magic", "Toronto Raptors", "Los Angeles Clippers", "Milwaukee Bucks"],
        "solid", 874, 23230, "PF", "6-10", ["9"],
        college=None, country="Republic of the Congo", draft_year=2008, draft_round=1, draft_pick=24,
        championships=1),
    P(2199, "Zydrunas Ilgauskas", True, 1996, 2010, "Cleveland Cavaliers",
        ["Cleveland Cavaliers", "Miami Heat"],
        "solid", 843, 25068, "C", "7-3", ["11"],
        college=None, country="Lithuania", draft_year=1996, draft_round=1, draft_pick=20,
        championships=1, all_star_count=2),
    P(202681, "Kyrie Irving", False, 2011, None, "Cleveland Cavaliers",
        ["Cleveland Cavaliers", "Boston Celtics", "Brooklyn Nets", "Dallas Mavericks"],
        "superstar", 782, 26600, "PG", "6-2", ["2", "11"],
        "Hit the most iconic shot in Finals history — Game 7, 2016",
        college="Duke", draft_year=2011, draft_round=1, draft_pick=1,
        championships=2, all_star_count=8, roy=True, signature_shoe_brand="Nike"),
    P(203506, "Victor Oladipo", False, 2013, None, "Orlando Magic",
        ["Orlando Magic", "Oklahoma City Thunder", "Indiana Pacers", "Houston Rockets", "Miami Heat"],
        "solid", 520, 15890, "SG", "6-4", ["4"],
        college="Indiana", draft_year=2013, draft_round=1, draft_pick=2,
        all_star_count=2, mip_count=1),

    # ════════════════════════════════════════════════
    # J
    # ════════════════════════════════════════════════
    P(893, "Michael Jordan", True, 1984, 2003, "Chicago Bulls",
        ["Chicago Bulls", "Washington Wizards"],
        "superstar", 1072, 41010, "SG", "6-6", ["23", "45"],
        "6-for-6 in NBA Finals with 6 Finals MVPs",
        college="North Carolina", draft_year=1984, draft_round=1, draft_pick=3,
        championships=6, all_star_count=14, mvp_count=5, finals_mvp_count=6,
        dpoy_count=1, roy=True, hall_of_fame=True, signature_shoe_brand="Jordan"),
    P(2544, "LeBron James", False, 2003, None, "Cleveland Cavaliers",
        ["Cleveland Cavaliers", "Miami Heat", "Los Angeles Lakers"],
        "superstar", 1492, 57446, "SF", "6-9", ["23", "6"],
        "NBA's all-time leading scorer with 40,000+ points",
        college=None, draft_year=2003, draft_round=1, draft_pick=1,
        championships=4, all_star_count=20, mvp_count=4, finals_mvp_count=4,
        hall_of_fame=False, signature_shoe_brand="Nike"),
    P(203999, "Nikola Jokic", False, 2015, None, "Denver Nuggets",
        ["Denver Nuggets"],
        "superstar", 710, 24780, "C", "6-11", ["15"],
        "Three-time MVP and 2023 Finals MVP — drafted 41st overall",
        college=None, country="Serbia", draft_year=2014, draft_round=2, draft_pick=41,
        championships=1, all_star_count=6, mvp_count=3, finals_mvp_count=1),
    P(101127, "Joe Johnson", True, 2001, 2018, "Boston Celtics",
        ["Boston Celtics", "Phoenix Suns", "Atlanta Hawks", "Brooklyn Nets", "Miami Heat", "Utah Jazz", "Houston Rockets"],
        "solid", 1276, 40683, "SG", "6-7", ["2"],
        college="Arkansas", draft_year=2001, draft_round=1, draft_pick=10,
        all_star_count=7),
    P(1629029, "Jaren Jackson Jr.", False, 2018, None, "Memphis Grizzlies",
        ["Memphis Grizzlies"],
        "solid", 349, 10875, "PF", "6-11", ["13"],
        "2023 Defensive Player of the Year",
        college="Michigan State", draft_year=2018, draft_round=1, draft_pick=4,
        dpoy_count=1),
    P(1628991, "DeAndre Jordan", True, 2008, 2023, "Los Angeles Clippers",
        ["Los Angeles Clippers", "Dallas Mavericks", "Brooklyn Nets", "Los Angeles Lakers", "Philadelphia 76ers", "Denver Nuggets"],
        "solid", 1083, 26154, "C", "6-11", ["6"],
        college="Texas A&M", draft_year=2008, draft_round=2, draft_pick=35,
        all_star_count=1),
    P(1629630, "Jalen Johnson", False, 2021, None, "Atlanta Hawks",
        ["Atlanta Hawks"],
        "deep_cut", 210, 5800, "PF", "6-9", ["1"],
        college="Duke", draft_year=2021, draft_round=1, draft_pick=20),
    P(1628382, "Justin Holiday", False, 2016, None, "Chicago Bulls",
        ["Chicago Bulls", "New York Knicks", "Indiana Pacers", "Atlanta Hawks", "Sacramento Kings", "Milwaukee Bucks", "Denver Nuggets"],
        "deep_cut", 520, 13140, "SG", "6-6", ["7"],
        college="Washington", draft_year=None, draft_round=None, draft_pick=None),
    P(1628969, "Jonathan Isaac", False, 2017, None, "Orlando Magic",
        ["Orlando Magic"],
        "deep_cut", 136, 3920, "PF", "6-10", ["1"],
        college="Florida State", draft_year=2017, draft_round=1, draft_pick=6),
    P(201572, "Jrue Holiday", False, 2009, None, "Philadelphia 76ers",
        ["Philadelphia 76ers", "New Orleans Pelicans", "Milwaukee Bucks", "Portland Trail Blazers", "Boston Celtics"],
        "superstar", 900, 29610, "PG", "6-3", ["21", "11"],
        "2021 champion and elite two-way guard",
        college="UCLA", draft_year=2009, draft_round=1, draft_pick=17,
        championships=2, all_star_count=2),
    P(1629029, "Jalen Brunson", False, 2018, None, "Dallas Mavericks",
        ["Dallas Mavericks", "New York Knicks"],
        "superstar", 420, 13650, "PG", "6-2", ["11"],
        "Led the Knicks back to relevance",
        college="Villanova", draft_year=2018, draft_round=2, draft_pick=33,
        all_star_count=2),

    # ════════════════════════════════════════════════
    # K
    # ════════════════════════════════════════════════
    P(202695, "Kawhi Leonard", False, 2011, None, "Indiana Pacers",
        ["San Antonio Spurs", "Toronto Raptors", "Los Angeles Clippers"],
        "superstar", 541, 18750, "SF", "6-7", ["2"],
        "Only player to win Finals MVP with two different teams and two DPOY awards",
        college="San Diego State", draft_year=2011, draft_round=1, draft_pick=15,
        championships=2, all_star_count=6, finals_mvp_count=2, dpoy_count=2,
        signature_shoe_brand="New Balance"),
    P(101106, "Jason Kidd", True, 1994, 2013, "Dallas Mavericks",
        ["Dallas Mavericks", "Phoenix Suns", "New Jersey Nets", "New York Knicks"],
        "superstar", 1391, 50110, "PG", "6-4", ["5", "2"],
        "Third all-time in assists and steals",
        college="California", draft_year=1994, draft_round=1, draft_pick=2,
        championships=1, all_star_count=10, roy=True, hall_of_fame=True),
    P(203937, "Kyle Kuzma", False, 2017, None, "Los Angeles Lakers",
        ["Los Angeles Lakers", "Washington Wizards"],
        "solid", 534, 16185, "PF", "6-10", ["0"],
        college="Utah", draft_year=2017, draft_round=1, draft_pick=27,
        championships=1),
    P(201988, "Khris Middleton", False, 2012, None, "Detroit Pistons",
        ["Detroit Pistons", "Milwaukee Bucks"],
        "solid", 746, 24412, "SF", "6-7", ["22"],
        college="Texas A&M", draft_year=2012, draft_round=2, draft_pick=39,
        championships=1, all_star_count=3),
    P(2616, "Andrei Kirilenko", True, 2001, 2015, "Utah Jazz",
        ["Utah Jazz", "Minnesota Timberwolves", "Brooklyn Nets"],
        "solid", 668, 22032, "SF", "6-9", ["47"],
        college=None, country="Russia", draft_year=1999, draft_round=1, draft_pick=24,
        all_star_count=1),
    P(1628398, "De'Aaron Fox", False, 2017, None, "Sacramento Kings",
        ["Sacramento Kings"],
        "solid", 530, 18128, "PG", "6-3", ["5"],
        college="Kentucky", draft_year=2017, draft_round=1, draft_pick=5,
        all_star_count=1, signature_shoe_brand="Nike"),
    P(203901, "Kentavious Caldwell-Pope", False, 2013, None, "Detroit Pistons",
        ["Detroit Pistons", "Los Angeles Lakers", "Washington Wizards", "Denver Nuggets", "Orlando Magic"],
        "solid", 764, 22940, "SG", "6-5", ["5"],
        college="Georgia", draft_year=2013, draft_round=1, draft_pick=8,
        championships=2),
    P(1628378, "Keldon Johnson", False, 2019, None, "San Antonio Spurs",
        ["San Antonio Spurs", "Brooklyn Nets"],
        "deep_cut", 340, 9280, "SF", "6-5", ["3"],
        college="Kentucky", draft_year=2019, draft_round=1, draft_pick=29),
    P(203918, "Kyle Anderson", False, 2014, None, "San Antonio Spurs",
        ["San Antonio Spurs", "Memphis Grizzlies", "Minnesota Timberwolves", "Golden State Warriors"],
        "deep_cut", 610, 14120, "SF", "6-9", ["1"],
        college="UCLA", draft_year=2014, draft_round=1, draft_pick=30),

    # ════════════════════════════════════════════════
    # L
    # ════════════════════════════════════════════════
    P(203081, "Damian Lillard", False, 2012, None, "Portland Trail Blazers",
        ["Portland Trail Blazers", "Milwaukee Bucks"],
        "superstar", 862, 31000, "PG", "6-2", ["0"],
        "Hit the series-winning buzzer-beater from 37 feet — Dame Time",
        college="Weber State", draft_year=2012, draft_round=1, draft_pick=6,
        championships=1, all_star_count=7, roy=True, signature_shoe_brand="Adidas"),
    P(1629630, "Luka Doncic", False, 2018, None, "Dallas Mavericks",
        ["Dallas Mavericks", "Los Angeles Lakers"],
        "superstar", 430, 15800, "PG", "6-7", ["77"],
        "Won EuroLeague MVP at 19 before entering the NBA",
        college=None, country="Slovenia", draft_year=2018, draft_round=1, draft_pick=3,
        all_star_count=5, roy=True, signature_shoe_brand="Jordan"),
    P(203897, "Zach LaVine", False, 2014, None, "Minnesota Timberwolves",
        ["Minnesota Timberwolves", "Chicago Bulls"],
        "solid", 618, 19780, "SG", "6-5", ["8"],
        "Back-to-back Slam Dunk Contest champion",
        college="UCLA", draft_year=2014, draft_round=1, draft_pick=13,
        all_star_count=2, signature_shoe_brand="New Balance"),
    P(101139, "Kevin Love", False, 2008, None, "Minnesota Timberwolves",
        ["Minnesota Timberwolves", "Cleveland Cavaliers", "Miami Heat"],
        "solid", 890, 27140, "PF", "6-8", ["42", "0"],
        "Grabbed 31 rebounds in a single game",
        college="UCLA", draft_year=2008, draft_round=1, draft_pick=5,
        championships=1, all_star_count=5),
    P(201950, "Brook Lopez", False, 2008, None, "Brooklyn Nets",
        ["Brooklyn Nets", "Los Angeles Lakers", "Milwaukee Bucks"],
        "solid", 949, 28152, "C", "7-0", ["11"],
        college="Stanford", draft_year=2008, draft_round=1, draft_pick=10,
        championships=1, all_star_count=1),
    P(200768, "Robin Lopez", False, 2008, None, "Phoenix Suns",
        ["Phoenix Suns", "New Orleans Hornets", "Portland Trail Blazers", "New York Knicks", "Chicago Bulls", "Milwaukee Bucks", "Washington Wizards", "Orlando Magic", "Cleveland Cavaliers"],
        "deep_cut", 926, 21010, "C", "7-0", ["8", "42"],
        college="Stanford", draft_year=2008, draft_round=1, draft_pick=15,
        championships=1),
    P(201627, "Caris LeVert", False, 2016, None, "Brooklyn Nets",
        ["Brooklyn Nets", "Indiana Pacers", "Cleveland Cavaliers"],
        "deep_cut", 398, 10410, "SG", "6-6", ["22"],
        college="Michigan", draft_year=2016, draft_round=1, draft_pick=20),
    P(1629637, "Tyler Herro", False, 2019, None, "Miami Heat",
        ["Miami Heat"],
        "solid", 342, 10240, "SG", "6-5", ["14"],
        "2022 Sixth Man of the Year",
        college="Kentucky", draft_year=2019, draft_round=1, draft_pick=13,
        sixmoy_count=1),
    P(201599, "Jeremy Lin", True, 2010, 2019, "Golden State Warriors",
        ["Golden State Warriors", "New York Knicks", "Houston Rockets", "Los Angeles Lakers", "Charlotte Hornets", "Brooklyn Nets", "Atlanta Hawks", "Toronto Raptors"],
        "solid", 480, 10789, "PG", "6-3", ["17", "7"],
        "Sparked Linsanity — went from undrafted to global icon in 2012",
        college="Harvard", country="USA", draft_year=None, draft_round=None, draft_pick=None,
        championships=1),
    P(1628389, "Lauri Markkanen", False, 2017, None, "Chicago Bulls",
        ["Chicago Bulls", "Cleveland Cavaliers", "Utah Jazz"],
        "solid", 465, 14300, "PF", "7-0", ["24"],
        "2023 Most Improved Player",
        college="Arizona", country="Finland", draft_year=2017, draft_round=1, draft_pick=7,
        mip_count=1, all_star_count=1),

    # ════════════════════════════════════════════════
    # M
    # ════════════════════════════════════════════════
    P(786, "Karl Malone", True, 1985, 2004, "Utah Jazz",
        ["Utah Jazz", "Los Angeles Lakers"],
        "superstar", 1476, 54852, "PF", "6-9", ["32"],
        "Second all-time scorer with 36,928 points — The Mailman",
        college="Louisiana Tech", draft_year=1985, draft_round=1, draft_pick=13,
        all_star_count=14, mvp_count=2, hall_of_fame=True),
    P(2037, "Reggie Miller", True, 1987, 2005, "Indiana Pacers",
        ["Indiana Pacers"],
        "superstar", 1389, 47616, "SG", "6-7", ["31"],
        "Hit 8 points in 8.9 seconds against the Knicks",
        college="UCLA", draft_year=1987, draft_round=1, draft_pick=11,
        all_star_count=5, hall_of_fame=True),
    P(1629630, "Ja Morant", False, 2019, None, "Memphis Grizzlies",
        ["Memphis Grizzlies"],
        "superstar", 294, 10580, "PG", "6-3", ["12"],
        "2022 Most Improved Player — one of the most explosive athletes ever",
        college="Murray State", draft_year=2019, draft_round=1, draft_pick=2,
        all_star_count=2, mip_count=1, roy=True, signature_shoe_brand="Nike"),
    P(1629008, "Donovan Mitchell", False, 2017, None, "Utah Jazz",
        ["Utah Jazz", "Cleveland Cavaliers"],
        "superstar", 500, 17450, "SG", "6-1", ["45"],
        "Scored 71 points in a single game — Cavaliers franchise record",
        college="Louisville", draft_year=2017, draft_round=1, draft_pick=13,
        all_star_count=4, signature_shoe_brand="Adidas"),
    P(2546, "Carmelo Anthony", True, 2003, 2022, "Denver Nuggets",
        ["Denver Nuggets", "New York Knicks", "Oklahoma City Thunder", "Houston Rockets", "Portland Trail Blazers", "Los Angeles Lakers"],
        "superstar", 1260, 44270, "SF", "6-7", ["15", "7"],
        "10-time All-Star and 3-time Olympic gold medalist",
        college="Syracuse", draft_year=2003, draft_round=1, draft_pick=3,
        all_star_count=10, signature_shoe_brand="Jordan"),
    P(203114, "CJ McCollum", False, 2013, None, "Portland Trail Blazers",
        ["Portland Trail Blazers", "New Orleans Pelicans"],
        "solid", 702, 23044, "SG", "6-3", ["3"],
        college="Lehigh", draft_year=2013, draft_round=1, draft_pick=10),
    P(201619, "Dejounte Murray", False, 2016, None, "San Antonio Spurs",
        ["San Antonio Spurs", "Atlanta Hawks", "New Orleans Pelicans"],
        "solid", 425, 13520, "PG", "6-4", ["5"],
        college="Washington", draft_year=2016, draft_round=1, draft_pick=29,
        all_star_count=1),
    P(204456, "Jamal Murray", False, 2016, None, "Denver Nuggets",
        ["Denver Nuggets"],
        "solid", 460, 15320, "PG", "6-3", ["27"],
        "Key piece of Denver's 2023 championship run",
        college="Kentucky", country="Canada", draft_year=2016, draft_round=1, draft_pick=7,
        championships=1),
    P(101133, "Manu Ginobili", True, 1999, 2018, "San Antonio Spurs",
        ["San Antonio Spurs"],
        "superstar", 1057, 26752, "SG", "6-6", ["20"],
        "Won Olympic gold, 4 NBA titles, and a EuroLeague title — FIBA triple crown",
        college=None, country="Argentina", draft_year=1999, draft_round=2, draft_pick=57,
        championships=4, all_star_count=2, sixmoy_count=1, hall_of_fame=True),
    P(1628389, "Malik Monk", False, 2017, None, "Charlotte Hornets",
        ["Charlotte Hornets", "Los Angeles Lakers", "Sacramento Kings"],
        "solid", 480, 12540, "SG", "6-3", ["1"],
        college="Kentucky", draft_year=2017, draft_round=1, draft_pick=11),
    P(203468, "Michael Porter Jr.", False, 2019, None, "Denver Nuggets",
        ["Denver Nuggets"],
        "solid", 300, 8580, "SF", "6-10", ["1"],
        college="Missouri", draft_year=2018, draft_round=1, draft_pick=14,
        championships=1),
    P(203107, "Marcus Morris Sr.", False, 2011, None, "Houston Rockets",
        ["Houston Rockets", "Phoenix Suns", "Detroit Pistons", "Boston Celtics", "New York Knicks", "Los Angeles Clippers", "Philadelphia 76ers", "Cleveland Cavaliers"],
        "deep_cut", 740, 19800, "PF", "6-8", ["13"],
        college="Kansas", draft_year=2011, draft_round=1, draft_pick=14),
    P(203109, "Markieff Morris", False, 2011, None, "Phoenix Suns",
        ["Phoenix Suns", "Washington Wizards", "Oklahoma City Thunder", "Los Angeles Lakers", "Miami Heat", "Brooklyn Nets", "Dallas Mavericks"],
        "deep_cut", 668, 16320, "PF", "6-8", ["88"],
        college="Kansas", draft_year=2011, draft_round=1, draft_pick=13,
        championships=1),

    # ════════════════════════════════════════════════
    # N
    # ════════════════════════════════════════════════
    P(959, "Steve Nash", True, 1996, 2014, "Phoenix Suns",
        ["Phoenix Suns", "Dallas Mavericks", "Los Angeles Lakers"],
        "superstar", 1217, 38026, "PG", "6-3", ["13"],
        "Back-to-back MVP and career 90/50/40 club member",
        college="Santa Clara", country="Canada", draft_year=1996, draft_round=1, draft_pick=15,
        all_star_count=8, mvp_count=2, hall_of_fame=True),
    P(1713, "Dirk Nowitzki", True, 1998, 2019, "Dallas Mavericks",
        ["Dallas Mavericks"],
        "superstar", 1522, 51367, "PF", "7-0", ["41"],
        "Led Dallas to 2011 title — played 21 seasons with one team",
        college=None, country="Germany", draft_year=1998, draft_round=1, draft_pick=9,
        championships=1, all_star_count=14, mvp_count=1, finals_mvp_count=1,
        hall_of_fame=True, signature_shoe_brand="Nike"),
    P(203994, "Jusuf Nurkic", False, 2014, None, "Denver Nuggets",
        ["Denver Nuggets", "Portland Trail Blazers", "Phoenix Suns"],
        "solid", 520, 13640, "C", "6-11", ["27"],
        college=None, country="Bosnia and Herzegovina", draft_year=2014, draft_round=1, draft_pick=16),
    P(203092, "Nerlens Noel", False, 2013, None, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Dallas Mavericks", "Oklahoma City Thunder", "New York Knicks", "Detroit Pistons"],
        "deep_cut", 419, 9200, "C", "6-11", ["3"],
        college="Kentucky", draft_year=2013, draft_round=1, draft_pick=6),
    P(1629670, "Nickeil Alexander-Walker", False, 2019, None, "New Orleans Pelicans",
        ["New Orleans Pelicans", "Utah Jazz", "Minnesota Timberwolves"],
        "deep_cut", 280, 6100, "SG", "6-5", ["6"],
        college="Virginia Tech", country="Canada", draft_year=2019, draft_round=1, draft_pick=17),

    # ════════════════════════════════════════════════
    # O
    # ════════════════════════════════════════════════
    P(165, "Shaquille O'Neal", True, 1992, 2011, "Orlando Magic",
        ["Orlando Magic", "Los Angeles Lakers", "Miami Heat", "Phoenix Suns", "Cleveland Cavaliers", "Boston Celtics"],
        "superstar", 1207, 41917, "C", "7-1", ["32", "34", "33", "36"],
        "Most dominant force ever — 3 consecutive Finals MVPs",
        college="LSU", draft_year=1992, draft_round=1, draft_pick=1,
        championships=4, all_star_count=15, mvp_count=1, finals_mvp_count=3,
        hall_of_fame=True, signature_shoe_brand="Reebok"),
    P(858, "Hakeem Olajuwon", True, 1984, 2002, "Houston Rockets",
        ["Houston Rockets", "Toronto Raptors"],
        "superstar", 1238, 44222, "C", "7-0", ["34"],
        "Only player to win MVP, DPOY, and Finals MVP in same season",
        college="Houston", country="Nigeria", draft_year=1984, draft_round=1, draft_pick=1,
        championships=2, all_star_count=12, mvp_count=1, finals_mvp_count=2,
        dpoy_count=2, hall_of_fame=True),
    P(1628378, "OG Anunoby", False, 2017, None, "Toronto Raptors",
        ["Toronto Raptors", "New York Knicks"],
        "solid", 430, 13260, "SF", "6-7", ["3"],
        college="Indiana", country="United Kingdom", draft_year=2017, draft_round=1, draft_pick=23,
        championships=1),
    P(1814, "Cedi Osman", False, 2017, None, "Cleveland Cavaliers",
        ["Cleveland Cavaliers", "San Antonio Spurs"],
        "deep_cut", 392, 8820, "SF", "6-7", ["16"],
        college=None, country="Turkey", draft_year=2015, draft_round=2, draft_pick=31),

    # ════════════════════════════════════════════════
    # P
    # ════════════════════════════════════════════════
    P(1891, "Tony Parker", True, 2001, 2019, "San Antonio Spurs",
        ["San Antonio Spurs", "Charlotte Hornets"],
        "superstar", 1254, 41425, "PG", "6-2", ["9"],
        "Youngest Finals MVP at age 25 — spoke 4 languages",
        college=None, country="France", draft_year=2001, draft_round=1, draft_pick=28,
        championships=4, all_star_count=6, finals_mvp_count=1, hall_of_fame=True),
    P(101108, "Chris Paul", False, 2005, None, "New Orleans Hornets",
        ["New Orleans Hornets", "Los Angeles Clippers", "Houston Rockets", "Oklahoma City Thunder", "Phoenix Suns", "Golden State Warriors", "San Antonio Spurs"],
        "superstar", 1272, 43672, "PG", "6-0", ["3"],
        "11-time All-NBA selection and steals leader of his generation",
        college="Wake Forest", draft_year=2005, draft_round=1, draft_pick=4,
        all_star_count=12, roy=True, signature_shoe_brand="Jordan"),
    P(600015, "Scottie Pippen", True, 1987, 2004, "Chicago Bulls",
        ["Chicago Bulls", "Houston Rockets", "Portland Trail Blazers"],
        "superstar", 1178, 41067, "SF", "6-8", ["33"],
        "Won 6 championships alongside Jordan — Hall of Fame defender",
        college="Central Arkansas", draft_year=1987, draft_round=1, draft_pick=5,
        championships=6, all_star_count=7, hall_of_fame=True, signature_shoe_brand="Nike"),
    P(203954, "Joel Embiid", False, 2016, None, "Philadelphia 76ers",
        ["Philadelphia 76ers"],
        "superstar", 433, 14460, "C", "7-0", ["21"],
        "2023 MVP — born in Cameroon, started playing basketball at 15",
        college="Kansas", country="Cameroon", draft_year=2014, draft_round=1, draft_pick=3,
        all_star_count=7, mvp_count=1, signature_shoe_brand="Under Armour"),
    P(2001, "Gary Payton", True, 1990, 2007, "Seattle SuperSonics",
        ["Seattle SuperSonics", "Milwaukee Bucks", "Los Angeles Lakers", "Boston Celtics", "Miami Heat"],
        "superstar", 1335, 47116, "PG", "6-4", ["20"],
        "Only point guard to win Defensive Player of the Year — The Glove",
        college="Oregon State", draft_year=1990, draft_round=1, draft_pick=2,
        championships=1, all_star_count=9, dpoy_count=1, hall_of_fame=True, signature_shoe_brand="Nike"),
    P(203486, "Mason Plumlee", False, 2013, None, "Brooklyn Nets",
        ["Brooklyn Nets", "Portland Trail Blazers", "Denver Nuggets", "Detroit Pistons", "Charlotte Hornets", "Los Angeles Clippers"],
        "deep_cut", 701, 15310, "C", "6-11", ["24"],
        college="Duke", draft_year=2013, draft_round=1, draft_pick=22),
    P(203953, "Pascal Siakam", False, 2016, None, "Toronto Raptors",
        ["Toronto Raptors", "Indiana Pacers"],
        "solid", 575, 18810, "PF", "6-8", ["43"],
        "2019 Most Improved Player and NBA champion",
        college=None, country="Cameroon", draft_year=2016, draft_round=1, draft_pick=27,
        championships=1, all_star_count=3, mip_count=1),
    P(1629011, "Gary Payton II", False, 2016, None, "Milwaukee Bucks",
        ["Milwaukee Bucks", "Los Angeles Lakers", "Washington Wizards", "Golden State Warriors", "Portland Trail Blazers"],
        "deep_cut", 268, 5760, "SG", "6-3", ["0"],
        college="Oregon State", draft_year=None, draft_round=None, draft_pick=None,
        championships=1),
    P(203935, "Marcus Smart", False, 2014, None, "Boston Celtics",
        ["Boston Celtics", "Memphis Grizzlies"],
        "solid", 650, 19930, "PG", "6-3", ["36"],
        "2022 Defensive Player of the Year — first guard since Payton",
        college="Oklahoma State", draft_year=2014, draft_round=1, draft_pick=6,
        championships=1, dpoy_count=1),
    P(203468, "Paolo Banchero", False, 2022, None, "Orlando Magic",
        ["Orlando Magic"],
        "superstar", 180, 6300, "PF", "6-10", ["5"],
        "2023 Rookie of the Year — first Duke player taken #1 since Kyrie",
        college="Duke", draft_year=2022, draft_round=1, draft_pick=1,
        roy=True),

    # ════════════════════════════════════════════════
    # R
    # ════════════════════════════════════════════════
    P(756, "David Robinson", True, 1989, 2003, "San Antonio Spurs",
        ["San Antonio Spurs"],
        "superstar", 987, 34271, "C", "7-1", ["50"],
        "Naval Academy graduate — scored 71 to win scoring title",
        college="Navy", draft_year=1987, draft_round=1, draft_pick=1,
        championships=2, all_star_count=10, mvp_count=1, dpoy_count=1,
        roy=True, hall_of_fame=True),
    P(201565, "Derrick Rose", True, 2008, 2022, "Chicago Bulls",
        ["Chicago Bulls", "New York Knicks", "Cleveland Cavaliers", "Minnesota Timberwolves", "Detroit Pistons", "Memphis Grizzlies"],
        "superstar", 723, 22571, "PG", "6-2", ["1", "25"],
        "Youngest MVP in NBA history at age 22",
        college="Memphis", draft_year=2008, draft_round=1, draft_pick=1,
        all_star_count=3, mvp_count=1, roy=True, signature_shoe_brand="Adidas"),
    P(201163, "Rajon Rondo", True, 2006, 2022, "Boston Celtics",
        ["Boston Celtics", "Dallas Mavericks", "Sacramento Kings", "Chicago Bulls", "New Orleans Pelicans", "Los Angeles Lakers", "Atlanta Hawks", "Los Angeles Clippers", "Cleveland Cavaliers"],
        "solid", 977, 31490, "PG", "6-1", ["9"],
        college="Kentucky", draft_year=2006, draft_round=1, draft_pick=21,
        championships=2, all_star_count=4),
    P(203087, "Terrence Ross", True, 2012, 2023, "Toronto Raptors",
        ["Toronto Raptors", "Orlando Magic", "Phoenix Suns"],
        "deep_cut", 724, 17980, "SG", "6-6", ["31"],
        college="Washington", draft_year=2012, draft_round=1, draft_pick=8),
    P(201566, "Julius Randle", False, 2014, None, "Los Angeles Lakers",
        ["Los Angeles Lakers", "New Orleans Pelicans", "New York Knicks", "Minnesota Timberwolves"],
        "solid", 670, 21220, "PF", "6-8", ["30"],
        college="Kentucky", draft_year=2014, draft_round=1, draft_pick=7,
        all_star_count=2, mip_count=1),
    P(203089, "Terry Rozier", False, 2015, None, "Boston Celtics",
        ["Boston Celtics", "Charlotte Hornets", "Miami Heat"],
        "solid", 600, 17400, "PG", "6-1", ["3"],
        college="Louisville", draft_year=2015, draft_round=1, draft_pick=16),
    P(1629634, "RJ Barrett", False, 2019, None, "New York Knicks",
        ["New York Knicks", "Toronto Raptors"],
        "solid", 360, 11100, "SF", "6-6", ["9"],
        college="Duke", country="Canada", draft_year=2019, draft_round=1, draft_pick=3),

    # ════════════════════════════════════════════════
    # S
    # ════════════════════════════════════════════════
    P(969, "John Stockton", True, 1984, 2003, "Utah Jazz",
        ["Utah Jazz"],
        "superstar", 1504, 47764, "PG", "6-1", ["12"],
        "All-time leader in assists and steals — records may never be broken",
        college="Gonzaga", draft_year=1984, draft_round=1, draft_pick=16,
        all_star_count=10, hall_of_fame=True),
    P(1628369, "Jayson Tatum", False, 2017, None, "Boston Celtics",
        ["Boston Celtics"],
        "superstar", 530, 19140, "SF", "6-8", ["0"],
        "Led Boston to 2024 championship — 5-time All-Star by age 26",
        college="Duke", draft_year=2017, draft_round=1, draft_pick=3,
        championships=1, all_star_count=5, finals_mvp_count=1, signature_shoe_brand="Jordan"),
    P(1629014, "Shai Gilgeous-Alexander", False, 2018, None, "Los Angeles Clippers",
        ["Los Angeles Clippers", "Oklahoma City Thunder"],
        "superstar", 420, 14480, "SG", "6-6", ["2"],
        "2024 MVP runner-up — leading OKC's rebuild",
        college="Kentucky", country="Canada", draft_year=2018, draft_round=1, draft_pick=11,
        all_star_count=3, signature_shoe_brand="Nike"),
    P(1629631, "Ben Simmons", False, 2017, None, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Brooklyn Nets"],
        "solid", 307, 10340, "PG", "6-10", ["25"],
        college="LSU", country="Australia", draft_year=2016, draft_round=1, draft_pick=1,
        all_star_count=3, roy=True),
    P(203471, "Dennis Schroder", False, 2013, None, "Atlanta Hawks",
        ["Atlanta Hawks", "Oklahoma City Thunder", "Los Angeles Lakers", "Boston Celtics", "Houston Rockets", "Toronto Raptors", "Brooklyn Nets", "Golden State Warriors"],
        "deep_cut", 730, 19230, "PG", "6-1", ["17"],
        college=None, country="Germany", draft_year=2013, draft_round=1, draft_pick=17,
        sixmoy_count=1),
    P(1627759, "Jaylen Brown", False, 2016, None, "Boston Celtics",
        ["Boston Celtics"],
        "superstar", 555, 18140, "SG", "6-6", ["7"],
        "2024 Finals MVP",
        college="California", draft_year=2016, draft_round=1, draft_pick=3,
        championships=1, all_star_count=3, finals_mvp_count=1, signature_shoe_brand="Adidas"),
    P(201942, "DeMar DeRozan", False, 2009, None, "Toronto Raptors",
        ["Toronto Raptors", "San Antonio Spurs", "Chicago Bulls", "Sacramento Kings"],
        "superstar", 1110, 38880, "SG", "6-6", ["10"],
        "One of just 8 players with 20,000+ career points and 5,000+ assists",
        college="USC", draft_year=2009, draft_round=1, draft_pick=9,
        all_star_count=6, signature_shoe_brand="Nike"),
    P(203110, "Draymond Green", False, 2012, None, "Golden State Warriors",
        ["Golden State Warriors"],
        "superstar", 806, 24550, "PF", "6-6", ["23"],
        "4-time champion and emotional heart of the Warriors dynasty",
        college="Michigan State", draft_year=2012, draft_round=2, draft_pick=35,
        championships=4, all_star_count=4, dpoy_count=1),
    P(1629636, "Anfernee Simons", False, 2018, None, "Portland Trail Blazers",
        ["Portland Trail Blazers"],
        "solid", 390, 10920, "SG", "6-3", ["1"],
        college=None, draft_year=2018, draft_round=1, draft_pick=24),
    P(2594, "Josh Smith", True, 2004, 2017, "Atlanta Hawks",
        ["Atlanta Hawks", "Detroit Pistons", "Houston Rockets", "Los Angeles Clippers", "New Orleans Pelicans"],
        "solid", 889, 28590, "PF", "6-9", ["5"],
        college=None, draft_year=2004, draft_round=1, draft_pick=17),
    P(203084, "Isaiah Thomas", True, 2011, 2022, "Sacramento Kings",
        ["Sacramento Kings", "Phoenix Suns", "Boston Celtics", "Cleveland Cavaliers", "Los Angeles Lakers", "Denver Nuggets", "Washington Wizards", "Minnesota Timberwolves", "New Orleans Pelicans", "Charlotte Hornets", "Dallas Mavericks"],
        "solid", 607, 16780, "PG", "5-9", ["4"],
        "Scored 53 on his late sister's birthday — 5'9\" heart of Boston's #1 seed",
        college="Washington", draft_year=2011, draft_round=2, draft_pick=60,
        all_star_count=2),

    # ════════════════════════════════════════════════
    # T
    # ════════════════════════════════════════════════
    P(1628384, "Karl-Anthony Towns", False, 2015, None, "Minnesota Timberwolves",
        ["Minnesota Timberwolves", "New York Knicks"],
        "superstar", 580, 19940, "C", "6-11", ["32"],
        "2016 Rookie of the Year — one of the best shooting centers ever",
        college="Kentucky", country="Dominican Republic", draft_year=2015, draft_round=1, draft_pick=1,
        all_star_count=4, roy=True),
    P(1629020, "Trae Young", False, 2018, None, "Atlanta Hawks",
        ["Atlanta Hawks"],
        "superstar", 420, 14480, "PG", "6-1", ["11"],
        "Led Hawks to 2021 Eastern Conference Finals as a 22-year-old",
        college="Oklahoma", draft_year=2018, draft_round=1, draft_pick=5,
        all_star_count=3, signature_shoe_brand="Adidas"),
    P(1627832, "Fred VanVleet", False, 2016, None, "Toronto Raptors",
        ["Toronto Raptors", "Houston Rockets"],
        "solid", 530, 17340, "PG", "6-1", ["23"],
        "Undrafted to NBA champion and All-Star",
        college="Wichita State", draft_year=None, draft_round=None, draft_pick=None,
        championships=1, all_star_count=1),
    P(1629639, "Jarrett Allen", False, 2017, None, "Brooklyn Nets",
        ["Brooklyn Nets", "Cleveland Cavaliers"],
        "solid", 500, 14340, "C", "6-11", ["31"],
        college="Texas", draft_year=2017, draft_round=1, draft_pick=22,
        all_star_count=1),
    P(201952, "Jeff Teague", True, 2009, 2021, "Atlanta Hawks",
        ["Atlanta Hawks", "Indiana Pacers", "Minnesota Timberwolves", "Boston Celtics", "Orlando Magic", "Milwaukee Bucks"],
        "deep_cut", 811, 22340, "PG", "6-2", ["0"],
        college="Wake Forest", draft_year=2009, draft_round=1, draft_pick=19,
        all_star_count=1, championships=1),

    # ════════════════════════════════════════════════
    # V
    # ════════════════════════════════════════════════
    P(202685, "Nikola Vucevic", False, 2011, None, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Orlando Magic", "Chicago Bulls"],
        "solid", 900, 27120, "C", "6-10", ["9"],
        college="USC", country="Montenegro", draft_year=2011, draft_round=1, draft_pick=16,
        all_star_count=2),
    P(201596, "Jonas Valanciunas", False, 2012, None, "Toronto Raptors",
        ["Toronto Raptors", "Memphis Grizzlies", "New Orleans Pelicans", "Washington Wizards"],
        "solid", 798, 20754, "C", "6-11", ["17"],
        college=None, country="Lithuania", draft_year=2011, draft_round=1, draft_pick=5),

    # ════════════════════════════════════════════════
    # W
    # ════════════════════════════════════════════════
    P(2548, "Dwyane Wade", True, 2003, 2019, "Miami Heat",
        ["Miami Heat", "Chicago Bulls", "Cleveland Cavaliers"],
        "superstar", 1054, 36052, "SG", "6-4", ["3"],
        "Won his first ring averaging 34.7 PPG in the Finals",
        college="Marquette", draft_year=2003, draft_round=1, draft_pick=5,
        championships=3, all_star_count=13, finals_mvp_count=1,
        hall_of_fame=True, signature_shoe_brand="Li-Ning"),
    P(201566, "Russell Westbrook", False, 2008, None, "Seattle SuperSonics",
        ["Oklahoma City Thunder", "Houston Rockets", "Washington Wizards", "Los Angeles Lakers", "Los Angeles Clippers", "Denver Nuggets"],
        "superstar", 1100, 38500, "PG", "6-3", ["0"],
        "Averaged a triple-double for 4 seasons — only player in history to do it",
        college="UCLA", draft_year=2008, draft_round=1, draft_pick=4,
        all_star_count=9, mvp_count=1, signature_shoe_brand="Jordan"),
    P(1629632, "Zion Williamson", False, 2019, None, "New Orleans Pelicans",
        ["New Orleans Pelicans"],
        "superstar", 226, 7360, "PF", "6-6", ["1"],
        "Most hyped prospect since LeBron — 285-pound freight train",
        college="Duke", draft_year=2019, draft_round=1, draft_pick=1,
        all_star_count=1, signature_shoe_brand="Jordan"),
    P(101109, "Deron Williams", True, 2005, 2017, "Utah Jazz",
        ["Utah Jazz", "Brooklyn Nets", "Dallas Mavericks", "Cleveland Cavaliers"],
        "solid", 846, 28584, "PG", "6-3", ["8"],
        "3-time All-Star — once considered the best PG alongside CP3",
        college="Illinois", draft_year=2005, draft_round=1, draft_pick=3,
        all_star_count=3),
    P(203952, "Andrew Wiggins", False, 2014, None, "Minnesota Timberwolves",
        ["Minnesota Timberwolves", "Golden State Warriors"],
        "solid", 700, 23540, "SF", "6-7", ["22"],
        "First overall pick turned championship starter",
        college="Kansas", country="Canada", draft_year=2014, draft_round=1, draft_pick=1,
        championships=1, all_star_count=1, roy=True),
    P(200755, "Kemba Walker", True, 2011, 2023, "Charlotte Bobcats",
        ["Charlotte Bobcats", "Charlotte Hornets", "Boston Celtics", "New York Knicks", "Dallas Mavericks"],
        "solid", 684, 22530, "PG", "6-0", ["15"],
        college="UConn", draft_year=2011, draft_round=1, draft_pick=9,
        all_star_count=4),
    P(203468, "Victor Wembanyama", False, 2023, None, "San Antonio Spurs",
        ["San Antonio Spurs"],
        "superstar", 140, 4760, "C", "7-4", ["1"],
        "2024 Rookie of the Year at 7'4\" — generational two-way talent",
        college=None, country="France", draft_year=2023, draft_round=1, draft_pick=1,
        dpoy_count=1, roy=True, signature_shoe_brand="Nike"),
    P(201566, "John Wall", False, 2010, None, "Washington Wizards",
        ["Washington Wizards", "Houston Rockets", "Los Angeles Clippers"],
        "solid", 613, 20600, "PG", "6-3", ["2"],
        college="Kentucky", draft_year=2010, draft_round=1, draft_pick=1,
        all_star_count=5, signature_shoe_brand="Adidas"),
    P(203933, "T.J. Warren", False, 2014, None, "Phoenix Suns",
        ["Phoenix Suns", "Indiana Pacers", "Brooklyn Nets", "Minnesota Timberwolves"],
        "deep_cut", 380, 10920, "SF", "6-8", ["12"],
        college="NC State", draft_year=2014, draft_round=1, draft_pick=14),
    P(1629636, "P.J. Washington", False, 2019, None, "Charlotte Hornets",
        ["Charlotte Hornets", "Dallas Mavericks"],
        "deep_cut", 360, 10260, "PF", "6-7", ["25"],
        college="Kentucky", draft_year=2019, draft_round=1, draft_pick=12),

    # ════════════════════════════════════════════════
    # Y
    # ════════════════════════════════════════════════
    P(2397, "Yao Ming", True, 2002, 2011, "Houston Rockets",
        ["Houston Rockets"],
        "superstar", 486, 15829, "C", "7-6", ["11"],
        "First international player selected #1 overall — changed NBA's global reach",
        college=None, country="China", draft_year=2002, draft_round=1, draft_pick=1,
        all_star_count=8, hall_of_fame=True),

    # ════════════════════════════════════════════════
    # Z
    # ════════════════════════════════════════════════
    P(1627826, "Ivica Zubac", False, 2016, None, "Los Angeles Lakers",
        ["Los Angeles Lakers", "Los Angeles Clippers"],
        "deep_cut", 520, 12340, "C", "7-0", ["40"],
        college=None, country="Croatia", draft_year=2016, draft_round=2, draft_pick=32),
    P(203469, "Cody Zeller", True, 2013, 2023, "Charlotte Bobcats",
        ["Charlotte Bobcats", "Charlotte Hornets", "Portland Trail Blazers", "New Orleans Pelicans"],
        "deep_cut", 471, 11340, "C", "6-11", ["40"],
        college="Indiana", draft_year=2013, draft_round=1, draft_pick=4),

    # ════════════════════════════════════════════════
    # ADDITIONAL PLAYERS (more I-Z depth)
    # ════════════════════════════════════════════════
    P(203952, "Anthony Edwards", False, 2020, None, "Minnesota Timberwolves",
        ["Minnesota Timberwolves"],
        "superstar", 310, 11340, "SG", "6-4", ["5"],
        "One of the most electric young scorers — Ant-Man led Minnesota to the WCF",
        college="Georgia", draft_year=2020, draft_round=1, draft_pick=1,
        all_star_count=3, signature_shoe_brand="Adidas"),
    P(1630169, "Chet Holmgren", False, 2023, None, "Oklahoma City Thunder",
        ["Oklahoma City Thunder"],
        "solid", 120, 3640, "C", "7-1", ["7"],
        "2024 Rookie of the Year runner-up",
        college="Gonzaga", draft_year=2022, draft_round=1, draft_pick=2),
    P(203078, "Bradley Beal", False, 2012, None, "Washington Wizards",
        ["Washington Wizards", "Phoenix Suns"],
        "superstar", 700, 24260, "SG", "6-4", ["3"],
        "Scored 60 points vs the Sixers — franchise record",
        college="Florida", draft_year=2012, draft_round=1, draft_pick=3,
        all_star_count=3),
    P(202331, "Reggie Jackson", False, 2011, None, "Oklahoma City Thunder",
        ["Oklahoma City Thunder", "Detroit Pistons", "Los Angeles Clippers", "Denver Nuggets", "Philadelphia 76ers"],
        "deep_cut", 770, 20840, "PG", "6-3", ["1"],
        college="Boston College", draft_year=2011, draft_round=1, draft_pick=24),
    P(101143, "Al Horford", False, 2007, None, "Atlanta Hawks",
        ["Atlanta Hawks", "Boston Celtics", "Philadelphia 76ers", "Oklahoma City Thunder"],
        "solid", 1140, 33720, "C", "6-9", ["42"],
        "One of the most versatile big men of his era",
        college="Florida", country="Dominican Republic", draft_year=2007, draft_round=1, draft_pick=3,
        championships=1, all_star_count=5),
    P(1627745, "Malcolm Brogdon", False, 2016, None, "Milwaukee Bucks",
        ["Milwaukee Bucks", "Indiana Pacers", "Boston Celtics", "Portland Trail Blazers", "Washington Wizards"],
        "solid", 485, 14880, "PG", "6-5", ["13"],
        "2017 Rookie of the Year",
        college="Virginia", draft_year=2016, draft_round=2, draft_pick=36,
        championships=1, roy=True),
    P(1629651, "Immanuel Quickley", False, 2020, None, "New York Knicks",
        ["New York Knicks", "Toronto Raptors"],
        "deep_cut", 280, 7040, "PG", "6-3", ["5"],
        college="Kentucky", draft_year=2020, draft_round=1, draft_pick=25),
    P(203077, "Dario Saric", False, 2016, None, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Minnesota Timberwolves", "Phoenix Suns", "Golden State Warriors", "Denver Nuggets"],
        "deep_cut", 380, 8950, "PF", "6-10", ["9"],
        college=None, country="Croatia", draft_year=2014, draft_round=1, draft_pick=12),
    P(203085, "Evan Turner", True, 2010, 2020, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Indiana Pacers", "Boston Celtics", "Portland Trail Blazers", "Atlanta Hawks", "Minnesota Timberwolves"],
        "deep_cut", 646, 16150, "SF", "6-7", ["12"],
        college="Ohio State", draft_year=2010, draft_round=1, draft_pick=2),
    P(1628973, "Miles Bridges", False, 2018, None, "Charlotte Hornets",
        ["Charlotte Hornets"],
        "deep_cut", 290, 8920, "PF", "6-6", ["0"],
        college="Michigan State", draft_year=2018, draft_round=1, draft_pick=12),
    P(1630559, "Scottie Barnes", False, 2021, None, "Toronto Raptors",
        ["Toronto Raptors"],
        "solid", 235, 7980, "PF", "6-7", ["4"],
        "2022 Rookie of the Year",
        college="Florida State", draft_year=2021, draft_round=1, draft_pick=4,
        all_star_count=1, roy=True),
    P(1630162, "Tyrese Maxey", False, 2020, None, "Philadelphia 76ers",
        ["Philadelphia 76ers"],
        "solid", 310, 9580, "PG", "6-2", ["0"],
        "2024 Most Improved Player",
        college="Kentucky", draft_year=2020, draft_round=1, draft_pick=21,
        all_star_count=1, mip_count=1),
    P(1630178, "Tyrese Haliburton", False, 2020, None, "Sacramento Kings",
        ["Sacramento Kings", "Indiana Pacers"],
        "solid", 295, 9440, "PG", "6-5", ["0"],
        college="Iowa State", draft_year=2020, draft_round=1, draft_pick=12,
        all_star_count=2),
    P(1630224, "Jalen Green", False, 2021, None, "Houston Rockets",
        ["Houston Rockets"],
        "solid", 240, 7680, "SG", "6-4", ["4"],
        college=None, draft_year=2021, draft_round=1, draft_pick=2),
    P(1630228, "Evan Mobley", False, 2021, None, "Cleveland Cavaliers",
        ["Cleveland Cavaliers"],
        "solid", 260, 8220, "C", "7-0", ["4"],
        college="USC", draft_year=2021, draft_round=1, draft_pick=3,
        all_star_count=1),
    P(203944, "Mikal Bridges", False, 2018, None, "Phoenix Suns",
        ["Phoenix Suns", "Brooklyn Nets", "New York Knicks"],
        "solid", 430, 14400, "SF", "6-6", ["1"],
        college="Villanova", draft_year=2018, draft_round=1, draft_pick=10),
    P(1630595, "Jabari Smith Jr.", False, 2022, None, "Houston Rockets",
        ["Houston Rockets"],
        "solid", 170, 5240, "PF", "6-10", ["10"],
        college="Auburn", draft_year=2022, draft_round=1, draft_pick=3),
    P(1629628, "Cam Reddish", False, 2019, None, "Atlanta Hawks",
        ["Atlanta Hawks", "New York Knicks", "Portland Trail Blazers", "Los Angeles Lakers"],
        "deep_cut", 264, 5890, "SF", "6-8", ["22"],
        college="Duke", draft_year=2019, draft_round=1, draft_pick=10),
    P(1629651, "Kendrick Nunn", False, 2019, None, "Miami Heat",
        ["Miami Heat", "Los Angeles Lakers", "Washington Wizards", "Cleveland Cavaliers"],
        "deep_cut", 240, 5860, "PG", "6-2", ["25"],
        college="Oakland", draft_year=None, draft_round=None, draft_pick=None,
        championships=1),
]
# fmt: on


def deduplicate(players):
    seen = set()
    unique = []
    for p in players:
        if p["id"] not in seen:
            seen.add(p["id"])
            unique.append(p)
    return unique


def sql_val(v):
    if v is None: return "NULL"
    if isinstance(v, bool): return str(v).lower()
    if isinstance(v, (int, float)): return str(v)
    return "'" + str(v).replace("'", "''") + "'"


def main():
    players = deduplicate(PLAYERS)
    tiers = {}
    for p in players:
        tiers[p["tier"]] = tiers.get(p["tier"], 0) + 1

    print(f"Generated {len(players)} I–Z players:")
    for tier, count in sorted(tiers.items()):
        print(f"  {tier}: {count}")

    awards = sum(1 for p in players if p["allStarCount"] > 0)
    intl = sum(1 for p in players if p["country"] != "USA")
    hof = sum(1 for p in players if p["hallOfFame"])
    print(f"  with awards: {awards}, international: {intl}, hall of fame: {hof}")

    output = Path(OUTPUT_PATH)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(players, indent=2))
    print(f"\nWrote JSON to {output}")

    sql_path = output.with_name("nba_game_players_i_z_inserts.sql")
    with open(sql_path, "w") as f:
        f.write("-- I–Z player upsert with Connections enrichment fields\n")
        f.write("-- Run in Supabase SQL Editor\n\n")
        for p in players:
            teams_pg = "ARRAY[" + ",".join(f"'{t}'" for t in p["teams"]) + "]"
            jerseys_pg = "ARRAY[" + ",".join(f"'{j}'" for j in p["jerseys"]) + "]" if p["jerseys"] else "'{}'"

            f.write(f"""INSERT INTO nba_game_players (id, name, retired, years_active, from_year, to_year, draft_team, teams, position, height, jerseys, tier, career_games, career_minutes, fun_fact, headshot_url, college, country, draft_year, draft_round, draft_pick, championships, all_star_count, mvp_count, finals_mvp_count, dpoy_count, roy, sixmoy_count, mip_count, hall_of_fame, signature_shoe_brand)
VALUES ({p['id']}, {sql_val(p['name'])}, {sql_val(p['retired'])}, {sql_val(p['yearsActive'])}, {p['fromYear']}, {sql_val(p['toYear'])}, {sql_val(p.get('draftTeam'))}, {teams_pg}, {sql_val(p['position'])}, {sql_val(p['height'])}, {jerseys_pg}, {sql_val(p['tier'])}, {p['careerGames']}, {p['careerMinutes']}, {sql_val(p.get('funFact'))}, {sql_val(p['headshotUrl'])}, {sql_val(p['college'])}, {sql_val(p['country'])}, {sql_val(p['draftYear'])}, {sql_val(p['draftRound'])}, {sql_val(p['draftPick'])}, {p['championships']}, {p['allStarCount']}, {p['mvpCount']}, {p['finalsMvpCount']}, {p['dpoyCount']}, {sql_val(p['roy'])}, {p['sixmoyCount']}, {p['mipCount']}, {sql_val(p['hallOfFame'])}, {sql_val(p['signatureShoeBrand'])})
ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, retired=EXCLUDED.retired, years_active=EXCLUDED.years_active, teams=EXCLUDED.teams, tier=EXCLUDED.tier, career_games=EXCLUDED.career_games, career_minutes=EXCLUDED.career_minutes, fun_fact=EXCLUDED.fun_fact, headshot_url=EXCLUDED.headshot_url, position=EXCLUDED.position, height=EXCLUDED.height, jerseys=EXCLUDED.jerseys, college=EXCLUDED.college, country=EXCLUDED.country, draft_year=EXCLUDED.draft_year, draft_round=EXCLUDED.draft_round, draft_pick=EXCLUDED.draft_pick, championships=EXCLUDED.championships, all_star_count=EXCLUDED.all_star_count, mvp_count=EXCLUDED.mvp_count, finals_mvp_count=EXCLUDED.finals_mvp_count, dpoy_count=EXCLUDED.dpoy_count, roy=EXCLUDED.roy, sixmoy_count=EXCLUDED.sixmoy_count, mip_count=EXCLUDED.mip_count, hall_of_fame=EXCLUDED.hall_of_fame, signature_shoe_brand=EXCLUDED.signature_shoe_brand;\n\n""")

    print(f"Wrote SQL upsert to {sql_path}")


if __name__ == "__main__":
    main()
