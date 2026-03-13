// ─────────────────────────────────────────────────────────────────────────────
// SelfAssessmentEngine.swift  —  NETR App
//
// Fixes:
//   1. Scenario-based questions replace raw 1–5 sliders (harder to max out)
//   2. Score mapping: answers produce realistic ranges, not 0–10 linear
//   3. Self-assessment ceiling: max possible score is 7.2 (Park Legend range)
//      — Elite/Pro ratings (8+) can only come from peer reviews
//   4. Self-assessment discount: 28% applied to overall composite
//   5. Age + context modifier applied to final score
//   6. Category scores shown as the actual skill value, not raw answer * 2
//
// Score philosophy:
//   A completely honest self-assessment by an avg recreational player → 3.5–4.5
//   A strong park player honest about their game           → 5.0–6.5
//   A genuinely elite player (D1, pro)                    → 6.5–7.2 (ceiling)
//   10.0 is unreachable through self-assessment. Period.
//
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

// MARK: ─── Answer Option ──────────────────────────────────────────────────────

struct AssessmentOption: Identifiable {
    let id: Int          // 0 = lowest, 3 = highest for most questions
    let label: String
    let sublabel: String // concrete detail to help honest selection
    let score: Double    // raw score contribution (0.0 – 1.0)
}

// MARK: ─── Question ───────────────────────────────────────────────────────────

struct AssessmentQuestion: Identifiable {
    let id: String
    let category: String     // maps to skill category
    let prompt: String       // the question
    let options: [AssessmentOption]
}

// MARK: ─── Context ────────────────────────────────────────────────────────────

struct AssessmentContext {
    let ageGroup: AgeGroup
    let playingLevel: PlayingLevel

    enum AgeGroup: String, CaseIterable, Identifiable {
        case teen       = "teen"        // Under 20
        case earlyAdult = "earlyAdult"  // 20–27
        case adult      = "adult"       // 28–38
        case master     = "master"      // 39+

        var id: String { rawValue }
        var label: String {
            switch self {
            case .teen:       return "Under 20"
            case .earlyAdult: return "20–27"
            case .adult:      return "28–38"
            case .master:     return "39+"
            }
        }

        /// Age-based athletic ceiling modifier (0.85 – 1.0)
        /// A 40-year-old ex-player is still a good player, just not peak
        var athleticModifier: Double {
            switch self {
            case .teen:       return 1.0
            case .earlyAdult: return 1.0
            case .adult:      return 0.93   // modest reduction
            case .master:     return 0.87
            }
        }
    }

    enum PlayingLevel: String, CaseIterable, Identifiable {
        case justStarted  = "justStarted"
        case recreational = "recreational"
        case exHighSchool = "exHighSchool"
        case exCollegiate = "exCollegiate"
        case currentLeague = "currentLeague"
        case parkRegular  = "parkRegular"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .justStarted:   return "Just started playing"
            case .recreational:  return "Rec / casual pick-up"
            case .exHighSchool:  return "Ex-high school player"
            case .exCollegiate:  return "Ex-collegiate player"
            case .currentLeague: return "Currently in a league"
            case .parkRegular:   return "Park regular / run every week"
            }
        }

        /// Base score anchor — the floor the assessment builds from
        var baseScore: Double {
            switch self {
            case .justStarted:   return 1.5
            case .recreational:  return 2.8
            case .exHighSchool:  return 3.5   // ex-HS player → starts around 3.5
            case .exCollegiate:  return 5.0
            case .currentLeague: return 4.2
            case .parkRegular:   return 4.0
            }
        }

        /// Max possible score from self-assessment for this background
        var scoreCeiling: Double {
            switch self {
            case .justStarted:   return 3.5
            case .recreational:  return 4.8
            case .exHighSchool:  return 5.5   // honest ex-HS → 3.5–5.5
            case .exCollegiate:  return 6.8
            case .currentLeague: return 6.5
            case .parkRegular:   return 6.0
            }
        }
    }
}

