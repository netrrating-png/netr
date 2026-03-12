import SwiftUI

struct CourtCardView: View {
    let court: Court
    let distance: String
    let isFavorite: Bool
    let isHomeCourt: Bool
    let onFavoriteToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(court.name)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)

                Spacer()

                if isHomeCourt {
                    Image(systemName: "house.fill")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.neonGreen)
                }

                Button {
                    onFavoriteToggle()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundStyle(isFavorite ? NETRTheme.red : NETRTheme.subtext)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .highPriorityGesture(TapGesture().onEnded { onFavoriteToggle() })

                if court.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(NETRTheme.blue)
                        .font(.caption)
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
                    CourtTagChip(text: "💡 Lights")
                }
                if court.indoor {
                    CourtTagChip(text: "🏠 Indoor")
                }
                if court.fullCourt {
                    CourtTagChip(text: "🏀 Full")
                }

                Spacer()

                if court.cosignCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 10))
                        Text("\(court.cosignCount)")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(NETRTheme.neonGreen)
                }
            }
        }
        .padding(14)
        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHomeCourt ? NETRTheme.neonGreen.opacity(0.4) : NETRTheme.border, lineWidth: 1)
        )
    }
}

struct CourtTagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(NETRTheme.subtext)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(NETRTheme.surface, in: Capsule())
    }
}
