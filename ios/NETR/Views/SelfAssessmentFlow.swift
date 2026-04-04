import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────
// MARK: — Enums
// ─────────────────────────────────────────────────────────────

enum Gender: String, CaseIterable, Identifiable {
    case male = "Male", female = "Female", preferNot = "Prefer Not to Say"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .male, .female: return "person.fill"
        case .preferNot:     return "eye.slash.fill"
        }
    }
}

enum SAPosition: String, CaseIterable, Identifiable {
    case pg = "Point Guard", sg = "Shooting Guard", sf = "Small Forward"
    case pf = "Power Forward", c = "Center", notSure = "Not Sure Yet"
    var id: String { rawValue }

    // Ordered roster positions (excludes notSure for adjacency checks)
    static let ordered: [SAPosition] = [.pg, .sg, .sf, .pf, .c]

    func isAdjacent(to other: SAPosition) -> Bool {
        guard self != .notSure, other != .notSure else { return false }
        guard let i1 = SAPosition.ordered.firstIndex(of: self),
              let i2 = SAPosition.ordered.firstIndex(of: other) else { return false }
        return abs(i1 - i2) == 1
    }
    var short: String {
        switch self {
        case .pg: return "PG"; case .sg: return "SG"; case .sf: return "SF"
        case .pf: return "PF"; case .c:  return "C"; case .notSure: return "?"
        }
    }
    var icon: String {
        switch self {
        case .pg:      return "arrow.left.and.right.circle.fill"
        case .sg:      return "scope"
        case .sf:      return "figure.run"
        case .pf:      return "rectangle.compress.vertical"
        case .c:       return "arrow.up.circle.fill"
        case .notSure: return "questionmark.circle.fill"
        }
    }
    var description: String {
        switch self {
        case .pg:      return "Ball handler, playmaker"
        case .sg:      return "Scorer, off-ball threat"
        case .sf:      return "Versatile, can do it all"
        case .pf:      return "Physical, interior presence"
        case .c:       return "Paint presence, rebounder"
        case .notSure: return "All categories weighted equally"
        }
    }
}

enum PlayLevel: String, CaseIterable, Identifiable {
    case nba       = "Pro / NBA / Overseas"
    case d1        = "College D1"
    case d2d3      = "College D2 / D3"
    case hsVarsity = "High School Varsity"
    case hsJV      = "High School JV"
    case aau       = "AAU / Travel Ball"
    case rec       = "Rec League / Organized"
    case pickup    = "Pickup Only"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nba:       return "star.fill"
        case .d1:        return "rosette"
        case .d2d3:      return "medal.fill"
        case .hsVarsity: return "checkmark.seal.fill"
        case .hsJV:      return "checkmark.circle.fill"
        case .aau:       return "figure.run.circle.fill"
        case .rec:       return "person.3.fill"
        case .pickup:    return "basketball.fill"
        }
    }
    var iconColor: Color {
        switch self {
        case .nba:       return Color(hex: "#C40010")
        case .d1:        return Color(hex: "#FF3B30")
        case .d2d3:      return Color(hex: "#FF7A00")
        case .hsVarsity: return Color(hex: "#FFC247")
        case .hsJV:      return Color(hex: "#39FF14")
        case .aau:       return Color(hex: "#2ECC71")
        case .rec:       return Color(hex: "#2DA8FF")
        case .pickup:    return Color(hex: "#9B8BFF")
        }
    }

    // Internal ceiling — never displayed to users
    var baseCeiling: Double {
        switch self {
        case .nba:       return 9.9
        case .d1:        return 7.8
        case .d2d3:      return 7.2
        case .hsVarsity: return 6.8
        case .hsJV:      return 6.2
        case .aau:       return 6.4
        case .rec:       return 6.0
        case .pickup:    return 5.5
        }
    }

    // Internal floor — guarantees a minimum score for the playing level
    // regardless of how conservatively someone answers. After the 28%
    // self-assessment discount the achievable ceiling is floor+(ceiling-floor)*0.72.
    var baseFloor: Double {
        switch self {
        case .nba:       return 8.5
        case .d1:        return 6.2
        case .d2d3:      return 5.7
        case .hsVarsity: return 5.3
        case .hsJV:      return 4.7
        case .aau:       return 5.0
        case .rec:       return 3.5
        case .pickup:    return 2.5
        }
    }

    // Per-level age decay — internal, never shown to users.
    //
    // Decay is years-past the typical exit age for each level.
    // The slope is shallower for higher-level players whose skills
    // are more deeply ingrained from structured training.
    //
    // Typical active windows used:
    //   Pro/NBA      active ~22-33,  exit ~33
    //   D1 / D2/D3   active ~18-22,  exit ~22
    //   AAU/Travel   active ~13-18,  exit ~18
    //   HS Varsity   active ~15-18,  exit ~18
    //   HS JV        active ~14-16,  exit ~16
    //   Rec/Pickup   ongoing — only physical decay by age bracket
    static func ageDecay(level: PlayLevel, age: Int, isCurrent: Bool) -> Double {
        guard !isCurrent else { return 1.0 }
        switch level {

        // Pro — deepest skill ingrained, slowest decay slope
        case .nba:
            let yp = max(0, age - 33)
            switch yp {
            case 0:       return 1.00
            case 1...3:   return 0.98
            case 4...7:   return 0.95
            case 8...12:  return 0.91
            default:      return 0.86
            }

        // D1 — high-level structured training, moderate-shallow decay
        // A 30-yr-old D1 player is only ~8 yrs out — less penalty than HS
        case .d1:
            let yp = max(0, age - 22)
            switch yp {
            case 0...2:   return 1.00
            case 3...5:   return 0.97
            case 6...9:   return 0.94
            case 10...14: return 0.90
            default:      return 0.85
            }

        // D2/D3 — solid college ball, slightly steeper than D1
        case .d2d3:
            let yp = max(0, age - 22)
            switch yp {
            case 0...2:   return 1.00
            case 3...5:   return 0.96
            case 6...9:   return 0.92
            case 10...14: return 0.87
            default:      return 0.82
            }

        // AAU — high-intensity club ball, exit ~18
        // A 30-yr-old ex-AAU player is 12 yrs out
        case .aau:
            let yp = max(0, age - 18)
            switch yp {
            case 0...2:   return 1.00
            case 3...5:   return 0.95
            case 6...9:   return 0.90
            case 10...14: return 0.84
            default:      return 0.78
            }

        // HS Varsity — exit ~18, steeper slope than AAU
        // A 30-yr-old Varsity player: same gap as AAU but lower skill baseline
        case .hsVarsity:
            let yp = max(0, age - 18)
            switch yp {
            case 0...2:   return 1.00
            case 3...5:   return 0.94
            case 6...9:   return 0.88
            case 10...14: return 0.81
            default:      return 0.74
            }

        // HS JV — exit ~16, steepest decay (youngest exit, lowest ceiling)
        // Even a 25-yr-old ex-JV player is ~9 years removed
        case .hsJV:
            let yp = max(0, age - 16)
            switch yp {
            case 0...2:   return 1.00
            case 3...5:   return 0.93
            case 6...9:   return 0.86
            case 10...14: return 0.78
            default:      return 0.70
            }

        // Rec / Pickup — no fixed exit age; physical decay by age bracket only
        case .rec, .pickup:
            switch age {
            case ..<25:   return 1.00
            case 25...30: return 0.97
            case 31...37: return 0.93
            case 38...44: return 0.87
            default:      return 0.80
            }
        }
    }
}

