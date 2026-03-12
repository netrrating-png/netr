import SwiftUI

struct SelfAssessmentSheetView: View {
    @Environment(SupabaseManager.self) private var supabase
    @Environment(\.dismiss) private var dismiss

    @State private var selfAssessmentScore: Double? = nil
    @State private var selfAssessmentCategoryScores: [String: Double] = [:]
    @State private var showResult: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    var onComplete: (() -> Void)?

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            if showResult {
                resultView
            } else {
                SelfAssessmentView(
                    estimatedScore: $selfAssessmentScore,
                    categoryScores: $selfAssessmentCategoryScores,
                    onComplete: {
                        if let score = selfAssessmentScore {
                            SelfAssessmentStore.save(
                                score: score,
                                categoryScores: selfAssessmentCategoryScores.isEmpty ? nil : selfAssessmentCategoryScores
                            )
                        }
                        withAnimation { showResult = true }
                    },
                    onBack: {
                        dismiss()
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isSaving)
    }

    private var resultView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("YOUR NETR SCORE")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(3)
                .foregroundStyle(NETRTheme.subtext)

            if let score = selfAssessmentScore {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 72, weight: .black, design: .default).width(.compressed))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .shadow(color: NETRTheme.neonGreen.opacity(0.5), radius: 30)
            }

            Text("Your self-assessment is complete. Peer ratings will refine this over time.")
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let error = saveError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(NETRTheme.red)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                saveAndDismiss()
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(NETRTheme.background)
                    }
                    Text("DONE")
                        .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                        .tracking(2)
                        .foregroundStyle(NETRTheme.background)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 16)
            }
            .buttonStyle(PressButtonStyle())
            .disabled(isSaving)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func saveAndDismiss() {
        guard let score = selfAssessmentScore else {
            dismiss()
            return
        }

        isSaving = true
        saveError = nil

        Task {
            do {
                try await supabase.saveSelfAssessmentScore(
                    score: score,
                    categoryScores: selfAssessmentCategoryScores.isEmpty ? nil : selfAssessmentCategoryScores
                )
                onComplete?()
                dismiss()
            } catch {
                saveError = error.localizedDescription
            }
            isSaving = false
        }
    }
}