// MARK: ─── Question Bank ──────────────────────────────────────────────────────

struct AssessmentQuestionBank {
    static let all: [AssessmentQuestion] = [

        // ── SCORING ──────────────────────────────────────────────────────────
        AssessmentQuestion(
            id: "scoring_1",
            category: "scoring",
            prompt: "When you're open on the perimeter, what usually happens?",
            options: [
                AssessmentOption(id: 0, label: "I pass it",          sublabel: "Not confident taking that shot",                score: 0.1),
                AssessmentOption(id: 1, label: "I shoot sometimes",  sublabel: "Maybe 50/50 on whether I take it",              score: 0.35),
                AssessmentOption(id: 2, label: "I shoot it",         sublabel: "I back myself from mid-range or 3",             score: 0.6),
                AssessmentOption(id: 3, label: "I want that ball",   sublabel: "I'm a threat from deep, defenders notice me",   score: 0.85),
            ]
        ),
        AssessmentQuestion(
            id: "scoring_2",
            category: "scoring",
            prompt: "How often do you score consistently in pick-up games?",
            options: [
                AssessmentOption(id: 0, label: "Rarely",             sublabel: "Scoring isn't really my thing",                score: 0.1),
                AssessmentOption(id: 1, label: "Sometimes",          sublabel: "A few buckets when I get good looks",           score: 0.35),
                AssessmentOption(id: 2, label: "Most games",         sublabel: "I get mine, reliable in most runs",             score: 0.6),
                AssessmentOption(id: 3, label: "Every game",         sublabel: "I'm one of the main scorers wherever I play",   score: 0.85),
            ]
        ),

        // ── IQ ────────────────────────────────────────────────────────────────
        AssessmentQuestion(
            id: "iq_1",
            category: "iq",
            prompt: "In a close game, how aware are you of the situation?",
            options: [
                AssessmentOption(id: 0, label: "Just playing",         sublabel: "I'm focused on my matchup, not the big picture", score: 0.1),
                AssessmentOption(id: 1, label: "Somewhat aware",        sublabel: "I know the score, react when told",              score: 0.35),
                AssessmentOption(id: 2, label: "Pretty aware",          sublabel: "I adjust my game to what the team needs",        score: 0.6),
                AssessmentOption(id: 3, label: "Always locked in",      sublabel: "I see the floor, I know who to feed, when to foul", score: 0.85),
            ]
        ),
        AssessmentQuestion(
            id: "iq_2",
            category: "iq",
            prompt: "When the defense takes away your first option, you usually:",
            options: [
                AssessmentOption(id: 0, label: "Force it anyway",       sublabel: "I go for my move regardless",                   score: 0.05),
                AssessmentOption(id: 1, label: "Reset or panic",        sublabel: "I look to reset but sometimes lose it",         score: 0.3),
                AssessmentOption(id: 2, label: "Find my second option", sublabel: "I have a countermove ready",                    score: 0.6),
                AssessmentOption(id: 3, label: "Exploit the coverage",  sublabel: "I read the defense and punish the adjustment",  score: 0.85),
            ]
        ),

        // ── DEFENSE ───────────────────────────────────────────────────────────
        AssessmentQuestion(
            id: "defense_1",
            category: "defense",
            prompt: "How do players you guard typically feel about you?",
            options: [
                AssessmentOption(id: 0, label: "They ignore me",        sublabel: "People go at me on purpose",                    score: 0.05),
                AssessmentOption(id: 1, label: "I'm ok",                sublabel: "I hold my own, nothing special",                score: 0.3),
                AssessmentOption(id: 2, label: "I make it hard",        sublabel: "Good players still score but have to work for it", score: 0.6),
                AssessmentOption(id: 3, label: "They avoid me",         sublabel: "I lock up my matchup, people don't want to go at me", score: 0.85),
            ]
        ),
        AssessmentQuestion(
            id: "defense_2",
            category: "defense",
            prompt: "How do you defend off the ball?",
            options: [
                AssessmentOption(id: 0, label: "I watch my player",     sublabel: "I stick to my man and not much else",           score: 0.15),
                AssessmentOption(id: 1, label: "I help sometimes",      sublabel: "I rotate when it's obvious",                    score: 0.35),
                AssessmentOption(id: 2, label: "I communicate",         sublabel: "I talk, rotate, and help teammates",            score: 0.65),
                AssessmentOption(id: 3, label: "I run the defense",     sublabel: "I'm directing traffic, calling screens, rotating", score: 0.85),
            ]
        ),

        // ── HANDLES ──────────────────────────────────────────────────────────
        AssessmentQuestion(
            id: "handles_1",
            category: "handles",
            prompt: "Against tight on-ball defense, what happens to your handle?",
            options: [
                AssessmentOption(id: 0, label: "I struggle",            sublabel: "Pressure causes me to pick it up or lose it",   score: 0.05),
                AssessmentOption(id: 1, label: "I manage",              sublabel: "I protect it but can't create much",             score: 0.3),
                AssessmentOption(id: 2, label: "I stay composed",       sublabel: "Pressure doesn't bother me, I can still create", score: 0.6),
                AssessmentOption(id: 3, label: "I cook them",           sublabel: "I use pressure to get into them — it's an advantage", score: 0.85),
            ]
        ),
        AssessmentQuestion(
            id: "handles_2",
            category: "handles",
            prompt: "Can you create off the dribble consistently?",
            options: [
                AssessmentOption(id: 0, label: "Not really",            sublabel: "I need to be set to do anything",               score: 0.1),
                AssessmentOption(id: 1, label: "Basic moves only",      sublabel: "Crossover, hesitation — that's about it",       score: 0.3),
                AssessmentOption(id: 2, label: "Yes, pretty reliably",  sublabel: "I can get to my spots off the dribble",         score: 0.6),
                AssessmentOption(id: 3, label: "All day",               sublabel: "I have multiple counters and can break anyone down", score: 0.85),
            ]
        ),

        // ── PLAYMAKING ────────────────────────────────────────────────────────
        AssessmentQuestion(
            id: "playmaking_1",
            category: "playmaking",
            prompt: "When you drive and the defense collapses, you typically:",
            options: [
                AssessmentOption(id: 0, label: "Keep going for it",     sublabel: "I finish or try to — I don't really look off",  score: 0.05),
                AssessmentOption(id: 1, label: "Kick it out sometimes", sublabel: "I find the open man if it's obvious",           score: 0.3),
                AssessmentOption(id: 2, label: "Look to pass first",    sublabel: "I read the collapse and distribute",             score: 0.6),
                AssessmentOption(id: 3, label: "I'm hunting the assist", sublabel: "I bait the defense to create open shots for teammates", score: 0.85),
            ]
        ),
        AssessmentQuestion(
            id: "playmaking_2",
            category: "playmaking",
            prompt: "How often do teammates tell you to get them the ball more?",
            options: [
                AssessmentOption(id: 0, label: "Never really",          sublabel: "I'm not known as a passer",                     score: 0.1),
                AssessmentOption(id: 1, label: "Occasionally",          sublabel: "I set people up when I see it",                 score: 0.35),
                AssessmentOption(id: 2, label: "Pretty often",          sublabel: "I'm a trusted facilitator on most teams I'm on", score: 0.6),
                AssessmentOption(id: 3, label: "Always",                sublabel: "I run the offense — my teammates feed off my vision", score: 0.85),
            ]
        ),

        // ── FINISHING ─────────────────────────────────────────────────────────
        AssessmentQuestion(
            id: "finishing_1",
            category: "finishing",
            prompt: "At the rim with a defender on you, how often do you score?",
            options: [
                AssessmentOption(id: 0, label: "Rarely",                sublabel: "Contact knocks me off my shot",                 score: 0.1),
                AssessmentOption(id: 1, label: "Sometimes",             sublabel: "I finish when relatively clean",                score: 0.3),
                AssessmentOption(id: 2, label: "More often than not",   sublabel: "I finish through light contact",                score: 0.6),
                AssessmentOption(id: 3, label: "Consistently",          sublabel: "Contact doesn't matter — I finish through anyone", score: 0.85),
            ]
        ),
        AssessmentQuestion(
            id: "finishing_2",
            category: "finishing",
            prompt: "How comfortable are you with your off-hand at the rim?",
            options: [
                AssessmentOption(id: 0, label: "I avoid it",            sublabel: "I always go to my strong hand",                 score: 0.05),
                AssessmentOption(id: 1, label: "I try it sometimes",    sublabel: "Basic layups with my off hand",                 score: 0.3),
                AssessmentOption(id: 2, label: "Pretty comfortable",    sublabel: "I go off-hand when the defense takes my strong side", score: 0.6),
                AssessmentOption(id: 3, label: "Equally comfortable",   sublabel: "Both hands at the rim — I finish from any angle", score: 0.85),
            ]
        ),

        // ── REBOUNDING ────────────────────────────────────────────────────────
        AssessmentQuestion(
            id: "rebounding_1",
            category: "rebounding",
            prompt: "When a shot goes up, where are you?",
            options: [
                AssessmentOption(id: 0, label: "Watching",              sublabel: "I watch what happens",                          score: 0.05),
                AssessmentOption(id: 1, label: "Near the action",       sublabel: "I get there if it comes my way",                score: 0.3),
                AssessmentOption(id: 2, label: "Boxing out",            sublabel: "I make contact and go after the ball",          score: 0.6),
                AssessmentOption(id: 3, label: "Already there",         sublabel: "I read the shot and have position before it falls", score: 0.85),
            ]
        ),
        AssessmentQuestion(
            id: "rebounding_2",
            category: "rebounding",
            prompt: "How often are you one of the leading rebounders in a game?",
            options: [
                AssessmentOption(id: 0, label: "Rarely",                sublabel: "Rebounding isn't really part of my game",       score: 0.05),
                AssessmentOption(id: 1, label: "Occasionally",          sublabel: "When I'm locked in I chip in on boards",        score: 0.3),
                AssessmentOption(id: 2, label: "Most games",            sublabel: "I'm usually in the top 2 on my team",           score: 0.6),
                AssessmentOption(id: 3, label: "Every game",            sublabel: "I dominate the glass, both ends",               score: 0.85),
            ]
        ),
    ]
}