enum SAPlayFrequency: String, CaseIterable, Identifiable {
    case daily   = "Multiple times a week"
    case weekly  = "Once a week"
    case monthly = "Few times a month"
    case rarely  = "Whenever I get the chance, but not often"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .daily:   return "flame.fill"
        case .weekly:  return "calendar.badge.checkmark"
        case .monthly: return "calendar"
        case .rarely:  return "moon.zzz.fill"
        }
    }
    // Internal — never shown to users
    var modifier: Double {
        switch self {
        case .daily:   return 1.00
        case .weekly:  return 0.95
        case .monthly: return 0.88
        case .rarely:  return 0.80
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Skill Categories
// ─────────────────────────────────────────────────────────────

enum SASkillCategory: String, CaseIterable {
    case shooting   = "Shooting"
    case finishing  = "Finishing"
    case rebounding = "Rebounding"
    case handles    = "Handles"
    case passing    = "Passing"
    case iq         = "IQ"
    case defense    = "Defense"

    var icon: String {
        switch self {
        case .shooting:   return "scope"
        case .finishing:  return "figure.run"
        case .rebounding: return "arrow.up.circle.fill"
        case .handles:    return "hand.point.up.left.fill"
        case .passing:    return "paperplane.fill"
        case .iq:         return "brain.head.profile"
        case .defense:    return "shield.lefthalf.filled"
        }
    }

    // Each category keeps its own color — used in labels and legend only
    var color: Color {
        switch self {
        case .shooting:   return Color(hex: "#39FF14")
        case .finishing:  return Color(hex: "#FF7A00")
        case .rebounding: return Color(hex: "#2DA8FF")
        case .handles:    return Color(hex: "#FFC247")
        case .passing:    return Color(hex: "#2ECC71")
        case .iq:         return Color(hex: "#9B8BFF")
        case .defense:    return Color(hex: "#FF3B30")
        }
    }

    // Maps to the storage key used by SelfAssessmentStore and SupabaseManager
    var storageKey: String {
        switch self {
        case .shooting:   return "scoring"
        case .finishing:  return "finishing"
        case .rebounding: return "rebounding"
        case .handles:    return "handles"
        case .passing:    return "playmaking"
        case .iq:         return "iq"
        case .defense:    return "defense"
        }
    }

    // Internal position weights — never shown to users
    func weight(for position: SAPosition) -> Double {
        switch self {
        case .shooting:
            switch position { case .pg: return 1.1; case .sg: return 1.2; case .sf: return 1.0; case .pf: return 0.9; case .c: return 0.8; case .notSure: return 1.0 }
        case .finishing:
            switch position { case .pg: return 1.0; case .sg: return 1.0; case .sf: return 1.1; case .pf: return 1.1; case .c: return 1.2; case .notSure: return 1.0 }
        case .rebounding:
            switch position { case .pg: return 0.7; case .sg: return 0.7; case .sf: return 0.9; case .pf: return 1.2; case .c: return 1.3; case .notSure: return 1.0 }
        case .handles:
            switch position { case .pg: return 1.3; case .sg: return 1.1; case .sf: return 0.9; case .pf: return 0.7; case .c: return 0.5; case .notSure: return 1.0 }
        case .passing:
            switch position { case .pg: return 1.3; case .sg: return 1.0; case .sf: return 1.0; case .pf: return 0.9; case .c: return 0.8; case .notSure: return 1.0 }
        case .iq:
            switch position { case .pg: return 1.2; case .sg: return 1.1; case .sf: return 1.1; case .pf: return 1.0; case .c: return 1.0; case .notSure: return 1.0 }
        case .defense:
            switch position { case .pg: return 1.0; case .sg: return 1.0; case .sf: return 1.0; case .pf: return 1.1; case .c: return 1.2; case .notSure: return 1.0 }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Question Data
// ─────────────────────────────────────────────────────────────

struct AssessmentChoice: Identifiable {
    let id    = UUID()
    let label: String
    let icon:  String
    let value: Int   // 5 = elite → 1 = beginner
}

struct SAAssessmentQuestion: Identifiable {
    let id       = UUID()
    let category: SASkillCategory
    let question: String
    let choices:  [AssessmentChoice]
}

let saAssessmentQuestions: [SAAssessmentQuestion] = [

    // SHOOTING
    SAAssessmentQuestion(category: .shooting, question: "You're open. What happens?", choices: [
        AssessmentChoice(label: "It goes in — I'm a knockdown shooter",              icon: "checkmark.seal.fill",         value: 5),
        AssessmentChoice(label: "I shoot with confidence, hits more than it misses", icon: "checkmark.circle",            value: 4),
        AssessmentChoice(label: "I hesitate unless I'm completely wide open",        icon: "pause.circle.fill",           value: 3),
        AssessmentChoice(label: "I'd rather pass than shoot",                        icon: "arrow.turn.up.right",         value: 2),
        AssessmentChoice(label: "I don't really shoot — it's not my game",           icon: "xmark.circle.fill",           value: 1),
    ]),
    SAAssessmentQuestion(category: .shooting, question: "Can you make your own shot off the dribble?", choices: [
        AssessmentChoice(label: "Pull-up, step-back — I don't need to be set",       icon: "bolt.fill",                   value: 5),
        AssessmentChoice(label: "If I have enough space to get my footing",          icon: "figure.stand",                value: 4),
        AssessmentChoice(label: "Only on a clear lane or a slow closeout",           icon: "arrow.right.to.line",         value: 3),
        AssessmentChoice(label: "Not really — I need the ball delivered to me",      icon: "hand.raised.fill",            value: 2),
        AssessmentChoice(label: "I can't create my own shot off the dribble",        icon: "xmark.circle.fill",           value: 1),
    ]),

    // FINISHING
    SAAssessmentQuestion(category: .finishing, question: "Going to the rim with a hand in your face?", choices: [
        AssessmentChoice(label: "I finish through it — contact doesn't bother me",  icon: "flame.fill",                  value: 5),
        AssessmentChoice(label: "I get there but I pick my spots",                   icon: "target",                      value: 4),
        AssessmentChoice(label: "I usually avoid contact and adjust",                icon: "arrow.left.and.right",        value: 3),
        AssessmentChoice(label: "I kick it out before it gets to that",              icon: "arrow.turn.up.right",         value: 2),
        AssessmentChoice(label: "I rarely attack the rim",                           icon: "xmark.circle.fill",           value: 1),
    ]),
    SAAssessmentQuestion(category: .finishing, question: "How's your layup game?", choices: [
        AssessmentChoice(label: "Both hands, floater, reverse — full package",       icon: "star.fill",                   value: 5),
        AssessmentChoice(label: "Strong hand is money, weak hand is coming",         icon: "hand.thumbsup.fill",          value: 4),
        AssessmentChoice(label: "Straight layups only — I keep it simple",           icon: "minus.circle.fill",           value: 3),
        AssessmentChoice(label: "I get up there but don't always finish",            icon: "questionmark.circle.fill",    value: 2),
        AssessmentChoice(label: "Finishing at the rim is a real weakness",           icon: "xmark.circle.fill",           value: 1),
    ]),

    // REBOUNDING
    SAAssessmentQuestion(category: .rebounding, question: "Shot goes up — where are you?", choices: [
        AssessmentChoice(label: "Boxing out first, going hard for every board",      icon: "rectangle.compress.vertical", value: 5),
        AssessmentChoice(label: "I get my share — especially on my side",            icon: "checkmark.circle.fill",       value: 4),
        AssessmentChoice(label: "I go for it but bigger bodies beat me",             icon: "figure.walk",                 value: 3),
        AssessmentChoice(label: "I get back on D — rebounding isn't my thing",      icon: "arrow.backward.circle.fill",  value: 2),
        AssessmentChoice(label: "I don't factor into rebounding at all",             icon: "xmark.circle.fill",           value: 1),
    ]),
    SAAssessmentQuestion(category: .rebounding, question: "How often are you crashing the offensive glass?", choices: [
        AssessmentChoice(label: "Every time — putbacks are part of my game",         icon: "flame.fill",                  value: 5),
        AssessmentChoice(label: "I tip in loose balls when I'm near the basket",     icon: "hand.point.up.fill",          value: 4),
        AssessmentChoice(label: "Sometimes — depends on the situation",              icon: "slider.horizontal.3",         value: 3),
        AssessmentChoice(label: "I stay back — can't give up easy buckets",         icon: "shield.fill",                 value: 2),
        AssessmentChoice(label: "Never — I don't crash the offensive glass",         icon: "xmark.circle.fill",           value: 1),
    ]),

    // HANDLES
    SAAssessmentQuestion(category: .handles, question: "One-on-one, top of the key — what do you do?", choices: [
        AssessmentChoice(label: "Attack — I make defenders look slow",               icon: "bolt.fill",                   value: 5),
        AssessmentChoice(label: "I can get by with moves and patience",              icon: "figure.walk.motion",          value: 4),
        AssessmentChoice(label: "I hold the ball but won't go at anyone",            icon: "hand.raised.fill",            value: 3),
        AssessmentChoice(label: "I move it quick — I'm not a one-on-one guy",       icon: "arrow.turn.up.right",         value: 2),
        AssessmentChoice(label: "Dribble pressure makes me pick it up",              icon: "xmark.circle.fill",           value: 1),
    ]),
    SAAssessmentQuestion(category: .handles, question: "Someone's pressing you full court — what happens?", choices: [
        AssessmentChoice(label: "I stay calm, split the pressure, push pace",        icon: "wind",                        value: 5),
        AssessmentChoice(label: "I find the outlet before it's a problem",           icon: "checkmark.circle.fill",       value: 4),
        AssessmentChoice(label: "I panic a little — pick up my dribble too soon",   icon: "exclamationmark.circle.fill", value: 3),
        AssessmentChoice(label: "I try to avoid that situation entirely",            icon: "arrow.backward.circle.fill",  value: 2),
        AssessmentChoice(label: "I almost always turn it over under pressure",       icon: "xmark.circle.fill",           value: 1),
    ]),

    // PASSING
    SAAssessmentQuestion(category: .passing, question: "Do you see the open man before he's open?", choices: [
        AssessmentChoice(label: "Always — I read the D and deliver on time",         icon: "eye.fill",                    value: 5),
        AssessmentChoice(label: "Most of the time — I make the right play",          icon: "checkmark.circle.fill",       value: 4),
        AssessmentChoice(label: "Sometimes — I still miss windows I should hit",     icon: "clock.fill",                  value: 3),
        AssessmentChoice(label: "I'm more focused on my own game",                   icon: "person.fill",                 value: 2),
        AssessmentChoice(label: "I rarely see the open man in time",                 icon: "xmark.circle.fill",           value: 1),
    ]),
    SAAssessmentQuestion(category: .passing, question: "Can you deliver the pass in traffic before the window closes?", choices: [
        AssessmentChoice(label: "Yes — I thread it before the defense can react",    icon: "sparkles",                    value: 5),
        AssessmentChoice(label: "If the window's clear enough, I'll make the pass",  icon: "checkmark.circle.fill",       value: 4),
        AssessmentChoice(label: "I tend to take my own shot — I miss tight windows", icon: "person.fill",                 value: 3),
        AssessmentChoice(label: "Passing in traffic isn't really my thing",          icon: "arrow.turn.up.right",         value: 2),
        AssessmentChoice(label: "I avoid passing entirely in those situations",      icon: "xmark.circle.fill",           value: 1),
    ]),

    // IQ
    SAAssessmentQuestion(category: .iq, question: "How well do you read the game?", choices: [
        AssessmentChoice(label: "High — I see the floor and I'm one step ahead",    icon: "brain.head.profile",          value: 5),
        AssessmentChoice(label: "Solid — good fundamentals, good decisions",         icon: "checkmark.seal.fill",         value: 4),
        AssessmentChoice(label: "Getting there — I get caught off guard sometimes",  icon: "arrow.up.right.circle.fill",  value: 3),
        AssessmentChoice(label: "Still learning — figuring it out as I go",          icon: "figure.walk",                 value: 2),
        AssessmentChoice(label: "I react — the game usually moves too fast for me",  icon: "xmark.circle.fill",           value: 1),
    ]),
    SAAssessmentQuestion(category: .iq, question: "When the game is close and it matters most?", choices: [
        AssessmentChoice(label: "I want the ball — I make the right play under pressure", icon: "flame.fill",             value: 5),
        AssessmentChoice(label: "I stay composed and stick to what I know",          icon: "lock.fill",                   value: 4),
        AssessmentChoice(label: "I manage it — play simpler and stay controlled",    icon: "exclamationmark.bubble.fill", value: 3),
        AssessmentChoice(label: "I try to stay out of the way",                      icon: "arrow.backward.circle.fill", value: 2),
        AssessmentChoice(label: "I tend to freeze up in big moments",                icon: "xmark.circle.fill",           value: 1),
    ]),

    // DEFENSE
    SAAssessmentQuestion(category: .defense, question: "On the ball — how do you guard your man?", choices: [
        AssessmentChoice(label: "I lock in, make them uncomfortable, force tough shots", icon: "shield.lefthalf.filled", value: 5),
        AssessmentChoice(label: "I contest and stay in front — I make it hard",      icon: "hand.raised.fill",            value: 4),
        AssessmentChoice(label: "I try but quick guards give me real trouble",       icon: "exclamationmark.circle.fill", value: 3),
        AssessmentChoice(label: "I'm honest — I'm a lot better on offense",         icon: "arrow.turn.up.right",         value: 2),
        AssessmentChoice(label: "Defense isn't something I really play",             icon: "xmark.circle.fill",           value: 1),
    ]),
    SAAssessmentQuestion(category: .defense, question: "When you're off the ball, where's your head at?", choices: [
        AssessmentChoice(label: "Talking, helping, rotating — I guard the whole team", icon: "person.3.fill",            value: 5),
        AssessmentChoice(label: "I keep track of my man and help when it's clear",   icon: "eye.fill",                    value: 4),
        AssessmentChoice(label: "I guard my man but lose the ball sometimes",        icon: "minus.circle.fill",           value: 3),
        AssessmentChoice(label: "Still figuring out where I'm supposed to be",       icon: "questionmark.circle.fill",    value: 2),
        AssessmentChoice(label: "I'm not paying attention to defense off the ball",  icon: "xmark.circle.fill",           value: 1),
    ]),
]

// ─────────────────────────────────────────────────────────────
// MARK: — Player Profile
// ─────────────────────────────────────────────────────────────

struct PlayerProfile {
    var gender:       Gender?
    var age:          Int?
    var position:     SAPosition?
    var position2:    SAPosition?
    var highestLevel: PlayLevel?
    var frequency:    SAPlayFrequency?

    var levelIsCurrent: Bool {
        guard let age, let level = highestLevel else { return false }
        switch level {
        case .nba:               return true
        case .d1, .d2d3:        return age <= 23
        case .hsVarsity, .hsJV: return age <= 18
        case .aau:               return age <= 20
        case .rec, .pickup:     return true
        }
    }

    // Internal effective ceiling — never displayed
    var effectiveCeiling: Double {
        guard let level = highestLevel, let freq = frequency, let age else { return 5.5 }
        let decay      = PlayLevel.ageDecay(level: level, age: age, isCurrent: levelIsCurrent)
        let base       = level.baseCeiling
        let afterDecay = levelIsCurrent ? base : base * decay
        // Don't apply frequency penalty for active players — they're still competing at this level
        let afterFreq  = levelIsCurrent ? afterDecay : afterDecay * freq.modifier
        return max(2.0, afterFreq)
    }

    // Internal effective floor — never displayed
    // Decays in proportion to the ceiling so the spread stays consistent.
    var effectiveFloor: Double {
        guard let level = highestLevel, let freq = frequency, let age else { return 2.0 }
        let decay      = PlayLevel.ageDecay(level: level, age: age, isCurrent: levelIsCurrent)
        let base       = level.baseFloor
        let afterDecay = levelIsCurrent ? base : base * decay
        // Don't apply frequency penalty for active players — their floor reflects current skill
        let afterFreq  = levelIsCurrent ? afterDecay : afterDecay * freq.modifier
        return max(2.0, min(afterFreq, effectiveCeiling - 0.5))
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — View Model
// ─────────────────────────────────────────────────────────────

@MainActor
class SelfAssessmentViewModel: ObservableObject {
    @Published var onboardingStep: Int    = 0
    @Published var profile              = PlayerProfile()
    @Published var ageText: String      = ""
    @Published var questionIndex: Int   = 0
    @Published var answers: [UUID: Int] = [:]
    @Published var showResult: Bool       = false
    @Published var showCalculating: Bool  = false
    @Published var finalScore: Double     = 0
    @Published var categoryScores: [SASkillCategory: Double] = [:]

    let questions            = saAssessmentQuestions
    let totalOnboardingSteps = 4

    var onboardingComplete: Bool {
        profile.gender != nil && profile.age != nil &&
        profile.position != nil && profile.highestLevel != nil && profile.frequency != nil
    }

    var currentQuestion: SAAssessmentQuestion { questions[questionIndex] }
    var questionProgress: Double { Double(questionIndex) / Double(questions.count) }
    var isLastQuestion: Bool { questionIndex == questions.count - 1 }
    var currentAnswer:  Int? { answers[currentQuestion.id] }
    var hasAnswered:    Bool { currentAnswer != nil }

    func commitAge() {
        if let a = Int(ageText), a >= 10, a <= 75 { profile.age = a }
    }
    func selectChoice(_ c: AssessmentChoice) { answers[currentQuestion.id] = c.value }

    func nextQuestion() {
        guard hasAnswered else { return }
        if isLastQuestion {
            let (score, cats) = calculateFinalScore()
            finalScore     = score
            categoryScores = cats
            withAnimation(.spring(response: 0.5)) { showCalculating = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.spring(response: 0.5)) {
                    self.showCalculating = false
                    self.showResult = true
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.22)) { questionIndex += 1 }
        }
    }
    func prevQuestion() {
        guard questionIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.22)) { questionIndex -= 1 }
    }

    private func calculateFinalScore() -> (Double, [SASkillCategory: Double]) {
        guard let position = profile.position else { return (3.2, [:]) }
        var catRatios: [SASkillCategory: Double] = [:]
        var ws = 0.0, wt = 0.0

        for cat in SASkillCategory.allCases {
            let vals = questions.filter { $0.category == cat }.compactMap { answers[$0.id] }
            guard !vals.isEmpty else { continue }
            let avg   = Double(vals.reduce(0, +)) / Double(vals.count)
            let ratio = (avg - 1.0) / 4.0   // 0.0–1.0 answer quality (5-point scale)
            catRatios[cat] = ratio
            // Average weights across both positions if two were selected
            let w1 = cat.weight(for: position)
            let w = profile.position2.map { (w1 + cat.weight(for: $0)) / 2.0 } ?? w1
            ws += ratio * w; wt += w
        }

        guard wt > 0 else { return (3.2, [:]) }
        let ceiling         = profile.effectiveCeiling
        let floor           = profile.effectiveFloor
        let avgRatio        = ws / wt
        let discountedRatio = avgRatio * 0.72   // 28% self-assessment discount
        let overall         = max(floor, min(ceiling, floor + discountedRatio * (ceiling - floor)))

        // Map each category into the same [floor, ceiling] range for the breakdown
        let catScores = catRatios.mapValues { ratio in
            let dr = ratio * 0.72
            return max(floor, min(ceiling, floor + dr * (ceiling - floor)))
        }
        return (overall, catScores)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Disclaimer Screen
// ─────────────────────────────────────────────────────────────

struct AssessmentDisclaimerView: View {
    var onBegin: () -> Void

    private let accent  = Color(hex: "#39FF14")
    private let card    = Color(hex: "#111116")
    private let border  = Color(hex: "#1E1E26")
    private let sub     = Color(hex: "#6A6A82")

    var body: some View {
        ZStack {
            Color(hex: "#050507").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.08))
                        .frame(width: 100, height: 100)
                    Circle()
                        .stroke(accent.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 100, height: 100)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(accent)
                }
                .padding(.bottom, 28)

                Text("ONE SHOT.\nMAKE IT COUNT.")
                    .font(.custom("BarlowCondensed-Black", size: 40))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)

                Text("Your NETR self-assessment is permanent.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accent)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                // Rules
                VStack(spacing: 14) {
                    DisclaimerRow(icon: "1.circle.fill",
                                  text: "You can only take this assessment once. Once submitted, your score is locked.")
                    DisclaimerRow(icon: "eye.fill",
                                  text: "Other players will see your rating. Be honest — it reflects how you actually play.")
                    DisclaimerRow(icon: "arrow.uturn.backward.circle.fill",
                                  text: "You can go back and change any answer before you submit.")
                    DisclaimerRow(icon: "checkmark.shield.fill",
                                  text: "Answer carefully. Overrating yourself hurts your credibility on the court.")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)

                Spacer()

                // CTA
                Button(action: onBegin) {
                    HStack(spacing: 8) {
                        Text("I UNDERSTAND — LET'S GO")
                            .font(.system(size: 15, weight: .black))
                            .kerning(0.5)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#050507"))
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: accent.opacity(0.4), radius: 16)
                }
                .buttonStyle(PressButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }
}

private struct DisclaimerRow: View {
    let icon: String
    let text: String
    private let accent = Color(hex: "#39FF14")
    private let card   = Color(hex: "#111116")
    private let border = Color(hex: "#1E1E26")

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(accent)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(14)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Root Entry Point
// ─────────────────────────────────────────────────────────────

struct SelfAssessmentFlowView: View {
    var initialAge: Int? = nil
    var onComplete: ((Double, PlayerProfile, [String: Double]) -> Void)? = nil
    @StateObject private var vm = SelfAssessmentViewModel()
    @State private var showDisclaimer = true

    var body: some View {
        ZStack {
            Color(hex: "#050507").ignoresSafeArea()
            if showDisclaimer {
                AssessmentDisclaimerView { withAnimation(.easeInOut(duration: 0.35)) { showDisclaimer = false } }
                    .transition(.opacity)
            } else if vm.showResult {
                AssessmentResultView(
                    score: vm.finalScore,
                    categoryScores: vm.categoryScores,
                    profile: vm.profile,
                    onDone: {
                        let mapped = Dictionary(uniqueKeysWithValues: vm.categoryScores.map { ($0.key.storageKey, $0.value) })
                        onComplete?(vm.finalScore, vm.profile, mapped)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if vm.showCalculating {
                CalculatingView()
                    .transition(.opacity)
            } else if vm.onboardingComplete {
                QuestionFlowView(vm: vm)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.94).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                OnboardingFlowView(vm: vm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showDisclaimer)
        .animation(.easeInOut(duration: 0.35), value: vm.showResult)
        .animation(.easeInOut(duration: 0.4), value: vm.showCalculating)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: vm.onboardingComplete)
        .onAppear {
            vm.profile.age = initialAge ?? 20
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Shared UI Components
// ─────────────────────────────────────────────────────────────

struct StepHeader: View {
    let step: String; let title: String; let subtitle: String
    var body: some View {
        VStack(spacing: 10) {
            Text(step.uppercased())
                .font(.system(size: 10, weight: .bold)).kerning(1.4)
                .foregroundColor(Color(hex: "#39FF14"))
            Text(title)
                .font(.custom("BarlowCondensed-Black", size: 36))
                .foregroundColor(.white).multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 14)).foregroundColor(Color(hex: "#6A6A82"))
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
        .padding(.bottom, 8)
    }
}

struct OptionCard<T: Equatable>: View {
    let value: T; let label: String; let sublabel: String?
    let icon: String; let selected: T?; let color: Color; let onTap: () -> Void
    var isSelected: Bool { selected == value }
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? color.opacity(0.2) : Color(hex: "#1A1A20"))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? color : Color(hex: "#6A6A82"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : Color(hex: "#CCCCCC"))
                    if let sub = sublabel {
                        Text(sub).font(.system(size: 12)).foregroundColor(Color(hex: "#6A6A82"))
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(isSelected ? color : Color(hex: "#333340"), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected { Circle().fill(color).frame(width: 12, height: 12) }
                }
            }
            .padding(14)
            .background(isSelected ? color.opacity(0.07) : Color(hex: "#111116"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? color.opacity(0.5) : Color(hex: "#1E1E26"),
                        lineWidth: isSelected ? 1.5 : 1))
            .shadow(color: isSelected ? color.opacity(0.12) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.01 : 1.0)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

struct ContinueButton: View {
    let label: String; let enabled: Bool; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label).font(.system(size: 16, weight: .bold))
                Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(enabled ? .white : Color(hex: "#444444"))
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(enabled
                ? LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [Color(hex: "#2A2A35"), Color(hex: "#2A2A35")], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: enabled ? color.opacity(0.35) : .clear, radius: 12)
        }
        .disabled(!enabled)
        .padding(.horizontal, 20).padding(.bottom, 40)
    }
}

struct ChoiceRow: View {
    let choice: AssessmentChoice; let isSelected: Bool; let accentColor: Color; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? accentColor.opacity(0.2) : Color(hex: "#1A1A20"))
                        .frame(width: 42, height: 42)
                    Image(systemName: choice.icon).font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isSelected ? accentColor : Color(hex: "#6A6A82"))
                }
                Text(choice.label)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color(hex: "#BBBBBB"))
                    .multilineTextAlignment(.leading).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer()
                ZStack {
                    Circle().stroke(isSelected ? accentColor : Color(hex: "#333340"), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected { Circle().fill(accentColor).frame(width: 12, height: 12) }
                }
            }
            .padding(14)
            .background(isSelected ? accentColor.opacity(0.07) : Color(hex: "#111116"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? accentColor.opacity(0.5) : Color(hex: "#1E1E26"),
                        lineWidth: isSelected ? 1.5 : 1))
            .shadow(color: isSelected ? accentColor.opacity(0.12) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.01 : 1.0)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Onboarding Steps
// ─────────────────────────────────────────────────────────────

struct OnboardingFlowView: View {
    @ObservedObject var vm: SelfAssessmentViewModel
    private let sub = Color(hex: "#6A6A82")

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                // Back button — hidden on step 0
                if vm.onboardingStep > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { vm.onboardingStep -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(sub)
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "#111116"))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(hex: "#1E1E26"), lineWidth: 1))
                    }
                } else {
                    Spacer().frame(width: 36)
                }

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<vm.totalOnboardingSteps, id: \.self) { i in
                        Capsule()
                            .fill(i <= vm.onboardingStep ? Color(hex: "#39FF14") : Color(hex: "#2A2A35"))
                            .frame(width: i == vm.onboardingStep ? 24 : 8, height: 6)
                            .animation(.spring(response: 0.3), value: vm.onboardingStep)
                    }
                }

                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20).padding(.bottom, 24)

            Group {
                switch vm.onboardingStep {
                case 0: GenderStepView(vm: vm)
                case 1: PositionStepView(vm: vm)
                case 2: LevelStepView(vm: vm)
                case 3: FrequencyStepView(vm: vm)
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)))
            .animation(.easeInOut(duration: 0.25), value: vm.onboardingStep)
        }
    }
}

