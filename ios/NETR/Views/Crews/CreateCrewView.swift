import SwiftUI

struct CreateCrewView: View {
    @Bindable var viewModel: CrewViewModel
    var onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var password: String = ""
    @State private var selectedIcon: String = "flame"
    @State private var isCreating: Bool = false
    @State private var errorMsg: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 4 }

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Name
                        fieldSection(label: "CREW NAME") {
                            TextField("e.g. The Wolfpack", text: $name)
                                .font(.system(size: 15))
                                .foregroundStyle(NETRTheme.text)
                                .autocorrectionDisabled()
                                .onChange(of: name) { _, v in if v.count > 30 { name = String(v.prefix(30)) } }
                        }

                        // Crew Code
                        fieldSection(label: "CREW CODE") {
                            VStack(alignment: .leading, spacing: 6) {
                                SecureField("Min. 4 characters", text: $password)
                                    .font(.system(size: 15))
                                    .foregroundStyle(NETRTheme.text)
                                Text("Share this with your crew outside the app")
                                    .font(.system(size: 11))
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                        }

                        // Icon Picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CREW ICON")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(NETRTheme.subtext)
                                .tracking(1.3)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(crewIcons, id: \.self) { icon in
                                    let isSelected = selectedIcon == icon
                                    Button { selectedIcon = icon } label: {
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? NETRTheme.neonGreen.opacity(0.15) : NETRTheme.card)
                                                .frame(width: 52, height: 52)
                                                .overlay(Circle().stroke(isSelected ? NETRTheme.neonGreen : NETRTheme.border, lineWidth: isSelected ? 2 : 1))
                                            LucideIcon(icon, size: 22)
                                                .foregroundStyle(isSelected ? NETRTheme.neonGreen : NETRTheme.subtext)
                                        }
                                    }
                                    .buttonStyle(PressButtonStyle())
                                }
                            }
                        }

                        // Error
                        if let err = errorMsg {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(NETRTheme.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        // Create Button
                        Button {
                            Task { await createCrew() }
                        } label: {
                            HStack {
                                if isCreating { ProgressView().tint(NETRTheme.background).scaleEffect(0.8) }
                                Text("CREATE CREW")
                                    .font(.system(.body, design: .default, weight: .black).width(.compressed))
                                    .tracking(1)
                            }
                            .foregroundStyle(NETRTheme.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(isValid ? NETRTheme.neonGreen : NETRTheme.muted, in: .rect(cornerRadius: 14))
                        }
                        .disabled(!isValid || isCreating)
                        .buttonStyle(PressButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Create Crew")
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

    private func createCrew() async {
        errorMsg = nil
        isCreating = true
        do {
            try await viewModel.createCrew(name: name.trimmingCharacters(in: .whitespaces), icon: selectedIcon, password: password)
            onSuccess()
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        isCreating = false
    }
}
