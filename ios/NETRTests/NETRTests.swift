//
//  NETRTests.swift
//  NETRTests
//
//  Created by Rork on March 9, 2026.
//

import Testing
@testable import NETR

struct NETRTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// MARK: - Self-Assessment Scoring Tests

struct SelfAssessmentEngineTests {

    // Build a full set of mid-level answers (option id 2, score 0.52) for all 15 questions
    private func midAnswers() -> [String: Int] {
        AssessmentQuestionBank.all.reduce(into: [:]) { $0[$1.id] = 2 }
    }

    // 21-year-old D1 player, plays multi-weekly
    @Test func youngAdultD1ShouldScoreHigherThan7() {
        let context = AssessmentContext(
            ageGroup: .youngAdult,
            playingLevel: .exD1D2,
            playFrequency: .multiWeekly,
            position: .sf
        )
        let result = AssessmentScoringEngine.calculate(answers: midAnswers(), context: context)
        #expect(result.overallScore >= 7.0, "21yo D1 player with mid answers should be 7.0+, got \(result.formattedScore)")
    }

    // Same profile before the fix would have scored ~5.3 with low frequency — verify it's now reasonable
    @Test func youngAdultD1LowFrequencyShouldStillReflectLevel() {
        let context = AssessmentContext(
            ageGroup: .youngAdult,
            playingLevel: .exD1D2,
            playFrequency: .fewTimesYear,
            position: .sf
        )
        let result = AssessmentScoringEngine.calculate(answers: midAnswers(), context: context)
        #expect(result.overallScore >= 6.0, "21yo D1 player (low freq, mid answers) should be 6.0+, got \(result.formattedScore)")
    }

    // Older ex-D1 player should NOT get the upgrade
    @Test func olderExD1ShouldUseOriginalRange() {
        let context = AssessmentContext(
            ageGroup: .adult,        // 26-32
            playingLevel: .exD1D2,
            playFrequency: .multiWeekly,
            position: .sf
        )
        let result = AssessmentScoringEngine.calculate(answers: midAnswers(), context: context)
        // Should top out around 7.x from the exD1D2 range, not the currentSemiPro ceiling
        #expect(result.overallScore < 8.5, "26-32yo ex-D1 with mid answers should not exceed 8.5, got \(result.formattedScore)")
        #expect(result.overallScore >= 6.0, "26-32yo ex-D1 with mid answers should still be 6.0+, got \(result.formattedScore)")
    }

    // Young JUCO/D3 player should also get a bump
    @Test func youngAdultJucoShouldScoreInRange() {
        let context = AssessmentContext(
            ageGroup: .youngAdult,
            playingLevel: .exJucoOrD3,
            playFrequency: .multiWeekly,
            position: .sf
        )
        let result = AssessmentScoringEngine.calculate(answers: midAnswers(), context: context)
        #expect(result.overallScore >= 6.0, "21yo JUCO player with mid answers should be 6.0+, got \(result.formattedScore)")
    }

    // effectiveRange returns currentSemiPro values for youngAdult + exD1D2
    @Test func effectiveRangeUpgradesYoungD1() {
        let range = AssessmentScoringEngine.effectiveRange(level: .exD1D2, age: .youngAdult)
        #expect(range.base == PlayingLevel.currentSemiPro.baseScore)
        #expect(range.ceiling == PlayingLevel.currentSemiPro.scoreCeiling)
    }

    // effectiveRange leaves older D1 alone
    @Test func effectiveRangeDoesNotUpgradeOlderD1() {
        let range = AssessmentScoringEngine.effectiveRange(level: .exD1D2, age: .adult)
        #expect(range.base == PlayingLevel.exD1D2.baseScore)
        #expect(range.ceiling == PlayingLevel.exD1D2.scoreCeiling)
    }
}
