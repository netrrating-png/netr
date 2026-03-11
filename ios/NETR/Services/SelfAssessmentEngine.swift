import Foundation
import SwiftUI

// MARK: - Gender

nonisolated enum Gender: String, CaseIterable, Sendable {
    case male = "Male"
    case female = "Female"
    case preferNotToAnswer = "Prefer not to answer"
}

// MARK: - Age Bracket

nonisolated enum AgeBracket: String, CaseIterable, Identifiable, Sendable {
    case teen = "13–18"
    case youngAdult = "19–25"
    case adult = "26–32"
    case lateAdult = "33–40"
    case masters = "41–50"
    case senior = "51+"

    var id: String { rawValue }

    var midpoint: Int {
        switch self {
        case .teen:       return 16
        case .youngAdult: return 22
        case .adult:      return 29
        case .lateAdult:  return 36
        case .masters:    return 45
        case .senior:     return 55
        }
    }

    var sublabel: String {
        switch self {
        case .teen:       return "Still developing athletically"
        case .youngAdult: return "Physical prime"
        case .adult:      return "Prime or near-prime"
        case .lateAdult:  return "Experience starts compensating"
        case .masters:    return "Vet game, some athletic decline"
        case .senior:     return "Pure IQ and experience"
        }
    }

    var athleticModifier: Double {
        switch self {
        case .teen:       return 0.97
        case .youngAdult: return 1.00
        case .adult:      return 0.97
        case .lateAdult:  return 0.91
        case .masters:    return 0.85
        case .senior:     return 0.82
        }
    }
}

// MARK: - Player Position

nonisolated enum PlayerPosition: String, CaseIterable, Identifiable, Sendable {
    case pg = "pg"
    case sg = "sg"
    case sf = "sf"
    case pf = "pf"
    case c  = "c"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pg: return "Point Guard"
        case .sg: return "Shooting Guard"
        case .sf: return "Small Forward"
        case .pf: return "Power Forward"
        case .c:  return "Center"
        }
    }

    var shortLabel: String {
        switch self {
        case .pg: return "PG"
        case .sg: return "SG"
        case .sf: return "SF"
        case .pf: return "PF"
        case .c:  return "C"
        }
    }

    var categoryWeightOverrides: [String: Double] {
        switch self {
        case .pg:
            return [
                "scoring": 0.85, "iq": 1.35, "defense": 0.90,
                "handles": 1.35, "playmaking": 1.35, "finishing": 0.75, "rebounding": 0.45,
            ]
        case .sg:
            return [
                "scoring": 1.25, "iq": 1.00, "defense": 0.95,
                "handles": 1.05, "playmaking": 0.85, "finishing": 1.10, "rebounding": 0.65,
            ]
        case .sf:
            return [
                "scoring": 1.05, "iq": 1.05, "defense": 1.10,
                "handles": 0.90, "playmaking": 0.95, "finishing": 1.05, "rebounding": 0.90,
            ]
        case .pf:
            return [
                "scoring": 0.90, "iq": 1.00, "defense": 1.15,
                "handles": 0.65, "playmaking": 0.75, "finishing": 1.15, "rebounding": 1.35,
            ]
        case .c:
            return [
                "scoring": 0.70, "iq": 0.95, "defense": 1.20,
                "handles": 0.40, "playmaking": 0.65, "finishing": 1.20, "rebounding": 1.55,
            ]
        }
    }

    init?(from position: Position) {
        switch position {
        case .pg: self = .pg
        case .sg: self = .sg
        case .sf: self = .sf
        case .pf: self = .pf
        case .c:  self = .c
        case .unknown: return nil
        }
    }
}

// MARK: - SA Question Models

nonisolated struct SAQuestion: Identifiable, Sendable {
    let id: Int
    let category: String
    let prompt: String
    let options: [SAOption]
}

nonisolated struct SAOption: Sendable {
    let emoji: String
    let label: String
    let detail: String
    let score: Double
}

