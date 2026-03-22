import SwiftUI

struct JoinCrewView: View {
    @Bindable var viewModel: CrewViewModel
    var onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var crewName: String = ""
    @State private var password: String = ""
    @State private var isJoining: Bool = false
    @State private var errorMsg: String? = nil

    var isValid: Bool { !crewName.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Explainer
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(NETRTheme.neonGreen.opacity(0.1)).frame(width: 48, height: 48)
                                LucideIcon("users", size: 22).foregroundStyle(NETRTheme.neonGreen)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Join your crew")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(NETRTheme.text)
                                Text("Get the crew name and code from whoever created the crew")
                                    .font(.system(size: 12))
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                        }
                        .padding(14)
                        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))

                        fieldSection(label: "CREW NAME") {
                            TextField("Enter exact crew name", text: $crewName)
                                .font(.system(size: 15))
                                .foregroundStyle(NETRTheme.text)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        fieldSection(label: "CREW CODE") {
                            SecureField("Enter the code", text: $password)
                                .font(.system(size: 15))
                                .foregroundStyle(NETRTheme.text)
                        }

                        if let err = errorMsg {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(NETRTheme.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            Task { await joinCrew() }
                        } label: {
                            HStack {
                                if isJoining { ProgressView().tint(NETRTheme.background).scaleEffect(0.8) }
                                Text("JOIN CREW")
                                    .font(.system(.body, design: .default, weight: .black).width(.compressed))
                                    .tracking(1)
                            }
                            .foregroundStyle(NETRTheme.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(isValid ? NETRTheme.neonGreen : NETRTheme.muted, in: .rect(cornerRadius: 14))
                        }
                        .disabled(!isValid || isJoining)
                        .buttonStyle(PressButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Join a Crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        LucideIcon("x", size: 16).foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fieldSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1.3)
            content()
                .padding(14)
                .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
        }
    }

    private func joinCrew() async {
        errorMsg = nil
        isJoining = true
        do {
            try await viewModel.joinCrew(name: crewName.trimmingCharacters(in: .whitespaces), password: password)
            onSuccess()
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        isJoining = false
    }
}
