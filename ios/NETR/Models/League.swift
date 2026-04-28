import Foundation

nonisolated struct LeaguePlayer: Identifiable, Decodable, Sendable {
    let id: String
    let leagueId: String
    let teamId: String
    let profileId: String?
    let displayName: String
    let isClaimed: Bool

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case leagueId = "league_id"
        case teamId = "team_id"
        case profileId = "profile_id"
        case displayName = "display_name"
        case isClaimed = "is_claimed"
    }
}

nonisolated struct League: Identifiable, Decodable, Sendable {
    let id: String
    let name: String
    let slug: String?
    let logoUrl: String?
    let accentColor: String?
    let sport: String?
    let season: String?
    let location: String?
    let customDomain: String?
    let customDomainStatus: String?

    var websiteURL: URL? {
        if let domain = customDomain?.trimmingCharacters(in: .whitespacesAndNewlines),
           !domain.isEmpty,
           customDomainStatus == "active" {
            let prefixed = domain.lowercased().hasPrefix("http") ? domain : "https://\(domain)"
            if let url = URL(string: prefixed) { return url }
        }
        guard let slug, !slug.isEmpty else { return nil }
        return URL(string: "https://netr.pro/league/\(slug)")
    }

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case name
        case slug
        case logoUrl = "logo_url"
        case accentColor = "accent_color"
        case sport
        case season
        case location
        case customDomain = "custom_domain"
        case customDomainStatus = "custom_domain_status"
    }
}

nonisolated struct LeagueTeam: Identifiable, Decodable, Sendable {
    let id: String
    let leagueId: String
    let name: String
    let color: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case leagueId = "league_id"
        case name
        case color
    }
}

nonisolated struct LeagueGame: Identifiable, Decodable, Sendable {
    let id: String
    let leagueId: String
    let homeTeamId: String
    let awayTeamId: String
    let scheduledAt: String?
    let location: String?
    let courtId: String?
    let status: String
    let homeScore: Int?
    let awayScore: Int?

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case leagueId = "league_id"
        case homeTeamId = "home_team_id"
        case awayTeamId = "away_team_id"
        case scheduledAt = "scheduled_at"
        case location
        case courtId = "court_id"
        case status
        case homeScore = "home_score"
        case awayScore = "away_score"
    }
}

nonisolated struct LeaguePlayerStats: Decodable, Sendable {
    let gameId: String
    let points: Int?
    let rebounds: Int?
    let assists: Int?
    let steals: Int?
    let blocks: Int?
    let turnovers: Int?
    let fieldGoalsMade: Int?
    let fieldGoalsAttempted: Int?
    let threePointersMade: Int?
    let threePointersAttempted: Int?
    let freeThrowsMade: Int?
    let freeThrowsAttempted: Int?

    nonisolated enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case points
        case rebounds
        case assists
        case steals
        case blocks
        case turnovers
        case fieldGoalsMade = "field_goals_made"
        case fieldGoalsAttempted = "field_goals_attempted"
        case threePointersMade = "three_pointers_made"
        case threePointersAttempted = "three_pointers_attempted"
        case freeThrowsMade = "free_throws_made"
        case freeThrowsAttempted = "free_throws_attempted"
    }
}

nonisolated struct LeagueStanding: Decodable, Sendable {
    let leagueId: String
    let teamId: String
    let wins: Int
    let losses: Int
    let pointsFor: Int?
    let pointsAgainst: Int?

    nonisolated enum CodingKeys: String, CodingKey {
        case leagueId = "league_id"
        case teamId = "team_id"
        case wins
        case losses
        case pointsFor = "points_for"
        case pointsAgainst = "points_against"
    }
}

struct LeagueEntry: Identifiable {
    let id: String
    let leaguePlayer: LeaguePlayer
    let league: League
    let team: LeagueTeam
    let standing: LeagueStanding?
}

struct LeagueAggrStats {
    var gamesPlayed: Int = 0
    var totalPoints: Double = 0
    var totalRebounds: Double = 0
    var totalAssists: Double = 0
    var totalSteals: Double = 0
    var totalBlocks: Double = 0
    var fgMade: Int = 0
    var fgAttempted: Int = 0
    var threeMade: Int = 0
    var threeAttempted: Int = 0
    var ftMade: Int = 0
    var ftAttempted: Int = 0

    var ppg: String { gamesPlayed > 0 ? String(format: "%.1f", totalPoints / Double(gamesPlayed)) : "0.0" }
    var rpg: String { gamesPlayed > 0 ? String(format: "%.1f", totalRebounds / Double(gamesPlayed)) : "0.0" }
    var apg: String { gamesPlayed > 0 ? String(format: "%.1f", totalAssists / Double(gamesPlayed)) : "0.0" }
    var spg: String { gamesPlayed > 0 ? String(format: "%.1f", totalSteals / Double(gamesPlayed)) : "0.0" }
    var bpg: String { gamesPlayed > 0 ? String(format: "%.1f", totalBlocks / Double(gamesPlayed)) : "0.0" }
    var fgPct: String {
        guard fgAttempted > 0 else { return "—" }
        return String(format: "%.0f%%", Double(fgMade) / Double(fgAttempted) * 100)
    }
    var threePct: String {
        guard threeAttempted > 0 else { return "—" }
        return String(format: "%.0f%%", Double(threeMade) / Double(threeAttempted) * 100)
    }
    var ftPct: String {
        guard ftAttempted > 0 else { return "—" }
        return String(format: "%.0f%%", Double(ftMade) / Double(ftAttempted) * 100)
    }
}