struct GenderStepView: View {
    @ObservedObject var vm: SelfAssessmentViewModel
    let accent = Color(hex: "#39FF14")
    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: "Step 1 of 4", title: "How do you\nidentify?",
                       subtitle: "Won't affect your rating. Used so players can filter games by gender.")
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Gender.allCases) { g in
                        OptionCard(value: g, label: g.rawValue, sublabel: nil, icon: g.icon,
                                   selected: vm.profile.gender, color: accent) {
                            withAnimation(.spring(response: 0.25)) { vm.profile.gender = g }
                        }
                    }
                }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
            }
            ContinueButton(label: "Continue", enabled: vm.profile.gender != nil, color: accent) {
                withAnimation { vm.onboardingStep = 1 }
            }
        }
    }
}

struct AgeStepView: View {
    @ObservedObject var vm: SelfAssessmentViewModel
    @FocusState private var focused: Bool
    let accent = Color(hex: "#39FF14")
    var isValid: Bool {
        guard let a = Int(vm.ageText) else { return false }; return a >= 10 && a <= 75
    }
    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: "Step 2 of 5", title: "How old\nare you?",
                       subtitle: "Helps us understand if your playing level is current or in the past.")
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(Color(hex: "#111116"))
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke(focused ? accent.opacity(0.5) : Color(hex: "#1E1E26"),
                                    lineWidth: focused ? 1.5 : 1))
                        .frame(height: 100)
                    HStack(spacing: 8) {
                        TextField("", text: $vm.ageText)
                            .font(.custom("BarlowCondensed-Black", size: 64))
                            .foregroundColor(isValid ? accent : .white)
                            .keyboardType(.numberPad).multilineTextAlignment(.center)
                            .focused($focused).frame(maxWidth: 120)
                        Text("yrs").font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color(hex: "#6A6A82"))
                    }
                }
                .padding(.horizontal, 40).onTapGesture { focused = true }
                if let a = Int(vm.ageText), a < 10 || a > 75 {
                    Text("Enter an age between 10 and 75")
                        .font(.system(size: 13)).foregroundColor(Color(hex: "#FF3B30"))
                }
            }
            Spacer()
            ContinueButton(label: "Continue", enabled: isValid, color: accent) {
                vm.commitAge(); withAnimation { vm.onboardingStep = 2 }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }
}

