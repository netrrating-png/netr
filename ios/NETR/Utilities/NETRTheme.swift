import SwiftUI

nonisolated enum NETRTheme {
    static let neonGreen = Color(red: 0.224, green: 1.0, blue: 0.078)
    static let darkGreen = Color(red: 0.122, green: 0.8, blue: 0.0)

    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.016, green: 0.016, blue: 0.024, alpha: 1)
        : UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
    })

    static let surface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.039, green: 0.039, blue: 0.051, alpha: 1)
        : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    })

    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.059, green: 0.059, blue: 0.078, alpha: 1)
        : UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1)
    })

    static let cardAlt = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.075, green: 0.075, blue: 0.098, alpha: 1)
        : UIColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1)
    })

    static let border = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.102, green: 0.102, blue: 0.141, alpha: 1)
        : UIColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1)
    })

    static let borderHi = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.149, green: 0.149, blue: 0.2, alpha: 1)
        : UIColor(red: 0.82, green: 0.82, blue: 0.85, alpha: 1)
    })

    static let gold = Color(red: 0.961, green: 0.773, blue: 0.259)
    static let blue = Color(red: 0.29, green: 0.62, blue: 1.0)
    static let purple = Color(red: 0.608, green: 0.427, blue: 1.0)
    static let red = Color(red: 1.0, green: 0.271, blue: 0.271)

    static let text = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.933, green: 0.933, blue: 0.961, alpha: 1)
        : UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
    })

    static let subtext = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.416, green: 0.416, blue: 0.51, alpha: 1)
        : UIColor(red: 0.45, green: 0.45, blue: 0.52, alpha: 1)
    })

    static let muted = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.165, green: 0.165, blue: 0.22, alpha: 1)
        : UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1)
    })

    static func ratingColor(for rating: Double?) -> Color {
        guard let r = rating else { return subtext }
        switch r {
        case 8.0...: return neonGreen
        case 6.5...: return Color(red: 0.478, green: 0.91, blue: 0.0)
        case 5.0...: return Color(red: 1.0, green: 0.839, blue: 0.039)
        default: return red
        }
    }

    static func tierColor(for player: Player) -> Color {
        if player.isProspect { return purple }
        if player.isProvisional { return subtext }
        return ratingColor(for: player.rating)
    }

    static var headingFont: Font {
        .system(.title, design: .default, weight: .black).width(.compressed)
    }

    static func headingFont(size: Font.TextStyle) -> Font {
        .system(size, design: .default, weight: .black).width(.compressed)
    }
}

struct NeonGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius)
            .shadow(color: color.opacity(0.3), radius: radius * 2)
    }
}

extension View {
    func neonGlow(_ color: Color = NETRTheme.neonGreen, radius: CGFloat = 8) -> some View {
        modifier(NeonGlowModifier(color: color, radius: radius))
    }
}
