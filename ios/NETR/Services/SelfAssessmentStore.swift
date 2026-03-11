import Foundation

enum SelfAssessmentStore {

    private static let scoreKey = "netr_self_assessment_score"
    private static let shootingKey = "netr_sa_shooting"
    private static let finishingKey = "netr_sa_finishing"
    private static let dribblingKey = "netr_sa_dribbling"
    private static let passingKey = "netr_sa_passing"
    private static let defenseKey = "netr_sa_defense"
    private static let reboundingKey = "netr_sa_rebounding"
    private static let iqKey = "netr_sa_iq"

    private static let categoryKeyMap: [String: String] = [
        "scoring": "netr_sa_shooting",
        "finishing": "netr_sa_finishing",
        "handles": "netr_sa_dribbling",
        "playmaking": "netr_sa_passing",
        "defense": "netr_sa_defense",
        "rebounding": "netr_sa_rebounding",
        "iq": "netr_sa_iq",
    ]

    static func save(score: Double, categoryScores: [String: Double]?) {
        let defaults = UserDefaults.standard
        defaults.set(score, forKey: scoreKey)

        if let cats = categoryScores {
            for (cat, val) in cats {
                if let key = categoryKeyMap[cat] {
                    defaults.set(val, forKey: key)
                }
            }
        }
    }

    static var savedScore: Double? {
        let defaults = UserDefaults.standard
        let val = defaults.double(forKey: scoreKey)
        return val > 0 ? val : nil
    }

    static var savedSkillRatings: SkillRatings? {
        let defaults = UserDefaults.standard
        let shooting = defaults.double(forKey: shootingKey)
        let finishing = defaults.double(forKey: finishingKey)
        let dribbling = defaults.double(forKey: dribblingKey)
        let passing = defaults.double(forKey: passingKey)
        let defense = defaults.double(forKey: defenseKey)
        let rebounding = defaults.double(forKey: reboundingKey)
        let iq = defaults.double(forKey: iqKey)

        let hasAny = [shooting, finishing, dribbling, passing, defense, rebounding, iq].contains { $0 > 0 }
        guard hasAny else { return nil }

        return SkillRatings(
            shooting: shooting > 0 ? shooting : nil,
            finishing: finishing > 0 ? finishing : nil,
            ballHandling: dribbling > 0 ? dribbling : nil,
            playmaking: passing > 0 ? passing : nil,
            defense: defense > 0 ? defense : nil,
            rebounding: rebounding > 0 ? rebounding : nil,
            basketballIQ: iq > 0 ? iq : nil
        )
    }

    static func clear() {
        let defaults = UserDefaults.standard
        [scoreKey, shootingKey, finishingKey, dribblingKey, passingKey, defenseKey, reboundingKey, iqKey].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
