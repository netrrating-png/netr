import SwiftUI

nonisolated enum NETRTheme {
    static let neonGreen = Color(red: 0.224, green: 1.0, blue: 0.078)
    static let darkGreen = Color(red: 0.122, green: 0.8, blue: 0.0)

    static let background = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let surface = Color(red: 0.039, green: 0.039, blue: 0.051)
    static let card = Color(red: 0.059, green: 0.059, blue: 0.078)
    static let cardAlt = Color(red: 0.075, green: 0.075, blue: 0.098)
    static let border = Color(red: 0.102, green: 0.102, blue: 0.141)
    static let borderHi = Color(red: 0.149, green: 0.149, blue: 0.2)

    static let gold = Color(red: 0.961, green: 0.773, blue: 0.259)
    static let blue = Color(red: 0.29, green: 0.62, blue: 1.0)
    static let purple = Color(red: 0.608, green: 0.427, blue: 1.0)
    static let red = Color(red: 1.0, green: 0.271, blue: 0.271)

    static let text = Color(red: 0.933, green: 0.933, blue: 0.961)
    static let subtext = Color(red: 0.416, green: 0.416, blue: 0.51)
    static let muted = Color(red: 0.165, green: 0.165, blue: 0.22)

    static func ratingColor(for rating: Double?) -> Color {
        NETRRating.color(for: rating)
    }

    static func tierColor(for player: Player) -> Color {
        if player.isProspect { return purple }
        if player.isProvisional { return subtext }
        return NETRRating.color(for: player.rating)
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

    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    func dismissKeyboardOnScroll() -> some View {
        self.scrollDismissesKeyboard(.immediately)
    }
}
