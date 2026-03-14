import SwiftUI

// MARK: - Rate Tab Root

struct RateView: View {
    @State private var tabVM = RateTabViewModel()
    @State private var selectedPlayer: RateablePlayer?
    @State private var section: RateSection = .ratePlayers

    enum RateSection { case ratePlayers, ratedBy }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                sectionPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if section == .ratePlayers {
                    ratePlayersContent
                } else {
                    ratedByContent
                }
            }
        }
        .task { await tabVM.load() }
        .fullScreenCover(item: $selectedPlayer) { player in
            RatePlayerSheetView(
                player: player,
                onDone: { gameId in
                    tabVM.markRated(playerId: player.id, gameId: gameId)
                    selectedPlayer = nil
                    Task { await tabVM.load() }
                },
                onCancel: {
                    selectedPlayer = nil
                }
            )
        }
    }

    // ── Section Picker ──────────────────────────────────────────

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            sectionTab("Rate Players", active: section == .ratePlayers) {
                withAnimation(.spring(response: 0.3)) { section = .ratePlayers }
            }
            sectionTab(
                "Rated By",
                active: section == .ratedBy,
                badge: tabVM.ratingsReceivedToday > 0 ? tabVM.ratingsReceivedToday : nil
            ) {
                withAnimation(.spring(response: 0.3)) { section = .ratedBy }
            }
        }
        .background(NETRTheme.surface, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
    }

    private func sectionTab(_ title: String, active: Bool, badge: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(active ? NETRTheme.neonGreen : NETRTheme.subtext)
                if let n = badge {
                    Text("\(n)")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(NETRTheme.background)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(NETRTheme.neonGreen, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(active ? NETRTheme.neonGreen.opacity(0.1) : Color.clear, in: .rect(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }

    // ── Rate Players ────────────────────────────────────────────

    @ViewBuilder
    private var ratePlayersContent: some View {
        if tabVM.isLoading {
            Spacer()
            ProgressView().tint(NETRTheme.neonGreen).scaleEffect(1.3)
            Spacer()
        } else if let err = tabVM.errorMessage {
            ratePlayersErrorView(err)
        } else if tabVM.isEmpty {
            ratePlayersEmptyView
        } else {
            sessionListView
        }
    }

    private var sessionListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WindowBannerView().padding(.horizontal, 20)
                ForEach(tabVM.sessions) { session in
                    VStack(alignment: .leading, spacing: 12) {
                        SessionHeaderView(session: session)
                        ForEach(session.players) { player in
                            RatePlayerCardView(player: player) {
                                selectedPlayer = player
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                Color.clear.frame(height: 100)
            }
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .refreshable { await tabVM.load() }
    }

    private var ratePlayersEmptyView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                ZStack {
                    Circle().fill(NETRTheme.neonGreen.opacity(0.08)).frame(width: 100, height: 100)
                    Circle().stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1).frame(width: 100, height: 100)
                    LucideIcon("circle-dot", size: 40).foregroundStyle(NETRTheme.neonGreen.opacity(0.5))
                }
                VStack(spacing: 8) {
                    Text("NO RECENT GAMES")
                        .font(NETRTheme.headingFont(size: .title3)).foregroundStyle(NETRTheme.text)
                    Text("Players appear here after you play in a game. Ratings are open for 24 hours.")
                        .font(.subheadline).foregroundStyle(NETRTheme.subtext)
                        .multilineTextAlignment(.center).lineSpacing(4)
                }
                VStack(spacing: 12) {
                    HowItWorksRow(icon: "dumbbell",                   text: "Join or create a game at any court")
                    HowItWorksRow(icon: "clock",                      text: "After the game ends, players appear here")
                    HowItWorksRow(icon: "star",                       text: "Rate each player on skill & vibe")
                    HowItWorksRow(icon: "chart.line.uptrend.xyaxis",  text: "Ratings build everyone's NETR score")
                }
                .padding(16)
                .background(NETRTheme.card, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(NETRTheme.border, lineWidth: 1))
            }
            .padding(.horizontal, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func ratePlayersErrorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            LucideIcon("alert-circle", size: 40).foregroundStyle(NETRTheme.subtext)
            Text("Couldn't load games").font(.headline).foregroundStyle(NETRTheme.text)
            Text(message).font(.caption).foregroundStyle(NETRTheme.subtext).multilineTextAlignment(.center)
            Button { Task { await tabVM.load() } } label: {
                HStack(spacing: 8) {
                    LucideIcon("refresh-cw", size: 14)
                    Text("REFRESH")
                        .font(.system(.subheadline, design: .default, weight: .black).width(.compressed)).tracking(1)
                }
                .foregroundStyle(NETRTheme.neonGreen)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(NETRTheme.neonGreen.opacity(0.1), in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1))
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // ── Rated By ────────────────────────────────────────────────

    private var ratedByContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 32)

                // Count circle
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(tabVM.ratingsReceivedToday > 0
                                  ? NETRTheme.neonGreen.opacity(0.1) : NETRTheme.muted.opacity(0.08))
                            .frame(width: 120, height: 120)
                        Circle()
                            .stroke(tabVM.ratingsReceivedToday > 0
                                    ? NETRTheme.neonGreen.opacity(0.3) : NETRTheme.border, lineWidth: 1.5)
                            .frame(width: 120, height: 120)
                        VStack(spacing: 2) {
                            Text("\(tabVM.ratingsReceivedToday)")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(tabVM.ratingsReceivedToday > 0 ? NETRTheme.neonGreen : NETRTheme.subtext)
                            Text("today")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(NETRTheme.subtext)
                        }
                    }
                    Text(tabVM.ratingsReceivedToday == 1
                         ? "1 person rated you today"
                         : "\(tabVM.ratingsReceivedToday) people rated you today")
                        .font(NETRTheme.headingFont(size: .title3))
                        .foregroundStyle(NETRTheme.text)
                        .multilineTextAlignment(.center)
                }

                // Info cards
                VStack(spacing: 0) {
                    infoRow(
                        icon: "lock.fill",
                        iconColor: NETRTheme.subtext,
                        title: "Ratings are anonymous",
                        body: "You can see how many people rated you, but not who."
                    )
                    Divider().background(NETRTheme.border).padding(.leading, 58)
                    infoRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: NETRTheme.neonGreen,
                        title: "Your score updates automatically",
                        body: "Vibe score and total ratings reflect all peer ratings you've received."
                    )
                }
                .background(NETRTheme.card, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(NETRTheme.border, lineWidth: 1))
                .padding(.horizontal, 20)

                Color.clear.frame(height: 80)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await tabVM.load() }
    }

    private func infoRow(icon: String, iconColor: Color, title: String, body: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(iconColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(NETRTheme.text)
                Text(body).font(.system(size: 12)).foregroundStyle(NETRTheme.subtext).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Window Banner

struct WindowBannerView: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(NETRTheme.neonGreen).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("24-Hour Rating Window")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(NETRTheme.neonGreen)
                Text("Only players from your game sessions in the last 24 hours appear here.")
                    .font(.system(size: 12)).foregroundStyle(NETRTheme.subtext).lineSpacing(3)
            }
            Spacer()
            LucideIcon("clock", size: 18).foregroundStyle(NETRTheme.neonGreen.opacity(0.5))
        }
        .padding(14)
        .background(NETRTheme.neonGreen.opacity(0.08), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.neonGreen.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Session Header

struct SessionHeaderView: View {
    let session: RecentGameSession

    private var timeAgoText: String {
        let diff = Date().timeIntervalSince(session.playedAt)
        let hrs = Int(diff / 3600)
        let mins = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
        if hrs > 0 { return "\(hrs)h ago" }
        return "\(max(1, mins))m ago"
    }
    private var ratedCount: Int { session.players.filter { $0.alreadyRated }.count }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    LucideIcon("circle-dot", size: 12).foregroundStyle(NETRTheme.neonGreen)
                    Text(session.courtName)
                        .font(NETRTheme.headingFont(size: .title3)).foregroundStyle(NETRTheme.text)
                }
                Text("\(timeAgoText) · \(session.players.count) players")
                    .font(.caption).foregroundStyle(NETRTheme.subtext)
            }
            Spacer()
            let allRated = ratedCount == session.players.count
            Text("\(ratedCount)/\(session.players.count) rated")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(allRated ? NETRTheme.neonGreen : NETRTheme.subtext)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    Capsule().stroke(allRated ? NETRTheme.neonGreen.opacity(0.4) : NETRTheme.border, lineWidth: 1)
                        .background(Capsule().fill(allRated ? NETRTheme.neonGreen.opacity(0.1) : NETRTheme.card))
                )
        }
    }
}

