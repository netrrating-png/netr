import Foundation

struct RecentGameSession: Identifiable {
    let id: String
    let courtName: String
    let playedAt: Date
    var players: [RateablePlayer]
}

struct RateablePlayer: Identifiable {
    let id: String
    let fullName: String
    let username: String
    let netrScore: Double?
    let vibeScore: Double?
    let position: String?
    let provisional: Bool
    let gameId: String
    var alreadyRated: Bool
}

nonisolated struct RateGameRow: Decodable, Sendable {
    let id: String
    let players: [String]?
    let createdAt: String
    let courtId: String?
    let status: String

    nonisolated enum CodingKeys: String, CodingKey {
        case id, players, status
        case createdAt = "created_at"
        case courtId = "court_id"
    }
}

nonisolated struct RateProfileRow: Decodable, Sendable {
    let id: String
    let fullName: String?
    let username: String?
    let netrScore: Double?
    let vibeScore: Double?
    let position: String?
    let provisional: Bool?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, position, provisional
        case fullName = "full_name"
        case username
        case netrScore = "netr_score"
        case vibeScore = "vibe_score"
    }
}

nonisolated struct RateCourtNameRow: Decodable, Sendable {
    let id: String
    let name: String
}

nonisolated struct RatedRow: Decodable, Sendable {
    let ratedId: String
    let gameId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case ratedId = "rated_id"
        case gameId = "game_id"
    }
}