struct PositionStepView: View {
    @ObservedObject var vm: SelfAssessmentViewModel
    let accent = Color(hex: "#39FF14")

    private func isSelected(_ pos: SAPosition) -> Bool {
        vm.profile.position == pos || vm.profile.position2 == pos
    }

    private func isDisabled(_ pos: SAPosition) -> Bool {
        // If two positions already selected, disable anything that isn't one of them
        guard vm.profile.position != nil, vm.profile.position2 != nil else { return false }
        return !isSelected(pos)
    }

    private func tap(_ pos: SAPosition) {
        withAnimation(.spring(response: 0.25)) {
            if vm.profile.position == pos {
                // Deselect primary → promote secondary if exists
                vm.profile.position = vm.profile.position2
                vm.profile.position2 = nil
            } else if vm.profile.position2 == pos {
                // Deselect secondary
                vm.profile.position2 = nil
            } else if vm.profile.position == nil {
                // Nothing selected yet
                vm.profile.position = pos
                vm.profile.position2 = nil
            } else if vm.profile.position2 == nil {
                // One selected — add second only if adjacent and not notSure
                if pos != .notSure, let p1 = vm.profile.position, p1 != .notSure, p1.isAdjacent(to: pos) {
                    vm.profile.position2 = pos
                } else {
                    // Not adjacent or notSure — replace
                    vm.profile.position = pos
                    vm.profile.position2 = nil
                }
            } else {
                // Two selected — replace all
                vm.profile.position = pos
                vm.profile.position2 = nil
            }
        }
    }