// MARK: - Player Card

struct RatePlayerCardView: View {
    let player: RateablePlayer
    let onTap: () -> Void

    private var initials: String {
        player.fullName.split(separator: " ").compactMap { $0.first }
            .map { String($0) }.joined().prefix(2).uppercased()
    }
    private var netrColor: Color { NETRRating.color(for: player.netrScore) }

    var body: some View {
        Button { if !player.alreadyRated { onTap() } } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(netrColor.opacity(0.15)).frame(width: 48, height: 48)
                    Circle().stroke(netrColor, lineWidth: 1.5).frame(width: 48, height: 48)
                    Text(String(initials))
                        .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                        .foregroundStyle(netrColor)
                }
                .opacity(player.alreadyRated ? 0.4 : 1.0)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(player.fullName).font(.subheadline.weight(.semibold))
                            .foregroundStyle(player.alreadyRated ? NETRTheme.subtext : NETRTheme.text)
                    }
                    HStack(spacing: 8) {
                        Text("@\(player.username)").font(.caption).foregroundStyle(NETRTheme.subtext)
                        if let pos = player.position {
                            Text("·").foregroundStyle(NETRTheme.muted)
                            Text(pos).font(.caption).foregroundStyle(NETRTheme.subtext)
                        }
                    }
                }

                Spacer()

                if player.alreadyRated {
                    VStack(spacing: 3) {
                        LucideIcon("check-circle", size: 20).foregroundStyle(NETRTheme.neonGreen.opacity(0.6))
                        Text("Rated").font(.system(size: 11, weight: .medium)).foregroundStyle(NETRTheme.subtext)
                    }
                } else {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle().fill(netrColor.opacity(0.12)).frame(width: 44, height: 44)
                            Circle().stroke(netrColor, lineWidth: 1.5).frame(width: 44, height: 44)
                            Text(player.netrScore.map { String(format: "%.1f", $0) } ?? "—")
                                .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                                .foregroundStyle(netrColor)
                        }
                        Text("Rate").font(.system(size: 11, weight: .medium)).foregroundStyle(NETRTheme.neonGreen)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background((player.alreadyRated ? NETRTheme.surface : NETRTheme.card), in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(player.alreadyRated ? NETRTheme.border.opacity(0.5) : NETRTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(player.alreadyRated)
    }
}

