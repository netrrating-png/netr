import SwiftUI

// MARK: - Model

struct FollowPlayer: Identifiable, Sendable {
    let id: String
    let displayName: String
    let username: String
    let avatarUrl: String?
    let netrScore: Double?
    let tierName: String
    let tierColor: Color
    var isFollowing: Bool
    var isMutual: Bool

    var displayHandle: String { "@\(username)" }
}

// MARK: - Row View

struct FollowPlayerRowView: View {
    let player: FollowPlayer
    let isFollowing: Bool
    let showFollowButton: Bool
    let onFollowTap: () -> Void
    let onRowTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onRowTap) {
            HStack(spacing: 14) {
                // Avatar with optional mutual-follow lime ring
                ZStack {
                    if player.isMutual {
                        Circle()
                            .stroke(NETRTheme.neonGreen.opacity(0.6), lineWidth: 2)
                            .frame(width: 56, height: 56)
                    }
                    AvatarView(
                        url: player.avatarUrl,
                        name: player.displayName,
                        size: 52,
                        borderColor: player.isMutual ? nil : NETRTheme.border,
                        borderWidth: player.isMutual ? 0 : 1
                    )
                }

                // Name + username
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.displayName)
                        .font(.system(size: 16, weight: .bold, design: .default).width(.condensed))
                        .foregroundStyle(NETRTheme.text)
                        .lineLimit(1)

                    Text(player.displayHandle)
                        .font(.system(size: 13))
                        .foregroundStyle(NETRTheme.subtext)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // NETR score ring
                scoreRing

                // Follow / Following button
                if showFollowButton {
                    followButton
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(NETRTheme.background)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScalePressStyle())
    }

    // MARK: - Score Ring

    private var scoreRing: some View {
        let color = player.tierColor
        let scoreText = player.netrScore.map { String(format: "%.1f", $0) } ?? "--"

        return ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 3)
                .frame(width: 36, height: 36)

            Circle()
                .trim(from: 0, to: trimAmount)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-90))

            Text(scoreText)
                .font(.system(size: 10, weight: .black, design: .default).width(.compressed))
                .foregroundStyle(color)
        }
    }

    private var trimAmount: CGFloat {
        guard let score = player.netrScore else { return 0 }
        return CGFloat((score - 2.0) / 8.0).clamped(to: 0...1)
    }

    // MARK: - Tier Badge

    private var tierBadge: some View {
        Text(player.tierName.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(player.tierColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(player.tierColor.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(player.tierColor.opacity(0.3), lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 6))
    }

    // MARK: - Follow Button

    private var followButton: some View {
        Button(action: onFollowTap) {
            Text(isFollowing ? "Following" : "Follow")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isFollowing ? NETRTheme.text : NETRTheme.background)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isFollowing ? Color(red: 0.1, green: 0.1, blue: 0.1) : NETRTheme.neonGreen)
                .overlay(
                    Capsule()
                        .stroke(isFollowing ? NETRTheme.neonGreen : Color.clear, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clamp helper

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
