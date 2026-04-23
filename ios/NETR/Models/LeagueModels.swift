import Foundation

// MARK: - League

nonisolated struct League: Identifiable, Sendable, Decodable {
    let id: String
    var name: String
    var slug: String
    var sport: String
    var season: String?
    var location: String?
    var logoUrl: String?
    var bannerUrl: String?
    var accentColor: String?
    var announcement: String?
    var isActive: Bool

    nonisolated enum CodingKeys: String, CodingKey {
        case id, name, slug, sport, season, location
        case logoUrl     = "logo_url"
        case bannerUrl   = "banner_url"
        case accentColor = "accent_color"
        case announcement
        case isActive    = "is_active"
    }
}

// MARK: - LeagueTeam

nonisolated struct LeagueTeam: Identifiable, Sendable, Decodable {
    let id: String
    let leagueId: String
    var name: String
    var color: String
    var logoUrl: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case leagueId = "league_id"
        case name, color
        case logoUrl  = "logo_url"
    }
}

// MARK: - LeaguePlayer

nonisolated struct LeaguePlayer: Identifiable, Sendable, Decodable {
    let id: String
    let teamId: String
    let leagueId: String
    var profileId: String?
    var displayName: String
    var jerseyNumber: String?
    var position: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case teamId       = "team_id"
        case leagueId     = "league_id"
        case profileId    = "profile_id"
        case displayName  = "display_name"
        case jerseyNumber = "jersey_number"
        case position
    }
}

// MARK: - LeagueGame

nonisolated struct LeagueGame: Identifiable, Sendable, Decodable {
    let id: String
    let leagueId: String
    let homeTeamId: String
    let awayTeamId: String
    var scheduledAt: String
    var location: String?
    var status: String         // 'scheduled' | 'final' | 'cancelled'
    var homeScore: Int?
    var awayScore: Int?
    var gameType: String?      // 'regular' | 'playoff'

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case leagueId    = "league_id"
        case homeTeamId  = "home_team_id"
        case awayTeamId  = "away_team_id"
        case scheduledAt = "scheduled_at"
        case location, status
        case homeScore   = "home_score"
        case awayScore   = "away_score"
        case gameType    = "game_type"
    }

    var isFinal: Bool     { status == "final" }
    var isScheduled: Bool { status == "scheduled" }

    var scheduledDate: Date? {
        ISO8601DateFormatter().date(from: scheduledAt)
    }

    var formattedDate: String {
        guard let date = scheduledDate else { return "" }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    var formattedTime: String {
        guard let date = scheduledDate else { return "" }
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: date)
    }
}

// MARK: - LeagueStanding

nonisolated struct LeagueStanding: Identifiable, Sendable, Decodable {
    let leagueId: String
    let teamId: String
    var teamName: String
    var color: String
    var wins: Int
    var losses: Int
    var ptsFor: Double?
    var ptsAgainst: Double?

    var id: String { teamId }

    nonisolated enum CodingKeys: String, CodingKey {
        case leagueId   = "league_id"
        case teamId     = "team_id"
        case teamName   = "team_name"
        case color, wins, losses
        case ptsFor     = "pts_for"
        case ptsAgainst = "pts_against"
    }

    var gamesPlayed: Int { wins + losses }

    var pct: Double { gamesPlayed > 0 ? Double(wins) / Double(gamesPlayed) : 0.0 }

    var pctString: String {
        guard gamesPlayed > 0 else { return ".000" }
        let s = String(format: "%.3f", pct)
        // Drop leading "0" → ".750"
        return s.hasPrefix("0") ? String(s.dropFirst()) : s
    }
}

// MARK: - LeaguePlayerStat

nonisolated struct LeaguePlayerStat: Identifiable, Sendable, Decodable {
    let gameId: String
    let playerId: String
    let teamId: String
    var points: Int
    var rebounds: Int
    var assists: Int
    var steals: Int
    var blocks: Int
    var turnovers: Int
    var fouls: Int
    var fieldGoalsMade: Int
    var fieldGoalsAttempted: Int
    var threePointersMade: Int
    var threePointersAttempted: Int
    var freeThrowsMade: Int
    var freeThrowsAttempted: Int

    var id: String { "\(gameId)-\(playerId)" }

    nonisolated enum CodingKeys: String, CodingKey {
        case gameId    = "game_id"
        case playerId  = "player_id"
        case teamId    = "team_id"
        case points, rebounds, assists, steals, blocks, turnovers, fouls
        case fieldGoalsMade         = "field_goals_made"
        case fieldGoalsAttempted    = "field_goals_attempted"
        case threePointersMade      = "three_pointers_made"
        case threePointersAttempted = "three_pointers_attempted"
        case freeThrowsMade         = "free_throws_made"
        case freeThrowsAttempted    = "free_throws_attempted"
    }

    var fgString: String { "\(fieldGoalsMade)/\(fieldGoalsAttempted)" }
    var tpString: String { "\(threePointersMade)/\(threePointersAttempted)" }
    var ftString: String { "\(freeThrowsMade)/\(freeThrowsAttempted)" }
}

// MARK: - LeagueGameAttendance

nonisolated struct LeagueGameAttendance: Identifiable, Sendable, Decodable {
    let id: String
    let gameId: String
    let playerId: String
    var status: String   // 'yes' | 'no' | 'maybe'
    var updatedAt: String

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case gameId    = "game_id"
        case playerId  = "player_id"
        case status
        case updatedAt = "updated_at"
    }
}

// MARK: - MyLeague (combined for profile display)

struct MyLeague: Identifiable {
    let league: League
    let team: LeagueTeam
    let player: LeaguePlayer

    var id: String { player.id }
}

// MARK: - PlayerStatLine (aggregated per-player season averages)

struct PlayerStatLine: Identifiable {
    let player: LeaguePlayer
    let team: LeagueTeam
    let gamesPlayed: Int
    let totalPoints: Int
    let totalRebounds: Int
    let totalAssists: Int
    let totalSteals: Int
    let totalBlocks: Int

    var id: String { player.id }

    var ppg: Double { gamesPlayed > 0 ? Double(totalPoints)   / Double(gamesPlayed) : 0 }
    var rpg: Double { gamesPlayed > 0 ? Double(totalRebounds) / Double(gamesPlayed) : 0 }
    var apg: Double { gamesPlayed > 0 ? Double(totalAssists)  / Double(gamesPlayed) : 0 }
    var spg: Double { gamesPlayed > 0 ? Double(totalSteals)   / Double(gamesPlayed) : 0 }
    var bpg: Double { gamesPlayed > 0 ? Double(totalBlocks)   / Double(gamesPlayed) : 0 }
}