// MARK: - Rating Sheet (Skill Screen → Vibe Screen)

struct RatePlayerSheetView: View {
    let player: RateablePlayer
    let onDone: (String) -> Void
    let onCancel: () -> Void

    @State private var rateVM = RateViewModel()
    @State private var showVibe = false

    var body: some View {
        NavigationStack {
            SkillRatingScreen(
                player: player,
                rateVM: rateVM,
                onCancel: onCancel,
                onNext: { showVibe = true }
            )
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showVibe) {
                VibeRatingScreen(
                    player: player,
                    rateVM: rateVM,
                    onBack: { showVibe = false },
                    onSubmit: {
                        Task {
                            await rateVM.submitRating(for: 0)
                            onDone(player.gameId)
                        }
                    }
                )
                .navigationBarHidden(true)
            }
        }
        .onAppear {
            rateVM.setGameId(player.gameId)
            rateVM.players = [
                PlayerToRate(
                    id:          player.id,
                    name:        player.fullName,
                    username:    player.username,
                    position:    player.position ?? "—",
                    avatarUrl:   nil,
                    currentNetr: player.netrScore,
                    currentVibe: player.vibeScore
                )
            ]
        }
    }
}

// MARK: - Screen 1: Skill Rating

struct SkillRatingScreen: View {
    let player: RateablePlayer
    @Bindable var rateVM: RateViewModel
    let onCancel: () -> Void
    let onNext: () -> Void

    private var ratedCount: Int {
        guard !rateVM.players.isEmpty else { return 0 }
        let s = rateVM.players[0].skillRatings
        return [s.shooting, s.finishing, s.dribbling, s.passing, s.defense, s.rebounding, s.basketballIQ]
            .compactMap { $0 }.count
    }
    private var allRated: Bool { ratedCount == 7 }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(NETRTheme.subtext)
                Spacer()
                // Compact player info
                HStack(spacing: 8) {
                    RatePlayerAvatar(name: player.fullName, avatarUrl: nil, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(player.fullName)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(NETRTheme.text)
                        if let netr = player.netrScore {
                            Text(String(format: "%.1f NETR", netr))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }
                }
                Spacer()
                // Progress
                Text("\(ratedCount)/7")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(allRated ? NETRTheme.neonGreen : NETRTheme.subtext)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(NETRTheme.background)

            Rectangle().fill(NETRTheme.border).frame(height: 0.5)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(skillCategories) { cat in
                        SkillSliderRow(
                            category: cat,
                            value: rateVM.skillValue(for: cat.id, playerIndex: 0)
                        ) { val in
                            rateVM.setSkillRating(playerIndex: 0, key: cat.id, value: val)
                        }
                    }
                    Color.clear.frame(height: 16)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)

