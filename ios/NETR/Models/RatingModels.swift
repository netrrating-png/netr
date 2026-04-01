import Foundation
import SwiftUI

// ─── SUBMISSION ──────────────────────────────────────────────

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
    // Single vibe question: 4=Definitely, 3=Yeah, 2=Probably Not, 1=No Thanks
    let vibeRunAgain: Int?

    nonisolated enum CodingKeys: String, CodingKey {
        case gameId          = "game_id"
        case raterId         = "rater_id"
        case ratedId         = "rated_id"
        case isSelfRating    = "is_self_rating"
        case catShooting     = "cat_shooting"
        case catFinishing    = "cat_finishing"
        case catDribbling    = "cat_dribbling"
        case catPassing      = "cat_passing"
        case catDefense      = "cat_defense"
        case catRebounding   = "cat_rebounding"
        case catBasketballIq = "cat_basketball_iq"
        case vibeRunAgain    = "vibe_run_again"
    }
}

// ─── PLAYER TO RATE ───────────────────────────────────────────

struct PlayerToRate: Identifiable {
    let id: String
    let name: String
    let username: String
    let position: String
    let avatarUrl: String?
    var currentNetr: Double?
    var currentVibe: Double?
    var skillRatings: InProgressSkillRatings = InProgressSkillRatings()
    var vibeRunAgain: Int? = 4  // Default to "Definitely" — rater must actively choose to go lower
    var isSubmitted: Bool = false

    struct InProgressSkillRatings {
        var shooting: Int?    = nil
        var finishing: Int?   = nil
        var dribbling: Int?   = nil
        var passing: Int?     = nil
        var defense: Int?     = nil
        var rebounding: Int?  = nil
        var basketballIQ: Int? = nil

        var allRated: Bool {
            [shooting, finishing, dribbling, passing, defense, rebounding, basketballIQ]
                .allSatisfy { $0 != nil }
        }
    }
}

// ─── SKILL CATEGORIES (7) ────────────────────────────────────

struct SkillCategory: Identifiable {
    let id: String
    let label: String
    let icon: String
    let description: String
    let colorHex: String

    var accentColor: Color { Color(hex: colorHex) }
}

let skillCategories: [SkillCategory] = [
    SkillCategory(id: "shooting",     label: "Shooting",    icon: "crosshair",       description: "Shot creation & consistency",      colorHex: "#39FF14"),
    SkillCategory(id: "finishing",    label: "Finishing",  icon: "dumbbell",        description: "At the rim through contact",       colorHex: "#FF7A00"),
    SkillCategory(id: "dribbling",    label: "Handles",    icon: "hand",            description: "Ball handling & shot creation",    colorHex: "#FFC247"),
    SkillCategory(id: "passing",      label: "Playmaking", icon: "route",           description: "Vision, passing & court reads",    colorHex: "#2ECC71"),
    SkillCategory(id: "defense",      label: "Defense",    icon: "shield",          description: "On-ball, help & intensity",        colorHex: "#FF3B30"),
    SkillCategory(id: "rebounding",   label: "Rebounding", icon: "arrow-up-from-line", description: "Boxing out & crashing the boards", colorHex: "#2DA8FF"),
    SkillCategory(id: "basketballIQ", label: "IQ",         icon: "brain",           description: "Spacing, reads & decision-making", colorHex: "#9B8BFF"),
]

let peerRatingLabels: [Int: String] = [
    5: "They're Better — they had me all game",
    4: "Slight Edge to Them — they outplayed me",
    3: "Dead Even — we matched up",
    2: "Slight Edge to Me — I had the upper hand",
    1: "I'm Better — I outplayed them",
]

// ─── VIBE: SINGLE "RUN AGAIN?" QUESTION ──────────────────────

struct VibeRunAgainOption: Identifiable {
    let id: Int              // 4=Definitely, 3=Yeah, 2=Probably Not, 1=No Thanks
    let label: String
    let sublabel: String
    let colorHex: String
}

