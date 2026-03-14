import SwiftUI

// MARK: - Rate Tab Root

struct RateView: View {
    @State private var tabVM = RateTabViewModel()
    @State private var selectedPlayer: RateablePlayer?
    @State private var showRateFlow: Bool = false
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
        .sheet(isPresented: $showRateFlow) {
            if let player = selectedPlayer {
                RatePlayerSheetView(
                    player: player,
                    onDone: { gameId in
                        tabVM.markRated(playerId: player.id, gameId: gameId)
                        showRateFlow = false
                        selectedPlayer = nil
                        Task { await tabVM.load() }
                    },
                    onCancel: {
                        showRateFlow = false
                        selectedPlayer = nil
                    }
                )
            }
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
                                showRateFlow = true
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
                        if player.provisional {
                            Text("PROV").font(.system(size: 9, weight: .bold)).foregroundStyle(NETRTheme.gold)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(NETRTheme.gold.opacity(0.15))
                                    .overlay(Capsule().stroke(NETRTheme.gold.opacity(0.4), lineWidth: 1)))
                        }
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

// MARK: - Rating Sheet Entry

struct RatePlayerSheetView: View {
    let player: RateablePlayer
    let onDone: (String) -> Void
    let onCancel: () -> Void

    @State private var rateVM = RateViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()
                RatePlayerFlowView(viewModel: rateVM, playerIndex: 0, onDismiss: { onDone(player.gameId) })
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }.foregroundStyle(NETRTheme.subtext)
                }
            }
        }
        .task {
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

// MARK: - Rating Flow (Skill → Vibe)

struct RatePlayerFlowView: View {
    @Bindable var viewModel: RateViewModel
    let playerIndex: Int
    let onDismiss: () -> Void

    @State private var ratingStep: Int = 0   // 0 = skill categories, 1 = vibe question

    private var player: PlayerToRate? {
        guard playerIndex >= 0, playerIndex < viewModel.players.count else { return nil }
        return viewModel.players[playerIndex]
    }

    var body: some View {
        if let player {
            VStack(spacing: 0) {
                playerHeader(player: player)
                stepIndicator
                if ratingStep == 0 {
                    skillPage(player: player)
                } else {
                    vibePage(player: player)
                }
            }
        } else {
            Color.clear.onAppear { onDismiss() }
        }
    }

    // ── Player Header ─────────────────────────────────────────

    private func playerHeader(player: PlayerToRate) -> some View {
        HStack(spacing: 14) {
            RatePlayerAvatar(name: player.name, avatarUrl: player.avatarUrl, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name).font(.headline.weight(.black)).foregroundStyle(NETRTheme.text)
                HStack(spacing: 8) {
                    Text(player.position)
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(NETRTheme.neonGreen)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(NETRTheme.neonGreen.opacity(0.12), in: .rect(cornerRadius: 6))
                    if let netr = player.currentNetr {
                        Text(String(format: "%.1f NETR", netr))
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(NETRTheme.subtext)
                    }
                    if let vibe = player.currentVibe {
                        VibeDecalView(vibe: vibe, size: .small)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
    }

    // ── Step Indicator ────────────────────────────────────────

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            stepDot(number: "1", title: "SKILL", active: ratingStep == 0, done: ratingStep > 0)
            Rectangle().fill(NETRTheme.border).frame(height: 1).frame(maxWidth: .infinity)
            stepDot(number: "2", title: "VIBE",  active: ratingStep == 1, done: false)
        }
        .padding(.horizontal, 28).padding(.vertical, 10)
        .background(NETRTheme.surface)
        .overlay(Rectangle().fill(NETRTheme.border).frame(height: 0.5), alignment: .bottom)
    }

    private func stepDot(number: String, title: String, active: Bool, done: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(active || done ? NETRTheme.neonGreen : NETRTheme.muted.opacity(0.3))
                    .frame(width: 28, height: 28)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black)).foregroundStyle(NETRTheme.background)
                } else {
                    Text(number).font(.system(size: 13, weight: .black))
                        .foregroundStyle(active ? NETRTheme.background : NETRTheme.subtext)
                }
            }
            Text(title).font(.system(size: 10, weight: .bold)).tracking(1)
                .foregroundStyle(active ? NETRTheme.neonGreen : NETRTheme.subtext)
        }
    }

    // ── Skill Page ────────────────────────────────────────────

    private func skillPage(player: PlayerToRate) -> some View {
        let allRated = player.skillRatings.allRated
        let ratedCount = [player.skillRatings.shooting, player.skillRatings.finishing,
                          player.skillRatings.dribbling, player.skillRatings.passing,
                          player.skillRatings.defense, player.skillRatings.rebounding,
                          player.skillRatings.basketballIQ].compactMap { $0 }.count

        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Text("Rate this player on each skill")
                            .font(.system(size: 13)).foregroundStyle(NETRTheme.subtext)
                        Spacer()
                        Text("\(ratedCount)/7")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ratedCount == 7 ? NETRTheme.neonGreen : NETRTheme.subtext)
                    }
                    .padding(.horizontal, 16).padding(.top, 16)

                    ForEach(skillCategories) { cat in
                        RatingCategoryCard(
                            icon: cat.icon,
                            label: cat.label,
                            description: cat.description,
                            labels: peerRatingLabels,
                            selectedValue: viewModel.skillValue(for: cat.id, playerIndex: playerIndex),
                            accentColor: NETRTheme.neonGreen
                        ) { value in
                            viewModel.setSkillRating(playerIndex: playerIndex, key: cat.id, value: value)
                        }
                        .padding(.horizontal, 16)
                    }
                    Color.clear.frame(height: 100)
                }
            }
            .scrollIndicators(.hidden)

            continueBar(enabled: allRated) {
                withAnimation(.easeInOut(duration: 0.25)) { ratingStep = 1 }
            }
        }
    }

    private func continueBar(enabled: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(NETRTheme.border).frame(height: 0.5)
            Button(action: action) {
                HStack(spacing: 8) {
                    Text("NEXT: VIBE CHECK")
                        .font(.system(.subheadline, design: .default, weight: .black).width(.compressed)).tracking(1.5)
                    LucideIcon("arrow-right", size: 14)
                }
                .foregroundStyle(enabled ? NETRTheme.background : NETRTheme.subtext)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(enabled ? NETRTheme.neonGreen : NETRTheme.muted.opacity(0.2), in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressButtonStyle())
            .disabled(!enabled)
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(NETRTheme.background)
    }

    // ── Vibe Page ─────────────────────────────────────────────

    private func vibePage(player: PlayerToRate) -> some View {
        let selectedAnswer = viewModel.vibeRunAgainValue(playerIndex: playerIndex)

        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("VIBE CHECK").font(.system(size: 11, weight: .black)).tracking(2)
                            .foregroundStyle(NETRTheme.subtext)
                        Text("Would you run with\n\(player.name.components(separatedBy: " ").first ?? player.name) again?")
                            .font(NETRTheme.headingFont(size: .title3))
                            .foregroundStyle(NETRTheme.text)
                            .multilineTextAlignment(.center).lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 24)

                    VStack(spacing: 10) {
                        ForEach(vibeRunAgainOptions) { option in
                            vibeOptionButton(option: option, selected: selectedAnswer == option.id)
                        }
                    }
                    .padding(.horizontal, 16)

                    Color.clear.frame(height: 100)
                }
            }
            .scrollIndicators(.hidden)

            // Submit bar
            VStack(spacing: 0) {
                Rectangle().fill(NETRTheme.border).frame(height: 0.5)
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { ratingStep = 0 }
                    } label: {
                        LucideIcon("arrow-left", size: 16).foregroundStyle(NETRTheme.subtext)
                            .frame(width: 50, height: 50)
                            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())

                    Button {
                        Task { await viewModel.submitRating(for: playerIndex); onDismiss() }
                    } label: {
                        HStack {
                            if viewModel.isSubmitting {
                                ProgressView().tint(NETRTheme.background)
                            } else {
                                Text("SUBMIT RATING")
                                    .font(.system(.subheadline, design: .default, weight: .black).width(.compressed)).tracking(1.5)
                                LucideIcon("arrow-right", size: 14)
                            }
                        }
                        .foregroundStyle(selectedAnswer != nil ? NETRTheme.background : NETRTheme.subtext)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(
                            selectedAnswer != nil
                                ? viewModel.vibeAccentColor(playerIndex: playerIndex)
                                : NETRTheme.muted.opacity(0.2),
                            in: .rect(cornerRadius: 14)
                        )
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(selectedAnswer == nil || viewModel.isSubmitting)
                    .sensoryFeedback(.success, trigger: viewModel.isSubmitting)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(NETRTheme.background)
        }
    }

    private func vibeOptionButton(option: VibeRunAgainOption, selected: Bool) -> some View {
        let color = Color(hex: option.colorHex)
        return Button {
            withAnimation(.spring(response: 0.25)) {
                viewModel.setVibeRunAgain(playerIndex: playerIndex, value: option.id)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(selected ? color : NETRTheme.muted.opacity(0.2)).frame(width: 22, height: 22)
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .black))
                            .foregroundStyle(NETRTheme.background)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label).font(.system(size: 15, weight: .bold))
                        .foregroundStyle(selected ? color : NETRTheme.text)
                    Text(option.sublabel).font(.system(size: 12)).foregroundStyle(NETRTheme.subtext)
                }
                Spacer()
                Circle().fill(color.opacity(selected ? 1.0 : 0.3)).frame(width: 12, height: 12)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(selected ? color.opacity(0.1) : NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? color.opacity(0.5) : NETRTheme.border, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(PressButtonStyle())
        .animation(.spring(response: 0.25), value: selected)
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

struct RatingCategoryCard: View {
    let icon: String
    let label: String
    let description: String
    let labels: [Int: String]
    let selectedValue: Int?
    let accentColor: Color
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                LucideIcon(icon, size: 16)
                    .foregroundStyle(selectedValue != nil ? accentColor : NETRTheme.subtext)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                        .tracking(1).foregroundStyle(NETRTheme.text)
                    Text(description).font(.system(size: 12)).foregroundStyle(NETRTheme.subtext)
                }
            }
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        withAnimation(.spring(response: 0.25)) { onSelect(value) }
                    } label: {
                        Circle()
                            .fill((selectedValue ?? 0) >= value ? accentColor : NETRTheme.muted)
                            .frame(width: 28, height: 28)
                            .overlay {
                                Text("\(value)").font(.system(size: 12, weight: .black))
                                    .foregroundStyle((selectedValue ?? 0) >= value
                                                     ? NETRTheme.background : NETRTheme.subtext)
                            }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            if let val = selectedValue, let labelText = labels[val] {
                Text(labelText).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(accentColor.opacity(0.10), in: .rect(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(16)
        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(selectedValue != nil ? accentColor.opacity(0.25) : NETRTheme.border, lineWidth: 1))
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
