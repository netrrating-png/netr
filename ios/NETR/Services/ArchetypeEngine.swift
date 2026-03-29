import Foundation

/// Pure Swift engine for computing NETR Player Archetypes.
/// Accepts category scores and returns the archetype name + key.
struct ArchetypeEngine {

    struct Result {
        let name: String
        let key: String        // e.g. "shooting", "handles_playmaking"
        let isSingle: Bool
        let topCategories: [String]
    }

    // MARK: - Category keys (canonical order)

    private static let categoryOrder = ["shooting", "finishing", "handles", "playmaking", "defense", "rebounding", "iq"]

    // MARK: - Single Category Archetypes (top 1 skill)

    private static let singleArchetypes: [String: [String]] = [
        "shooting":   ["The Marksman", "Green Light", "The Microwave"],
        "finishing":  ["Paint Bully", "The Maestro", "Interior Force"],
        "handles":    ["Ankle Taker", "Showtime", "The Magician"],
        "playmaking": ["The Architect", "Court Vision", "Third Eye"],
        "defense":    ["Enforcer", "The Stopper", "Fortress"],
        "rebounding": ["Board Man", "Glass King", "The Magnet"],
        "iq":         ["Coach", "The Professor", "Wise Guy"],
    ]

    // MARK: - Dual Category Archetypes (top 2 skills)
    // Key format: "cat1_cat2" where cat1 < cat2 alphabetically

    private static let dualArchetypes: [String: [String]] = [
        "finishing_shooting":     ["Slim Reaper", "No Conscience", "Bucket"],
        "handles_shooting":       ["Chef", "Iso God", "Off the Dribble"],
        "playmaking_shooting":    ["Green and Deal", "Shot Creator", "Luka Magic"],
        "defense_shooting":       ["Two-Way", "Double Agent", "The Claw"],
        "rebounding_shooting":    ["Melo", "The Opportunist", "No Help Needed"],
        "iq_shooting":            ["The Truth", "Already Knew", "Called Game"],
        "finishing_handles":      ["The Answer", "Uncle Drew", "Street Surgeon"],
        "finishing_playmaking":   ["The Hybrid", "Attack and Assist", "The Catalyst"],
        "defense_finishing":      ["Gladiator", "Two-Way Enforcer", "Dominant Force"],
        "finishing_rebounding":   ["Thanos", "Putback King", "Juggernaut"],
        "finishing_iq":           ["Fundamentals", "The Scientist", "Post Work"],
        "handles_playmaking":     ["Point Gawd", "The Floor General", "Magic"],
        "defense_handles":        ["The Glove", "The Pickpocket", "Quick Hands"],
        "handles_rebounding":     ["Ball Hawk", "Full Throttle", "Brodie"],
        "handles_iq":             ["Zeke", "The Processor", "Dribble Wizard"],
        "defense_playmaking":     ["Read and React", "The Glue", "Spark Generator"],
        "playmaking_rebounding":  ["Joker", "Crash and Dish", "Glass General"],
        "iq_playmaking":          ["The Kidd", "The Orchestrator", "Mastermind"],
        "defense_rebounding":     ["The Worm", "Dirty Work", "Not in My House"],
        "defense_iq":             ["The Technician", "Calculated Stopper", "Film Room"],
        "iq_rebounding":          ["Clairvoyant", "Crash Calculator", "Glass Reader"],
    ]

    // MARK: - Compute Archetype

