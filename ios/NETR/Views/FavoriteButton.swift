import SwiftUI

/// Completely isolated favorite button — NOT nested inside any other
/// interactive element. Uses @State for instant optimistic toggle
/// before the async Supabase write completes.
struct FavoriteButton: View {
    let isFavorite: Bool
    let onToggle: () -> Void

    @State private var localFavorite: Bool?

    private var displayed: Bool { localFavorite ?? isFavorite }

    var body: some View {
        Button {
            localFavorite = !displayed
            onToggle()
        } label: {
            LucideIcon(displayed ? "heart" : "heart", size: 16)
                .foregroundStyle(displayed ? NETRTheme.red : NETRTheme.subtext)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: isFavorite) { _, newValue in
            localFavorite = nil
        }
    }
}
