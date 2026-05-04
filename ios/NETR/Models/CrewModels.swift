import Foundation

// MARK: - Crew (maps to crews table)

nonisolated struct Crew: Identifiable, Sendable, Decodable {
    let id: String
    var name: String
    var icon: String
    let creatorId: String
    var adminId: String
    let createdAt: String?
    var password: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, name, icon, password
        case creatorId = "creator_id"
        case adminId   = "admin_id"
        case createdAt = "created_at"
    }
}

// MARK: - Crew Member (maps to crew_members table)

nonisolated struct CrewMember: Identifiable, Sendable, Decodable {
    let id: String
    let crewId: String
    let userId: String
    let joinedAt: String?
    var isPrimary: Bool?
    var lastReadAt: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case crewId     = "crew_id"
        case userId     = "user_id"
        case joinedAt   = "joined_at"
        case isPrimary  = "is_primary"
        case lastReadAt = "last_read_at"
    }
}

// MARK: - My Crew (combined crew + member row for current user)

struct MyCrew: Identifiable {
    let crew: Crew
    let memberRow: CrewMember
    var id: String { crew.id }
    var isPrimary: Bool { memberRow.isPrimary ?? false }
    // Convenience forwarders so call sites can use crew.name, crew.icon, etc.
    var name: String { crew.name }
    var icon: String { crew.icon }
    var adminId: String { crew.adminId }
    var creatorId: String { crew.creatorId }
    var password: String? { crew.password }
}

// MARK: - Crew Member Profile (enriched for leaderboard)

struct CrewMemberProfile: Identifiable {
    let id: String          // user_id
    let memberId: String    // crew_members.id
    let fullName: String?
    let username: String?
    let avatarUrl: String?
    let netrScore: Double?
    let catShooting: Double?
    let catFinishing: Double?
    let catDribbling: Double?
    let catPassing: Double?
    let catDefense: Double?
    let catRebounding: Double?
    let catBasketballIq: Double?
    let reviewCount: Int?
    let isPrimary: Bool
    let joinedAt: String?

    var ratingProgress: Double { min(1.0, Double(reviewCount ?? 0) / 5.0) }
    var isRated: Bool { (reviewCount ?? 0) >= 5 }

    var displayName: String {
        if let n = fullName, !n.isEmpty { return n }
        if let u = username { return "@\(u)" }
        return "Player"
    }

    func score(for filter: CrewLeaderboardFilter) -> Double? {
        switch filter {
        case .overall:    return netrScore
        case .shooting:   return catShooting
        case .finishing:  return catFinishing
        case .handles:    return catDribbling
        case .playmaking: return catPassing
        case .defense:    return catDefense
        case .rebounding: return catRebounding
        case .iq:         return catBasketballIq
        }
    }
}

// MARK: - Crew Message (maps to crew_messages table)

nonisolated struct CrewMessage: Identifiable, Sendable, Decodable {
    let id: String
    let crewId: String
    let senderId: String
    let content: String
    let createdAt: String
    var messageType: String
    let gameId: String?
    var isPinned: Bool
    var gameInvite: CrewGameInvite?

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case crewId      = "crew_id"
        case senderId    = "sender_id"
        case content
        case createdAt   = "created_at"
        case messageType = "message_type"
        case gameId      = "game_id"
        case isPinned    = "is_pinned"
        case gameInvite  = "games"
    }

    var isGameInvite: Bool { messageType == "game_invite" }
}

// MARK: - Crew Game Invite (game data joined into crew message)

nonisolated struct CrewGameInvite: Sendable, Decodable {
    let id: String
    let joinCode: String
    let format: String?
    let scheduledAt: String?
    let isPrivate: Bool
    let courtName: String?

    nonisolated struct CourtRef: Decodable, Sendable {
        let name: String
    }

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case joinCode   = "join_code"
        case format
        case scheduledAt = "scheduled_at"
        case isPrivate  = "is_private"
        case courtName  = "courts"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        joinCode    = try c.decode(String.self, forKey: .joinCode)
        format      = try c.decodeIfPresent(String.self, forKey: .format)
        scheduledAt = try c.decodeIfPresent(String.self, forKey: .scheduledAt)
        isPrivate   = (try? c.decode(Bool.self, forKey: .isPrivate)) ?? false
        if let court = try? c.decode(CourtRef.self, forKey: .courtName) {
            courtName = court.name
        } else {
            courtName = nil
        }
    }
}

