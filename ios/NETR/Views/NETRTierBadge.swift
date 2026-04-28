import SwiftUI

enum NETRTierKind: String {
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
        case .established: return "#39FF14"
        case .verified:    return "#FFC247"
        }
    }
}

struct NETRTierBadge: View {
    let tier: NETRTierKind

    var body: some View {
        Text(tier.label.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.5)
            .foregroundColor(Color(hex: tier.hex))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .stroke(Color(hex: tier.hex).opacity(0.6), lineWidth: 1)
                    .background(Capsule().fill(Color(hex: tier.hex).opacity(0.12)))
            )
            .accessibilityLabel("\(tier.label) tier — \(tier.tooltip)")
    }
}
