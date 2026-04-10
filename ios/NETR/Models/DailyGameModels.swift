import Foundation

// MARK: - NBA Player (pool row)

nonisolated struct NBAGamePlayer: Identifiable, Sendable, Hashable {
    let id: Int64
    let name: String
    let retired: Bool
    let yearsActive: String
    let fromYear: Int
    let toYear: Int?
    let draftTeam: String?
    let teams: [String]
    let position: String?
    let height: String?
    let jerseys: [String]
    let tier: String
    let funFact: String?
}

extension NBAGamePlayer: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case name
        case retired
        case yearsActive = "years_active"
        case fromYear = "from_year"
        case toYear = "to_year"
        case draftTeam = "draft_team"
        case teams
        case position
        case height
        case jerseys
        case tier
        case funFact = "fun_fact"
    }
}

// MARK: - Today's Puzzle (nba_game_today view row)

nonisolated struct DailyPuzzle: Sendable {
    let puzzleDate: String          // "2026-04-10"
    let player: NBAGamePlayer
}

extension DailyPuzzle: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case puzzleDate = "puzzle_date"
        case id
        case name
        case retired
        case yearsActive = "years_active"
        case fromYear = "from_year"
        case toYear = "to_year"
        case draftTeam = "draft_team"
        case teams
        case position
        case height
        case jerseys
        case tier
        case funFact = "fun_fact"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.puzzleDate = try c.decode(String.self, forKey: .puzzleDate)
        self.player = NBAGamePlayer(
            id: try c.decode(Int64.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            retired: try c.decode(Bool.self, forKey: .retired),
            yearsActive: try c.decode(String.self, forKey: .yearsActive),
            fromYear: try c.decode(Int.self, forKey: .fromYear),
            toYear: try c.decodeIfPresent(Int.self, forKey: .toYear),
            draftTeam: try c.decodeIfPresent(String.self, forKey: .draftTeam),
            teams: try c.decodeIfPresent([String].self, forKey: .teams) ?? [],
            position: try c.decodeIfPresent(String.self, forKey: .position),
            height: try c.decodeIfPresent(String.self, forKey: .height),
            jerseys: try c.decodeIfPresent([String].self, forKey: .jerseys) ?? [],
            tier: try c.decode(String.self, forKey: .tier),
            funFact: try c.decodeIfPresent(String.self, forKey: .funFact)
        )
    }
}

// MARK: - Hints (5 progressive reveals)

nonisolated enum HintStage: Int, CaseIterable, Sendable {
    case retiredStatus = 0   // "Retired" or "Still Active"
    case yearsActive   = 1   // "1996 – 2016"
    case draftTeam     = 2   // "Drafted by the Charlotte Hornets"
    case allTeams      = 3   // "Played for the Hornets, Lakers"
    case funFact       = 4   // Hand-written fact, or built from position/height/jersey

    var title: String {
        switch self {
        case .retiredStatus: return "Status"
        case .yearsActive:   return "Years Active"
        case .draftTeam:     return "Drafted By"
        case .allTeams:      return "Teams"
        case .funFact:       return "Final Clue"
        }
    }
}

extension NBAGamePlayer {
    /// Returns the revealed hint text for a given stage, based on this player's data.
    func hintText(for stage: HintStage) -> String {
        switch stage {
        case .retiredStatus:
            return retired ? "Retired" : "Still Active"
        case .yearsActive:
            return yearsActive.replacingOccurrences(of: "-", with: " – ")
        case .draftTeam:
            return draftTeam ?? "Unknown"
        case .allTeams:
            if teams.isEmpty { return "Unknown" }
            if teams.count == 1 { return teams[0] }
            return teams.joined(separator: ", ")
        case .funFact:
            if let fact = funFact, !fact.isEmpty { return fact }
            // Fallback programmatic hint when no hand-curated funFact exists
            var parts: [String] = []
            if let p = position, !p.isEmpty { parts.append(p) }
            if let h = height, !h.isEmpty { parts.append("\(h) tall") }
            if let j = jerseys.first, !j.isEmpty { parts.append("wore #\(j)") }
            return parts.isEmpty ? "No further hints" : parts.joined(separator: " · ")
        }
    }
}

// MARK: - Per-guess result

nonisolated struct DailyGameGuess: Identifiable, Sendable, Hashable {
    let id: UUID
    let player: NBAGamePlayer
    let isCorrect: Bool

    init(player: NBAGamePlayer, isCorrect: Bool) {
        self.id = UUID()
        self.player = player
        self.isCorrect = isCorrect
    }
}

// MARK: - Game status

nonisolated enum DailyGameStatus: Sendable, Equatable {
    case playing
    case won(guessCount: Int)
    case lost
}

// MARK: - Streak stats (local @AppStorage)

nonisolated struct DailyGameStats: Codable, Sendable {
    var currentStreak: Int = 0
    var maxStreak: Int = 0
    var totalPlayed: Int = 0
    var totalWon: Int = 0
    var guessDistribution: [Int: Int] = [:]    // guessCount -> times achieved (1-6)
    var lastPlayedDate: String? = nil           // "2026-04-10"

    var winPercent: Int {
        guard totalPlayed > 0 else { return 0 }
        return Int((Double(totalWon) / Double(totalPlayed)) * 100)
    }
}

// MARK: - Result payload (for Supabase insert)

nonisolated struct DailyGameResultPayload: Encodable, Sendable {
    let userId: String
    let puzzleDate: String
    let guessCount: Int
    let won: Bool

    nonisolated enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case puzzleDate = "puzzle_date"
        case guessCount = "guess_count"
        case won
    }
}
