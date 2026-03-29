import SwiftUI

// MARK: - NETR Player Card

struct NETRPlayerCardView: View {
    let user: Player
    let milestones: [PlayerMilestone]
    let homeCourt: Court?

    @State private var shimmerX: CGFloat = -400
    @State private var glowPulse: CGFloat = 0.3
    @State private var scoreScale: CGFloat = 1.0

    static let cardWidth: CGFloat  = 340
    static let cardHeight: CGFloat = 500

    private var tierColor: Color  { NETRRating.color(for: user.rating) }
    private var tierName: String   { NETRRating.tierName(for: user.rating ?? 0) }
    private var hasRating: Bool    { (user.rating ?? 0) > 0 }
    private var scoreText: String  {
        guard let r = user.rating, r > 0 else { return "--" }
        return String(format: "%.1f", r)
    }
    private var initials: String {
        user.name.split(separator: " ").compactMap { $0.first }.map { String($0) }.joined()
    }

    var body: some View {
        ZStack {
            // ── Background layers ──────────────────────────
            cardBase
            diagonalTexture
            tierGradientOverlay

            // ── Content ───────────────────────────────────
            VStack(spacing: 0) {
                topBar
                playerSection      // avatar + name block
                Spacer(minLength: 0)
                dividerLine
                statBarsBlock
                dividerLine
                footerStrip
            }

            // ── Shimmer sweep ──────────────────────────────
            shimmerLayer

            // ── Border ────────────────────────────────────
            cardBorder
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .clipShape(.rect(cornerRadius: 22))
        .shadow(color: tierColor.opacity(hasRating ? 0.5 : 0.15), radius: 32, x: 0, y: 12)
        .onAppear { animate() }
    }

    // MARK: - Background

    private var cardBase: some View {
        LinearGradient(
            colors: [Color(hex: "#0D0D10"), Color(hex: "#111116"), Color(hex: "#0A0A0D")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var diagonalTexture: some View {
        Canvas { ctx, size in
            for i in stride(from: -size.height, through: size.width + size.height, by: 18) {
                var p = Path()
                p.move(to:    CGPoint(x: i,             y: 0))
                p.addLine(to: CGPoint(x: i + size.height, y: size.height))
                ctx.stroke(p, with: .color(Color.white.opacity(0.028)), lineWidth: 1)
            }
        }
    }

    private var tierGradientOverlay: some View {
        ZStack {
            // Top-center bloom (behind avatar)
            RadialGradient(
                colors: [tierColor.opacity(0.28), tierColor.opacity(0.08), .clear],
                center: .init(x: 0.5, y: 0.18),
                startRadius: 0,
                endRadius: 220
            )
            // Bottom sweep
            LinearGradient(
                colors: [.clear, tierColor.opacity(0.12), tierColor.opacity(0.22)],
                startPoint: .init(x: 0.5, y: 0.55),
                endPoint: .bottom
            )
        }
    }

    private var shimmerLayer: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.06), tierColor.opacity(0.08), .clear],
                    startPoint: .init(x: 0, y: 0),
                    endPoint:   .init(x: 1, y: 1)
                )
            )
            .frame(width: 120)
            .blur(radius: 8)
            .offset(x: shimmerX)
            .allowsHitTesting(false)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 22)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        tierColor.opacity(0.9),
                        tierColor.opacity(0.3),
                        .white.opacity(0.05),
                        tierColor.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            // NETR wordmark
            HStack(spacing: 0) {
                Text("NET")
                    .foregroundStyle(.white)
                Text("R")
                    .foregroundStyle(tierColor)
            }
            .font(.system(size: 15, weight: .black).width(.compressed))
            .tracking(3)

            Spacer()

            // Tier pill
            HStack(spacing: 5) {
                if hasRating {
                    Circle()
                        .fill(tierColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: tierColor, radius: 3)
                }
                Text(tierName.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(hasRating ? tierColor : Color.white.opacity(0.35))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(hasRating ? tierColor.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(Capsule().stroke(hasRating ? tierColor.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // MARK: - Player Section (avatar + name + score)

    private var playerSection: some View {
        VStack(spacing: 0) {
            // ── Avatar ──────────────────────────────────────
            ZStack(alignment: .bottom) {
                ZStack {
                    Circle()
                        .fill(tierColor.opacity(0.10))
                        .frame(width: 148, height: 148)
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [tierColor, tierColor.opacity(0.15), tierColor.opacity(0.5), tierColor],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 148, height: 148)
                        .shadow(color: tierColor.opacity(glowPulse), radius: 14)
                    if let urlStr = user.avatarUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                                    .frame(width: 138, height: 138)
                                    .clipShape(Circle())
                            default: initialsCircle
                            }
                        }
                    } else {
                        initialsCircle
                    }
                }
                // Position pill at bottom of avatar
                Text(user.position.rawValue)
                    .font(.system(size: 10, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(hasRating ? .black : .white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(hasRating ? tierColor : Color.white.opacity(0.08))
                            .shadow(color: tierColor.opacity(0.5), radius: 6)
                    )
                    .offset(y: 14)
            }
            .padding(.bottom, 28)

            // ── Name + Score row ────────────────────────────
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name.uppercased())
                        .font(.system(size: 28, weight: .black, design: .default).width(.compressed))
                        .tracking(0.5)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    HStack(spacing: 6) {
                        Text(user.username)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                        if !user.city.isEmpty {
                            Circle().fill(.white.opacity(0.25)).frame(width: 3, height: 3)
                            Text(user.city)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
                Spacer()
                // Score badge
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [tierColor.opacity(0.3), tierColor.opacity(0.06)],
                            center: .center, startRadius: 0, endRadius: 35
                        ))
                        .frame(width: 72, height: 72)
                    Circle()
                        .strokeBorder(tierColor.opacity(0.7), lineWidth: 1.5)
                        .frame(width: 72, height: 72)
                        .shadow(color: tierColor.opacity(glowPulse), radius: 12)
                    VStack(spacing: -1) {
                        Text(scoreText)
                            .font(.system(size: 22, weight: .black).width(.compressed))
                            .foregroundStyle(hasRating ? tierColor : Color.white.opacity(0.25))
                        Text("NETR")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(hasRating ? tierColor.opacity(0.7) : Color.white.opacity(0.2))
                    }
                }
                .scaleEffect(scoreScale)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle()
                .fill(tierColor.opacity(0.12))
                .frame(width: 138, height: 138)
            Text(initials)
                .font(.system(size: 42, weight: .black).width(.compressed))
                .foregroundStyle(tierColor.opacity(hasRating ? 1 : 0.4))
        }
    }

    // MARK: - Stat Bars

    private var dividerLine: some View {
        LinearGradient(
            colors: [.clear, tierColor.opacity(0.35), tierColor.opacity(0.5), tierColor.opacity(0.35), .clear],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: 1)
        .padding(.horizontal, 14)
    }

    private var statBarsBlock: some View {
        let entries = buildSkillEntries()
        let hasAnyData = entries.contains { $0.value > 0 }

        return VStack(spacing: 6) {
            ForEach(entries, id: \.label) { entry in
                HStack(spacing: 10) {
                    Text(entry.label)
                        .font(.system(size: 9, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(entry.color.opacity(0.8))
                        .frame(width: 30, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 6)
                            // Fill
                            if entry.value > 0 {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [entry.color.opacity(0.6), entry.color],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(entry.value / 10.0), height: 6)
                                    .shadow(color: entry.color.opacity(0.6), radius: 4)
                            }
                        }
                    }
                    .frame(height: 6)

                    if hasAnyData {
                        Text(entry.value > 0 ? String(format: "%.1f", entry.value) : "--")
                            .font(.system(size: 10, weight: .bold).width(.compressed))
                            .foregroundStyle(entry.value > 0 ? entry.color : Color.white.opacity(0.2))
                            .frame(width: 28, alignment: .trailing)
                    } else {
                        Text("--")
                            .font(.system(size: 10, weight: .bold).width(.compressed))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footerStrip: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: archetype or top milestone
            archetypeOrMilestone

            Spacer()

            // Right: home court + serial
            VStack(alignment: .trailing, spacing: 3) {
                if let court = homeCourt {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(tierColor.opacity(0.8))
                        Text(court.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }
                Text("\(user.games) RUNS  ·  \(user.reviews) RATED")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var archetypeOrMilestone: some View {
        let skills = user.skills
        let scores = ArchetypeEngine.categoryScoresFromProfile(
            shooting: skills.shooting, finishing: skills.finishing,
            dribbling: skills.ballHandling, passing: skills.playmaking,
            defense: skills.defense, rebounding: skills.rebounding,
            basketballIQ: skills.basketballIQ
        )
        if let archetype = ArchetypeEngine.computeArchetype(categoryScores: scores) {
            HStack(spacing: 6) {
                LucideIcon("zap", size: 11)
                    .foregroundStyle(NETRTheme.neonGreen)
                VStack(alignment: .leading, spacing: 1) {
                    Text(archetype.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(NETRTheme.neonGreen)
                    Text(archetype.key.replacingOccurrences(of: "_", with: " · ").uppercased())
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        } else if let top = milestones.max(by: { $0.milestoneType.prestige < $1.milestoneType.prestige }) {
            HStack(spacing: 6) {
                Image(systemName: top.milestoneType.sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(top.milestoneType.badgeColor)
                Text(top.milestoneType.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(top.milestoneType.badgeColor)
            }
        }
    }

    // MARK: - Helpers

    private struct SkillEntry { let label: String; let value: Double; let color: Color }

    private func buildSkillEntries() -> [SkillEntry] {
        let s = user.skills
        return [
            SkillEntry(label: "SHT", value: s.shooting     ?? 0, color: Color(red: 1.0,  green: 0.85, blue: 0.0)),
            SkillEntry(label: "FIN", value: s.finishing    ?? 0, color: Color(red: 1.0,  green: 0.48, blue: 0.0)),
            SkillEntry(label: "HND", value: s.ballHandling ?? 0, color: Color(red: 0.0,  green: 0.9,  blue: 1.0)),
            SkillEntry(label: "PLY", value: s.playmaking   ?? 0, color: Color(red: 0.0,  green: 1.0,  blue: 0.6)),
            SkillEntry(label: "DEF", value: s.defense      ?? 0, color: Color(red: 0.18, green: 0.66, blue: 1.0)),
            SkillEntry(label: "REB", value: s.rebounding   ?? 0, color: Color(red: 0.65, green: 0.4,  blue: 1.0)),
            SkillEntry(label: "IQ",  value: s.basketballIQ ?? 0, color: Color(red: 0.24, green: 1.0,  blue: 0.55))
        ]
    }

    private func normalize(_ v: Double?) -> Double { min(max((v ?? 0) / 10.0, 0), 1) }

    // MARK: - Animation

    private func animate() {
        withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
            shimmerX = 500
        }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowPulse = 0.7
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.4)) {
            scoreScale = 1.05
        }
    }
}

// MARK: - Settings Entry Button

struct NETRPlayerCardSection: View {
    let user: Player
    let milestones: [PlayerMilestone]
    let homeCourt: Court?

    @State private var showCardSheet = false

    var body: some View {
        Button { showCardSheet = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(NETRTheme.neonGreen.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(NETRTheme.neonGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Player Card")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                    Text("View & share your NETR card")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }
                Spacer()
                LucideIcon("chevron-right", size: 12)
                    .foregroundStyle(NETRTheme.muted)
            }
            .padding(14)
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle())
        .padding(.horizontal, 16)
        .sheet(isPresented: $showCardSheet) {
            NETRPlayerCardSheet(user: user, milestones: milestones, homeCourt: homeCourt)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Card Sheet

struct NETRPlayerCardSheet: View {
    let user: Player
    let milestones: [PlayerMilestone]
    let homeCourt: Court?

    @Environment(\.dismiss) private var dismiss
    @State private var cardImage: UIImage?
    @State private var isRendering = false

    var body: some View {
        ZStack {
            Color(hex: "#080810").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.08)).frame(width: 32, height: 32)
                            Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 8)

                Text("YOUR PLAYER CARD")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.5)
                    .foregroundStyle(Color.white.opacity(0.35))
                    .padding(.bottom, 28)

                // Card
                NETRPlayerCardView(user: user, milestones: milestones, homeCourt: homeCourt)

                Spacer()

                // Share / render button
                Group {
                    if let img = cardImage {
                        ShareLink(
                            item: Image(uiImage: img),
                            preview: SharePreview("\(user.name)'s NETR Card", image: Image(uiImage: img))
                        ) {
                            shareLabel(loading: false)
                        }
                    } else {
                        Button { renderCard() } label: {
                            shareLabel(loading: isRendering)
                        }
                        .disabled(isRendering)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear { renderCard() }
    }

    private func shareLabel(loading: Bool) -> some View {
        HStack(spacing: 10) {
            if loading {
                ProgressView().tint(.black).scaleEffect(0.9)
                Text("Preparing...").font(.system(size: 16, weight: .bold)).foregroundStyle(.black)
            } else {
                Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                Text("Share Card").font(.system(size: 16, weight: .bold)).foregroundStyle(.black)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 17)
        .background(NETRTheme.neonGreen)
        .clipShape(.rect(cornerRadius: 16))
    }

    @MainActor
    private func renderCard() {
        isRendering = true
        let renderer = ImageRenderer(
            content: NETRPlayerCardView(user: user, milestones: milestones, homeCourt: homeCourt)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3.0
        cardImage = renderer.uiImage
        isRendering = false
    }
}
