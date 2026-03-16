import SwiftUI

struct AddCourtView: View {
    @Bindable var viewModel: CourtsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var courtName: String = ""
    @State private var streetAddress: String = ""
    @State private var neighborhood: String = ""
    @State private var city: String = "New York, NY"
    @State private var selectedSurface: SurfaceType = .asphalt
    @State private var hasLights: Bool = false
    @State private var isIndoor: Bool = false
    @State private var isFullCourt: Bool = true
    @State private var showSuccess: Bool = false
    @State private var isSubmitting: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if showSuccess {
                    successView
                } else {
                    formView
                }
            }
            .dismissKeyboardOnScroll()
            .scrollIndicators(.hidden)
            .navigationTitle("Add Court")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                LucideIcon("info")
                    .foregroundStyle(NETRTheme.blue)
                Text("New courts are marked Pending until verified by the NETR team.")
                    .font(.caption)
                    .foregroundStyle(NETRTheme.blue)
            }
            .padding(10)
            .background(NETRTheme.blue.opacity(0.08), in: .rect(cornerRadius: 10))
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("COURT NAME")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1)
                NETRTextField(placeholder: "e.g. Rucker Park", text: $courtName, icon: "basketball.fill")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("STREET ADDRESS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1)
                NETRTextField(placeholder: "e.g. 155th St & Harlem River Dr", text: $streetAddress, icon: "mappin")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("NEIGHBORHOOD")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1)
                NETRTextField(placeholder: "e.g. Harlem, Fort Greene", text: $neighborhood, icon: "building.2")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("CITY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1)
                NETRTextField(placeholder: "e.g. New York, NY", text: $city, icon: "map")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("SURFACE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1)
                HStack(spacing: 8) {
                    ForEach(SurfaceType.allCases, id: \.rawValue) { surface in
                        Button {
                            selectedSurface = surface
                        } label: {
                            Text(surface.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedSurface == surface ? NETRTheme.background : NETRTheme.text)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedSurface == surface ? NETRTheme.neonGreen : NETRTheme.card,
                                    in: Capsule()
                                )
                                .overlay(Capsule().stroke(
                                    selectedSurface == surface ? Color.clear : NETRTheme.border, lineWidth: 1
                                ))
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                }
            }

            Toggle(isOn: $hasLights) {
                HStack(spacing: 8) {
                    LucideIcon("lightbulb")
                        .foregroundStyle(hasLights ? NETRTheme.gold : NETRTheme.subtext)
                    Text("Has Lights")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                }
            }
            .tint(NETRTheme.neonGreen)
            .padding(12)
            .background(NETRTheme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))

            Toggle(isOn: $isIndoor) {
                HStack(spacing: 8) {
                    LucideIcon("building-2")
                        .foregroundStyle(isIndoor ? NETRTheme.blue : NETRTheme.subtext)
                    Text("Indoor Court")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                }
            }
            .tint(NETRTheme.neonGreen)
            .padding(12)
            .background(NETRTheme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))

            Toggle(isOn: $isFullCourt) {
                HStack(spacing: 8) {
                    LucideIcon("circle-dot")
                        .foregroundStyle(isFullCourt ? NETRTheme.neonGreen : NETRTheme.subtext)
                    Text("Full Court")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                }
            }
            .tint(NETRTheme.neonGreen)
            .padding(12)
            .background(NETRTheme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))

            Spacer(minLength: 32)

            Button {
                isSubmitting = true
                Task {
                    let success = await viewModel.addCourt(
                        name: courtName, address: streetAddress,
                        neighborhood: neighborhood, city: city,
                        surface: selectedSurface, lights: hasLights,
                        indoor: isIndoor, fullCourt: isFullCourt
                    )
                    isSubmitting = false
                    if success {
                        withAnimation(.snappy) { showSuccess = true }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView().tint(NETRTheme.background)
                    } else {
                        Text("SUBMIT COURT FOR REVIEW")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                    }
                }
                .foregroundStyle(NETRTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    (courtName.isEmpty || streetAddress.isEmpty) ? NETRTheme.muted : NETRTheme.neonGreen,
                    in: .rect(cornerRadius: 14)
                )
            }
            .buttonStyle(PressButtonStyle())
            .disabled(courtName.isEmpty || streetAddress.isEmpty || isSubmitting)
            .sensoryFeedback(.success, trigger: showSuccess)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
    }

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)

            LucideIcon("check-circle", size: 64)
                .foregroundStyle(NETRTheme.neonGreen)
                .neonGlow(radius: 16)

            Text("COURT SUBMITTED")
                .font(NETRTheme.headingFont(size: .title2))
                .foregroundStyle(NETRTheme.text)

            Text("Court submitted for review! We'll verify and add it within 24 hours.")
                .font(.body)
                .foregroundStyle(NETRTheme.subtext)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                LucideIcon("clock")
                    .foregroundStyle(NETRTheme.gold)
                Text("PENDING")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.gold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(NETRTheme.gold.opacity(0.1), in: Capsule())

            Spacer(minLength: 60)

            Button {
                dismiss()
            } label: {
                Text("DONE")
                    .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(NETRTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressButtonStyle())
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
    }
}
