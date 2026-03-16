import SwiftUI

struct SelfAssessmentSheetView: View {
    @Environment(SupabaseManager.self) private var supabase
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving: Bool = false

    var onComplete: (() -> Void)?

    var body: some View {
        SelfAssessmentFlowView { score, _, catScores in
            SelfAssessmentStore.save(score: score, categoryScores: catScores)
            Task { try? await supabase.saveSelfAssessmentScore(score: score, categoryScores: catScores) }
            onComplete?()
            dismiss()
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isSaving)
    }
}