// MARK: ─── Scoring Engine ─────────────────────────────────────────────────────

struct AssessmentScoringEngine {

    // ── Self-assessment discount factor ──────────────────────────────────────
    // Research shows self-raters systematically overestimate by ~25–35%.
    // We apply a 28% discount to the raw question scores.
    static let selfAssessmentDiscount: Double = 0.72

    // ── Hard ceiling on self-assessed scores ─────────────────────────────────
    // No self-assessment can produce an 8.0+ rating.
    // Elite ratings require peer validation.
    static let absoluteCeiling: Double = 7.2

    // ── Minimum floor (having played the game at all gives you something) ────
    static let absoluteFloor: Double = 1.5

    // ── Category weight map ───────────────────────────────────────────────────
    static let categoryWeights: [String: Double] = [
        "scoring":    1.0,
        "iq":         1.1,   // slightly higher — most predictive of overall rating
        "defense":    1.0,
        "handles":    0.9,
        "playmaking": 1.0,
        "finishing":  0.9,
        "rebounding": 0.8,   // position-agnostic penalty — not everyone's primary role
    ]

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Main calculate function
    // ─────────────────────────────────────────────────────────────────────────

    static func calculate(
        answers: [String: Int],          // questionId → optionId (0–3)
        context: AssessmentContext
    ) -> AssessmentResult {

        let questions = AssessmentQuestionBank.all

        // ── Step 1: Average raw score per category ────────────────────────────
        var categoryRawScores: [String: [Double]] = [:]
        for q in questions {
            guard let answerId = answers[q.id],
                  let option   = q.options.first(where: { $0.id == answerId }) else { continue }
            categoryRawScores[q.category, default: []].append(option.score)
        }

        // ── Step 2: Average within category ───────────────────────────────────
        var categoryAverages: [String: Double] = [:]
        for (cat, scores) in categoryRawScores {
            let avg = scores.reduce(0, +) / Double(scores.count)
            categoryAverages[cat] = avg
        }

        // ── Step 3: Apply self-assessment discount ────────────────────────────
        var discounted: [String: Double] = [:]
        for (cat, avg) in categoryAverages {
            discounted[cat] = avg * selfAssessmentDiscount
        }

        // ── Step 4: Map 0–1 score to realistic NETR range using context ───────
        // context.playingLevel gives us a base anchor and ceiling
        let base    = context.playingLevel.baseScore
        let ceiling = min(context.playingLevel.scoreCeiling, absoluteCeiling)

        var categoryNetrScores: [String: Double] = [:]
        for (cat, d) in discounted {
            // Map discounted (0–1) into [base, ceiling]
            let raw = base + d * (ceiling - base)
            // Apply age modifier
            let aged = raw * context.ageGroup.athleticModifier
            // Clamp
            categoryNetrScores[cat] = min(max(aged, absoluteFloor), ceiling)
        }

        // ── Step 5: Weighted composite overall score ──────────────────────────
        var weightedSum   = 0.0
        var totalWeight   = 0.0
        for (cat, netr) in categoryNetrScores {
            let w = categoryWeights[cat] ?? 1.0
            weightedSum += netr * w
            totalWeight += w
        }
        let composite = totalWeight > 0 ? weightedSum / totalWeight : base
        let overall   = min(max(composite, absoluteFloor), ceiling)

        // ── Step 6: Fill in missing categories with the base score ────────────
        let allCategories = ["scoring","iq","defense","handles","playmaking","finishing","rebounding"]
        for cat in allCategories {
            if categoryNetrScores[cat] == nil {
                categoryNetrScores[cat] = base * context.ageGroup.athleticModifier
            }
        }

        // ── Step 7: Derive strengths & focus areas ────────────────────────────
        let sorted     = categoryNetrScores.sorted { $0.value > $1.value }
        let strengths  = Array(sorted.prefix(2).map { $0.key })
        let focusAreas = Array(sorted.suffix(2).map { $0.key })

        return AssessmentResult(
            overallScore:     overall,
            categoryScores:   categoryNetrScores,
            strengths:        strengths,
            focusAreas:       focusAreas,
            context:          context,
            tierLabel:        netrTierLabel(overall),
            tierColor:        netrTierHex(overall),
            isPeerRated:      false,
            peerRatingCount:  0
        )
    }

