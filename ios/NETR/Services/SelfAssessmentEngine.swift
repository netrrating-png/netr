import Foundation

nonisolated struct AssessmentOption: Identifiable, Sendable {
    let id: Int
    let emoji: String
    let label: String
    let detail: String
    let score: Double
}

nonisolated struct AssessmentQuestion: Identifiable, Sendable {
    let id: String
    let number: Int
    let category: String
    let prompt: String
    let options: [AssessmentOption]
}

// ─────────────────────────────────────────────────────────────
// MARK: — Playing Level
// "What is the highest level of play you played at?"
// Age + frequency handle all decay — no "ex-" / "current" split.
// ─────────────────────────────────────────────────────────────

nonisolated enum PlayingLevel: String, CaseIterable, Identifiable, Sendable {
    case neverPlayed       = "neverPlayed"
    case parkRegular       = "parkRegular"
    case middleSchool      = "middleSchool"
    case recLeague         = "recLeague"
    case highSchoolJV      = "highSchoolJV"
    case highSchoolVarsity = "highSchoolVarsity"
    case jucoOrD3          = "jucoOrD3"
    case semiPro           = "semiPro"
    case divisionII        = "divisionII"
    case divisionI         = "divisionI"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .neverPlayed:       return "Never played organized ball"
        case .parkRegular:       return "Pickup / park regular"
        case .middleSchool:      return "Middle school"
        case .recLeague:         return "Rec / adult league"
        case .highSchoolJV:      return "High school JV"
        case .highSchoolVarsity: return "High school varsity"
        case .jucoOrD3:          return "JUCO / Division III"
        case .semiPro:           return "Semi-pro / Pro-Am"
        case .divisionII:        return "NCAA Division II"
        case .divisionI:         return "NCAA Division I"
        }
    }

    var sublabel: String {
        switch self {
        case .neverPlayed:       return "Pickup, casual, or brand new to the game"
        case .parkRegular:       return "Consistent pickup — no organized school ball"
        case .middleSchool:      return "Played organized school ball at middle school level"
        case .recLeague:         return "Adult or recreational league — open enrollment"
        case .highSchoolJV:      return "Made a HS team — JV or limited varsity minutes"
        case .highSchoolVarsity: return "Meaningful varsity minutes — started or key role"
        case .jucoOrD3:          return "Competed at the collegiate level (JUCO or NCAA D3)"
        case .semiPro:           return "Pro-Am, semi-pro, or elite amateur circuits"
        case .divisionII:        return "NCAA Division II — scholarship-level competition"
        case .divisionI:         return "NCAA Division I — highest amateur level"
        }
    }

    var icon: String {
        switch self {
        case .neverPlayed:       return "footprints"
        case .parkRegular:       return "circle-dot"
        case .middleSchool:      return "graduation-cap"
        case .recLeague:         return "layout-grid"
        case .highSchoolJV:      return "award"
        case .highSchoolVarsity: return "trophy"
        case .jucoOrD3:          return "medal"
        case .semiPro:           return "zap"
        case .divisionII:        return "star"
        case .divisionI:         return "crown"
        }
    }

    // ── Score band ─────────────────────────────────────────────
    // floor: minimum score at this level (with heavy age/freq decay)
    // scoreCeiling: maximum reachable at this level (young, active, peak)

    var baseScore: Double {
        switch self {
        case .neverPlayed:       return 2.0
        case .parkRegular:       return 2.5
        case .middleSchool:      return 2.6
        case .recLeague:         return 2.8
        case .highSchoolJV:      return 3.0
        case .highSchoolVarsity: return 3.5
        case .jucoOrD3:          return 4.0
        case .semiPro:           return 4.5
        case .divisionII:        return 5.0
        case .divisionI:         return 5.5
        }
    }

    var scoreCeiling: Double {
        switch self {
        case .neverPlayed:       return 3.0
        case .parkRegular:       return 4.5
        case .middleSchool:      return 4.8
        case .recLeague:         return 5.0
        case .highSchoolJV:      return 5.6
        case .highSchoolVarsity: return 6.8
        case .jucoOrD3:          return 7.6
        case .semiPro:           return 8.2
        case .divisionII:        return 8.8
        case .divisionI:         return 9.5
        }
    }

    // Frequency sensitivity — higher levels decay faster when inactive
    var frequencySensitivity: Double {
        switch self {
        case .neverPlayed:       return 0.30
        case .parkRegular:       return 0.40
        case .middleSchool:      return 0.45
        case .recLeague:         return 0.50
        case .highSchoolJV:      return 0.60
        case .highSchoolVarsity: return 0.75
        case .jucoOrD3:          return 0.90
        case .semiPro:           return 1.00
        case .divisionII:        return 1.10
        case .divisionI:         return 1.20
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Age Group
// athleticModifier kept for UI display only ("age-adjusted" note).
// The real age impact is applied via ageLevelDecay() in the engine.
// ─────────────────────────────────────────────────────────────

nonisolated enum AgeGroup: String, CaseIterable, Identifiable, Sendable {
    case youth      = "youth"
    case youngAdult = "youngAdult"
    case adult      = "adult"
    case lateAdult  = "lateAdult"
    case masters    = "masters"
    case senior     = "senior"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .youth:      return "13–18"
        case .youngAdult: return "19–25"
        case .adult:      return "26–32"
        case .lateAdult:  return "33–40"
        case .masters:    return "41–50"
        case .senior:     return "51+"
        }
    }

    var sublabel: String {
        switch self {
        case .youth:      return "Still developing athletically"
        case .youngAdult: return "Physical prime"
        case .adult:      return "Prime or near-prime"
        case .lateAdult:  return "Experience compensates for some decline"
        case .masters:    return "Vet game, noticeable athletic decline"
        case .senior:     return "Pure IQ and experience"
        }
    }

    // UI-only: used to show "age-adjusted" note on the result screen
    var athleticModifier: Double {
        switch self {
        case .youth:      return 1.00
        case .youngAdult: return 1.00
        case .adult:      return 0.97
        case .lateAdult:  return 0.91
        case .masters:    return 0.85
        case .senior:     return 0.82
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Play Frequency
// ─────────────────────────────────────────────────────────────

nonisolated enum PlayFrequency: String, CaseIterable, Identifiable, Sendable {
    case almostNever  = "almostNever"
    case fewTimesYear = "fewTimesYear"
    case monthly      = "monthly"
    case weekly       = "weekly"
    case multiWeekly  = "multiWeekly"
    case daily        = "daily"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .almostNever:  return "Rarely — less than once a month"
        case .fewTimesYear: return "A few times a year"
        case .monthly:      return "A few times a month"
        case .weekly:       return "1–2 times a week"
        case .multiWeekly:  return "3–4 times a week"
        case .daily:        return "Almost every day"
        }
    }

    var emoji: String {
        switch self {
        case .almostNever:  return "🌵"
        case .fewTimesYear: return "📅"
        case .monthly:      return "🗓️"
        case .weekly:       return "✅"
        case .multiWeekly:  return "🔥"
        case .daily:        return "💪"
        }
    }

    // Base decay factor before level sensitivity is applied
    var baseFactor: Double {
        switch self {
        case .almostNever:  return 0.72
        case .fewTimesYear: return 0.81
        case .monthly:      return 0.88
        case .weekly:       return 0.94
        case .multiWeekly:  return 0.98
        case .daily:        return 1.00
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Player Position
// ─────────────────────────────────────────────────────────────

nonisolated enum PlayerPosition: String, CaseIterable, Identifiable, Sendable {
    case pg = "pg"
    case sg = "sg"
    case sf = "sf"
    case pf = "pf"
    case c  = "c"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pg: return "Point Guard (PG)"
        case .sg: return "Shooting Guard (SG)"
        case .sf: return "Small Forward (SF)"
        case .pf: return "Power Forward (PF)"
        case .c:  return "Center (C)"
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

    var icon: String {
        switch self {
        case .pg: return "route"
        case .sg: return "crosshair"
        case .sf: return "git-branch"
        case .pf: return "dumbbell"
        case .c:  return "shield"
        }
    }

    var sublabel: String {
        switch self {
        case .pg: return "Floor general, runs the offense"
        case .sg: return "Scorer, wings, handles the ball"
        case .sf: return "Versatile, attacks from anywhere"
        case .pf: return "Physical, interior and stretch"
        case .c:  return "Paint presence, rebounding, rim protection"
        }
    }

    // ── Position weights ────────────────────────────────────────
    // Higher = this category matters more for the position.
    // Low weights on irrelevant categories ensure they barely move the score.
    // Keys match question categories: scoring, iq, defense, handles,
    //                                 playmaking, finishing, rebounding

    var categoryWeightOverrides: [String: Double] {
        switch self {
        case .pg:
            return [
                "scoring":    0.80,   // important but not primary
                "finishing":  0.65,   // less critical
                "handles":    1.50,   // most important — PG lives and dies by this
                "playmaking": 1.40,   // second most important
                "defense":    0.85,
                "rebounding": 0.20,   // nearly irrelevant — a PG missing boards is fine
                "iq":         1.35,
            ]
        case .sg:
            return [
                "scoring":    1.35,   // primary role
                "finishing":  1.10,
                "handles":    1.15,
                "playmaking": 0.90,
                "defense":    1.00,
                "rebounding": 0.50,   // not expected
                "iq":         1.00,
            ]
        case .sf:
            return [
                "scoring":    1.10,
                "finishing":  1.05,
                "handles":    0.85,
                "playmaking": 1.00,
                "defense":    1.15,
                "rebounding": 0.85,
                "iq":         1.05,
            ]
        case .pf:
            return [
                "scoring":    0.85,
                "finishing":  1.20,
                "handles":    0.50,   // not expected
                "playmaking": 0.70,
                "defense":    1.20,
                "rebounding": 1.40,
                "iq":         1.00,
            ]
        case .c:
            return [
                "scoring":    0.30,   // barely matters for a C
                "finishing":  1.30,
                "handles":    0.20,   // nearly irrelevant
                "playmaking": 0.55,
                "defense":    1.25,
                "rebounding": 1.65,   // single most important category
                "iq":         0.90,
            ]
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Assessment Context
// ─────────────────────────────────────────────────────────────

nonisolated struct AssessmentContext: Sendable {
    let ageGroup: AgeGroup
    let playingLevel: PlayingLevel
    let playFrequency: PlayFrequency
    let position: PlayerPosition
}

// ─────────────────────────────────────────────────────────────
// MARK: — Question Bank
// ─────────────────────────────────────────────────────────────

nonisolated enum AssessmentQuestionBank: Sendable {
    static let all: [AssessmentQuestion] = [

        // SCORING (Q1, Q2, Q3)
        AssessmentQuestion(
            id: "scoring_1", number: 1, category: "scoring",
            prompt: "When you're open on the perimeter, what usually happens?",
            options: [
                AssessmentOption(id: 0, emoji: "🙅", label: "I usually pass it up", detail: "I don't feel comfortable taking that shot", score: 0.05),
                AssessmentOption(id: 1, emoji: "📍", label: "Only if it's a very comfortable spot", detail: "Very selective — ideal look only", score: 0.28),
                AssessmentOption(id: 2, emoji: "✅", label: "I'll take it with decent confidence", detail: "I back myself from the perimeter when I'm open", score: 0.52),
                AssessmentOption(id: 3, emoji: "⚡", label: "I'm a real shooting threat from outside", detail: "The defense has to respect me and close out hard", score: 0.75),
                AssessmentOption(id: 4, emoji: "🔒", label: "Defenders have to stay attached to me", detail: "My shot changes how the whole team is guarded", score: 0.92),
            ]
        ),
        AssessmentQuestion(
            id: "scoring_2", number: 2, category: "scoring",
            prompt: "How well can you create a shot for yourself?",
            options: [
                AssessmentOption(id: 0, emoji: "🙅", label: "I rarely create my own shot", detail: "I need the ball ready to go — I can't manufacture looks", score: 0.05),
                AssessmentOption(id: 1, emoji: "🤞", label: "I can get one occasionally", detail: "Every now and then, but it's not reliable", score: 0.28),
                AssessmentOption(id: 2, emoji: "✅", label: "I can create decent looks in rhythm", detail: "I get myself open shots with regularity when things are flowing", score: 0.52),
                AssessmentOption(id: 3, emoji: "🎯", label: "I create good looks consistently", detail: "I manufacture shots for myself in most situations", score: 0.75),
                AssessmentOption(id: 4, emoji: "🔥", label: "I can get to my spots against almost anyone", detail: "Shot creation is a strength — quality looks regardless of the defense", score: 0.92),
            ]
        ),
        AssessmentQuestion(
            id: "scoring_3", number: 3, category: "scoring",
            prompt: "How do the people you play with usually view you as a scorer?",
            options: [
                AssessmentOption(id: 0, emoji: "👻", label: "Not really a shooting option", detail: "Nobody expects me to score — that's not my role", score: 0.05),
                AssessmentOption(id: 1, emoji: "🤝", label: "I score here and there", detail: "I contribute occasionally but I'm not someone they're looking to feed", score: 0.28),
                AssessmentOption(id: 2, emoji: "✅", label: "I'm a reliable shooting option", detail: "Teammates trust me to score when I get the ball in good spots", score: 0.52),
                AssessmentOption(id: 3, emoji: "⭐", label: "I'm one of the main shooting threats", detail: "I'm a consistent go-to — teams build looks for me", score: 0.75),
                AssessmentOption(id: 4, emoji: "🎯", label: "Defenses clearly key in on me", detail: "I'm the player they game-plan for — and I still score", score: 0.92),
            ]
        ),

        // IQ (Q4, Q5)
        AssessmentQuestion(
            id: "iq_1", number: 4, category: "iq",
            prompt: "How well do you use screens in live play?",
            options: [
                AssessmentOption(id: 0, emoji: "😅", label: "I don't really know how to use them well", detail: "I run off them but I'm not making reads or setting anything up", score: 0.05),
                AssessmentOption(id: 1, emoji: "🚶", label: "I use them basically, without many reads", detail: "I know to come off the screen but I'm not reading the coverage", score: 0.28),
                AssessmentOption(id: 2, emoji: "👀", label: "I can make simple reads off them", detail: "I can tell the difference between a curl and a fade", score: 0.52),
                AssessmentOption(id: 3, emoji: "🧩", label: "I set defenders up and use screens with purpose", detail: "I time and use screens deliberately to create advantages", score: 0.75),
                AssessmentOption(id: 4, emoji: "🎓", label: "I consistently exploit coverages and create advantages", detail: "I read switch, hedge, ICE — and punish each one differently", score: 0.92),
            ]
        ),
        AssessmentQuestion(
            id: "iq_2", number: 5, category: "iq",
            prompt: "In close games, how aware are you of time, score, spacing, and matchups?",
            options: [
                AssessmentOption(id: 0, emoji: "🙈", label: "I mostly just play without thinking about that", detail: "I'm focused on the action in front of me, not the big picture", score: 0.05),
                AssessmentOption(id: 1, emoji: "🤷", label: "I notice some of it, but not consistently", detail: "I pick up on it sometimes but miss things regularly", score: 0.28),
                AssessmentOption(id: 2, emoji: "🧠", label: "I usually understand the situation", detail: "I know the score, the clock, and who to go to", score: 0.52),
                AssessmentOption(id: 3, emoji: "🗣️", label: "I help organize and execute in big moments", detail: "I'm communicating and making sure we run the right things", score: 0.75),
                AssessmentOption(id: 4, emoji: "👑", label: "I see the game a step ahead of most players", detail: "I process matchups, spacing, and situations before they fully develop", score: 0.92),
            ]
        ),

        // DEFENSE (Q6, Q7)
        AssessmentQuestion(
            id: "defense_1", number: 6, category: "defense",
            prompt: "How do you usually defend 1-on-1?",
            options: [
                AssessmentOption(id: 0, emoji: "😬", label: "I get beat a lot", detail: "I struggle to stay in front of people consistently", score: 0.05),
                AssessmentOption(id: 1, emoji: "🤷", label: "I compete, but I'm not very effective", detail: "I try, but good offensive players get past me more often than not", score: 0.28),
                AssessmentOption(id: 2, emoji: "💪", label: "I can hold my own", detail: "I compete and make them work — I'm not a liability", score: 0.52),
                AssessmentOption(id: 3, emoji: "🛡️", label: "I make good scorers work hard", detail: "Solid players can score on me but have to earn every bucket", score: 0.75),
                AssessmentOption(id: 4, emoji: "🔒", label: "I consistently shut down my matchup", detail: "I lock people up regularly — my matchup knows they're in for a tough night", score: 0.92),
            ]
        ),
        AssessmentQuestion(
            id: "defense_2", number: 7, category: "defense",
            prompt: "How good are you away from the ball on defense?",
            options: [
                AssessmentOption(id: 0, emoji: "😴", label: "I ball-watch and miss rotations", detail: "I follow the ball instead of staying connected to my man", score: 0.05),
                AssessmentOption(id: 1, emoji: "🙂", label: "I mostly just stay near my man", detail: "I keep tabs on my player but don't make team plays", score: 0.28),
                AssessmentOption(id: 2, emoji: "✅", label: "I make normal help and recovery rotations", detail: "I rotate when it's clear and get back to my man", score: 0.52),
                AssessmentOption(id: 3, emoji: "🗣️", label: "I rotate early and communicate well", detail: "I call out screens, hedge, and help before breakdowns happen", score: 0.75),
                AssessmentOption(id: 4, emoji: "🧱", label: "I anchor and organize the defense", detail: "I direct the whole team — I see breakdowns forming and fix them early", score: 0.92),
            ]
        ),

        // HANDLES (Q8, Q9)
        AssessmentQuestion(
            id: "handles_1", number: 8, category: "handles",
            prompt: "How comfortable are you handling the ball under pressure?",
            options: [
                AssessmentOption(id: 0, emoji: "😰", label: "I really struggle with pressure", detail: "It disrupts me — I pick it up early or turn it over", score: 0.05),
                AssessmentOption(id: 1, emoji: "😬", label: "I survive, but just barely", detail: "I get through it but I'm not doing anything creative", score: 0.28),
                AssessmentOption(id: 2, emoji: "✅", label: "I'm generally comfortable", detail: "Pressure doesn't bother me — I keep things moving", score: 0.52),
                AssessmentOption(id: 3, emoji: "🔥", label: "I handle pressure and create advantages", detail: "I break pressure and use it to attack the defense", score: 0.75),
                AssessmentOption(id: 4, emoji: "💨", label: "Pressure helps me attack and break down the defense", detail: "I want teams to press me — it opens things up", score: 0.92),
            ]
        ),
        AssessmentQuestion(
            id: "handles_2", number: 9, category: "handles",
            prompt: "How deep is your handle in real games?",
            options: [
                AssessmentOption(id: 0, emoji: "1️⃣", label: "Very basic", detail: "Simple dribble to move — not a creation tool", score: 0.05),
                AssessmentOption(id: 1, emoji: "2️⃣", label: "A couple dependable moves", detail: "Crossover or hesitation — a few things that work at this level", score: 0.28),
                AssessmentOption(id: 2, emoji: "🎒", label: "Multiple moves with some counters", detail: "I have a real bag and can counter when my first move is taken", score: 0.52),
                AssessmentOption(id: 3, emoji: "🧙", label: "I can chain moves together and shift defenders", detail: "I keep defenders guessing and get where I want on the floor", score: 0.75),
                AssessmentOption(id: 4, emoji: "💫", label: "My handle creates offense for me and others consistently", detail: "My dribble is a weapon — it creates advantages for the whole team", score: 0.92),
            ]
        ),

        // PLAYMAKING (Q10, Q11)
        AssessmentQuestion(
            id: "playmaking_1", number: 10, category: "playmaking",
            prompt: "How often do you create easy baskets for other players?",
            options: [
                AssessmentOption(id: 0, emoji: "🙅", label: "Rarely", detail: "I'm not looking to create for others — I play my own game", score: 0.05),
                AssessmentOption(id: 1, emoji: "🤝", label: "Mostly only simple passes", detail: "Basic kick-outs and handoffs — nothing requiring real vision", score: 0.28),
                AssessmentOption(id: 2, emoji: "🎯", label: "Pretty often", detail: "I find open teammates consistently and set them up in good spots", score: 0.52),
                AssessmentOption(id: 3, emoji: "⭐", label: "I create good looks consistently", detail: "Teammates trust me to get them open — I'm a real facilitator", score: 0.75),
                AssessmentOption(id: 4, emoji: "🎩", label: "Creating for others is one of my biggest strengths", detail: "I see angles others miss and consistently find teammates in high-percentage spots", score: 0.92),
            ]
        ),
        AssessmentQuestion(
            id: "playmaking_2", number: 11, category: "playmaking",
            prompt: "When you drive and help collapses, what usually happens?",
            options: [
                AssessmentOption(id: 0, emoji: "💥", label: "I force the shot too often", detail: "I keep going regardless — the kick-out doesn't come naturally", score: 0.05),
                AssessmentOption(id: 1, emoji: "😬", label: "I pass late or only when stuck", detail: "I'll kick it out but only once I'm fully stopped", score: 0.28),
                AssessmentOption(id: 2, emoji: "👁️", label: "I usually make the right read", detail: "I can tell if I should finish or kick — and I usually choose correctly", score: 0.52),
                AssessmentOption(id: 3, emoji: "🎯", label: "I draw help on purpose and find the open man", detail: "I attack the paint with the intention of collapsing the defense", score: 0.75),
                AssessmentOption(id: 4, emoji: "🎬", label: "I manipulate the defense before it fully reacts", detail: "I create the advantage before the help arrives — I'm a step ahead", score: 0.92),
            ]
        ),

        // FINISHING (Q12, Q13)
        AssessmentQuestion(
            id: "finishing_1", number: 12, category: "finishing",
            prompt: "How well do you finish at the rim with defenders around you?",
            options: [
                AssessmentOption(id: 0, emoji: "😬", label: "I struggle once there's contact", detail: "Contact takes me off my shot — I need a clean path", score: 0.05),
                AssessmentOption(id: 1, emoji: "🤞", label: "I finish mostly when the lane is clean", detail: "I can score with a clear look, but contact is a problem", score: 0.28),
                AssessmentOption(id: 2, emoji: "✅", label: "I finish through light contact", detail: "A hand or body doesn't stop me — I finish with decent reliability", score: 0.52),
                AssessmentOption(id: 3, emoji: "🏆", label: "I finish well through real contests", detail: "I score through legit defenders — I have counters at the rim", score: 0.75),
                AssessmentOption(id: 4, emoji: "🔥", label: "I finish through heavy contact and draw fouls", detail: "Contact doesn't stop me — I absorb it, score, and get to the line", score: 0.92),
            ]
        ),
        AssessmentQuestion(
            id: "finishing_2", number: 13, category: "finishing",
            prompt: "How many ways can you finish around the basket?",
            options: [
                AssessmentOption(id: 0, emoji: "1️⃣", label: "Mostly one way with one hand", detail: "I have a go-to finish and that's about it", score: 0.05),
                AssessmentOption(id: 1, emoji: "2️⃣", label: "A couple basic finishes", detail: "A layup and maybe a floater or reverse", score: 0.28),
                AssessmentOption(id: 2, emoji: "✅", label: "I can use either hand in the right situations", detail: "Functional finishes with both hands when the defense dictates", score: 0.52),
                AssessmentOption(id: 3, emoji: "💪", label: "I have multiple finishes and counters", detail: "I adjust on the fly — I'm not predictable at the rim", score: 0.75),
                AssessmentOption(id: 4, emoji: "🎯", label: "I can finish with either hand from different angles consistently", detail: "Defenders can't take a side on me — I go through, around, or over", score: 0.92),
            ]
        ),

        // REBOUNDING (Q14, Q15)
        AssessmentQuestion(
            id: "rebounding_1", number: 14, category: "rebounding",
            prompt: "When a shot goes up, what are you usually doing?",
            options: [
                AssessmentOption(id: 0, emoji: "👀", label: "Watching the play", detail: "I see who gets it — I'm not chasing the ball", score: 0.05),
                AssessmentOption(id: 1, emoji: "🚶", label: "Moving toward the ball late", detail: "I react after it's off the rim — I'm not anticipating", score: 0.28),
                AssessmentOption(id: 2, emoji: "📦", label: "Finding position and boxing out", detail: "I make contact and go after it — I'm a real factor on the glass", score: 0.52),
                AssessmentOption(id: 3, emoji: "🏃", label: "Reading the miss and getting into position early", detail: "I track the shot and have my body in place before it hits the iron", score: 0.75),
                AssessmentOption(id: 4, emoji: "🧲", label: "Anticipating the rebound before most players do", detail: "I read arc and angle — I'm already there before the ball comes down", score: 0.92),
            ]
        ),
        AssessmentQuestion(
            id: "rebounding_2", number: 15, category: "rebounding",
            prompt: "How much of an impact do you make on the glass in your games?",
            options: [
                AssessmentOption(id: 0, emoji: "❌", label: "Rebounding is not part of my game", detail: "I don't factor into it — other roles take priority for me", score: 0.05),
                AssessmentOption(id: 1, emoji: "🤷", label: "I grab a few if they come to me", detail: "I get boards when they happen to be there, but I don't seek them", score: 0.28),
                AssessmentOption(id: 2, emoji: "🙋", label: "I'm a solid rebounder for my role", detail: "I contribute consistently on the glass relative to my position", score: 0.52),
                AssessmentOption(id: 3, emoji: "💪", label: "I'm one of the better rebounders in most games", detail: "I lead or co-lead my team on the boards most nights", score: 0.75),
                AssessmentOption(id: 4, emoji: "🦁", label: "Rebounding is one of my biggest strengths", detail: "It's a weapon — I dominate the glass and teams notice", score: 0.92),
            ]
        ),
    ]
}

// ─────────────────────────────────────────────────────────────
// MARK: — Scoring Engine
// ─────────────────────────────────────────────────────────────

nonisolated enum AssessmentScoringEngine: Sendable {

    static let selfAssessmentDiscount: Double = 0.85  // discount self-reported answers
    static let absoluteCeiling: Double = 9.5           // regular player max (pros are 9.5+)
    static let absoluteFloor: Double   = 2.0

    // Global category weights (position weights multiply on top of these)
    static let categoryWeights: [String: Double] = [
        "scoring":    1.00,
        "iq":         1.10,
        "defense":    1.00,
        "handles":    0.90,
        "playmaking": 1.00,
        "finishing":  0.90,
        "rebounding": 0.85,
    ]

    // ── Age × Level decay ───────────────────────────────────────
    // How much of the level band can you still reach given your age?
    // Higher levels decay faster with age since you've been away from
    // a higher competition environment for longer.
    // Returns a multiplier (0–1) applied to the (ceiling - floor) band.

    static func ageLevelDecay(level: PlayingLevel, age: AgeGroup) -> Double {
        switch age {

        case .youth: // 13–18 — at or near peak for their level
            switch level {
            case .neverPlayed, .parkRegular, .middleSchool,
                 .recLeague, .highSchoolJV, .highSchoolVarsity:
                return 1.00
            case .jucoOrD3, .semiPro, .divisionII, .divisionI:
                return 0.95 // rare at this age — early college
            }

        case .youngAdult: // 19–25 — physical prime, minimal decay
            switch level {
            case .neverPlayed, .parkRegular, .middleSchool, .recLeague:
                return 1.00
            case .highSchoolJV:
                return 0.97 // recently finished JV
            case .highSchoolVarsity:
                return 0.97 // recently finished varsity
            case .jucoOrD3, .semiPro, .divisionII, .divisionI:
                return 1.00 // likely currently at this level
            }

        case .adult: // 26–32 — modest decay begins
            switch level {
            case .neverPlayed, .parkRegular, .middleSchool, .recLeague:
                return 0.98
            case .highSchoolJV:
                return 0.93
            case .highSchoolVarsity:
                return 0.91
            case .jucoOrD3:
                return 0.90
            case .semiPro:
                return 0.89
            case .divisionII:
                return 0.88
            case .divisionI:
                return 0.87
            }

        case .lateAdult: // 33–40 — meaningful decay for high levels
            switch level {
            case .neverPlayed, .parkRegular, .middleSchool, .recLeague:
                return 0.95
            case .highSchoolJV:
                return 0.86
            case .highSchoolVarsity:
                return 0.83
            case .jucoOrD3:
                return 0.80
            case .semiPro:
                return 0.79
            case .divisionII:
                return 0.78
            case .divisionI:
                return 0.77
            }

        case .masters: // 41–50 — significant decay
            switch level {
            case .neverPlayed, .parkRegular, .middleSchool, .recLeague:
                return 0.91
            case .highSchoolJV:
                return 0.79
            case .highSchoolVarsity:
                return 0.75
            case .jucoOrD3:
                return 0.72
            case .semiPro:
                return 0.71
            case .divisionII:
                return 0.70
            case .divisionI:
                return 0.69
            }

        case .senior: // 51+ — heavy decay, IQ carries the load
            switch level {
            case .neverPlayed, .parkRegular, .middleSchool, .recLeague:
                return 0.87
            case .highSchoolJV:
                return 0.73
            case .highSchoolVarsity:
                return 0.69
            case .jucoOrD3:
                return 0.65
            case .semiPro:
                return 0.64
            case .divisionII:
                return 0.63
            case .divisionI:
                return 0.62
            }
        }
    }

    // ── Frequency decay ─────────────────────────────────────────
    // How much does inactivity hurt you at your level?
    // High-level players who rarely play decay much faster than
    // a park regular who plays rarely — they have more to lose.
    // Formula: baseFactor ^ levelSensitivity

    static func frequencyDecay(level: PlayingLevel, freq: PlayFrequency) -> Double {
        pow(freq.baseFactor, level.frequencySensitivity)
    }

    // ── Main calculation ────────────────────────────────────────

    static func calculate(
        answers: [String: Int],
        context: AssessmentContext
    ) -> AssessmentResult {
        let questions   = AssessmentQuestionBank.all
        let floor       = context.playingLevel.baseScore
        let ceiling     = min(context.playingLevel.scoreCeiling, absoluteCeiling)
        let band        = ceiling - floor

        // 1. Combined decay from age × level interaction and frequency
        let ageFactor   = ageLevelDecay(level: context.playingLevel, age: context.ageGroup)
        let freqFactor  = frequencyDecay(level: context.playingLevel, freq: context.playFrequency)
        let combined    = ageFactor * freqFactor

        // 2. Effective ceiling: how high can this player actually reach?
        //    Floor stays fixed — the level guarantees a minimum.
        let effectiveCeiling = min(floor + band * combined, ceiling)

        // 3. Score answers per category (0 → floor, 1 → effectiveCeiling)
        let posOverrides = context.position.categoryWeightOverrides

        var rawByCategory: [String: [Double]] = [:]
        for q in questions {
            guard let answerId = answers[q.id],
                  let option = q.options.first(where: { $0.id == answerId })
            else { continue }
            rawByCategory[q.category, default: []].append(option.score)
        }

        // 4. Average answers per category and apply self-assessment discount
        var categoryAvg: [String: Double] = [:]
        for (cat, scores) in rawByCategory {
            let avg = scores.reduce(0, +) / Double(scores.count)
            categoryAvg[cat] = avg * selfAssessmentDiscount
        }

        // 5. Map discounted score (0–1) into [floor, effectiveCeiling]
        var netrByCategory: [String: Double] = [:]
        for (cat, d) in categoryAvg {
            let mapped = floor + d * (effectiveCeiling - floor)
            netrByCategory[cat] = mapped.clamped(to: absoluteFloor...effectiveCeiling)
        }

        // 6. Fill any unanswered categories with the floor
        let allCategories = ["scoring", "iq", "defense", "handles", "playmaking", "finishing", "rebounding"]
        for cat in allCategories where netrByCategory[cat] == nil {
            netrByCategory[cat] = floor
        }

        // 7. Weighted composite: global weight × position weight
        var wSum = 0.0, wTotal = 0.0
        for (cat, score) in netrByCategory {
            let globalW = categoryWeights[cat] ?? 1.0
            let posW    = posOverrides[cat]    ?? 1.0
            let w       = globalW * posW
            wSum   += score * w
            wTotal += w
        }
        let composite = wTotal > 0 ? wSum / wTotal : floor
        let overall   = composite.clamped(to: absoluteFloor...effectiveCeiling)

        // 8. Strengths / focus areas weighted by position relevance
        let sorted = netrByCategory.sorted { a, b in
            let wa = (posOverrides[a.key] ?? 1.0) * a.value
            let wb = (posOverrides[b.key] ?? 1.0) * b.value
            return wa > wb
        }
        let strengths   = Array(sorted.prefix(2).map { $0.key })
        let focusAreas  = Array(sorted.suffix(2).map { $0.key })

        return AssessmentResult(
            overallScore:   overall,
            categoryScores: netrByCategory,
            strengths:      strengths,
            focusAreas:     focusAreas,
            context:        context,
            tierLabel:      tierLabel(overall),
            tierColorHex:   tierColorHex(overall)
        )
    }

    static func tierLabel(_ r: Double) -> String {
        NETRRating.tierName(for: r)
    }

    static func tierColorHex(_ r: Double) -> String {
        NETRRating.tier(for: r)?.hexColor ?? "#444444"
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: — Assessment Result
// ─────────────────────────────────────────────────────────────

nonisolated struct AssessmentResult: Sendable {
    let overallScore: Double
    let categoryScores: [String: Double]
    let strengths: [String]
    let focusAreas: [String]
    let context: AssessmentContext
    let tierLabel: String
    let tierColorHex: String

    var formattedScore: String { String(format: "%.1f", overallScore) }

    static let categoryDisplayNames: [String: String] = [
        "scoring":    "Shooting",
        "iq":         "IQ",
        "defense":    "Defense",
        "handles":    "Handles",
        "playmaking": "Playmaking",
        "finishing":  "Finishing",
        "rebounding": "Rebounding",
    ]

    static let categoryIcons: [String: String] = [
        "scoring":    "crosshair",
        "iq":         "brain",
        "defense":    "shield",
        "handles":    "hand",
        "playmaking": "zap",
        "finishing":  "flame",
        "rebounding": "arrow-up-circle",
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

// ─────────────────────────────────────────────────────────────
// MARK: — Helpers
// ─────────────────────────────────────────────────────────────

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
