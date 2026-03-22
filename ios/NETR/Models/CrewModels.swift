import Foundation

// MARK: - Crew (maps to crews table)

nonisolated struct Crew: Identifiable, Sendable, Decodable {
    let id: String
    var name: String
    var icon: String
    let creatorId: String
    var adminId: String
    let createdAt: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, name, icon
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
    let catDribbling: Double?
    let catPassing: Double?
    let catDefense: Double?
    let catHustle: Double?
    let catSportsmanship: Double?
    let isPrimary: Bool
    let joinedAt: String?

    var displayName: String {
        if let n = fullName, !n.isEmpty { return n }
        if let u = username { return "@\(u)" }
        return "Player"
    }

    func score(for filter: CrewLeaderboardFilter) -> Double? {
        switch filter {
        case .overall:       return netrScore
        case .shooting:      return catShooting
        case .handles:       return catDribbling
        case .playmaking:    return catPassing
        case .defense:       return catDefense
        case .hustle:        return catHustle
        case .sportsmanship: return catSportsmanship
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

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case crewId    = "crew_id"
        case senderId  = "sender_id"
        case content
        case createdAt = "created_at"
    }
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

    nonisolated enum CodingKeys: String, CodingKey {
        case crewId   = "crew_id"
        case senderId = "sender_id"
        case content
    }
}

// MARK: - Leaderboard Filter

enum CrewLeaderboardFilter: String, CaseIterable {
    case overall       = "Overall"
    case shooting      = "Shooting"
    case handles       = "Handles"
    case playmaking    = "Playmaking"
    case defense       = "Defense"
    case hustle        = "Hustle"
    case sportsmanship = "Sportsmanship"

    var icon: String {
        switch self {
        case .overall:       return "trophy"
        case .shooting:      return "crosshair"
        case .handles:       return "dumbbell"
        case .playmaking:    return "route"
        case .defense:       return "shield"
        case .hustle:        return "zap"
        case .sportsmanship: return "handshake"
        }
    }
}

// MARK: - Crew Icons (15 sport-themed Lucide icons)

let crewIcons: [String] = [
    "flame", "zap", "trophy", "star", "target",
    "shield", "crown", "swords", "rocket", "activity",
    "trending-up", "award", "dumbbell", "medal", "globe"
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
