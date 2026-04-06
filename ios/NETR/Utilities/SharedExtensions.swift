import SwiftUI

// MARK: - Reusable Button Style (Scale on Press)

struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - String Identifiable (for .fullScreenCover(item:) and .sheet(item:))

extension String: @retroactive Identifiable {
    public var id: String { self }
}