let vibeRunAgainOptions: [VibeRunAgainOption] = [
    VibeRunAgainOption(id: 4, label: "Definitely",    sublabel: "First pick every time",     colorHex: "#39FF14"),
    VibeRunAgainOption(id: 3, label: "Yeah",          sublabel: "I'd run with them again",   colorHex: "#FFD700"),
    VibeRunAgainOption(id: 2, label: "Probably Not",  sublabel: "Not my first choice",       colorHex: "#FF7A00"),
    VibeRunAgainOption(id: 1, label: "No Thanks",     sublabel: "Didn't enjoy the run",      colorHex: "#FF3B30"),
]

// ─── VIBE TIER (display helper, maps vibe_score 1–4 to tier) ─

nonisolated struct VibeTier: Sendable {
    let label: String
    let emoji: String
    let sublabel: String?
    let color: VibeColor

    nonisolated enum VibeColor: Sendable {
        case great, solid, mixed, bad, none

        var red: Double {
            switch self {
            case .great: return 0.224; case .solid: return 0.961
            case .mixed: return 1.0;   case .bad:   return 1.0
            case .none:  return 0.416
            }
        }
        var green: Double {
            switch self {
            case .great: return 1.0;   case .solid: return 0.773
            case .mixed: return 0.549; case .bad:   return 0.271
            case .none:  return 0.416
            }
        }
        var blue: Double {
            switch self {
            case .great: return 0.078; case .solid: return 0.259
            case .mixed: return 0.0;   case .bad:   return 0.271
            case .none:  return 0.51
            }
        }
    }

    /// Map a raw vibe_score to a display tier.
    /// Applies provisional period (< 5 ratings = Great Vibe) and Red floor (< 7 ratings = min 2.0).
    static func from(score: Double?, ratingCount: Int? = nil) -> VibeTier? {
        guard let score else { return nil }

        let count = ratingCount ?? 999

        // Provisional period: fewer than 5 ratings → always Great Vibe
        if count < 5 {
            return VibeTier(label: "Great Vibe", emoji: "🟢", sublabel: nil, color: .great)
        }

        // Red floor protection: fewer than 7 ratings → floor at 2.0 (Mixed at worst)
        let displayScore = (count < 7 && score < 2.0) ? 2.0 : score

        switch displayScore {
        case 3.5...:       return VibeTier(label: "Great Vibe", emoji: "🟢", sublabel: nil, color: .great)
        case 2.8..<3.5:    return VibeTier(label: "Solid",      emoji: "🟡", sublabel: nil, color: .solid)
        case 2.0..<2.8:    return VibeTier(label: "Mixed",      emoji: "🟠", sublabel: "Some mixed feedback from the community", color: .mixed)
        default:           return VibeTier(label: "Bad Vibe",   emoji: "🔴", sublabel: "Consistent feedback suggests room for improvement", color: .bad)
        }
    }

    /// Returns a tier for display purposes — defaults to Great Vibe (green) for unrated players.
    static func display(score: Double?, ratingCount: Int? = nil) -> VibeTier {
        from(score: score, ratingCount: ratingCount) ?? VibeTier(label: "Great Vibe", emoji: "🟢", sublabel: nil, color: .great)
    }

    static var none: VibeTier {
        VibeTier(label: "No Vibe Yet", emoji: "⚪️", sublabel: nil, color: .none)
    }

    /// Apply decay toward green: if last rated 30+ days ago, add +0.1 per week elapsed, max 4.0
    static func applyDecay(score: Double, lastRatedAt: String?) -> Double {
        guard let lastRatedStr = lastRatedAt else { return score }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let lastRated = fmt.date(from: lastRatedStr) ?? {
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            return f2.date(from: lastRatedStr)
        }() else { return score }

        let daysSince = -lastRated.timeIntervalSinceNow / 86400
        guard daysSince > 30 else { return score }

        let weeksElapsed = (daysSince - 30) / 7
        let bonus = weeksElapsed * 0.1
        return min(score + bonus, 4.0)
    }
}
