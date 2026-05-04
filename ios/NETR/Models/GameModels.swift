import Foundation

nonisolated struct SupabaseGame: Identifiable, Sendable {
    let id: String
    let courtId: String?
    let hostId: String
    let joinCode: String
    let format: String
    let skillLevel: String
    let status: String
    let maxPlayers: Int
    let createdAt: String?
    let scheduledAt: String?
    let completedAt: String?
    let isPrivate: Bool
    let passcode: String?
}

extension SupabaseGame: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case courtId = "court_id"
        case hostId = "host_id"
        case joinCode = "join_code"
        case format
        case skillLevel = "skill_level"
        case status
        case maxPlayers = "max_players"
        case createdAt = "created_at"
        case scheduledAt = "scheduled_at"
        case completedAt = "completed_at"
        case isPrivate = "is_private"
        case passcode
    }
}

nonisolated struct CreateGamePayload: Encodable, Sendable {
    let courtId: String?
    let hostId: String
    let joinCode: String
    let format: String
    let skillLevel: String
    let status: String
    let maxPlayers: Int
    let scheduledAt: String?
    let isPrivate: Bool
    let passcode: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case courtId = "court_id"
        case hostId = "host_id"
        case joinCode = "join_code"
        case format
        case skillLevel = "skill_level"
        case status
        case maxPlayers = "max_players"
        case scheduledAt = "scheduled_at"
        case isPrivate = "is_private"
        case passcode
    }
}

nonisolated struct LobbyPlayer: Identifiable, Sendable {
    let id: String
    let userId: String
    let gameId: String
    let checkedInAt: String?
    let checkedOutAt: String?
    let removed: Bool?
    let profile: LobbyPlayerProfile

    var isCheckedOut: Bool { checkedOutAt != nil }
    var isRemoved: Bool { removed ?? false }
}

extension LobbyPlayer: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case gameId = "game_id"
        case checkedInAt = "checked_in_at"
        case checkedOutAt = "checked_out_at"
        case removed
        case profile = "profiles"
    }
}

nonisolated struct LobbyPlayerProfile: Sendable {
    let id: String
    let fullName: String?
    let username: String?
    let position: String?
    let avatarUrl: String?
    let netrScore: Double?
    let vibeScore: Double?
    var totalRatings: Int?
}

extension LobbyPlayerProfile: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case username
        case position
        case avatarUrl = "avatar_url"
        case netrScore = "netr_score"
        case vibeScore = "vibe_score"
        case totalRatings = "total_ratings"
        // Note: fullName maps to full_name in the DB
    }
}

nonisolated struct GamePlayerPayload: Encodable, Sendable {
    let gameId: String
    let userId: String
    let checkedInAt: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case userId = "user_id"
        case checkedInAt = "checked_in_at"
    }
}

nonisolated struct GameStatusUpdate: Encodable, Sendable {
    let status: String
}

func generateJoinCode() -> String {
    let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return String((0..<6).map { _ in chars.randomElement()! })
}

// MARK: - Discoverable Game (for Join / My Games)

nonisolated struct DiscoverableGame: Identifiable, Sendable {
    let id: String
    let courtId: String?
    let hostId: String
    let joinCode: String
    let format: String?
    let skillLevel: String?
    let status: String
    let maxPlayers: Int?
    let createdAt: String
    let scheduledAt: String?

    let courts: DiscoverableGameCourt?
    let host: DiscoverableGameHost?
    let gamePlayers: [DiscoverableGamePlayerCount]?

    var courtName: String { courts?.name ?? "Unknown Court" }
    var neighborhood: String { courts?.neighborhood ?? "" }
    var hostName: String {
        if let name = host?.fullName, !name.isEmpty { return name }
        if let username = host?.username { return "@\(username)" }
        return "Unknown"
    }
    var joinedCount: Int { gamePlayers?.first?.count ?? 0 }

    var scheduledDate: Date? {
        guard let str = scheduledAt else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }

    var startedAgo: String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: createdAt) else { return "" }
        let diff = Int(-date.timeIntervalSinceNow / 60)
        if diff < 1 { return "Just started" }
        if diff == 1 { return "1 min ago" }
        return "\(diff) min ago"
    }
}

extension DiscoverableGame: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case courtId = "court_id"
        case hostId = "host_id"
        case joinCode = "join_code"
        case format
        case skillLevel = "skill_level"
        case status
        case maxPlayers = "max_players"
        case createdAt = "created_at"
        case scheduledAt = "scheduled_at"
        case courts
        case host
        case gamePlayers = "game_players"
    }
}

nonisolated struct DiscoverableGameCourt: Decodable, Sendable {
    let name: String
    let neighborhood: String?
}

nonisolated struct DiscoverableGameHost: Decodable, Sendable {
    let fullName: String?
    let username: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case username
    }
}

nonisolated struct DiscoverableGamePlayerCount: Decodable, Sendable {
    let count: Int
}

// MARK: - No-Show Reports

nonisolated struct NoShowReportPayload: Encodable, Sendable {
    let gameId: String
    let reportedByUserId: String
    let reportedUserId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case reportedByUserId = "reported_by_user_id"
        case reportedUserId = "reported_user_id"
    }
}

nonisolated struct NoShowReport: Decodable, Sendable {
    let id: String
    let gameId: String
    let reportedByUserId: String
    let reportedUserId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case reportedByUserId = "reported_by_user_id"
        case reportedUserId = "reported_user_id"
    }
}