// MARK: - 15 Questions

nonisolated enum SAQuestionBank: Sendable {
    static let all: [SAQuestion] = [

    // SCORING (Q1, Q2, Q3)
    SAQuestion(id: 1, category: "scoring",
        prompt: "When you're open on the perimeter, what usually happens?",
        options: [
            SAOption(emoji: "🙅", label: "I usually pass it up", detail: "I don't feel comfortable taking that shot", score: 0.05),
            SAOption(emoji: "📍", label: "Only if it's a very comfortable spot", detail: "Very selective — ideal look only", score: 0.28),
            SAOption(emoji: "✅", label: "I'll take it with decent confidence", detail: "I back myself from the perimeter when I'm open", score: 0.52),
            SAOption(emoji: "⚡", label: "I'm a real shooting threat from outside", detail: "The defense has to respect me and close out hard", score: 0.75),
            SAOption(emoji: "🔒", label: "Defenders have to stay attached to me", detail: "My shot changes how the whole team is guarded", score: 0.92),
        ]),
    SAQuestion(id: 2, category: "scoring",
        prompt: "How well can you create a shot for yourself?",
        options: [
            SAOption(emoji: "🙅", label: "I rarely create my own shot", detail: "I need the ball ready to go — I can't manufacture looks", score: 0.05),
            SAOption(emoji: "🤞", label: "I can get one occasionally", detail: "Every now and then, but it's not reliable", score: 0.28),
            SAOption(emoji: "✅", label: "I can create decent looks in rhythm", detail: "I get myself open shots with regularity when things are flowing", score: 0.52),
            SAOption(emoji: "🎯", label: "I create good looks consistently", detail: "I manufacture shots for myself in most situations", score: 0.75),
            SAOption(emoji: "🔥", label: "I can get to my spots against almost anyone", detail: "Shot creation is a strength — quality looks regardless of defense", score: 0.92),
        ]),
    SAQuestion(id: 3, category: "scoring",
        prompt: "How do the people you play with usually view you as a scorer?",
        options: [
            SAOption(emoji: "👻", label: "Not really a scoring option", detail: "Nobody expects me to score — that's not my role", score: 0.05),
            SAOption(emoji: "🤝", label: "I score here and there", detail: "I contribute occasionally but I'm not someone they're looking to feed", score: 0.28),
            SAOption(emoji: "✅", label: "I'm a reliable scoring option", detail: "Teammates trust me to score when I get the ball in good spots", score: 0.52),
            SAOption(emoji: "⭐", label: "I'm one of the main scoring threats", detail: "I'm a consistent go-to — teams build looks for me", score: 0.75),
            SAOption(emoji: "🎯", label: "Defenses clearly key in on me", detail: "I'm the player they game-plan for — and I still score", score: 0.92),
        ]),

    // IQ (Q4, Q5)
    SAQuestion(id: 4, category: "iq",
        prompt: "How well do you use screens in live play?",
        options: [
            SAOption(emoji: "😅", label: "I don't really know how to use them well", detail: "I run off them but I'm not making reads or setting anything up", score: 0.05),
            SAOption(emoji: "🚶", label: "I use them basically, without many reads", detail: "I know to come off the screen but I'm not reading the coverage", score: 0.28),
            SAOption(emoji: "👀", label: "I can make simple reads off them", detail: "I can tell the difference between a curl and a fade", score: 0.52),
            SAOption(emoji: "🧩", label: "I set defenders up and use screens with purpose", detail: "I time and use screens deliberately to create advantages", score: 0.75),
            SAOption(emoji: "🎓", label: "I consistently exploit coverages and create advantages", detail: "I read switch, hedge, ICE — and punish each one differently", score: 0.92),
        ]),
    SAQuestion(id: 5, category: "iq",
        prompt: "In close games, how aware are you of time, score, spacing, and matchups?",
        options: [
            SAOption(emoji: "🙈", label: "I mostly just play without thinking about that", detail: "I'm focused on the action in front of me, not the big picture", score: 0.05),
            SAOption(emoji: "🤷", label: "I notice some of it, but not consistently", detail: "I pick up on it sometimes but miss things regularly", score: 0.28),
            SAOption(emoji: "🧠", label: "I usually understand the situation", detail: "I know the score, the clock, and who to go to", score: 0.52),
            SAOption(emoji: "🗣️", label: "I help organize and execute in big moments", detail: "I'm communicating and making sure we run the right things", score: 0.75),
            SAOption(emoji: "👑", label: "I see the game a step ahead of most players", detail: "I process matchups, spacing, and situations before they fully develop", score: 0.92),
        ]),

    // DEFENSE (Q6, Q7)
    SAQuestion(id: 6, category: "defense",
        prompt: "How do you usually defend 1-on-1?",
        options: [
            SAOption(emoji: "😬", label: "I get beat a lot", detail: "I struggle to stay in front of people consistently", score: 0.05),
            SAOption(emoji: "🤷", label: "I compete, but I'm not very effective", detail: "I try, but good offensive players get past me more often than not", score: 0.28),
            SAOption(emoji: "💪", label: "I can hold my own", detail: "I compete and make them work — I'm not a liability", score: 0.52),
            SAOption(emoji: "🛡️", label: "I make good scorers work hard", detail: "Solid players can score on me but have to earn every bucket", score: 0.75),
            SAOption(emoji: "🔒", label: "I consistently shut down my matchup", detail: "I lock people up regularly — my matchup knows they're in for a tough night", score: 0.92),
        ]),
    SAQuestion(id: 7, category: "defense",
        prompt: "How good are you away from the ball on defense?",
        options: [
            SAOption(emoji: "😴", label: "I ball-watch and miss rotations", detail: "I follow the ball instead of staying connected to my man", score: 0.05),
            SAOption(emoji: "🙂", label: "I mostly just stay near my man", detail: "I keep tabs on my player but don't make team plays", score: 0.28),
            SAOption(emoji: "✅", label: "I make normal help and recovery rotations", detail: "I rotate when it's clear and get back to my man", score: 0.52),
            SAOption(emoji: "🗣️", label: "I rotate early and communicate well", detail: "I call out screens, hedge, and help before breakdowns happen", score: 0.75),
            SAOption(emoji: "🧱", label: "I anchor and organize the defense", detail: "I direct the whole team — I see breakdowns forming and fix them early", score: 0.92),
        ]),

    // HANDLES (Q8, Q9)
    SAQuestion(id: 8, category: "handles",
        prompt: "How comfortable are you handling the ball under pressure?",
        options: [
            SAOption(emoji: "😰", label: "I really struggle with pressure", detail: "It disrupts me — I pick it up early or turn it over", score: 0.05),
            SAOption(emoji: "😬", label: "I survive, but just barely", detail: "I get through it but I'm not doing anything creative", score: 0.28),
            SAOption(emoji: "✅", label: "I'm generally comfortable", detail: "Pressure doesn't bother me — I keep things moving", score: 0.52),
            SAOption(emoji: "🔥", label: "I handle pressure and create advantages", detail: "I break pressure and use it to attack the defense", score: 0.75),
            SAOption(emoji: "💨", label: "Pressure helps me attack and break down the defense", detail: "I want teams to press me — it opens things up", score: 0.92),
        ]),
    SAQuestion(id: 9, category: "handles",
        prompt: "How deep is your handle in real games?",
        options: [
            SAOption(emoji: "1️⃣", label: "Very basic", detail: "Simple dribble to move — not a creation tool", score: 0.05),
            SAOption(emoji: "2️⃣", label: "A couple dependable moves", detail: "Crossover or hesitation — a few things that work at this level", score: 0.28),
            SAOption(emoji: "🎒", label: "Multiple moves with some counters", detail: "I have a real bag and can counter when my first move is taken", score: 0.52),
            SAOption(emoji: "🧙", label: "I can chain moves together and shift defenders", detail: "I keep defenders guessing and get where I want on the floor", score: 0.75),
            SAOption(emoji: "💫", label: "My handle creates offense for me and others consistently", detail: "My dribble is a weapon — it creates advantages for the whole team", score: 0.92),
        ]),

    // PLAYMAKING (Q10, Q11)
    SAQuestion(id: 10, category: "playmaking",
        prompt: "How often do you create easy baskets for other players?",
        options: [
            SAOption(emoji: "🙅", label: "Rarely", detail: "I'm not looking to create for others — I play my own game", score: 0.05),
            SAOption(emoji: "🤝", label: "Mostly only simple passes", detail: "Basic kick-outs and handoffs — nothing requiring real vision", score: 0.28),
            SAOption(emoji: "🎯", label: "Pretty often", detail: "I find open teammates consistently and set them up in good spots", score: 0.52),
            SAOption(emoji: "⭐", label: "I create good looks consistently", detail: "Teammates trust me to get them open — I'm a real facilitator", score: 0.75),
            SAOption(emoji: "🎩", label: "Creating for others is one of my biggest strengths", detail: "I see angles others miss and find teammates in high-percentage spots", score: 0.92),
        ]),
    SAQuestion(id: 11, category: "playmaking",
        prompt: "When you drive and help collapses, what usually happens?",
        options: [
            SAOption(emoji: "💥", label: "I force the shot too often", detail: "I keep going regardless — the kick-out doesn't come naturally", score: 0.05),
            SAOption(emoji: "😬", label: "I pass late or only when stuck", detail: "I'll kick it out but only once I'm fully stopped", score: 0.28),
            SAOption(emoji: "👁️", label: "I usually make the right read", detail: "I can tell if I should finish or kick — and I usually choose correctly", score: 0.52),
            SAOption(emoji: "🎯", label: "I draw help on purpose and find the open man", detail: "I attack the paint with the intention of collapsing the defense", score: 0.75),
            SAOption(emoji: "🎬", label: "I manipulate the defense before it fully reacts", detail: "I create the advantage before the help arrives — I'm a step ahead", score: 0.92),
        ]),

    // FINISHING (Q12, Q13)
    SAQuestion(id: 12, category: "finishing",
        prompt: "How well do you finish at the rim with defenders around you?",
        options: [
            SAOption(emoji: "😬", label: "I struggle once there's contact", detail: "Contact takes me off my shot — I need a clean path", score: 0.05),
            SAOption(emoji: "🤞", label: "I finish mostly when the lane is clean", detail: "I can score with a clear look, but contact is a problem", score: 0.28),
            SAOption(emoji: "✅", label: "I finish through light contact", detail: "A hand or body doesn't stop me — I finish with decent reliability", score: 0.52),
            SAOption(emoji: "🏆", label: "I finish well through real contests", detail: "I score through legit defenders — I have counters at the rim", score: 0.75),
            SAOption(emoji: "🔥", label: "I finish through heavy contact and draw fouls", detail: "Contact doesn't stop me — I absorb it, score, and get to the line", score: 0.92),
        ]),
    SAQuestion(id: 13, category: "finishing",
        prompt: "How many ways can you finish around the basket?",
        options: [
            SAOption(emoji: "1️⃣", label: "Mostly one way with one hand", detail: "I have a go-to finish and that's about it", score: 0.05),
            SAOption(emoji: "2️⃣", label: "A couple basic finishes", detail: "A layup and maybe a floater or reverse", score: 0.28),
            SAOption(emoji: "✅", label: "I can use either hand in the right situations", detail: "Functional finishes with both hands when the defense dictates", score: 0.52),
            SAOption(emoji: "💪", label: "I have multiple finishes and counters", detail: "I adjust on the fly — I'm not predictable at the rim", score: 0.75),
            SAOption(emoji: "🎯", label: "I can finish with either hand from different angles consistently", detail: "Defenders can't take a side on me — I go through, around, or over", score: 0.92),
        ]),

    // REBOUNDING (Q14, Q15)
    SAQuestion(id: 14, category: "rebounding",
        prompt: "When a shot goes up, what are you usually doing?",
        options: [
            SAOption(emoji: "👀", label: "Watching the play", detail: "I see who gets it — I'm not chasing the ball", score: 0.05),
            SAOption(emoji: "🚶", label: "Moving toward the ball late", detail: "I react after it's off the rim — I'm not anticipating", score: 0.28),
            SAOption(emoji: "📦", label: "Finding position and boxing out", detail: "I make contact and go after it — I'm a real factor on the glass", score: 0.52),
            SAOption(emoji: "🏃", label: "Reading the miss and getting into position early", detail: "I track the shot and have my body in place before it hits the iron", score: 0.75),
            SAOption(emoji: "🧲", label: "Anticipating the rebound before most players do", detail: "I read arc and angle — I'm already there before the ball comes down", score: 0.92),
        ]),
    SAQuestion(id: 15, category: "rebounding",
        prompt: "How much of an impact do you make on the glass in your games?",
        options: [
            SAOption(emoji: "❌", label: "Rebounding is not part of my game", detail: "I don't factor into it — other roles take priority for me", score: 0.05),
            SAOption(emoji: "🤷", label: "I grab a few if they come to me", detail: "I get boards when they happen to be there, but I don't seek them", score: 0.28),
            SAOption(emoji: "🙋", label: "I'm a solid rebounder for my role", detail: "I contribute consistently on the glass relative to my position", score: 0.52),
            SAOption(emoji: "💪", label: "I'm one of the better rebounders in most games", detail: "I lead or co-lead my team on the boards most nights", score: 0.75),
            SAOption(emoji: "🦁", label: "Rebounding is one of my biggest strengths", detail: "It's a weapon — I dominate the glass and teams notice", score: 0.92),
        ]),
    ]
}