    var selectionLabel: String {
        guard let p1 = vm.profile.position else { return "" }
        if let p2 = vm.profile.position2 {
            return "\(p1.short) / \(p2.short) selected"
        }
        return "\(p1.short) selected"
    }

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: "Step 2 of 4", title: "What's your\nposition?",
                       subtitle: "Different categories are weighted based on your role on the court.")

            // Hint text
            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 12))
                Text("You can pick 2 positions if you play both — they must be next to each other (e.g. PG+SG, SF+PF)")
                    .font(.system(size: 12))
            }
            .foregroundColor(Color(hex: "#6A6A82"))
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(SAPosition.allCases) { pos in
                        let label = pos == .notSure ? pos.rawValue : "\(pos.short) — \(pos.rawValue)"
                        let selected = isSelected(pos)
                        let dimmed = isDisabled(pos)
                        Button { tap(pos) } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selected ? accent.opacity(0.2) : Color(hex: "#1A1A20"))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: pos.icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(selected ? accent : Color(hex: dimmed ? "#333340" : "#6A6A82"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(label)
                                        .font(.system(size: 15, weight: selected ? .semibold : .regular))
                                        .foregroundColor(selected ? .white : Color(hex: dimmed ? "#444450" : "#CCCCCC"))
                                    Text(pos.description)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: dimmed ? "#333340" : "#6A6A82"))
                                }
                                Spacer()
                                ZStack {
                                    Circle()
                                        .stroke(selected ? accent : Color(hex: dimmed ? "#222228" : "#333340"), lineWidth: 2)
                                        .frame(width: 22, height: 22)
                                    if selected { Circle().fill(accent).frame(width: 12, height: 12) }
                                }
                            }
                            .padding(14)
                            .background(selected ? accent.opacity(0.07) : Color(hex: "#111116"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(selected ? accent.opacity(0.5) : Color(hex: dimmed ? "#181820" : "#1E1E26"),
                                        lineWidth: selected ? 1.5 : 1))
                            .shadow(color: selected ? accent.opacity(0.12) : .clear, radius: 8)
                            .opacity(dimmed ? 0.4 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(selected ? 1.01 : 1.0)
                        .animation(.spring(response: 0.25), value: selected)
                    }
                }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
            }

            if vm.profile.position != nil {
                Text(selectionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
                    .padding(.bottom, 4)
            }

            ContinueButton(label: "Continue", enabled: vm.profile.position != nil, color: accent) {
                withAnimation { vm.onboardingStep = 2 }
            }
        }
    }
}

