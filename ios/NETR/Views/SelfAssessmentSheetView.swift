import SwiftUI

struct SelfAssessmentSheetView: View {
    @Environment(SupabaseManager.self) private var supabase
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving: Bool = false

    var onComplete: (() -> Void)?

    var body: some View {
        SelfAssessmentFlowView { score, profile, catScores in
            let isProClaim = profile.highestLevel == .nba
            SelfAssessmentStore.save(score: score, categoryScores: catScores)
            let genderRaw = profile.gender?.rawValue
            Task {
                try? await supabase.saveSelfAssessmentScore(score: score, categoryScores: catScores)
                if let genderRaw {
                    try? await supabase.saveGender(genderRaw)
                }
                if isProClaim { try? await supabase.flagProVerificationPending() }
            }
            onComplete?()
            dismiss()
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isSaving)
    }
}