// MARK: - SA Scorer

nonisolated enum SAScorer: Sendable {
    static let selfAssessmentDiscount = 0.72
    static let absoluteCeiling = 7.0
    static let absoluteFloor = 1.0

    static let baseWeights: [String: Double] = [
        "scoring": 1.0, "iq": 1.15, "defense": 1.0,
        "handles": 0.9, "playmaking": 1.0, "finishing": 0.9, "rebounding": 0.85,
    ]

    static func calculate(
        answers: [Int: Int],
        gender: Gender,
        ageBracket: AgeBracket,
        position: PlayerPosition
    ) -> Double {
        var rawByCategory: [String: [Double]] = [:]
        let questions = SAQuestionBank.all
        for q in questions {
            guard let idx = answers[q.id], idx < q.options.count else { continue }
            rawByCategory[q.category, default: []].append(q.options[idx].score)
        }

        var categoryAvg: [String: Double] = [:]
        for (cat, scores) in rawByCategory {
            categoryAvg[cat] = scores.reduce(0, +) / Double(scores.count)
        }

        var discounted: [String: Double] = [:]
        for (cat, avg) in categoryAvg {
            discounted[cat] = avg * selfAssessmentDiscount
        }

        let posOverrides = position.categoryWeightOverrides
        let ageMod = ageBracket.athleticModifier

        var netrByCategory: [String: Double] = [:]
        for (cat, d) in discounted {
            let mapped = absoluteFloor + d * (absoluteCeiling - absoluteFloor)
            let aged = mapped * ageMod
            netrByCategory[cat] = min(max(aged, absoluteFloor), absoluteCeiling)
        }

        for cat in baseWeights.keys where netrByCategory[cat] == nil {
            netrByCategory[cat] = absoluteFloor
        }

        var wSum = 0.0, wTotal = 0.0
        for (cat, netr) in netrByCategory {
            let w = (baseWeights[cat] ?? 1.0) * (posOverrides[cat] ?? 1.0)
            wSum += netr * w
            wTotal += w
        }

        let overall = wTotal > 0 ? wSum / wTotal : absoluteFloor
        return min(max(overall, absoluteFloor), absoluteCeiling)
    }

    static func calculateCategoryScores(
        answers: [Int: Int],
        ageBracket: AgeBracket,
        position: PlayerPosition
    ) -> [String: Double] {
        var rawByCategory: [String: [Double]] = [:]
        let questions = SAQuestionBank.all
        for q in questions {
            guard let idx = answers[q.id], idx < q.options.count else { continue }
            rawByCategory[q.category, default: []].append(q.options[idx].score)
        }

        var categoryAvg: [String: Double] = [:]
        for (cat, scores) in rawByCategory {
            categoryAvg[cat] = scores.reduce(0, +) / Double(scores.count)
        }

        var discounted: [String: Double] = [:]
        for (cat, avg) in categoryAvg {
            discounted[cat] = avg * selfAssessmentDiscount
        }

        let ageMod = ageBracket.athleticModifier
        var netrByCategory: [String: Double] = [:]
        for (cat, d) in discounted {
            let mapped = absoluteFloor + d * (absoluteCeiling - absoluteFloor)
            let aged = mapped * ageMod
            netrByCategory[cat] = min(max(aged, absoluteFloor), absoluteCeiling)
        }

        for cat in baseWeights.keys where netrByCategory[cat] == nil {
            netrByCategory[cat] = absoluteFloor
        }

        return netrByCategory
    }

    static func tierLabel(_ r: Double) -> String {
        switch r {
        case 9.5...:    return "NBA Level"
        case 9.0..<9.5: return "Elite Pro"
        case 8.0..<9.0: return "Elite"
        case 7.0..<8.0: return "D3 / High-Level Amateur"
        case 6.0..<7.0: return "Park Legend"
        case 5.0..<6.0: return "Park Dominant"
        case 4.0..<5.0: return "Above Average"
        case 3.0..<4.0: return "Recreational"
        case 2.0..<3.0: return "Developing"
        default:        return "Just Getting Started"
        }
    }

    static func tierColor(_ r: Double) -> Color {
        switch r {
        case 7...:    return NETRTheme.neonGreen
        case 5..<7:   return Color(red: 0.224, green: 1.0, blue: 0.078)
        case 3.5..<5: return NETRTheme.gold
        default:      return NETRTheme.red
        }
    }
}