    // ── Tier helpers ──────────────────────────────────────────────────────────

    static func netrTierLabel(_ r: Double) -> String {
        switch r {
        case 9...:   return "NBA Level"
        case 8..<9:  return "Elite"
        case 7..<8:  return "D3 Level"
        case 6..<7:  return "Park Legend"
        case 5..<6:  return "Park Dominant"
        case 4..<5:  return "Above Average"
        case 3..<4:  return "Recreational"
        case 2..<3:  return "Developing"
        default:     return "Beginner"
        }
    }

    static func netrTierHex(_ r: Double) -> String {
        switch r {
        case 8...:  return "#30D158"
        case 6..<8: return "#00FF41"
        case 4..<6: return "#F5C542"
        default:    return "#FF453A"
        }
    }
}

// MARK: ─── Result Model ───────────────────────────────────────────────────────

struct AssessmentResult {
    let overallScore:    Double
    let categoryScores:  [String: Double]
    let strengths:       [String]
    let focusAreas:      [String]
    let context:         AssessmentContext
    let tierLabel:       String
    let tierColor:       String
    let isPeerRated:     Bool
    let peerRatingCount: Int

    var formattedScore: String { String(format: "%.1f", overallScore) }

    // Category display names
    static let categoryLabels: [String: String] = [
        "scoring":    "Scoring",
        "iq":         "IQ",
        "defense":    "Defense",
        "handles":    "Handles",
        "playmaking": "Playmaking",
        "finishing":  "Finishing",
        "rebounding": "Rebounding",
    ]

