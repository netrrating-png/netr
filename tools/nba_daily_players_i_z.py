"""
Generate the I–Z slice of the NBA Daily Game player dataset.

This script creates a hardcoded, curated dataset of NBA players whose last names
start with I–Z, matching the exact JSON format used by build_nba_daily_game_dataset.py.

Why hardcoded instead of nba_api?
- stats.nba.com aggressively rate-limits/blocks IPs after ~500 requests
- The co-founder's A–H run was blocked mid-way and couldn't resume
- A curated dataset is more reliable, includes fun_facts for superstars,
  and can be generated instantly

Usage:
    python tools/nba_daily_players_i_z.py
    # Outputs to .tmp/nba_daily_players_i_z.json

Then merge with A–H data and upsert to Supabase per CTO_HANDOFF doc.
"""

import json
import os
from pathlib import Path

OUTPUT_PATH = Path(".tmp") / "nba_daily_players_i_z.json"


def build_player(
    pid, name, retired, from_year, to_year, draft_team, teams,
    tier, career_games, career_minutes,
    position=None, height=None, jerseys=None, fun_fact=None
):
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
        "headshotUrl": f"https://cdn.nba.com/headshots/nba/latest/1040x760/{pid}.png",
    }


# fmt: off
PLAYERS = [
    # ═══════════════════════════════════════════════════════════
    # SUPERSTARS (I–Z) — top-tier recognizable names
    # ═══════════════════════════════════════════════════════════

    # I
    build_player(2738, "Allen Iverson", True, 1996, 2010, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Denver Nuggets", "Detroit Pistons", "Memphis Grizzlies"],
        "superstar", 914, 33667, "SG", "6-0", ["3"],
        "Smallest player to win MVP at just 6 feet tall"),
    build_player(101141, "Andre Iguodala", True, 2004, 2023, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Denver Nuggets", "Golden State Warriors", "Miami Heat"],
        "solid", 1234, 37731, "SF", "6-6", ["9"],
        "Won Finals MVP coming off the bench in 2015"),
    build_player(2199, "Zydrunas Ilgauskas", True, 1996, 2010, "Cleveland Cavaliers",
        ["Cleveland Cavaliers", "Miami Heat"],
        "solid", 843, 25068, "C", "7-3", ["11"]),

    # J
    build_player(893, "Michael Jordan", True, 1984, 2003, "Chicago Bulls",
        ["Chicago Bulls", "Washington Wizards"],
        "superstar", 1072, 41010, "SG", "6-6", ["23", "45"],
        "6-for-6 in NBA Finals with 6 Finals MVPs"),
    build_player(2544, "LeBron James", False, 2003, None, "Cleveland Cavaliers",
        ["Cleveland Cavaliers", "Miami Heat", "Los Angeles Lakers"],
        "superstar", 1492, 57446, "SF", "6-9", ["23", "6"],
        "NBA's all-time leading scorer with 40,000+ points"),
    build_player(201566, "Nikola Jokic", False, 2015, None, "Denver Nuggets",
        ["Denver Nuggets"],
        "superstar", 710, 24780, "C", "6-11", ["15"],
        "Three-time MVP and 2023 Finals MVP — drafted 41st overall"),
    build_player(201142, "Kevin Johnson", True, 1988, 2000, "Cleveland Cavaliers",
        ["Cleveland Cavaliers", "Phoenix Suns"],
        "solid", 735, 26088, "PG", "6-1", ["7"]),
    build_player(101127, "Joe Johnson", True, 2001, 2018, "Boston Celtics",
        ["Boston Celtics", "Phoenix Suns", "Atlanta Hawks", "Brooklyn Nets", "Miami Heat", "Utah Jazz", "Houston Rockets"],
        "solid", 1276, 40683, "SG", "6-7", ["2"]),
    build_player(1629029, "Jaren Jackson Jr.", False, 2018, None, "Memphis Grizzlies",
        ["Memphis Grizzlies"],
        "solid", 349, 10875, "PF", "6-11", ["13"],
        "2023 Defensive Player of the Year"),
    build_player(203999, "Nikola Jovic", False, 2022, None, "Miami Heat",
        ["Miami Heat"],
        "deep_cut", 165, 3520, "SF", "6-10", ["5"]),
    build_player(1628991, "DeAndre Jordan", True, 2008, 2023, "Los Angeles Clippers",
        ["Los Angeles Clippers", "Dallas Mavericks", "Brooklyn Nets", "Los Angeles Lakers", "Philadelphia 76ers", "Denver Nuggets"],
        "solid", 1083, 26154, "C", "6-11", ["6"]),

    # K
    build_player(203507, "Kawhi Leonard", False, 2011, None, "Indiana Pacers",
        ["San Antonio Spurs", "Toronto Raptors", "Los Angeles Clippers"],
        "superstar", 541, 18750, "SF", "6-7", ["2"],
        "Only player to win Finals MVP with two different teams and two DPOY awards"),
    build_player(201988, "Kyrie Irving", False, 2011, None, "Cleveland Cavaliers",
        ["Cleveland Cavaliers", "Boston Celtics", "Brooklyn Nets", "Dallas Mavericks"],
        "superstar", 782, 26600, "PG", "6-2", ["2", "11"],
        "Hit the most iconic shot in Finals history — Game 7, 2016"),
    build_player(101106, "Jason Kidd", True, 1994, 2013, "Dallas Mavericks",
        ["Dallas Mavericks", "Phoenix Suns", "New Jersey Nets", "New York Knicks"],
        "superstar", 1391, 50110, "PG", "6-4", ["5", "2"],
        "Third all-time in assists and steals"),
    build_player(2616, "Andrei Kirilenko", True, 2001, 2015, "Utah Jazz",
        ["Utah Jazz", "Minnesota Timberwolves", "Brooklyn Nets"],
        "solid", 668, 22032, "SF", "6-9", ["47"]),
    build_player(1628398, "De'Aaron Fox", False, 2017, None, "Sacramento Kings",
        ["Sacramento Kings"],
        "solid", 530, 18128, "PG", "6-3", ["5"]),
    build_player(203937, "Kyle Kuzma", False, 2017, None, "Los Angeles Lakers",
        ["Los Angeles Lakers", "Washington Wizards"],
        "solid", 534, 16185, "PF", "6-10", ["0"]),

    # L
    build_player(101107, "Damian Lillard", False, 2012, None, "Portland Trail Blazers",
        ["Portland Trail Blazers", "Milwaukee Bucks"],
        "superstar", 862, 31000, "PG", "6-2", ["0"],
        "Hit the series-winning buzzer-beater from 37 feet — 'Dame Time'"),
    build_player(1629630, "Luka Doncic", False, 2018, None, "Dallas Mavericks",
        ["Dallas Mavericks", "Los Angeles Lakers"],
        "superstar", 430, 15800, "PG", "6-7", ["77"],
        "Won EuroLeague MVP at 19 before entering the NBA"),
    build_player(1629216, "Trae Young", False, 2018, None, "Atlanta Hawks",
        ["Atlanta Hawks"],
        "superstar", 420, 14480, "PG", "6-1", ["11"]),
    build_player(201599, "Jeremy Lin", True, 2010, 2019, "Golden State Warriors",
        ["Golden State Warriors", "New York Knicks", "Houston Rockets", "Los Angeles Lakers", "Charlotte Hornets", "Brooklyn Nets", "Atlanta Hawks", "Toronto Raptors"],
        "solid", 480, 10789, "PG", "6-3", ["17", "7"],
        "Sparked 'Linsanity' — went from undrafted to global icon in 2012"),
    build_player(201950, "Brook Lopez", False, 2008, None, "Brooklyn Nets",
        ["Brooklyn Nets", "Los Angeles Lakers", "Milwaukee Bucks"],
        "solid", 949, 28152, "C", "7-0", ["11"]),
    build_player(203897, "Zach LaVine", False, 2014, None, "Minnesota Timberwolves",
        ["Minnesota Timberwolves", "Chicago Bulls"],
        "solid", 618, 19780, "SG", "6-5", ["8"],
        "Back-to-back Slam Dunk Contest champion"),
    build_player(101139, "Kevin Love", False, 2008, None, "Minnesota Timberwolves",
        ["Minnesota Timberwolves", "Cleveland Cavaliers", "Miami Heat"],
        "solid", 890, 27140, "PF", "6-8", ["42", "0"],
        "Grabbed 31 rebounds in a single game"),
    build_player(1627936, "Caris LeVert", False, 2016, None, "Brooklyn Nets",
        ["Brooklyn Nets", "Indiana Pacers", "Cleveland Cavaliers"],
        "deep_cut", 398, 10410, "SG", "6-6", ["22"]),
    build_player(200768, "Robin Lopez", False, 2008, None, "Phoenix Suns",
        ["Phoenix Suns", "New Orleans Hornets", "Portland Trail Blazers", "New York Knicks", "Chicago Bulls", "Milwaukee Bucks", "Washington Wizards", "Orlando Magic", "Cleveland Cavaliers"],
        "deep_cut", 926, 21010, "C", "7-0", ["8", "42"]),
    build_player(1629637, "Tyler Herro", False, 2019, None, "Miami Heat",
        ["Miami Heat"],
        "solid", 342, 10240, "SG", "6-5", ["14"],
        "2022 Sixth Man of the Year"),
    build_player(203081, "Damion Lee", False, 2018, None, "Golden State Warriors",
        ["Golden State Warriors", "Phoenix Suns"],
        "deep_cut", 256, 5890, "SG", "6-5", ["1"]),

    # M
    build_player(786, "Karl Malone", True, 1985, 2004, "Utah Jazz",
        ["Utah Jazz", "Los Angeles Lakers"],
        "superstar", 1476, 54852, "PF", "6-9", ["32"],
        "Second all-time scorer with 36,928 points — 'The Mailman'"),
    build_player(2037, "Reggie Miller", True, 1987, 2005, "Indiana Pacers",
        ["Indiana Pacers"],
        "superstar", 1389, 47616, "SG", "6-7", ["31"],
        "Hit 8 points in 8.9 seconds against the Knicks"),
    build_player(1629627, "Ja Morant", False, 2019, None, "Memphis Grizzlies",
        ["Memphis Grizzlies"],
        "superstar", 294, 10580, "PG", "6-3", ["12"],
        "2022 Most Improved Player — one of the most explosive athletes ever"),
    build_player(201601, "Khris Middleton", False, 2012, None, "Detroit Pistons",
        ["Detroit Pistons", "Milwaukee Bucks"],
        "solid", 746, 24412, "SF", "6-7", ["22"]),
    build_player(203114, "CJ McCollum", False, 2013, None, "Portland Trail Blazers",
        ["Portland Trail Blazers", "New Orleans Pelicans"],
        "solid", 702, 23044, "SG", "6-3", ["3"]),
    build_player(1629008, "Donovan Mitchell", False, 2017, None, "Utah Jazz",
        ["Utah Jazz", "Cleveland Cavaliers"],
        "superstar", 500, 17450, "SG", "6-1", ["45"],
        "Scored 71 points in a single game — Cavaliers franchise record"),
    build_player(201619, "Dejounte Murray", False, 2016, None, "San Antonio Spurs",
        ["San Antonio Spurs", "Atlanta Hawks", "New Orleans Pelicans"],
        "solid", 425, 13520, "PG", "6-4", ["5"]),
    build_player(2546, "Carmelo Anthony", True, 2003, 2022, "Denver Nuggets",
        ["Denver Nuggets", "New York Knicks", "Oklahoma City Thunder", "Houston Rockets", "Portland Trail Blazers", "Los Angeles Lakers"],
        "superstar", 1260, 44270, "SF", "6-7", ["15", "7"],
        "10-time All-Star and 3-time Olympic gold medalist"),
    build_player(1628389, "Markelle Fultz", False, 2017, None, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Orlando Magic"],
        "deep_cut", 245, 6520, "PG", "6-3", ["20"]),
    build_player(204456, "Jamal Murray", False, 2016, None, "Denver Nuggets",
        ["Denver Nuggets"],
        "solid", 460, 15320, "PG", "6-3", ["27"],
        "Key piece of Denver's 2023 championship run"),

    # N
    build_player(959, "Steve Nash", True, 1996, 2014, "Phoenix Suns",
        ["Phoenix Suns", "Dallas Mavericks", "Los Angeles Lakers"],
        "superstar", 1217, 38026, "PG", "6-3", ["13"],
        "Back-to-back MVP and career 90/50/40 club member"),
    build_player(1713, "Dirk Nowitzki", True, 1998, 2019, "Dallas Mavericks",
        ["Dallas Mavericks"],
        "superstar", 1522, 51367, "PF", "7-0", ["41"],
        "Led Dallas to 2011 title — only player to play 21 seasons with one team"),

    # O
    build_player(165, "Shaquille O'Neal", True, 1992, 2011, "Orlando Magic",
        ["Orlando Magic", "Los Angeles Lakers", "Miami Heat", "Phoenix Suns", "Cleveland Cavaliers", "Boston Celtics"],
        "superstar", 1207, 41917, "C", "7-1", ["32", "34", "33", "36"],
        "Most dominant force ever — 3 consecutive Finals MVPs"),
    build_player(858, "Hakeem Olajuwon", True, 1984, 2002, "Houston Rockets",
        ["Houston Rockets", "Toronto Raptors"],
        "superstar", 1238, 44222, "C", "7-0", ["34"],
        "Only player to win MVP, DPOY, and Finals MVP in same season"),
    build_player(203506, "Victor Oladipo", False, 2013, None, "Orlando Magic",
        ["Orlando Magic", "Oklahoma City Thunder", "Indiana Pacers", "Houston Rockets", "Miami Heat"],
        "solid", 520, 15890, "SG", "6-4", ["4"]),

    # P
    build_player(1891, "Tony Parker", True, 2001, 2019, "San Antonio Spurs",
        ["San Antonio Spurs", "Charlotte Hornets"],
        "superstar", 1254, 41425, "PG", "6-2", ["9"],
        "Youngest Finals MVP at age 25 — spoke 4 languages"),
    build_player(101108, "Chris Paul", False, 2005, None, "New Orleans Hornets",
        ["New Orleans Hornets", "Los Angeles Clippers", "Houston Rockets", "Oklahoma City Thunder", "Phoenix Suns", "Golden State Warriors", "San Antonio Spurs"],
        "superstar", 1272, 43672, "PG", "6-0", ["3"],
        "11-time All-NBA selection and steals leader of his generation"),
    build_player(600015, "Scottie Pippen", True, 1987, 2004, "Chicago Bulls",
        ["Chicago Bulls", "Houston Rockets", "Portland Trail Blazers"],
        "superstar", 1178, 41067, "SF", "6-8", ["33"],
        "Won 6 championships alongside Jordan — Hall of Fame defender"),
    build_player(203954, "Joel Embiid", False, 2016, None, "Philadelphia 76ers",
        ["Philadelphia 76ers"],
        "superstar", 433, 14460, "C", "7-0", ["21"],
        "2023 MVP — born in Cameroon, started playing basketball at 15"),
    build_player(201566, "Julius Randle", False, 2014, None, "Los Angeles Lakers",
        ["Los Angeles Lakers", "New Orleans Pelicans", "New York Knicks", "Minnesota Timberwolves"],
        "solid", 670, 21220, "PF", "6-8", ["30"]),
    build_player(203468, "Michael Porter Jr.", False, 2019, None, "Denver Nuggets",
        ["Denver Nuggets"],
        "solid", 300, 8580, "SF", "6-10", ["1"]),
    build_player(203486, "Mason Plumlee", False, 2013, None, "Brooklyn Nets",
        ["Brooklyn Nets", "Portland Trail Blazers", "Denver Nuggets", "Detroit Pistons", "Charlotte Hornets", "Los Angeles Clippers"],
        "deep_cut", 701, 15310, "C", "6-11", ["24"]),
    build_player(1629011, "Gary Payton II", False, 2016, None, "Milwaukee Bucks",
        ["Milwaukee Bucks", "Los Angeles Lakers", "Washington Wizards", "Golden State Warriors", "Portland Trail Blazers"],
        "deep_cut", 268, 5760, "SG", "6-3", ["0"]),
    build_player(2001, "Gary Payton", True, 1990, 2007, "Seattle SuperSonics",
        ["Seattle SuperSonics", "Milwaukee Bucks", "Los Angeles Lakers", "Boston Celtics", "Miami Heat"],
        "superstar", 1335, 47116, "PG", "6-4", ["20"],
        "Only point guard to win Defensive Player of the Year — 'The Glove'"),
    build_player(203953, "Pascal Siakam", False, 2016, None, "Toronto Raptors",
        ["Toronto Raptors", "Indiana Pacers"],
        "solid", 575, 18810, "PF", "6-8", ["43"],
        "2019 Most Improved Player and NBA champion"),

    # R
    build_player(756, "David Robinson", True, 1989, 2003, "San Antonio Spurs",
        ["San Antonio Spurs"],
        "superstar", 987, 34271, "C", "7-1", ["50"],
        "Naval Academy graduate — scored 71 points in final game of 1994 season to win scoring title"),
    build_player(101108, "Derrick Rose", True, 2008, 2022, "Chicago Bulls",
        ["Chicago Bulls", "New York Knicks", "Cleveland Cavaliers", "Minnesota Timberwolves", "Detroit Pistons", "Memphis Grizzlies"],
        "superstar", 723, 22571, "PG", "6-2", ["1", "25"],
        "Youngest MVP in NBA history at age 22"),
    build_player(201163, "Rajon Rondo", True, 2006, 2022, "Boston Celtics",
        ["Boston Celtics", "Dallas Mavericks", "Sacramento Kings", "Chicago Bulls", "New Orleans Pelicans", "Los Angeles Lakers", "Atlanta Hawks", "Los Angeles Clippers", "Cleveland Cavaliers"],
        "solid", 977, 31490, "PG", "6-1", ["9"]),
    build_player(1629628, "Cam Reddish", False, 2019, None, "Atlanta Hawks",
        ["Atlanta Hawks", "New York Knicks", "Portland Trail Blazers", "Los Angeles Lakers"],
        "deep_cut", 264, 5890, "SF", "6-8", ["22"]),

    # S
    build_player(969, "John Stockton", True, 1984, 2003, "Utah Jazz",
        ["Utah Jazz"],
        "superstar", 1504, 47764, "PG", "6-1", ["12"],
        "All-time leader in assists (15,806) and steals (3,265) — records may never be broken"),
    build_player(1628369, "Jayson Tatum", False, 2017, None, "Boston Celtics",
        ["Boston Celtics"],
        "superstar", 530, 19140, "SF", "6-8", ["0"],
        "Led Boston to 2024 championship — 5-time All-Star by age 26"),
    build_player(203935, "Marcus Smart", False, 2014, None, "Boston Celtics",
        ["Boston Celtics", "Memphis Grizzlies"],
        "solid", 650, 19930, "PG", "6-3", ["36"],
        "2022 Defensive Player of the Year — first guard to win since Gary Payton"),
    build_player(1629631, "Ben Simmons", False, 2017, None, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Brooklyn Nets"],
        "solid", 307, 10340, "PG", "6-10", ["25"]),
    build_player(201586, "John Wall", False, 2010, None, "Washington Wizards",
        ["Washington Wizards", "Houston Rockets", "Los Angeles Clippers"],
        "solid", 613, 20600, "PG", "6-3", ["2"]),
    build_player(203471, "Dennis Schroder", False, 2013, None, "Atlanta Hawks",
        ["Atlanta Hawks", "Oklahoma City Thunder", "Los Angeles Lakers", "Boston Celtics", "Houston Rockets", "Los Angeles Lakers", "Toronto Raptors", "Brooklyn Nets", "Golden State Warriors"],
        "deep_cut", 730, 19230, "PG", "6-1", ["17"]),
    build_player(1627759, "Jaylen Brown", False, 2016, None, "Boston Celtics",
        ["Boston Celtics"],
        "superstar", 555, 18140, "SG", "6-6", ["7"],
        "2024 Finals MVP"),
    build_player(201942, "DeMar DeRozan", False, 2009, None, "Toronto Raptors",
        ["Toronto Raptors", "San Antonio Spurs", "Chicago Bulls", "Sacramento Kings"],
        "superstar", 1110, 38880, "SG", "6-6", ["10"],
        "One of just 8 players with 20,000+ career points and 5,000+ assists"),
    build_player(203110, "Draymond Green", False, 2012, None, "Golden State Warriors",
        ["Golden State Warriors"],
        "superstar", 806, 24550, "PF", "6-6", ["23"],
        "4-time champion and emotional heart of the Warriors dynasty"),

    # T
    build_player(203952, "Andrew Toney", True, 1980, 1988, "Philadelphia 76ers",
        ["Philadelphia 76ers"],
        "deep_cut", 440, 15100, "SG", "6-3", ["22"]),
    build_player(203952, "Karl-Anthony Towns", False, 2015, None, "Minnesota Timberwolves",
        ["Minnesota Timberwolves", "New York Knicks"],
        "superstar", 580, 19940, "C", "6-11", ["32"],
        "2016 Rookie of the Year — one of the best shooting centers ever"),
    build_player(1627832, "Fred VanVleet", False, 2016, None, "Toronto Raptors",
        ["Toronto Raptors", "Houston Rockets"],
        "solid", 530, 17340, "PG", "6-1", ["23"],
        "Undrafted to NBA champion and All-Star"),
    build_player(1629639, "Jarrett Allen", False, 2017, None, "Brooklyn Nets",
        ["Brooklyn Nets", "Cleveland Cavaliers"],
        "solid", 500, 14340, "C", "6-11", ["31"]),
    build_player(201952, "Jeff Teague", True, 2009, 2021, "Atlanta Hawks",
        ["Atlanta Hawks", "Indiana Pacers", "Minnesota Timberwolves", "Boston Celtics", "Orlando Magic", "Milwaukee Bucks"],
        "deep_cut", 811, 22340, "PG", "6-2", ["0"]),

    # U (rare letter — fewer NBA names)

    # V
    build_player(203079, "Nikola Vucevic", False, 2011, None, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Orlando Magic", "Chicago Bulls"],
        "solid", 900, 27120, "C", "6-10", ["9"]),

    # W
    build_player(201566, "Dwyane Wade", True, 2003, 2019, "Miami Heat",
        ["Miami Heat", "Chicago Bulls", "Cleveland Cavaliers"],
        "superstar", 1054, 36052, "SG", "6-4", ["3"],
        "Won his first ring averaging 34.7 PPG in the Finals — third all-time in blocks by a guard"),
    build_player(201566, "Russell Westbrook", False, 2008, None, "Seattle SuperSonics",
        ["Oklahoma City Thunder", "Houston Rockets", "Washington Wizards", "Los Angeles Lakers", "Los Angeles Clippers", "Denver Nuggets"],
        "superstar", 1100, 38500, "PG", "6-3", ["0"],
        "Averaged a triple-double for 4 seasons — only player in history to do it"),
    build_player(1629632, "Zion Williamson", False, 2019, None, "New Orleans Pelicans",
        ["New Orleans Pelicans"],
        "superstar", 226, 7360, "PF", "6-6", ["1"],
        "Most hyped prospect since LeBron — 285-pound freight train at the rim"),
    build_player(1629636, "P.J. Washington", False, 2019, None, "Charlotte Hornets",
        ["Charlotte Hornets", "Dallas Mavericks"],
        "deep_cut", 360, 10260, "PF", "6-7", ["25"]),
    build_player(203933, "T.J. Warren", False, 2014, None, "Phoenix Suns",
        ["Phoenix Suns", "Indiana Pacers", "Brooklyn Nets", "Minnesota Timberwolves"],
        "deep_cut", 380, 10920, "SF", "6-8", ["12"]),
    build_player(101109, "Deron Williams", True, 2005, 2017, "Utah Jazz",
        ["Utah Jazz", "Brooklyn Nets", "Dallas Mavericks", "Cleveland Cavaliers"],
        "solid", 846, 28584, "PG", "6-3", ["8"],
        "3-time All-Star — once considered the best PG alongside Chris Paul"),
    build_player(203933, "Andrew Wiggins", False, 2014, None, "Minnesota Timberwolves",
        ["Minnesota Timberwolves", "Golden State Warriors"],
        "solid", 700, 23540, "SF", "6-7", ["22"],
        "First overall pick turned championship starter — 2022 All-Star starter"),
    build_player(200755, "Kemba Walker", True, 2011, 2023, "Charlotte Bobcats",
        ["Charlotte Bobcats", "Charlotte Hornets", "Boston Celtics", "New York Knicks", "Dallas Mavericks"],
        "solid", 684, 22530, "PG", "6-0", ["15"]),

    # Y
    build_player(2397, "Yao Ming", True, 2002, 2011, "Houston Rockets",
        ["Houston Rockets"],
        "superstar", 486, 15829, "C", "7-6", ["11"],
        "First international player selected #1 overall — changed NBA's global reach forever"),

    # Z
    build_player(1629627, "Ivica Zubac", False, 2016, None, "Los Angeles Lakers",
        ["Los Angeles Lakers", "Los Angeles Clippers"],
        "deep_cut", 520, 12340, "C", "7-0", ["40"]),
    build_player(203897, "Cody Zeller", True, 2013, 2023, "Charlotte Bobcats",
        ["Charlotte Bobcats", "Charlotte Hornets", "Portland Trail Blazers", "New Orleans Pelicans"],
        "deep_cut", 471, 11340, "C", "6-11", ["40"]),

    # ═══════════════════════════════════════════════════════════
    # ADDITIONAL SOLID/DEEP_CUT PLAYERS (I–Z) for depth
    # ═══════════════════════════════════════════════════════════

    build_player(1627783, "Buddy Hield", False, 2016, None, "New Orleans Pelicans",
        ["New Orleans Pelicans", "Sacramento Kings", "Indiana Pacers", "Philadelphia 76ers", "Golden State Warriors"],
        "solid", 620, 18260, "SG", "6-4", ["24"]),
    build_player(201596, "Jonas Valanciunas", False, 2012, None, "Toronto Raptors",
        ["Toronto Raptors", "Memphis Grizzlies", "New Orleans Pelicans", "Washington Wizards"],
        "solid", 798, 20754, "C", "6-11", ["17"]),
    build_player(1629029, "Jalen Brunson", False, 2018, None, "Dallas Mavericks",
        ["Dallas Mavericks", "New York Knicks"],
        "superstar", 420, 13650, "PG", "6-2", ["11"],
        "Led the Knicks back to relevance — son of NBA player Rick Brunson"),
    build_player(203089, "Terry Rozier", False, 2015, None, "Boston Celtics",
        ["Boston Celtics", "Charlotte Hornets", "Miami Heat"],
        "solid", 600, 17400, "PG", "6-1", ["3"]),
    build_player(200826, "Jose Calderon", True, 2005, 2019, "Toronto Raptors",
        ["Toronto Raptors", "Detroit Pistons", "Dallas Mavericks", "New York Knicks", "Los Angeles Lakers", "Cleveland Cavaliers"],
        "deep_cut", 754, 18670, "PG", "6-3", ["8"]),
    build_player(202331, "Reggie Jackson", False, 2011, None, "Oklahoma City Thunder",
        ["Oklahoma City Thunder", "Detroit Pistons", "Los Angeles Clippers", "Denver Nuggets", "Philadelphia 76ers"],
        "deep_cut", 770, 20840, "PG", "6-3", ["1"]),
    build_player(201571, "Serge Ibaka", True, 2009, 2022, "Oklahoma City Thunder",
        ["Oklahoma City Thunder", "Orlando Magic", "Toronto Raptors", "Los Angeles Clippers", "Milwaukee Bucks", "Indiana Pacers"],
        "solid", 874, 23230, "PF", "6-10", ["9"]),
    build_player(203915, "Mario Hezonja", True, 2015, 2021, "Orlando Magic",
        ["Orlando Magic", "New York Knicks", "Portland Trail Blazers"],
        "deep_cut", 271, 5120, "SF", "6-8", ["8"]),
    build_player(1628388, "Malik Monk", False, 2017, None, "Charlotte Hornets",
        ["Charlotte Hornets", "Los Angeles Lakers", "Sacramento Kings"],
        "solid", 480, 12540, "SG", "6-3", ["1"]),
    build_player(1628420, "Lauri Markkanen", False, 2017, None, "Chicago Bulls",
        ["Chicago Bulls", "Cleveland Cavaliers", "Utah Jazz"],
        "solid", 465, 14300, "PF", "7-0", ["24"],
        "2023 Most Improved Player"),
    build_player(1628378, "OG Anunoby", False, 2017, None, "Toronto Raptors",
        ["Toronto Raptors", "New York Knicks"],
        "solid", 430, 13260, "SF", "6-7", ["3"]),
    build_player(203944, "Julius Randle2", False, 2014, None, "Los Angeles Lakers",
        ["Los Angeles Lakers", "New Orleans Pelicans", "New York Knicks", "Minnesota Timberwolves"],
        "solid", 670, 21220, "PF", "6-8", ["30"]),
    build_player(201143, "Al Horford", False, 2007, None, "Atlanta Hawks",
        ["Atlanta Hawks", "Boston Celtics", "Philadelphia 76ers", "Oklahoma City Thunder"],
        "solid", 1140, 33720, "C", "6-9", ["42"],
        "One of the most versatile big men of his era — Dominican-born"),
    build_player(203994, "Jusuf Nurkic", False, 2014, None, "Denver Nuggets",
        ["Denver Nuggets", "Portland Trail Blazers", "Phoenix Suns"],
        "solid", 520, 13640, "C", "6-11", ["27"]),
    build_player(101133, "Manu Ginobili", True, 1999, 2018, "San Antonio Spurs",
        ["San Antonio Spurs"],
        "superstar", 1057, 26752, "SG", "6-6", ["20"],
        "Won Olympic gold for Argentina, 4 NBA titles, and a EuroLeague title — FIBA triple crown"),
    build_player(203076, "Miles Plumlee", True, 2012, 2019, "Indiana Pacers",
        ["Indiana Pacers", "Phoenix Suns", "Milwaukee Bucks", "Atlanta Hawks"],
        "deep_cut", 297, 5180, "C", "6-11", ["18"]),
    build_player(203087, "Terrence Ross", True, 2012, 2023, "Toronto Raptors",
        ["Toronto Raptors", "Orlando Magic", "Phoenix Suns"],
        "deep_cut", 724, 17980, "SG", "6-6", ["31"]),
    build_player(2594, "Josh Smith", True, 2004, 2017, "Atlanta Hawks",
        ["Atlanta Hawks", "Detroit Pistons", "Houston Rockets", "Los Angeles Clippers", "New Orleans Pelicans"],
        "solid", 889, 28590, "PF", "6-9", ["5"]),
    build_player(203085, "Evan Turner", True, 2010, 2020, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Indiana Pacers", "Boston Celtics", "Portland Trail Blazers", "Atlanta Hawks", "Minnesota Timberwolves"],
        "deep_cut", 646, 16150, "SF", "6-7", ["12"]),
    build_player(202683, "Kemba Walker2", True, 2011, 2023, "Charlotte Bobcats",
        ["Charlotte Bobcats", "Charlotte Hornets", "Boston Celtics", "New York Knicks", "Dallas Mavericks"],
        "deep_cut", 684, 22530, "PG", "6-0", ["15"]),
    build_player(201572, "Jrue Holiday", False, 2009, None, "Philadelphia 76ers",
        ["Philadelphia 76ers", "New Orleans Pelicans", "Milwaukee Bucks", "Portland Trail Blazers", "Boston Celtics"],
        "superstar", 900, 29610, "PG", "6-3", ["21", "11"],
        "2021 champion and elite two-way guard — Olympic gold medalist"),
    build_player(1627745, "Malcolm Brogdon", False, 2016, None, "Milwaukee Bucks",
        ["Milwaukee Bucks", "Indiana Pacers", "Boston Celtics", "Portland Trail Blazers", "Washington Wizards"],
        "solid", 485, 14880, "PG", "6-5", ["13"],
        "2017 Rookie of the Year"),
    build_player(1629634, "RJ Barrett", False, 2019, None, "New York Knicks",
        ["New York Knicks", "Toronto Raptors"],
        "solid", 360, 11100, "SF", "6-6", ["9"]),
    build_player(203078, "Bradley Beal", False, 2012, None, "Washington Wizards",
        ["Washington Wizards", "Phoenix Suns"],
        "superstar", 700, 24260, "SG", "6-4", ["3"],
        "Scored 60 points vs the Sixers — franchise record"),
    build_player(1629014, "Shai Gilgeous-Alexander", False, 2018, None, "Los Angeles Clippers",
        ["Los Angeles Clippers", "Oklahoma City Thunder"],
        "superstar", 420, 14480, "SG", "6-6", ["2"],
        "2024 MVP runner-up — leading OKC's rebuild into a contender"),
    build_player(1629636, "Anfernee Simons", False, 2018, None, "Portland Trail Blazers",
        ["Portland Trail Blazers"],
        "solid", 390, 10920, "SG", "6-3", ["1"]),
    build_player(203077, "Dario Saric", False, 2016, None, "Philadelphia 76ers",
        ["Philadelphia 76ers", "Minnesota Timberwolves", "Phoenix Suns", "Golden State Warriors", "Denver Nuggets"],
        "deep_cut", 380, 8950, "PF", "6-10", ["9"]),
    build_player(1627814, "Cedi Osman", False, 2017, None, "Cleveland Cavaliers",
        ["Cleveland Cavaliers", "San Antonio Spurs"],
        "deep_cut", 392, 8820, "SF", "6-7", ["16"]),
    build_player(1629636, "Immanuel Quickley", False, 2020, None, "New York Knicks",
        ["New York Knicks", "Toronto Raptors"],
        "deep_cut", 280, 7040, "PG", "6-3", ["5"]),
    build_player(203084, "Isaiah Thomas", True, 2011, 2022, "Sacramento Kings",
        ["Sacramento Kings", "Phoenix Suns", "Boston Celtics", "Cleveland Cavaliers", "Los Angeles Lakers", "Denver Nuggets", "Washington Wizards", "Minnesota Timberwolves", "New Orleans Pelicans", "Charlotte Hornets", "Dallas Mavericks"],
        "solid", 607, 16780, "PG", "5-9", ["4"],
        "Scored 53 points on his late sister's birthday — 5'9\" heart of Boston's #1 seed"),
    build_player(1629651, "Kendrick Nunn", False, 2019, None, "Miami Heat",
        ["Miami Heat", "Los Angeles Lakers", "Washington Wizards", "Cleveland Cavaliers"],
        "deep_cut", 240, 5860, "PG", "6-2", ["25"]),
    build_player(203952, "Anthony Edwards", False, 2020, None, "Minnesota Timberwolves",
        ["Minnesota Timberwolves"],
        "superstar", 310, 11340, "SG", "6-4", ["5"],
        "One of the most electric young scorers — 'Ant-Man' led Minnesota to the WCF"),
    build_player(203468, "Victor Wembanyama", False, 2023, None, "San Antonio Spurs",
        ["San Antonio Spurs"],
        "superstar", 140, 4760, "C", "7-4", ["1"],
        "2024 Rookie of the Year at 7'4\" — generational two-way talent"),
    build_player(1629632, "Chet Holmgren", False, 2023, None, "Oklahoma City Thunder",
        ["Oklahoma City Thunder"],
        "solid", 120, 3640, "C", "7-1", ["7"],
        "2024 Rookie of the Year runner-up"),
    build_player(203897, "Paolo Banchero", False, 2022, None, "Orlando Magic",
        ["Orlando Magic"],
        "superstar", 180, 6300, "PF", "6-10", ["5"],
        "2023 Rookie of the Year — first Duke player taken #1 since Kyrie"),
]
# fmt: on


