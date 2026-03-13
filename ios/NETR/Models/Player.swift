import Foundation

nonisolated struct SkillRatings: Sendable, Equatable {
    var shooting: Double?
    var finishing: Double?
    var ballHandling: Double?
    var playmaking: Double?
    var defense: Double?
    var rebounding: Double?
    var basketballIQ: Double?

    var overall: Double? {
        let values = [shooting, finishing, ballHandling, playmaking, defense, rebounding, basketballIQ].compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

nonisolated enum PlayerTier: String, Sendable {
    case verified
    case basic
    case prospect
}

nonisolated enum Position: String, Sendable, CaseIterable, Identifiable {
    case pg = "PG"
    case sg = "SG"
    case sf = "SF"
    case pf = "PF"
    case c = "C"
    case unknown = "?"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .pg: return "Point Guard"
        case .sg: return "Shooting Guard"
        case .sf: return "Small Forward"
        case .pf: return "Power Forward"
        case .c: return "Center"
        case .unknown: return "I Don't Know Yet"
        }
    }

    var shortDesc: String {
        switch self {
        case .pg: return "Floor general, runs the offense"
        case .sg: return "Scorer, wings, handles the ball"
        case .sf: return "Versatile, attacks from anywhere"
        case .pf: return "Physical, interior and stretch"
        case .c: return "Paint presence, rebounding, rim protection"
        case .unknown: return "No worries, you can update this later"
        }
    }

    var icon: String {
        switch self {
        case .pg: return "route"
        case .sg: return "crosshair"
        case .sf: return "git-branch"
        case .pf: return "dumbbell"
        case .c: return "shield"
        case .unknown: return "help-circle"
        }
    }
}

nonisolated enum TrendDirection: String, Sendable {
    case up, down, stable, none
}

struct Player: Identifiable, Equatable {
    let id: Int
    var name: String
    var username: String
    var avatar: String
    var rating: Double?
    var reviews: Int
    var age: Int
    var tier: PlayerTier
    var city: String
    var position: Position
    var trend: TrendDirection
    var games: Int
    var isProspect: Bool
    var skills: SkillRatings
    var profileImageData: Data?
    var avatarUrl: String?

    var isProvisional: Bool { reviews < 5 }
    var isVerified: Bool { tier == .verified && reviews >= 5 }

    var ratingTierName: String {
        if isProspect { return "Prospect" }
        return NETRRating.tierName(for: rating)
    }
}
