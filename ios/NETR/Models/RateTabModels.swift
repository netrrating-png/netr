import Foundation

struct RecentGameSession: Identifiable {
    let id: String
    let courtName: String
    let playedAt: Date
    var players: [RateablePlayer]
}

struct RateablePlayer: Identifiable, Hashable {
    let id: String
    let fullName: String
    let username: String
    let netrScore: Double?
    let vibeScore: Double?
    let position: String?
    let gameId: String
    var alreadyRated: Bool
}

nonisolated struct RateGameRow: Decodable, Sendable {
    let id: String
    let createdAt: String
    let completedAt: String?
    let courtId: String?
    let status: String

    nonisolated enum CodingKeys: String, CodingKey {
        case id, status
        case createdAt   = "created_at"
        case completedAt = "completed_at"
        case courtId     = "court_id"
    }
}

nonisolated struct RateProfileRow: Decodable, Sendable {
    let id: String
    let fullName: String?
    let username: String?
    let netrScore: Double?
    let vibeScore: Double?
    let position: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, position
        case fullName  = "full_name"
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
        case gameId  = "game_id"
    }
}

nonisolated struct OtherPlayerRow: Decodable, Sendable {
    let userId: String
    let gameId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case gameId = "game_id"
    }
}

nonisolated struct MyGameIdRow: Decodable, Sendable {
    let gameId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
    }
}

nonisolated struct RatingCountRow: Decodable, Sendable {
    let id: String
}