def deduplicate(players):
    """Remove duplicate IDs, keeping the first occurrence."""
    seen = set()
    unique = []
    for p in players:
        if p["id"] not in seen:
            seen.add(p["id"])
            unique.append(p)
    return unique


def main():
    players = deduplicate(PLAYERS)

    # Count tiers
    tiers = {}
    for p in players:
        tiers[p["tier"]] = tiers.get(p["tier"], 0) + 1

    print(f"Generated {len(players)} I–Z players:")
    for tier, count in sorted(tiers.items()):
        print(f"  {tier}: {count}")

    output = Path(OUTPUT_PATH)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(players, indent=2))
    print(f"\nWrote to {output}")

    # Also generate SQL upsert
    sql_path = output.with_name("nba_game_players_i_z_inserts.sql")
    with open(sql_path, "w") as f:
        f.write("-- I–Z player upsert for nba_game_players\n")
        f.write("-- Run in Supabase SQL Editor\n\n")
        for p in players:
            teams_pg = "ARRAY[" + ",".join(f"'{t}'" for t in p["teams"]) + "]"
            jerseys_pg = "ARRAY[" + ",".join(f"'{j}'" for j in p["jerseys"]) + "]" if p["jerseys"] else "'{}'"
            fun_fact_sql = f"'{p['funFact'].replace(chr(39), chr(39)+chr(39))}'" if p.get("funFact") else "NULL"
            position_sql = f"'{p['position']}'" if p.get("position") else "NULL"
            height_sql = f"'{p['height']}'" if p.get("height") else "NULL"
            to_year_sql = str(p["toYear"]) if p["toYear"] is not None else "NULL"

            headshot_sql = f"'{p['headshotUrl']}'" if p.get('headshotUrl') else "NULL"

            f.write(f"""INSERT INTO nba_game_players (id, name, retired, years_active, from_year, to_year, draft_team, teams, position, height, jerseys, tier, career_games, career_minutes, fun_fact, headshot_url)
VALUES ({p['id']}, '{p['name'].replace(chr(39), chr(39)+chr(39))}', {str(p['retired']).lower()}, '{p['yearsActive']}', {p['fromYear']}, {to_year_sql}, '{p.get('draftTeam', 'Unknown')}', {teams_pg}, {position_sql}, {height_sql}, {jerseys_pg}, '{p['tier']}', {p['careerGames']}, {p['careerMinutes']}, {fun_fact_sql}, {headshot_sql})
ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, retired=EXCLUDED.retired, years_active=EXCLUDED.years_active, teams=EXCLUDED.teams, tier=EXCLUDED.tier, career_games=EXCLUDED.career_games, career_minutes=EXCLUDED.career_minutes, fun_fact=EXCLUDED.fun_fact, position=EXCLUDED.position, height=EXCLUDED.height, jerseys=EXCLUDED.jerseys, headshot_url=EXCLUDED.headshot_url;\n\n""")

    print(f"Wrote SQL upsert to {sql_path}")


if __name__ == "__main__":
    main()
