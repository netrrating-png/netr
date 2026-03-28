import SwiftUI

/// Reusable avatar component used throughout the app.
/// - For the **current user**: pass `SupabaseManager.shared.currentUserAvatarUrl`
/// - For **other users**: pass the `avatar_url` from their profile / author data
/// - Always provide `initials` as a fallback when the URL is nil or the image fails to load.
struct AvatarView: View {
    let url: String?
    let initials: String
    let size: CGFloat
    var borderColor: Color? = nil
    var borderWidth: CGFloat = 0

    var body: some View {
        Group {
            if let urlString = url, let imageUrl = URL(string: urlString) {
                NETRTheme.card
                    .frame(width: size, height: size)
                    .overlay {
                        AsyncImage(url: imageUrl) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .allowsHitTesting(false)
                            } else if phase.error != nil {
                                initialsView
                            } else {
                                // Loading placeholder
                                NETRTheme.card
                            }
                        }
                    }
                    .clipShape(Circle())
            } else {
                initialsView
            }
        }
        .overlay {
            if let color = borderColor, borderWidth > 0 {
                Circle().stroke(color, lineWidth: borderWidth)
            }
        }
    }

    private var initialsView: some View {
        Text(initials)
            .font(.system(size: size * 0.35, weight: .bold))
            .foregroundStyle(NETRTheme.neonGreen)
            .frame(width: size, height: size)
            .background(NETRTheme.card, in: Circle())
    }
}

// MARK: - Helper to compute initials from a name

extension AvatarView {
    /// Creates an AvatarView from a name string, computing initials automatically.
    init(url: String?, name: String?, size: CGFloat, borderColor: Color? = nil, borderWidth: CGFloat = 0) {
        self.url = url
        self.size = size
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        let name = name ?? "?"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            self.initials = "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else {
            self.initials = String(name.prefix(2)).uppercased()
        }
    }

    /// Creates an AvatarView for the current user using the single source of truth.
    static func currentUser(size: CGFloat, borderColor: Color? = nil, borderWidth: CGFloat = 0) -> AvatarView {
        AvatarView(
            url: SupabaseManager.shared.currentUserAvatarUrl,
            name: SupabaseManager.shared.currentProfile?.fullName,
            size: size,
            borderColor: borderColor,
            borderWidth: borderWidth
        )
    }
}