    // SF Symbols for each category
    static let categoryIcons: [String: String] = [
        "scoring":    "scope",
        "iq":         "brain",
        "defense":    "shield.fill",
        "handles":    "hand.raised.fill",
        "playmaking": "bolt.fill",
        "finishing":  "flame.fill",
        "rebounding": "arrow.up.circle",
    ]

    // Dot color on radar chart based on score
    func dotColorHex(for category: String) -> String {
        guard let score = categoryScores[category] else { return "#333333" }
        switch score {
        case 6...:  return "#00FF41"   // Strong — green
        case 4..<6: return "#4A9EFF"   // Solid — blue
        case 3..<4: return "#F5C542"   // Developing — gold
        default:    return "#FF453A"   // Focus area — red
        }
    }

    func dotLabel(for category: String) -> String {
        guard let score = categoryScores[category] else { return "Developing" }
        switch score {
        case 6...:  return "Strong"
        case 4..<6: return "Solid"
        case 3..<4: return "Developing"
        default:    return "Focus area"
        }
    }
}

// MARK: ─── Example: 30-year-old ex-HS player ─────────────────────────────────
//
// Context:
//   ageGroup    = .adult       (28–38) → athleticModifier = 0.93
//   playingLevel = .exHighSchool → baseScore = 3.5, ceiling = 5.5
//
// If they answer honestly (mix of 1s and 2s, maybe one 3):
//   Raw avg per category ≈ 0.35–0.50
//   After 28% discount ≈ 0.25–0.36
//   Mapped to [3.5, 5.5]: 3.5 + 0.30 * 2.0 ≈ 4.1
//   After age modifier: 4.1 * 0.93 ≈ 3.8
//   Overall: ~3.8–4.3 → "Above Average" / "Recreational" ✓
//
// If they over-rate themselves (all 3s / "I cook them" on everything):
//   Raw avg per category ≈ 0.85
//   After discount ≈ 0.61
//   Mapped to [3.5, 5.5]: 3.5 + 0.61 * 2.0 ≈ 4.7
//   After age modifier: 4.7 * 0.93 ≈ 4.4
//   Overall: ~4.4 → still "Above Average", not 10.0 ✓
//   Category max: 5.5 ceiling → categories show 4.5–5.5, not 10.0 ✓
//
// If a D1 player rates themselves (all 3s, .exCollegiate, .earlyAdult):
//   Ceiling = 6.8, base = 5.0, modifier = 1.0
//   3.5 + 0.61 * 1.8 ≈ 6.1 → "Park Legend" range
//   (Gets to 7+ only via peer reviews) ✓
//
// ─────────────────────────────────────────────────────────────────────────────