// MARK: - Crew Poll Response

nonisolated struct CrewPollResponse: Identifiable, Sendable, Decodable {
    let id: String
    let messageId: String
    let userId: String
    let response: String  // "in" | "out" | "maybe"

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case userId    = "user_id"
        case response
    }
}

nonisolated struct CrewPollResponsePayload: Encodable, Sendable {
    let messageId: String
    let userId: String
    let response: String

    nonisolated enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case userId    = "user_id"
        case response
    }
}

// MARK: - Crew Poll Counts

struct CrewPollCounts: Sendable {
    var inCount: Int    = 0
    var outCount: Int   = 0
    var maybeCount: Int = 0
    var myResponse: String? = nil
}

// MARK: - Crew Search Result

nonisolated struct CrewSearchResult: Identifiable, Decodable, Sendable {
    let id: String
    let name: String
    let icon: String
}

// MARK: - Payloads

nonisolated struct CreateCrewPayload: Encodable, Sendable {
    let name: String
    let icon: String
    let password: String
    let creatorId: String
    let adminId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case name, icon, password
        case creatorId = "creator_id"
        case adminId   = "admin_id"
    }
}

nonisolated struct CrewMemberPayload: Encodable, Sendable {
    let crewId: String
    let userId: String
    let joinedAt: String

    nonisolated enum CodingKeys: String, CodingKey {
        case crewId   = "crew_id"
        case userId   = "user_id"
        case joinedAt = "joined_at"
    }
}

nonisolated struct CrewMessagePayload: Encodable, Sendable {
    let crewId: String
    let senderId: String
    let content: String
    var messageType: String = "text"
    var gameId: String? = nil

    nonisolated enum CodingKeys: String, CodingKey {
        case crewId      = "crew_id"
        case senderId    = "sender_id"
        case content
        case messageType = "message_type"
        case gameId      = "game_id"
    }
}

// MARK: - Leaderboard Filter

enum CrewLeaderboardFilter: String, CaseIterable {
    case overall    = "Overall"
    case shooting   = "Shooting"
    case finishing  = "Finishing"
    case handles    = "Handles"
    case playmaking = "Playmaking"
    case defense    = "Defense"
    case rebounding = "Rebounding"
    case iq         = "IQ"

    var icon: String {
        switch self {
        case .overall:    return "trophy"
        case .shooting:   return "crosshair"
        case .finishing:  return "flame"
        case .handles:    return "dumbbell"
        case .playmaking: return "route"
        case .defense:    return "shield"
        case .rebounding: return "arrow-up-from-line"
        case .iq:         return "brain"
        }
    }

    /// Matches the accent colors from skillCategories in RatingModels
    var colorHex: String {
        switch self {
        case .overall:    return "#39FF14"
        case .shooting:   return "#39FF14"
        case .finishing:  return "#FF7A00"
        case .handles:    return "#FFC247"
        case .playmaking: return "#2ECC71"
        case .defense:    return "#FF3B30"
        case .rebounding: return "#2DA8FF"
        case .iq:         return "#9B8BFF"
        }
    }
}

// MARK: - Crew Icons (15 sport-themed Lucide icons)

let crewIcons: [String] = [
    "flame", "zap", "wind", "tornado", "skull",          // energy / danger
    "trophy", "medal", "award", "target", "crosshair",   // competition
    "shield", "sword", "swords", "dumbbell", "mountain", // strength
    "crown", "star", "diamond", "gem", "sparkles",       // prestige
    "rocket", "moon", "timer", "globe", "activity",      // motion / vibe
    "trending-up", "headphones", "ghost", "bomb", "pizza" // personality
]

// MARK: - Errors

enum CrewError: LocalizedError {
    case notAuthenticated
    case tooManyCrews
    case crewFull
    case alreadyMember
    case crewNotFound
    case wrongPassword
    case nameTaken

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in."
        case .tooManyCrews:     return "You can be in at most 5 crews."
        case .crewFull:         return "This crew is full (50 members max)."
        case .alreadyMember:    return "You're already in this crew."
        case .crewNotFound:     return "Crew not found. Check the name and try again."
        case .wrongPassword:    return "Wrong password. Ask your crew for the code."
        case .nameTaken:        return "That crew name is already taken."
        }
    }
}
