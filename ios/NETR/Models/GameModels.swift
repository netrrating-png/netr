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

    nonisolated enum CodingKeys: String, CodingKey {
        case courtId = "court_id"
        case hostId = "host_id"
        case joinCode = "join_code"
        case format
        case skillLevel = "skill_level"
        case status
        case maxPlayers = "max_players"
    }
}

nonisolated struct LobbyPlayer: Identifiable, Sendable {
    let id: String
    let userId: String
    let gameId: String
    let profile: LobbyPlayerProfile
}

extension LobbyPlayer: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case gameId = "game_id"
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
    }
}

nonisolated struct GamePlayerPayload: Encodable, Sendable {
    let gameId: String
    let userId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case userId = "user_id"
    }
}

nonisolated struct GameStatusUpdate: Encodable, Sendable {
    let status: String
}

func generateJoinCode() -> String {
    let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return String((0..<6).map { _ in chars.randomElement()! })
}