// MARK: - Legacy Types (kept for profile/radar compatibility)

nonisolated struct AssessmentResult: Sendable {
    let overallScore: Double
    let categoryScores: [String: Double]
    let strengths: [String]
    let focusAreas: [String]
    let tierLabel: String
    let tierColorHex: String

    var formattedScore: String { String(format: "%.1f", overallScore) }

    static let categoryDisplayNames: [String: String] = [
        "scoring": "Scoring", "iq": "IQ", "defense": "Defense",
        "handles": "Handles", "playmaking": "Playmaking",
        "finishing": "Finishing", "rebounding": "Rebounding",
    ]

    static let categoryIcons: [String: String] = [
        "scoring": "scope", "iq": "brain", "defense": "shield.fill",
        "handles": "hand.raised.fill", "playmaking": "bolt.fill",
        "finishing": "flame.fill", "rebounding": "arrow.up.circle",
    ]

    func radarDotColorHex(for cat: String) -> String {
        guard let s = categoryScores[cat] else { return "#333333" }
        switch s {
        case 6...:      return "#00FF41"
        case 4.5..<6:   return "#4A9EFF"
        case 3.0..<4.5: return "#F5C542"
        default:        return "#FF453A"
        }
    }

    func radarDotLabel(for cat: String) -> String {
        guard let s = categoryScores[cat] else { return "N/A" }
        switch s {
        case 6...:      return "Strong"
        case 4.5..<6:   return "Solid"
        case 3.0..<4.5: return "Developing"
        default:        return "Focus area"
        }
    }
}
