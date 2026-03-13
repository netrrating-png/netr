import SwiftUI

private struct SkillRow: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: Double?
}

struct PlayerCardView: View {
    let player: Player
    var onDismiss: (() -> Void)? = nil

    @State private var ratingScale: CGFloat = 0.75
    @State private var ratingOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var barsVisible: Bool = false

    private var isPeerRated: Bool { player.reviews >= 5 }
    private var peerProgress: Double { min(1.0, Double(player.reviews) / 5.0) }
    private var displayRating: Double { player.rating ?? 0 }
    private var ratingColor: Color { NETRRating.color(for: player.rating) }

    private var skills: [SkillRow] {[
        SkillRow(icon: "crosshair", label: "Scoring", value: player.skills.shooting),
        SkillRow(icon: "flame", label: "Finishing", value: player.skills.finishing),
        SkillRow(icon: "zap", label: "Handles", value: player.skills.ballHandling),
        SkillRow(icon: "send", label: "Playmaking", value: player.skills.playmaking),
        SkillRow(icon: "shield", label: "Defense", value: player.skills.defense),
        SkillRow(icon: "arrow-up-circle", label: "Rebounding", value: player.skills.rebounding),
        SkillRow(icon: "brain", label: "IQ", value: player.skills.basketballIQ),
    ]}

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 28)
                .fill(NETRTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ratingColor.opacity(0.6),
                                    ratingColor.opacity(0.1),
                                    NETRTheme.border,
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )

            VStack(spacing: 0) {
                cardTopBar
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 24)

                ratingHero
                    .padding(.bottom, 20)

                VStack(spacing: 6) {
                    Text(player.name.uppercased())
                        .font(.system(size: 28, weight: .black, design: .default).width(.compressed))
                        .foregroundStyle(NETRTheme.text)
                        .tracking(0.5)
                    HStack(spacing: 10) {
                        Text(player.username)
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.subtext)
                        VibeOrbView(player: player)
                    }
                }
                .padding(.bottom, 22)

                statsStrip
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                Divider().background(NETRTheme.border).padding(.horizontal, 20).padding(.bottom, 20)

                if isPeerRated {
                    skillBreakdown
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    Divider().background(NETRTheme.border).padding(.horizontal, 20).padding(.bottom, 20)
                }

            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.1)) {
                ratingScale = 1.0
                ratingOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.4).delay(0.4)) {
                glowOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { barsVisible = true }
            }
        }
    }

    private var cardTopBar: some View {
        HStack {
            if let dismiss = onDismiss {
                Button(action: dismiss) {
                    ZStack {
                        Circle().fill(NETRTheme.muted.opacity(0.5)).frame(width: 30, height: 30)
                        LucideIcon("x", size: 12)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
            }

            Spacer()

            Text("NETR")
                .font(.system(size: 14, weight: .black, design: .default).width(.compressed))
                .foregroundStyle(NETRTheme.neonGreen)
                .tracking(2.5)

            Spacer()

            Text(player.position.rawValue)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(player.isVerified ? NETRTheme.gold : NETRTheme.neonGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((player.isVerified ? NETRTheme.gold : NETRTheme.neonGreen).opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke((player.isVerified ? NETRTheme.gold : NETRTheme.neonGreen).opacity(0.4), lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: 6))
        }
    }

    private var ratingHero: some View {
        let heroSize: CGFloat = 170
        let ringSize: CGFloat = 196

        return ZStack {
            Circle()
                .fill(ratingColor.opacity(isPeerRated ? 0.08 : 0.04))
                .frame(width: 240, height: 240)
                .blur(radius: 28)
                .opacity(glowOpacity)

            ZStack {
                if !isPeerRated {
                    Circle()
                        .stroke(NETRTheme.muted, lineWidth: 3)
                        .frame(width: ringSize, height: ringSize)
                    Circle()
                        .trim(from: 0, to: peerProgress)
                        .stroke(
                            ratingColor.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: peerProgress)
                } else {
                    Circle()
                        .stroke(ratingColor.opacity(0.35), lineWidth: 2)
                        .frame(width: ringSize, height: ringSize)
                    Circle()
                        .stroke(ratingColor.opacity(0.12), lineWidth: 14)
                        .frame(width: ringSize, height: ringSize)
                        .blur(radius: 6)
                }
            }
            .opacity(ratingOpacity)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ratingColor.opacity(0.18),
                                ratingColor.opacity(0.04),
                                NETRTheme.card,
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: heroSize / 2
                        )
                    )
                    .frame(width: heroSize, height: heroSize)
                    .shadow(color: ratingColor.opacity(isPeerRated ? 0.45 : 0.15), radius: isPeerRated ? 30 : 12)

                VStack(spacing: 4) {
                    if let rating = player.rating {
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 64, weight: .black, design: .default).width(.compressed))
                            .foregroundStyle(ratingColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text("UNRATED")
                            .font(.system(size: 28, weight: .black, design: .default).width(.compressed))
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    Text(NETRRating.tierName(for: player.rating).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ratingColor.opacity(0.7))
                        .tracking(1.5)
                }
            }
            .frame(width: heroSize, height: heroSize)
            .scaleEffect(ratingScale)
            .opacity(ratingOpacity)

            if !isPeerRated {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        lockBadge
                            .offset(x: 8, y: 8)
                    }
                }
                .frame(width: heroSize, height: heroSize)
                .opacity(ratingOpacity)
            }

            if isPeerRated {
                VStack {
                    HStack {
                        avatarChip
                            .offset(x: -heroSize / 2 + 10, y: heroSize / 2 - 10)
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: heroSize + 60, height: heroSize + 60)
                .opacity(ratingOpacity)
            }
        }
        .frame(height: 220)
    }

    private var lockBadge: some View {
        VStack(spacing: 3) {
            LucideIcon("lock", size: 11)
                .foregroundStyle(NETRTheme.subtext)
            Text("\(player.reviews)/5")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.muted, lineWidth: 1))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var avatarChip: some View {
        ZStack {
            Circle()
                .fill(ratingColor.opacity(0.15))
                .frame(width: 38, height: 38)
            Circle()
                .stroke(ratingColor.opacity(0.5), lineWidth: 1.5)
                .frame(width: 38, height: 38)
            if let urlStr = player.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                    } else {
                        Text(player.avatar)
                            .font(.system(size: 13, weight: .black, design: .default).width(.compressed))
                            .foregroundStyle(ratingColor)
                    }
                }
            } else {
                Text(player.avatar)
                    .font(.system(size: 13, weight: .black, design: .default).width(.compressed))
                    .foregroundStyle(ratingColor)
            }
        }
    }

    private var statsStrip: some View {
        HStack(spacing: 0) {
            StatCellView(
                value: isPeerRated ? "PEER" : "SELF",
                label: "RATED",
                color: isPeerRated ? ratingColor : NETRTheme.subtext,
                sublabel: isPeerRated ? "\(player.reviews) raters" : "Updates at 5"
            )

            Rectangle().fill(NETRTheme.muted).frame(width: 1, height: 40)

            StatCellView(
                value: "\(player.games)",
                label: "GAMES",
                color: NETRTheme.text,
                sublabel: player.city
            )

            Rectangle().fill(NETRTheme.muted).frame(width: 1, height: 40)

            StatCellView(
                value: "\(player.reviews)",
                label: "RATINGS",
                color: isPeerRated ? ratingColor : NETRTheme.subtext,
                sublabel: isPeerRated ? "Peer avg" : "\(max(0, 5 - player.reviews)) to unlock"
            )
        }
        .padding(.vertical, 14)
        .background(NETRTheme.muted.opacity(0.25))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var skillBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SKILL BREAKDOWN")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1.5)

            ForEach(skills) { skill in
                if let val = skill.value {
                    SkillBarRowView(
                        icon: skill.icon,
                        label: skill.label,
                        value: val,
                        visible: barsVisible,
                        accentColor: ratingColor
                    )
                }
            }
        }
    }

}