            // Submit button
            VStack(spacing: 0) {
                Rectangle().fill(NETRTheme.border).frame(height: 0.5)
                Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text(allRated ? "VIBE CHECK" : "RATE ALL 7 TO CONTINUE")
                            .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                            .tracking(1.5)
                        if allRated {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .black))
                        }
                    }
                    .foregroundStyle(allRated ? NETRTheme.background : NETRTheme.subtext)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(allRated ? NETRTheme.neonGreen : NETRTheme.muted.opacity(0.2),
                                in: .rect(cornerRadius: 14))
                }
                .buttonStyle(PressButtonStyle())
                .disabled(!allRated)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(NETRTheme.background)
        }
        .background(NETRTheme.background.ignoresSafeArea())
    }
}

// MARK: - Skill Slider Row

struct SkillSliderRow: View {
    let category: SkillCategory
    let value: Int?
    let onSelect: (Int) -> Void

    @State private var isDragging = false
    private var color: Color { category.accentColor }
    private let labels = ["", "Weak", "Below Avg", "Solid", "Strong", "Elite"]

    var body: some View {
        HStack(spacing: 12) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(value != nil ? color.opacity(0.15) : NETRTheme.muted.opacity(0.08))
                    .frame(width: 36, height: 36)
                LucideIcon(category.icon, size: 15)
                    .foregroundStyle(value != nil ? color : NETRTheme.subtext)
            }
            .scaleEffect(isDragging ? 1.15 : 1.0)
            .animation(.spring(response: 0.2), value: isDragging)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category.label.uppercased())
                        .font(.system(size: 11, weight: .black)).tracking(0.8)
                        .foregroundStyle(value != nil ? color : NETRTheme.text)
                    Spacer()
                    if let v = value {
                        HStack(spacing: 4) {
                            Text(labels[v])
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(color.opacity(0.8))
                            Text("\(v)")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(color)
                                .frame(width: 22, height: 22)
                                .background(color.opacity(0.15), in: Circle())
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        Text("Slide →")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NETRTheme.muted)
                    }
                }

                // Drag track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(NETRTheme.muted.opacity(0.15))
                            .frame(height: 8)

                        // Filled portion
                        if let v = value {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [color.opacity(0.6), color],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(v) / 5.0, height: 8)
                                .animation(.spring(response: 0.25), value: v)

                            // Thumb
                            Circle()
                                .fill(color)
                                .frame(width: isDragging ? 20 : 16, height: isDragging ? 20 : 16)
                                .shadow(color: color.opacity(0.5), radius: isDragging ? 8 : 4)
                                .offset(x: geo.size.width * CGFloat(v) / 5.0 - (isDragging ? 10 : 8))
                                .animation(.spring(response: 0.2), value: isDragging)
                                .animation(.spring(response: 0.25), value: v)
                        }

                        // Segment ticks
                        HStack(spacing: 0) {
                            ForEach(1...5, id: \.self) { i in
                                Spacer()
                                Circle()
                                    .fill((value ?? 0) >= i ? color : NETRTheme.muted.opacity(0.3))
                                    .frame(width: 4, height: 4)
                                if i == 5 { Spacer() }
                            }
                        }
                    }
                    .contentShape(Rectangle().size(CGSize(width: geo.size.width, height: 44)).offset(CGPoint(x: 0, y: -18)))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if !isDragging {
                                    withAnimation(.spring(response: 0.2)) { isDragging = true }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                                let x = min(max(drag.location.x, 0), geo.size.width)
                                let raw = x / geo.size.width * 5
                                let snapped = min(max(Int(raw.rounded()), 1), 5)
                                if snapped != (value ?? 0) {
                                    withAnimation(.spring(response: 0.15)) { onSelect(snapped) }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.2)) { isDragging = false }
                            }
                    )
                }
                .frame(height: 20)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(value != nil ? color.opacity(0.05) : NETRTheme.card, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(value != nil ? color.opacity(0.3) : NETRTheme.border, lineWidth: 1)
        )
        .animation(.spring(response: 0.3), value: value != nil)
    }
}