// MARK: ─── Unit Tests (run in Preview) ───────────────────────────────────────

#if DEBUG
struct ScoringEngineTests {
    static func run() {
        print("── Scoring Engine Tests ──")

        // Test 1: 30yr ex-HS player, honest answers (mostly 1s)
        let honestExHS = AssessmentContext(ageGroup: .adult, playingLevel: .exHighSchool)
        let honestAnswers: [String: Int] = [
            "scoring_1": 1, "scoring_2": 1,
            "iq_1": 2,      "iq_2": 1,
            "defense_1": 1, "defense_2": 1,
            "handles_1": 0, "handles_2": 1,
            "playmaking_1": 1, "playmaking_2": 1,
            "finishing_1": 1,  "finishing_2": 0,
            "rebounding_1": 1, "rebounding_2": 1,
        ]
        let r1 = AssessmentScoringEngine.calculate(answers: honestAnswers, context: honestExHS)
        print("Test 1 — Honest ex-HS (30yr): \(r1.formattedScore) [\(r1.tierLabel)]")
        assert(r1.overallScore >= 3.0 && r1.overallScore <= 4.5, "Expected 3.0–4.5, got \(r1.overallScore)")
        assert(r1.categoryScores.values.allSatisfy { $0 <= 5.5 }, "Category score exceeded ceiling!")
        print("  ✓ Category scores: \(r1.categoryScores.mapValues { String(format:"%.1f",$0) })")

        // Test 2: Same player, over-inflated answers (all 3s)
        let inflatedAnswers: [String: Int] = Dictionary(
            uniqueKeysWithValues: AssessmentQuestionBank.all.map { ($0.id, 3) }
        )
        let r2 = AssessmentScoringEngine.calculate(answers: inflatedAnswers, context: honestExHS)
        print("Test 2 — Inflated ex-HS (30yr): \(r2.formattedScore) [\(r2.tierLabel)]")
        assert(r2.overallScore <= 5.5, "Inflated ex-HS score too high: \(r2.overallScore)")
        assert(r2.categoryScores.values.allSatisfy { $0 <= 5.5 }, "Category exceeded ceiling!")
        print("  ✓ Category max: \(r2.categoryScores.values.max().map { String(format:"%.1f",$0) } ?? "?")")

        // Test 3: D1 player all 3s — should still be under 7.2
        let d1Context = AssessmentContext(ageGroup: .earlyAdult, playingLevel: .exCollegiate)
        let r3 = AssessmentScoringEngine.calculate(answers: inflatedAnswers, context: d1Context)
        print("Test 3 — Inflated D1 (22yr): \(r3.formattedScore) [\(r3.tierLabel)]")
        assert(r3.overallScore <= AssessmentScoringEngine.absoluteCeiling, "Exceeded absolute ceiling!")
        print("  ✓ Under ceiling (\(AssessmentScoringEngine.absoluteCeiling))")

        // Test 4: Nobody gets 10.0
        let eliteContext = AssessmentContext(ageGroup: .teen, playingLevel: .exCollegiate)
        let r4 = AssessmentScoringEngine.calculate(answers: inflatedAnswers, context: eliteContext)
        assert(r4.overallScore < 8.0, "Self-assessment should never reach 8.0!")
        assert(r4.categoryScores.values.allSatisfy { $0 < 8.0 }, "Category should never reach 8.0!")
        print("Test 4 — Nobody gets 10.0: \(r4.formattedScore) ✓")

        print("── All tests passed ──")
    }
}
#endif

// MARK: ─── Usage in SelfAssessmentView ───────────────────────────────────────
//
// Replace the existing scoring logic in SelfAssessmentView with:
//
//   let context = AssessmentContext(
//       ageGroup:     selectedAgeGroup,
//       playingLevel: selectedPlayingLevel
//   )
//   let result = AssessmentScoringEngine.calculate(answers: answers, context: context)
//
//   // Save to Supabase
//   try await supabase
//       .from("profiles")
//       .update([
//           "netr_score":         result.overallScore,
//           "skill_scoring":      result.categoryScores["scoring"],
//           "skill_iq":           result.categoryScores["iq"],
//           "skill_defense":      result.categoryScores["defense"],
//           "skill_handles":      result.categoryScores["handles"],
//           "skill_playmaking":   result.categoryScores["playmaking"],
//           "skill_finishing":    result.categoryScores["finishing"],
//           "skill_rebounding":   result.categoryScores["rebounding"],
//           "provisional":        true,
//       ])
//       .eq("id", value: userId.uuidString)
//       .execute()
