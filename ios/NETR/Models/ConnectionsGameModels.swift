import Foundation

// MARK: - Server models (decoded from nba_connections_today view)

nonisolated struct ConnectionsGroup: Decodable, Sendable {
    let label: String
    let type: String           // "team", "college", "jersey", "country", etc.
    let difficulty: Int        // 1 (Yellow/easiest) – 4 (Purple/hardest)
    let playerIds: [Int64]
    let playerNames: [String]  // revealed when group is solved
    let headshotUrls: [String]

    nonisolated enum CodingKeys: String, CodingKey {
        case label, type, difficulty
        case playerIds    = "player_ids"
        case playerNames  = "player_names"
        case headshotUrls = "headshot_urls"
    }
}

nonisolated struct ConnectionsPuzzle: Decodable, Sendable {
    let puzzleDate: String              // "2026-04-14"
    let categories: [ConnectionsGroup]  // always 4 groups

    nonisolated enum CodingKeys: String, CodingKey {
        case puzzleDate  = "puzzle_date"
        case categories
    }
}

// MARK: - Flat tile model (built from shuffled group players)

nonisolated struct ConnectionsTile: Identifiable, Sendable, Hashable {
    let id: Int            // index 0–11 in the shuffled list
    let groupIndex: Int    // which of the 4 groups this tile belongs to (0–3)
    let playerName: String
    let headshotUrl: String
}

// MARK: - Game state

nonisolated enum ConnectionsStatus: String, Codable, Sendable, Equatable {
    case playing
    case won
    case lost
}

/// Persisted to UserDefaults so users can resume mid-game.
nonisolated struct ConnectionsGameState: Codable, Sendable {
    var selectedTileIds: [Int] = []      // Set<Int> serialised as sorted array
    var solvedGroupIndices: [Int] = []   // indices into puzzle.categories that have been solved
    var mistakeCount: Int = 0
    var status: ConnectionsStatus = .playing
}

// MARK: - Streak stats (persisted to UserDefaults)

nonisolated struct ConnectionsGameStats: Codable, Sendable {
    var currentStreak: Int = 0
    var maxStreak: Int = 0
    var totalPlayed: Int = 0
    var totalWon: Int = 0
    var lastPlayedDate: String? = nil   // "2026-04-14"

    var winPercent: Int {
        guard totalPlayed > 0 else { return 0 }
        return Int((Double(totalWon) / Double(totalPlayed)) * 100)
    }
}

// MARK: - Result payload (for Supabase insert)

nonisolated struct ConnectionsResultPayload: Encodable, Sendable {
    let userId: String
    let puzzleDate: String
    let won: Bool
    let mistakes: Int

    nonisolated enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case puzzleDate = "puzzle_date"
        case won
        case mistakes
    }
}

// MARK: - Difficulty display helpers

extension ConnectionsGroup {
    /// SwiftUI hex color string for this group's difficulty band.
    var colorHex: String {
        switch difficulty {
        case 1:  return "F9DF6D"  // Yellow
        case 2:  return "A0C35A"  // Green
        case 3:  return "B0C4EF"  // Blue
        default: return "BA81C5"  // Purple
        }
    }
}