// MARK: - Screen 2: Vibe Rating

struct VibeRatingScreen: View {
    let player: RateablePlayer
    @Bindable var rateVM: RateViewModel
    let onBack: () -> Void
    let onSubmit: () -> Void

    private var selectedAnswer: Int? { rateVM.vibeRunAgainValue(playerIndex: 0) }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(NETRTheme.subtext)
                }
                Spacer()
                Text("VIBE CHECK")
                    .font(.system(size: 13, weight: .black)).tracking(1.5)
                    .foregroundStyle(NETRTheme.text)
                Spacer()
                Text("2 of 2")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 28) {
                    // Profile
                    VStack(spacing: 10) {
                        RatePlayerAvatar(name: player.fullName, avatarUrl: nil, size: 88)
                        Text(player.fullName)
                            .font(.title2.weight(.black))
                            .foregroundStyle(NETRTheme.text)
                    }
                    .padding(.top, 8)

                    // Question
                    Text("Would you run with \(player.fullName.components(separatedBy: " ").first ?? player.fullName) again?")
                        .font(NETRTheme.headingFont(size: .title3))
                        .foregroundStyle(NETRTheme.text)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Options
                    VStack(spacing: 10) {
                        ForEach(vibeRunAgainOptions) { option in
                            VibeOptionCard(
                                option: option,
                                selected: selectedAnswer == option.id
                            ) {
                                withAnimation(.spring(response: 0.2)) {
                                    rateVM.setVibeRunAgain(playerIndex: 0, value: option.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Color.clear.frame(height: 100)
                }
            }
            .scrollIndicators(.hidden)

            // Submit button
            VStack(spacing: 0) {
                Rectangle().fill(NETRTheme.border).frame(height: 0.5)
                Button(action: onSubmit) {
                    HStack(spacing: 8) {
                        if rateVM.isSubmitting {
                            ProgressView().tint(NETRTheme.background)
                        } else {
                            Text("SUBMIT RATING")
                                .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                                .tracking(1.5)
                        }
                    }
                    .foregroundStyle(selectedAnswer != nil ? NETRTheme.background : NETRTheme.subtext)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        selectedAnswer != nil
                            ? rateVM.vibeAccentColor(playerIndex: 0)
                            : NETRTheme.muted.opacity(0.2),
                        in: .rect(cornerRadius: 14)
                    )
                }
                .buttonStyle(PressButtonStyle())
                .disabled(selectedAnswer == nil || rateVM.isSubmitting)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(NETRTheme.background)
        }
        .background(NETRTheme.background.ignoresSafeArea())
    }
}

// MARK: - Vibe Option Card

struct VibeOptionCard: View {
    let option: VibeRunAgainOption
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        let color = Color(hex: option.colorHex)
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(selected ? color : NETRTheme.muted.opacity(0.2))
                        .frame(width: 24, height: 24)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(NETRTheme.background)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(selected ? color : NETRTheme.text)
                    Text(option.sublabel)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                }
                Spacer()
                Circle()
                    .fill(color.opacity(selected ? 1.0 : 0.3))
                    .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 18).padding(.vertical, 18)
            .background(selected ? color.opacity(0.1) : NETRTheme.card, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(selected ? color.opacity(0.6) : NETRTheme.border, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(PressButtonStyle())
        .animation(.spring(response: 0.2), value: selected)
    }
}

// MARK: - Shared Sub-views

struct RatePlayerAvatar: View {
    let name: String
    let avatarUrl: String?
    let size: CGFloat

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        if let avatarUrl, let url = URL(string: avatarUrl) {
            NETRTheme.card.frame(width: size, height: size)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                        }
                    }
                }
                .clipShape(Circle())
                .overlay(Circle().stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1.5))
        } else {
            Text(initials).font(.system(size: size * 0.32, weight: .bold)).foregroundStyle(NETRTheme.neonGreen)
                .frame(width: size, height: size)
                .background(NETRTheme.card, in: Circle())
                .overlay(Circle().stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1.5))
        }
    }
}


struct HowItWorksRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            LucideIcon(icon, size: 14).foregroundStyle(NETRTheme.neonGreen)
                .frame(width: 28, height: 28).background(NETRTheme.neonGreen.opacity(0.1), in: Circle())
            Text(text).font(.system(size: 14)).foregroundStyle(NETRTheme.subtext)
            Spacer()
        }
    }
}