    /// Computes the archetype for a given set of category scores.
    /// Returns nil if no scores are available.
    /// The name is deterministically selected (not random) based on score hash — call `assignArchetype` for persistent random assignment.
    static func computeArchetype(categoryScores: [String: Double]) -> Result? {
        let scores = normalizeKeys(categoryScores)
        let sorted = scores.sorted { $0.value > $1.value }
        guard let first = sorted.first, first.value > 0 else { return nil }

        // Check dual archetype conditions
        if sorted.count >= 2 {
            let top1 = sorted[0]
            let top2 = sorted[1]
            let remaining = sorted.dropFirst(2)
            let maxRemaining = remaining.map(\.value).max() ?? 0

            let isTied = abs(top1.value - top2.value) < 0.05
            let bothDominant = top1.value >= maxRemaining + 1.0 && top2.value >= maxRemaining + 1.0

            if isTied || bothDominant {
                let pairKey = [top1.key, top2.key].sorted().joined(separator: "_")
                if let options = dualArchetypes[pairKey], !options.isEmpty {
                    let idx = stableIndex(top1.value, top2.value, count: options.count)
                    return Result(
                        name: options[idx],
                        key: pairKey,
                        isSingle: false,
                        topCategories: [top1.key, top2.key]
                    )
                }
            }
        }

        // Fall back to single category archetype
        let topKey = sorted[0].key
        if let options = singleArchetypes[topKey], !options.isEmpty {
            let idx = stableIndex(sorted[0].value, 0, count: options.count)
            return Result(
                name: options[idx],
                key: topKey,
                isSingle: true,
                topCategories: [topKey]
            )
        }

        return nil
    }

    /// Assigns an archetype with random selection from the 3 options.
    /// Use this when persisting — the randomness only happens once, then it's saved.
    static func assignArchetype(categoryScores: [String: Double]) -> Result? {
        let scores = normalizeKeys(categoryScores)
        let sorted = scores.sorted { $0.value > $1.value }
        guard let first = sorted.first, first.value > 0 else { return nil }

        // Check dual conditions
        if sorted.count >= 2 {
            let top1 = sorted[0]
            let top2 = sorted[1]
            let remaining = sorted.dropFirst(2)
            let maxRemaining = remaining.map(\.value).max() ?? 0

            let isTied = abs(top1.value - top2.value) < 0.05
            let bothDominant = top1.value >= maxRemaining + 1.0 && top2.value >= maxRemaining + 1.0

            if isTied || bothDominant {
                let pairKey = [top1.key, top2.key].sorted().joined(separator: "_")
                if let options = dualArchetypes[pairKey], !options.isEmpty {
                    let idx = Int.random(in: 0..<options.count)
                    return Result(
                        name: options[idx],
                        key: pairKey,
                        isSingle: false,
                        topCategories: [top1.key, top2.key]
                    )
                }
            }
        }

        // Single
        let topKey = sorted[0].key
        if let options = singleArchetypes[topKey], !options.isEmpty {
            let idx = Int.random(in: 0..<options.count)
            return Result(
                name: options[idx],
                key: topKey,
                isSingle: true,
                topCategories: [topKey]
            )
        }

        return nil
    }

    // MARK: - Helpers

    /// Normalize input keys to our canonical format (lowercase, "handles" not "dribbling", "iq" not "basketball_iq")
    private static func normalizeKeys(_ input: [String: Double]) -> [String: Double] {
        var result: [String: Double] = [:]
        for (key, value) in input {
            let normalized = key.lowercased()
                .replacingOccurrences(of: "ball_handling", with: "handles")
                .replacingOccurrences(of: "ballhandling", with: "handles")
                .replacingOccurrences(of: "dribbling", with: "handles")
                .replacingOccurrences(of: "basketball_iq", with: "iq")
                .replacingOccurrences(of: "basketballiq", with: "iq")
                .replacingOccurrences(of: "passing", with: "playmaking")
                .replacingOccurrences(of: "cat_", with: "")
            result[normalized] = value
        }
        return result
    }

    /// Deterministic index selection based on score values (stable across loads)
    private static func stableIndex(_ v1: Double, _ v2: Double, count: Int) -> Int {
        let hash = abs(Int((v1 * 1000 + v2 * 777).rounded()))
        return hash % count
    }

    /// Build category scores dictionary from a UserProfile's category fields
    static func categoryScoresFromProfile(
        shooting: Double?, finishing: Double?, dribbling: Double?,
        passing: Double?, defense: Double?, rebounding: Double?,
        basketballIQ: Double?
    ) -> [String: Double] {
        var scores: [String: Double] = [:]
        if let v = shooting { scores["shooting"] = v }
        if let v = finishing { scores["finishing"] = v }
        if let v = dribbling { scores["handles"] = v }
        if let v = passing { scores["playmaking"] = v }
        if let v = defense { scores["defense"] = v }
        if let v = rebounding { scores["rebounding"] = v }
        if let v = basketballIQ { scores["iq"] = v }
        return scores
    }
}
