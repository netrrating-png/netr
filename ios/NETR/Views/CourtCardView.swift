import SwiftUI

/// Court card using the isolated-button pattern:
/// - The card body is a plain VStack (no Button, no NavigationLink, no gesture modifier)
/// - The outer HStack separates the tappable card area from the FavoriteButton
/// - The FavoriteButton is a sibling, NOT nested inside any other interactive element
/// - Navigation is triggered by onTap on the card body alone
struct CourtCardView: View {
    let court: Court
    let distance: String
    let isFavorite: Bool
    let isHomeCourt: Bool
    let onFavoriteToggle: () -> Void
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Card body — tappable for navigation
            cardBody
                .contentShape(.rect)
                .onTapGesture { onTap?() }

            // Favorite button — completely isolated, never nested
            FavoriteButton(isFavorite: isFavorite, onToggle: onFavoriteToggle)
                .padding(.trailing, 4)
        }
        .padding(.leading, 14)
        .padding(.vertical, 10)
        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHomeCourt ? NETRTheme.neonGreen.opacity(0.4) : NETRTheme.border, lineWidth: 1)
        )
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(court.name)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)

                if isHomeCourt {
                    LucideIcon("house", size: 12)
                        .foregroundStyle(NETRTheme.neonGreen)
                }

                if court.verified {
                    LucideIcon("badge-check", size: 12)
                        .foregroundStyle(NETRTheme.blue)
                } else {
                    Text("PENDING")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(NETRTheme.gold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NETRTheme.gold.opacity(0.15), in: Capsule())
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if !court.neighborhood.isEmpty {
                    Text(court.neighborhood)
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                    Text("·")
                        .foregroundStyle(NETRTheme.muted)
                }
                Text(distance)
                    .font(.caption)
                    .foregroundStyle(NETRTheme.subtext)
                if !court.city.isEmpty {
                    Text("·")
                        .foregroundStyle(NETRTheme.muted)
                    Text(court.city)
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                CourtTagChip(text: court.surfaceType.rawValue)
                if court.lights {
                    CourtTagChip(text: "Lights", icon: "lightbulb")
                }
                if court.indoor {
                    CourtTagChip(text: "Indoor", icon: "building-2")
                }
                if court.fullCourt {
                    CourtTagChip(text: "Full Court", icon: "circle-dot")
                }
            }
        }
        .padding(.trailing, 4)
        .padding(.vertical, 4)
    }
}

struct CourtTagChip: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                LucideIcon(icon, size: 9)
                    .foregroundStyle(NETRTheme.muted)
            }
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NETRTheme.subtext)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(NETRTheme.surface, in: Capsule())
    }
}