struct LevelStepView: View {
    @ObservedObject var vm: SelfAssessmentViewModel
    let accent = Color(hex: "#39FF14")
    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: "Step 3 of 4", title: "Highest level\nyou've played?",
                       subtitle: "Current or past — we figure that out based on your age.")
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(PlayLevel.allCases) { level in
                        OptionCard(value: level, label: level.rawValue, sublabel: nil,
                                   icon: level.icon, selected: vm.profile.highestLevel,
                                   color: level.iconColor) {
                            withAnimation(.spring(response: 0.25)) { vm.profile.highestLevel = level }
                        }
                    }
                }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
            }
            ContinueButton(label: "Continue", enabled: vm.profile.highestLevel != nil, color: accent) {
                withAnimation { vm.onboardingStep = 3 }
            }
        }
    }
}

struct FrequencyStepView: View {
    @ObservedObject var vm: SelfAssessmentViewModel
    @State private var pendingFrequency: SAPlayFrequency? = nil
    let accent = Color(hex: "#39FF14")
    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: "Step 4 of 4", title: "How often do you\ncurrently play?",
                       subtitle: "Helps us understand where you are right now.")
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(SAPlayFrequency.allCases) { freq in
                        OptionCard(value: freq, label: freq.rawValue, sublabel: nil,
                                   icon: freq.icon, selected: pendingFrequency, color: accent) {
                            withAnimation(.spring(response: 0.25)) { pendingFrequency = freq }
                        }
                    }
                }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
            }
            ContinueButton(label: "Start Assessment", enabled: pendingFrequency != nil, color: accent) {
                guard let freq = pendingFrequency else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    vm.profile.frequency = freq
                }
            }
        }
        .onAppear {
            // Pre-select previously saved value when returning from question flow
            if pendingFrequency == nil { pendingFrequency = vm.profile.frequency }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Question Flow
// ─────────────────────────────────────────────────────────────

struct QuestionFlowView: View {
    @ObservedObject var vm: SelfAssessmentViewModel
    let muted = Color(hex: "#2A2A35")
    let sub   = Color(hex: "#6A6A82")

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(muted).frame(height: 3)
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [vm.currentQuestion.category.color.opacity(0.6),
                                     vm.currentQuestion.category.color],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * vm.questionProgress, height: 3)
                        .animation(.easeInOut(duration: 0.3), value: vm.questionIndex)
                }
            }.frame(height: 3)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HStack {
                        Button {
                            if vm.questionIndex > 0 {
                                vm.prevQuestion()
                            } else {
                                // Back to onboarding — return to frequency step
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    vm.profile.frequency = nil
                                    vm.onboardingStep = 3
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                                .foregroundColor(sub).frame(width: 36, height: 36)
                                .background(Color(hex: "#111116")).clipShape(Circle())
                                .overlay(Circle().stroke(Color(hex: "#1E1E26"), lineWidth: 1))
                        }
                        Spacer()
                        Text("\(vm.questionIndex + 1) of \(vm.questions.count)")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(sub)
                        Spacer()
                        Spacer().frame(width: 36)
                    }
                    .padding(.horizontal, 20).padding(.top, 16)

                    HStack(spacing: 6) {
                        Image(systemName: vm.currentQuestion.category.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(vm.currentQuestion.category.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold)).kerning(1.2)
                    }
                    .foregroundColor(vm.currentQuestion.category.color)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(vm.currentQuestion.category.color.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(vm.currentQuestion.category.color.opacity(0.3), lineWidth: 1))

                    Text(vm.currentQuestion.question)
                        .font(.custom("BarlowCondensed-Black", size: 34)).foregroundColor(.white)
                        .multilineTextAlignment(.center).padding(.horizontal, 28)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        ForEach(vm.currentQuestion.choices) { choice in
                            ChoiceRow(choice: choice,
                                      isSelected: vm.currentAnswer == choice.value,
                                      accentColor: vm.currentQuestion.category.color) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                    vm.selectChoice(choice)
                                }
                            }
                        }
                    }.padding(.horizontal, 20)

                    let cc = vm.currentQuestion.category.color
                    Button(action: vm.nextQuestion) {
                        HStack(spacing: 8) {
                            Text(vm.isLastQuestion ? "See My Score" : "Next")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: vm.isLastQuestion ? "chart.bar.fill" : "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(vm.hasAnswered ? .white : Color(hex: "#444444"))
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(vm.hasAnswered
                            ? LinearGradient(colors: [cc, cc.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [muted, muted], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: vm.hasAnswered ? cc.opacity(0.35) : .clear, radius: 12)
                    }
                    .disabled(!vm.hasAnswered)
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Radar / Skill Graph
//
// Graph fill, stroke, and dots:  neon green (#39FF14) only
// Axis labels and legend values: each category's own color
// ─────────────────────────────────────────────────────────────

struct SASkillRadarView: View {
    let categoryScores: [SASkillCategory: Double]

    private let ordered: [SASkillCategory] = [
        .shooting, .finishing, .rebounding, .handles, .passing, .iq, .defense
    ]
    private let accent    = Color(hex: "#39FF14")
    private let ringDim   = Color(hex: "#1C1C2A")
    private let ringOuter = Color(hex: "#2A2A3A")
    private let cardBg    = Color(hex: "#111116")
    private let border    = Color(hex: "#1E1E26")
    private let sub       = Color(hex: "#6A6A82")
    private let rings     = 5
    private let maxVal    = 10.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SKILL BREAKDOWN")
                    .font(.system(size: 10, weight: .bold)).kerning(1.1)
                    .foregroundColor(sub)
                Spacer()
            }
            .padding(.bottom, 16)

            GeometryReader { geo in
                let size   = min(geo.size.width, geo.size.height)
                let cx     = geo.size.width / 2
                let cy     = size / 2
                let radius = size / 2 - 52
                let n      = ordered.count

                ZStack {
                    // Grid rings
                    ForEach(1...rings, id: \.self) { r in
                        let frac = CGFloat(r) / CGFloat(rings)
                        Path { p in
                            for i in 0..<n {
                                let pt = radarPt(i: i, n: n, f: frac, cx: cx, cy: cy, r: radius)
                                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                            }
                            p.closeSubpath()
                        }
                        .stroke(r == rings ? ringOuter : ringDim,
                                lineWidth: r == rings ? 1.2 : 0.7)
                    }

                    // Spokes
                    ForEach(0..<n, id: \.self) { i in
                        Path { p in
                            p.move(to: CGPoint(x: cx, y: cy))
                            p.addLine(to: radarPt(i: i, n: n, f: 1.0, cx: cx, cy: cy, r: radius))
                        }
                        .stroke(ringDim, lineWidth: 0.7)
                    }

                    // Ring value labels on top spoke only
                    ForEach(1...rings, id: \.self) { r in
                        let frac = CGFloat(r) / CGFloat(rings)
                        let pt   = radarPt(i: 0, n: n, f: frac, cx: cx, cy: cy, r: radius)
                        Text("\(Int(Double(r) / Double(rings) * maxVal))")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "#2E2E42"))
                            .position(x: pt.x, y: pt.y - 7)
                    }

                    // Data fill — neon green, very low opacity
                    Path { p in
                        for i in 0..<n {
                            let s = categoryScores[ordered[i]] ?? 0
                            let pt = radarPt(i: i, n: n, f: CGFloat(s / maxVal), cx: cx, cy: cy, r: radius)
                            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                        }
                        p.closeSubpath()
                    }
                    .fill(accent.opacity(0.07))

                    // Data stroke — neon green
                    Path { p in
                        for i in 0..<n {
                            let s = categoryScores[ordered[i]] ?? 0
                            let pt = radarPt(i: i, n: n, f: CGFloat(s / maxVal), cx: cx, cy: cy, r: radius)
                            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                        }
                        p.closeSubpath()
                    }
                    .stroke(accent.opacity(0.8), lineWidth: 1.8)

                    // Spoke lines from center to data point — faint green
                    ForEach(0..<n, id: \.self) { i in
                        let s  = categoryScores[ordered[i]] ?? 0
                        let pt = radarPt(i: i, n: n, f: CGFloat(s / maxVal), cx: cx, cy: cy, r: radius)
                        Path { p in p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: pt) }
                            .stroke(accent.opacity(0.15), lineWidth: 1)
                    }

                    // Dots (neon green) + axis labels (category color)
                    ForEach(0..<n, id: \.self) { i in
                        let cat   = ordered[i]
                        let score = categoryScores[cat] ?? 0
                        let pt    = radarPt(i: i, n: n, f: CGFloat(score / maxVal), cx: cx, cy: cy, r: radius)
                        let angle = radarAngle(i: i, n: n)
                        let lx    = cx + (radius + 30) * cos(angle)
                        let ly    = cy + (radius + 30) * sin(angle)

                        // Glow halo — neon green
                        Circle().fill(accent.opacity(0.12)).frame(width: 14, height: 14).position(pt)
                        // Outer dot — neon green
                        Circle().fill(accent).frame(width: 9, height: 9).position(pt)
                        // Inner fill — match background
                        Circle().fill(Color(hex: "#050507")).frame(width: 4, height: 4).position(pt)

                        // Axis label and score — category color
                        VStack(spacing: 2) {
                            Text(cat.rawValue)
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(cat.color)
                            Text(score > 0 ? String(format: "%.1f", score) : "—")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(cat.color)
                        }
                        .position(x: lx, y: ly)
                    }
                }
                .frame(width: geo.size.width, height: size)
            }
            .frame(height: 280)

            // Legend — category color for dot and score, neutral for name
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(ordered, id: \.self) { cat in
                    let score = categoryScores[cat]
                    HStack(spacing: 7) {
                        Circle().fill(cat.color).frame(width: 8, height: 8)
                        Text(cat.rawValue)
                            .font(.system(size: 11)).foregroundColor(Color(hex: "#BBBBBB"))
                        Spacer()
                        Text(score != nil ? String(format: "%.1f", score!) : "—")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(score != nil ? cat.color : Color(hex: "#444444"))
                    }
                }
            }
            .padding(.top, 12)
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(border, lineWidth: 1))
    }

    private func radarAngle(i: Int, n: Int) -> CGFloat {
        CGFloat(i) / CGFloat(n) * .pi * 2 - .pi / 2
    }
    private func radarPt(i: Int, n: Int, f: CGFloat, cx: CGFloat, cy: CGFloat, r: CGFloat) -> CGPoint {
        let a = radarAngle(i: i, n: n)
        return CGPoint(x: cx + r * f * cos(a), y: cy + r * f * sin(a))
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Result View
// ─────────────────────────────────────────────────────────────

struct AssessmentResultView: View {
    let score:          Double
    let categoryScores: [SASkillCategory: Double]
    let profile:        PlayerProfile
    var onDone: (() -> Void)? = nil

    @State private var appeared:     Bool   = false
    @State private var ringProgress: Double = 0

    private let bg     = Color(hex: "#050507")
    private let card   = Color(hex: "#111116")
    private let border = Color(hex: "#1E1E26")
    private let sub    = Color(hex: "#6A6A82")

    private var tierColor: Color  { NETRRating.color(for: score) }
    private var tierName:  String { NETRRating.tierName(for: score) }
    private var ringFill:  Double { (score - 2.0) / 7.0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Score ring
                ZStack {
                    Circle().stroke(Color(hex: "#1E1E26"), lineWidth: 6).frame(width: 180, height: 180)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(AngularGradient(colors: [tierColor.opacity(0.4), tierColor], center: .center),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 180, height: 180)
                        .animation(.easeOut(duration: 1.4), value: ringProgress)
                    VStack(spacing: 6) {
                        Text(String(format: "%.2f", score))
                            .font(.custom("BarlowCondensed-Black", size: 58))
                            .foregroundColor(tierColor)
                            .shadow(color: tierColor.opacity(0.45), radius: 12)
                        Text("NETR").font(.system(size: 11, weight: .bold))
                            .foregroundColor(tierColor.opacity(0.6)).kerning(2)
                    }
                }
                .opacity(appeared ? 1 : 0).scaleEffect(appeared ? 1 : 0.75)
                .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1), value: appeared)
                .padding(.top, 44)

                Spacer().frame(height: 20)

                Text(tierName)
                    .font(.custom("BarlowCondensed-Black", size: 44)).foregroundColor(.white)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)

                Text(contextLine)
                    .font(.system(size: 15)).foregroundColor(sub)
                    .multilineTextAlignment(.center).padding(.horizontal, 40).padding(.top, 8)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.5).delay(0.55), value: appeared)

                HStack(spacing: 8) {
                    if let pos = profile.position    { profileChip(icon: pos.icon,  label: pos.short) }
                    if let lv  = profile.highestLevel { profileChip(icon: lv.icon,  label: levelShort(lv)) }
                }
                .padding(.top, 16)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.65), value: appeared)

                Spacer().frame(height: 24)

                SASkillRadarView(categoryScores: categoryScores)
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.55).delay(0.75), value: appeared)

                Spacer().frame(height: 16)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill").font(.system(size: 13))
                            .foregroundColor(tierColor.opacity(0.7))
                        Text("This is your starting point")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                    }
                    Text("Self-assessment gets you on the board. Your real NETR score is built by the players you run with — one game at a time.")
                        .font(.system(size: 12)).foregroundColor(sub)
                        .multilineTextAlignment(.center).lineSpacing(3)
                }
                .padding(16).background(card).clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(border, lineWidth: 1))
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(0.9), value: appeared)

                Spacer().frame(height: 20)

                Button(action: { onDone?() }) {
                    Text("Let's Run").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(LinearGradient(colors: [tierColor, tierColor.opacity(0.75)],
                                                   startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: tierColor.opacity(0.4), radius: 16)
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(1.0), value: appeared)

                Spacer().frame(height: 52)
            }
        }
        .background(bg.ignoresSafeArea())
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { ringProgress = ringFill }
        }
    }

    private func profileChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(label).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(sub).padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color(hex: "#111116")).clipShape(Capsule())
        .overlay(Capsule().stroke(Color(hex: "#1E1E26"), lineWidth: 1))
    }

    private var contextLine: String {
        switch score {
        case 6.0...:    return "You can hoop. Peer reviews will confirm it."
        case 5.0..<6.0: return "Better than most who lace up. The ceiling is right there."
        case 4.0..<5.0: return "The foundation is there. Keep putting in work."
        case 3.0..<4.0: return "Most players start here. Every run moves the number."
        default:        return "Everybody started here. You showed up — that's the whole thing."
        }
    }

    private func levelShort(_ level: PlayLevel) -> String {
        switch level {
        case .nba:       return "Pro"
        case .d1:        return "D1"
        case .d2d3:      return "D2/D3"
        case .hsVarsity: return "Varsity"
        case .hsJV:      return "JV"
        case .aau:       return "AAU"
        case .rec:       return "Rec"
        case .pickup:    return "Pickup"
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Calculating View
// ─────────────────────────────────────────────────────────────

struct CalculatingView: View {
    private let neon   = Color(hex: "#39FF14")
    private let bg     = Color(hex: "#050507")
    private let sub    = Color(hex: "#6A6A82")
    private let card   = Color(hex: "#111116")
    private let border = Color(hex: "#1E1E26")

    private let skills = ["Shooting", "Finishing", "Handles", "Playmaking", "Defense", "Rebounding", "IQ"]
    private let skillColors: [Color] = [
        Color(hex: "#39FF14"),
        Color(hex: "#FF7A00"),
        Color(hex: "#FFC247"),
        Color(hex: "#2DA8FF"),
        Color(hex: "#FF3B30"),
        Color(hex: "#2DA8FF"),
        Color(hex: "#9B8BFF"),
    ]

    @State private var appeared      = false
    @State private var pulseRing     = false
    @State private var phaseIndex    = 0
    @State private var barWidths     = Array(repeating: 0.0, count: 7)
    @State private var dotsVisible   = [false, false, false]

    private let phases = [
        "Analyzing your answers",
        "Weighing your skills",
        "Calibrating your score",
        "Almost ready",
    ]

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Pulsing ring
                ZStack {
                    Circle()
                        .stroke(neon.opacity(pulseRing ? 0.12 : 0.04), lineWidth: pulseRing ? 28 : 14)
                        .frame(width: 140, height: 140)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulseRing)

                    Circle()
                        .stroke(Color(hex: "#1E1E26"), lineWidth: 5)
                        .frame(width: 116, height: 116)

                    SpinningArc(color: neon)
                        .frame(width: 116, height: 116)

                    VStack(spacing: 3) {
                        Text("NETR")
                            .font(.system(size: 10, weight: .bold)).kerning(2.5)
                            .foregroundColor(neon.opacity(0.7))
                        Image(systemName: "waveform")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(neon)
                            .scaleEffect(pulseRing ? 1.12 : 0.92)
                            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulseRing)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)
                .animation(.spring(response: 0.65, dampingFraction: 0.6).delay(0.1), value: appeared)

                Spacer().frame(height: 28)

                // Phase text
                VStack(spacing: 6) {
                    Text("CALCULATING")
                        .font(.system(size: 10, weight: .bold)).kerning(2.5)
                        .foregroundColor(neon)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)

                    HStack(spacing: 0) {
                        Text(phases[phaseIndex])
                            .font(.custom("BarlowCondensed-Black", size: 30))
                            .foregroundColor(.white)
                            .id(phaseIndex)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))

                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(neon)
                                    .frame(width: 4, height: 4)
                                    .opacity(dotsVisible[i] ? 1 : 0.2)
                            }
                        }
                        .padding(.leading, 6)
                        .padding(.bottom, 2)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)
                }

                Spacer().frame(height: 28)

                // Skill bars
                VStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        HStack(spacing: 10) {
                            Text(skills[i])
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(sub)
                                .frame(width: 80, alignment: .trailing)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: "#1A1A20"))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(skillColors[i])
                                        .frame(width: geo.size.width * barWidths[i])
                                        .animation(.easeOut(duration: 0.55).delay(Double(i) * 0.08 + 0.5), value: barWidths[i])
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .padding(.horizontal, 32)
                .padding(16)
                .background(card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(border, lineWidth: 1))
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)

                Spacer()
            }
        }
        .onAppear {
            appeared  = true
            pulseRing = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                for i in 0..<7 { barWidths[i] = Double.random(in: 0.45...0.92) }
            }

            animateDots()

            for p in 1..<phases.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(p) * 1.2) {
                    withAnimation(.easeInOut(duration: 0.3)) { phaseIndex = p }
                }
            }
        }
    }

    private func animateDots() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                withAnimation(.easeInOut(duration: 0.3)) { dotsVisible[i] = true }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                    withAnimation(.easeInOut(duration: 0.3)) { dotsVisible[i] = false }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { animateDots() }
        }
    }
}

struct SpinningArc: View {
    let color: Color
    @State private var rotation = 0.0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