private struct VibeOrbView: View {
    let player: Player
    @State private var glow: Bool = false

    private var vibeTier: VibeTier? {
        nil
    }

    var body: some View {
        if player.isProvisional {
            HStack(spacing: 5) {
                ZStack {
                    Circle().fill(NETRTheme.subtext.opacity(0.2)).frame(width: 14, height: 14)
                    Circle().fill(NETRTheme.subtext).frame(width: 8, height: 8)
                }
                .frame(width: 14, height: 14)
                Text("Pending")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)
            }
        } else if let rating = player.rating, rating >= 7.0 {
            HStack(spacing: 5) {
                ZStack {
                    Circle().fill(NETRTheme.neonGreen.opacity(0.2)).frame(width: 14, height: 14)
                        .scaleEffect(glow ? 1.4 : 1.0)
                        .opacity(glow ? 0 : 0.7)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false), value: glow)
                    Circle().fill(NETRTheme.neonGreen).frame(width: 8, height: 8)
                        .shadow(color: NETRTheme.neonGreen.opacity(0.8), radius: 4)
                }
                .frame(width: 14, height: 14)
                Text("Locked In")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NETRTheme.neonGreen)
            }
            .onAppear { glow = true }
        } else {
            EmptyView()
        }
    }
}

private struct StatCellView: View {
    let value: String
    let label: String
    let color: Color
    let sublabel: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .default).width(.compressed))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1.2)
            Text(sublabel)
                .font(.system(size: 10))
                .foregroundStyle(NETRTheme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SkillBarRowView: View {
    let icon: String
    let label: String
    let value: Double
    let visible: Bool
    let accentColor: Color
    @State private var appeared: Bool = false

    private var pct: Double { value / 10.0 }
    private var valColor: Color { NETRRating.color(for: value) }

    var body: some View {
        HStack(spacing: 10) {
            LucideIcon(icon, size: 13)
                .foregroundStyle(NETRTheme.subtext)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NETRTheme.subtext)
                .frame(width: 90, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(NETRTheme.muted).frame(height: 3)
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [valColor.opacity(0.55), valColor]),
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: appeared ? geo.size.width * pct : 0, height: 3)
                        .animation(.easeOut(duration: 0.65), value: appeared)
                }
            }
            .frame(height: 3)
            Text(String(format: "%.1f", value))
                .font(.system(size: 14, weight: .black, design: .default).width(.compressed))
                .foregroundStyle(valColor)
                .frame(width: 32, alignment: .trailing)
        }
        .onAppear {
            if visible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appeared = true }
            }
        }
        .onChange(of: visible) { _, newValue in
            if newValue { appeared = true }
        }
    }
}

struct PlayerCardScreen: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(NETRTheme.muted)
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    PlayerCardView(player: player, onDismiss: { dismiss() })
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}

struct SelfAssessedBanner: View {
    let peerCount: Int
    let threshold: Int
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            LucideIcon("lock", size: 14)
                .foregroundStyle(NETRTheme.subtext)
            VStack(alignment: .leading, spacing: 3) {
                Text("Self-Assessed Rating")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NETRTheme.text)
                Text("Your score is from your onboarding assessment. Once \(threshold) players rate you after games, it switches to your peer average.")
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
                    .lineSpacing(3)
            }
            Spacer()
            VStack(spacing: 4) {
                Text("\(peerCount)/\(threshold)")
                    .font(.system(size: 18, weight: .black, design: .default).width(.compressed))
                    .foregroundStyle(accentColor)
                Text("raters")
                    .font(.system(size: 9))
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .padding(16)
        .background(NETRTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.muted, lineWidth: 1))
        .clipShape(.rect(cornerRadius: 14))
    }
}
