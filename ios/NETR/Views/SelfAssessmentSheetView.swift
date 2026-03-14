import SwiftUI

struct SelfAssessmentSheetView: View {
    @Environment(SupabaseManager.self) private var supabase
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving: Bool = false

    var onComplete: (() -> Void)?

    var body: some View {
        SelfAssessmentFlowView { score, _ in
            SelfAssessmentStore.save(score: score, categoryScores: nil)
            Task { try? await supabase.saveSelfAssessmentScore(score: score, categoryScores: nil) }
            onComplete?()
            dismiss()
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isSaving)
    }
}
