import SwiftUI

enum NETRTierKind: String, CaseIterable {
    case provisional, building, established, verified

    init?(serverValue: String?) {
        guard let v = serverValue?.lowercased() else { return nil }
        self.init(rawValue: v)
    }

    static func fromCount(_ count: Int) -> NETRTierKind {
        if count >= 100 { return .verified }
        if count >= 20  { return .established }
        if count >= 5   { return .building }
        return .provisional
    }

    var label: String {
        switch self {
        case .provisional: return "Provisional"
        case .building:    return "Building"
        case .established: return "Established"
        case .verified:    return "Verified"
        }
    }

    var rangeLabel: String {
        switch self {
        case .provisional: return "0–4 ratings"
        case .building:    return "5–19 ratings"
        case .established: return "20–99 ratings"
        case .verified:    return "100+ ratings"
        }
    }

    var tooltip: String {
        switch self {
        case .provisional: return "Score is settling — improves with more ratings"
        case .building:    return "Calibrating — more ratings will sharpen this"
        case .established: return "Score reflects consistent peer feedback"
        case .verified:    return "Highly accurate — built on extensive peer review"
        }
    }

    var hex: String {
        switch self {
        case .provisional: return "#9B8BFF"
        case .building:    return "#2DA8FF"
        case .established: return "#FFC247"
        case .verified:    return "#39FF14"
        }
    }
}

struct NETRTierBadge: View {
    let tier: NETRTierKind
    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            Text(tier.label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundColor(Color(hex: tier.hex))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .stroke(Color(hex: tier.hex).opacity(0.6), lineWidth: 1)
                        .background(Capsule().fill(Color(hex: tier.hex).opacity(0.12)))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tier.label) tier — \(tier.tooltip). Tap for details.")
        .sheet(isPresented: $showInfo) {
            NETRTierInfoSheet(currentTier: tier)
                .presentationDetents([.fraction(0.55), .large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct NETRTierInfoSheet: View {
    let currentTier: NETRTierKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Confidence in a player's NETR grows as they collect ratings from peers. The tier shows how settled the score is.")
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.subtext)
                        .padding(.top, 4)

                    VStack(spacing: 10) {
                        ForEach(NETRTierKind.allCases, id: \.rawValue) { t in
                            tierRow(t)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(NETRTheme.background)
            .navigationTitle("NETR Tiers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(NETRTheme.neonGreen)
                }
            }
        }
    }

    @ViewBuilder
    private func tierRow(_ t: NETRTierKind) -> some View {
        let isCurrent = (t == currentTier)
        let color = Color(hex: t.hex)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(t.label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .stroke(color.opacity(0.6), lineWidth: 1)
                            .background(Capsule().fill(color.opacity(0.12)))
                    )

                Text(t.rangeLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NETRTheme.subtext)

                Spacer()

                if isCurrent {
                    Text("YOU")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(NETRTheme.neonGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(NETRTheme.neonGreen.opacity(0.15))
                        )
                }
            }

            Text(t.tooltip)
                .font(.system(size: 13))
                .foregroundStyle(NETRTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(NETRTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isCurrent ? color.opacity(0.5) : NETRTheme.border, lineWidth: 1)
                )
        )
    }
}
