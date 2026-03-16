import SwiftUI

struct CourtCardView: View {
    let court: Court
    let distance: String
    let isFavorite: Bool
    let isHomeCourt: Bool
    let onFavoriteToggle: () -> Void
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(court.name)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)

                Spacer()

                if isHomeCourt {
                    LucideIcon("home", size: 12)
                        .foregroundStyle(NETRTheme.neonGreen)
                }

                Button {
                    onFavoriteToggle()
                } label: {
                    LucideIcon(isFavorite ? "heart" : "heart", size: 16)
                        .foregroundStyle(isFavorite ? NETRTheme.red : NETRTheme.subtext)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

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

                Spacer()
            }
        }
        .padding(14)
        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHomeCourt ? NETRTheme.neonGreen.opacity(0.4) : NETRTheme.border, lineWidth: 1)
        )
        .contentShape(.rect(cornerRadius: 14))
        .onTapGesture {
            onTap?()
        }
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
