import Foundation

nonisolated struct RatingSubmission: Encodable, Sendable {
    let gameId: String
    let raterId: String
    let ratedId: String
    let isSelfRating: Bool
    let catShooting: Int?
    let catFinishing: Int?
    let catDribbling: Int?
    let catPassing: Int?
    let catDefense: Int?
    let catRebounding: Int?
    let catBasketballIq: Int?
    let vibeCommunication: Int?
    let vibeUnselfishness: Int?
    let vibeEffort: Int?
    let vibeAttitude: Int?
    let vibeInclusion: Int?

    nonisolated enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case raterId = "rater_id"
        case ratedId = "rated_id"
        case isSelfRating = "is_self_rating"
        case catShooting = "cat_shooting"
        case catFinishing = "cat_finishing"
        case catDribbling = "cat_dribbling"
        case catPassing = "cat_passing"
        case catDefense = "cat_defense"
        case catRebounding = "cat_rebounding"
        case catBasketballIq = "cat_basketball_iq"
        case vibeCommunication = "vibe_communication"
        case vibeUnselfishness = "vibe_unselfishness"
        case vibeEffort = "vibe_effort"
        case vibeAttitude = "vibe_attitude"
        case vibeInclusion = "vibe_inclusion"
    }
}

struct PlayerToRate: Identifiable {
    let id: String
    let name: String
    let username: String
    let position: String
    let avatarUrl: String?
    var currentNetr: Double?
    var currentVibe: Double?
    var skillRatings: InProgressSkillRatings = InProgressSkillRatings()
    var vibeRatings: InProgressVibeRatings = InProgressVibeRatings()
    var isSubmitted: Bool = false

    struct InProgressSkillRatings {
        var shooting: Int? = nil
        var finishing: Int? = nil
        var dribbling: Int? = nil
        var passing: Int? = nil
        var defense: Int? = nil
        var rebounding: Int? = nil
        var basketballIQ: Int? = nil
    }

    struct InProgressVibeRatings {
        var communication: Int? = nil
        var unselfishness: Int? = nil
        var effort: Int? = nil
        var attitude: Int? = nil
        var inclusion: Int? = nil
    }
}

nonisolated struct VibeTier: Sendable {
    let label: String
    let emoji: String
    let color: VibeColor

    nonisolated enum VibeColor: Sendable {
        case great
        case solid
        case mixed
        case bad
        case none

        var red: Double {
            switch self {
            case .great: return 0.224
            case .solid: return 0.961
            case .mixed: return 1.0
            case .bad: return 1.0
            case .none: return 0.416
            }
        }

        var green: Double {
            switch self {
            case .great: return 1.0
            case .solid: return 0.773
            case .mixed: return 0.549
            case .bad: return 0.271
            case .none: return 0.416
            }
        }

        var blue: Double {
            switch self {
            case .great: return 0.078
            case .solid: return 0.259
            case .mixed: return 0.0
            case .bad: return 0.271
            case .none: return 0.51
            }
        }
    }

    static func from(score: Double?) -> VibeTier? {
        guard let score else { return nil }
        switch score {
        case 4.5...: return VibeTier(label: "Great Vibe", emoji: "🟢", color: .great)
        case 3.5..<4.5: return VibeTier(label: "Solid", emoji: "🟡", color: .solid)
        case 2.5..<3.5: return VibeTier(label: "Mixed", emoji: "🟠", color: .mixed)
        default: return VibeTier(label: "Bad Vibe", emoji: "🔴", color: .bad)
        }
    }

    static var none: VibeTier {
        VibeTier(label: "No Vibe Yet", emoji: "⚪️", color: .none)
    }
}

struct SkillCategory: Identifiable {
    let id: String
    let label: String
    let icon: String
    let description: String
}

let skillCategories: [SkillCategory] = [
    SkillCategory(id: "shooting", label: "Scoring", icon: "scope", description: "Can they create and hit shots consistently?"),
    SkillCategory(id: "finishing", label: "Finishing", icon: "flame.fill", description: "Finishing at the rim through contact and traffic."),
    SkillCategory(id: "dribbling", label: "Handles", icon: "figure.basketball", description: "Ball handling, getting to their spot, breaking defenders."),
    SkillCategory(id: "passing", label: "Playmaking", icon: "point.topleft.down.to.point.bottomright.curvepath", description: "Court vision, decision-making, setting teammates up."),
    SkillCategory(id: "defense", label: "Defense", icon: "shield.fill", description: "On-ball, help-side, effort on the defensive end."),
    SkillCategory(id: "rebounding", label: "Rebounding", icon: "arrow.up.circle.fill", description: "Crashing the boards, boxing out, second chances."),
    SkillCategory(id: "basketballIQ", label: "IQ", icon: "brain", description: "Spacing, reads, off-ball movement, decision-making."),
]

struct VibeCategory: Identifiable {
    let id: String
    let label: String
    let icon: String
    let description: String
}

let vibeCategories: [VibeCategory] = [
    VibeCategory(id: "communication", label: "Communication", icon: "megaphone.fill", description: "Calls fouls fairly, communicates on defense."),
    VibeCategory(id: "unselfishness", label: "Unselfishness", icon: "person.2.fill", description: "Moves the ball, doesn't force, includes teammates."),
    VibeCategory(id: "effort", label: "Effort", icon: "bolt.fill", description: "Plays hard the whole game, doesn't dog it."),
    VibeCategory(id: "attitude", label: "Attitude", icon: "face.smiling.inverse", description: "Handles wins and losses with respect."),
    VibeCategory(id: "inclusion", label: "Inclusion", icon: "hand.raised.fill", description: "Doesn't freeze out weaker players."),
]

let peerRatingLabels: [Int: String] = [
    5: "Elite — one of the best I've played with",
    4: "Stood out — real game, real impact",
    3: "Held their own — competed, contributed",
    2: "Below this level — struggled to keep up",
    1: "Clearly out of place at this level",
]

let vibeRatingLabels: [Int: String] = [
    5: "Perfect — wouldn't change a thing",
    4: "Good energy — easy to run with",
    3: "Fine — no major issues",
    2: "Annoying — affected the run",
    1: "Ruined the vibe",
]
