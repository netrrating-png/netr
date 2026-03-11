import SwiftUI

struct RateView: View {
    @State private var tabVM = RateTabViewModel()
    @State private var selectedPlayer: RateablePlayer?
    @State private var showRateFlow: Bool = false

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            if tabVM.isLoading {
                loadingView
            } else if let error = tabVM.errorMessage {
                errorView(error)
            } else if tabVM.isEmpty {
                emptyView
            } else {
                sessionListView
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
                    },
                    onCancel: {
                        showRateFlow = false
                        selectedPlayer = nil
                    }
                )
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(NETRTheme.neonGreen)
                .scaleEffect(1.3)
            Text("Loading your recent games...")
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(NETRTheme.neonGreen.opacity(0.08))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1)
                    .frame(width: 100, height: 100)
                Image(systemName: "basketball.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(NETRTheme.neonGreen.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("NO RECENT GAMES")
                    .font(NETRTheme.headingFont(size: .title3))
                    .foregroundStyle(NETRTheme.text)

                Text("Players appear here after you play in a game session. Ratings are open for 24 hours after a game ends.")
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 12) {
                HowItWorksRow(icon: "figure.basketball", text: "Join or create a game at any court")
                HowItWorksRow(icon: "clock.fill", text: "After the game ends, players appear here")
                HowItWorksRow(icon: "star.fill", text: "Rate each player across skill & vibe categories")
                HowItWorksRow(icon: "chart.line.uptrend.xyaxis", text: "Ratings build everyone's NETR score")
            }
            .padding(16)
            .background(NETRTheme.card, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(NETRTheme.border, lineWidth: 1)
            )
        }
        .padding(.horizontal, 28)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(NETRTheme.neonGreen.opacity(0.08))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1)
                    .frame(width: 100, height: 100)
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(NETRTheme.neonGreen.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("RATE YOUR OPPONENTS")
                    .font(NETRTheme.headingFont(size: .title3))
                    .foregroundStyle(NETRTheme.text)

                Text("After you play a game at a court, the players you competed with will show up here for you to rate.")
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 12) {
                HowItWorksRow(icon: "figure.basketball", text: "Join or create a game at any court")
                HowItWorksRow(icon: "clock.fill", text: "After the game ends, players appear here")
                HowItWorksRow(icon: "star.fill", text: "Rate each player across skill & vibe categories")
                HowItWorksRow(icon: "chart.line.uptrend.xyaxis", text: "Ratings build everyone's NETR score")
            }
            .padding(16)
            .background(NETRTheme.card, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(NETRTheme.border, lineWidth: 1)
            )

            Button {
                Task { await tabVM.load() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                    Text("REFRESH")
                        .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                        .tracking(1)
                }
                .foregroundStyle(NETRTheme.neonGreen)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(NETRTheme.neonGreen.opacity(0.1), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 32)
    }

    private var sessionListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RATE PLAYERS")
                        .font(NETRTheme.headingFont(size: .title2))
                        .foregroundStyle(NETRTheme.text)
                    Text("Rate players from your recent games")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                }
                .padding(.horizontal, 20)

                WindowBannerView()
                    .padding(.horizontal, 20)

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
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .refreshable { await tabVM.load() }
    }
}

struct WindowBannerView: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(NETRTheme.neonGreen)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("24-Hour Rating Window")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NETRTheme.neonGreen)
                Text("Only players from your game sessions in the last 24 hours appear here.")
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
                    .lineSpacing(3)
            }

            Spacer()

            Image(systemName: "clock.fill")
                .font(.system(size: 18))
                .foregroundStyle(NETRTheme.neonGreen.opacity(0.5))
        }
        .padding(14)
        .background(NETRTheme.neonGreen.opacity(0.08), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(NETRTheme.neonGreen.opacity(0.25), lineWidth: 1)
        )
    }
}

struct SessionHeaderView: View {
    let session: RecentGameSession

    private var timeAgoText: String {
        let diff = Date().timeIntervalSince(session.playedAt)
        let hrs = Int(diff / 3600)
        let mins = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
        if hrs > 0 { return "\(hrs)h ago" }
        return "\(max(1, mins))m ago"
    }

    private var ratedCount: Int {
        session.players.filter { $0.alreadyRated }.count
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "basketball.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.neonGreen)
                    Text(session.courtName)
                        .font(NETRTheme.headingFont(size: .title3))
                        .foregroundStyle(NETRTheme.text)
                }
                Text("\(timeAgoText) \u{00B7} \(session.players.count) players")
                    .font(.caption)
                    .foregroundStyle(NETRTheme.subtext)
            }

            Spacer()

            let allRated = ratedCount == session.players.count
            Text("\(ratedCount)/\(session.players.count) rated")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(allRated ? NETRTheme.neonGreen : NETRTheme.subtext)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .stroke(
                            allRated ? NETRTheme.neonGreen.opacity(0.4) : NETRTheme.border,
                            lineWidth: 1
                        )
                        .background(
                            Capsule().fill(
                                allRated ? NETRTheme.neonGreen.opacity(0.1) : NETRTheme.card
                            )
                        )
                )
        }
    }
}

struct RatePlayerCardView: View {
    let player: RateablePlayer
    let onTap: () -> Void

    private var initials: String {
        player.fullName
            .split(separator: " ")
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
            .prefix(2)
            .uppercased()
    }

    private var netrColor: Color {
        NETRTheme.ratingColor(for: player.netrScore)
    }

    var body: some View {
        Button {
            if !player.alreadyRated { onTap() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(netrColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Circle()
                        .stroke(netrColor, lineWidth: 1.5)
                        .frame(width: 48, height: 48)
                    Text(String(initials))
                        .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                        .foregroundStyle(netrColor)
                }
                .opacity(player.alreadyRated ? 0.4 : 1.0)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(player.fullName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(player.alreadyRated ? NETRTheme.subtext : NETRTheme.text)

                        if player.provisional {
                            Text("PROV")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(NETRTheme.gold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(NETRTheme.gold.opacity(0.15))
                                        .overlay(Capsule().stroke(NETRTheme.gold.opacity(0.4), lineWidth: 1))
                                )
                        }
                    }

                    HStack(spacing: 8) {
                        Text("@\(player.username)")
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)

                        if let pos = player.position {
                            Text("\u{00B7}")
                                .foregroundStyle(NETRTheme.muted)
                            Text(pos)
                                .font(.caption)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }
                }

                Spacer()

                if player.alreadyRated {
                    VStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(NETRTheme.neonGreen.opacity(0.6))
                        Text("Rated")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                } else {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(netrColor.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Circle()
                                .stroke(netrColor, lineWidth: 1.5)
                                .frame(width: 44, height: 44)
                            Text(player.netrScore.map { String(format: "%.1f", $0) } ?? "\u{2014}")
                                .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                                .foregroundStyle(netrColor)
                        }
                        Text("Rate")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                (player.alreadyRated ? NETRTheme.surface : NETRTheme.card)
            , in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        player.alreadyRated ? NETRTheme.border.opacity(0.5) : NETRTheme.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(player.alreadyRated)
    }
}

struct RatePlayerSheetView: View {
    let player: RateablePlayer
    let onDone: (String) -> Void
    let onCancel: () -> Void

    @State private var rateVM = RateViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                RatePlayerFlowView(
                    viewModel: rateVM,
                    playerIndex: 0,
                    onDismiss: { onDone(player.gameId) }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
        .task {
            rateVM.setGameId(player.gameId)
            rateVM.players = [
                PlayerToRate(
                    id: player.id,
                    name: player.fullName,
                    username: player.username,
                    position: player.position ?? "PG",
                    avatarUrl: nil,
                    currentNetr: player.netrScore,
                    currentVibe: player.vibeScore
                )
            ]
        }
    }
}

struct RatePlayerFlowView: View {
    @Bindable var viewModel: RateViewModel
    let playerIndex: Int
    let onDismiss: () -> Void

    private var player: PlayerToRate? {
        guard playerIndex >= 0, playerIndex < viewModel.players.count else { return nil }
        return viewModel.players[playerIndex]
    }

    var body: some View {
        if let player {
            playerFlowContent(player: player)
        } else {
            Color.clear.onAppear { onDismiss() }
        }
    }

    @ViewBuilder
    private func playerFlowContent(player: PlayerToRate) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                RatePlayerAvatar(name: player.name, avatarUrl: player.avatarUrl, size: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name)
                        .font(.headline.weight(.black))
                        .foregroundStyle(NETRTheme.text)
                    HStack(spacing: 8) {
                        Text(player.position)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(NETRTheme.neonGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(NETRTheme.neonGreen.opacity(0.12), in: .rect(cornerRadius: 6))

                        if let netr = player.currentNetr {
                            Text(String(format: "%.1f NETR", netr))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(NETRTheme.subtext)
                        }

                        if let vibe = player.currentVibe {
                            VibeDecalView(vibe: vibe, size: .small)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)

            HStack(spacing: 0) {
                ForEach(RateViewModel.RatingTab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.activeTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .black))
                                .tracking(1.5)
                                .foregroundStyle(
                                    viewModel.activeTab == tab
                                    ? NETRTheme.neonGreen
                                    : NETRTheme.subtext
                                )
                            Rectangle()
                                .fill(
                                    viewModel.activeTab == tab
                                    ? NETRTheme.neonGreen
                                    : Color.clear
                                )
                                .frame(height: 2)
                                .animation(.spring(), value: viewModel.activeTab)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }
            }
            .background(NETRTheme.surface)

            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.activeTab == .skill {
                        ForEach(skillCategories) { cat in
                            RatingCategoryCard(
                                icon: cat.icon,
                                label: cat.label,
                                description: cat.description,
                                labels: peerRatingLabels,
                                selectedValue: viewModel.skillValue(for: cat.id, playerIndex: playerIndex),
                                accentColor: NETRTheme.neonGreen
                            ) { value in
                                viewModel.setSkillRating(
                                    playerIndex: playerIndex,
                                    key: cat.id,
                                    value: value
                                )
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            Text("Rate the energy, not the skill.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NETRTheme.subtext)
                            Spacer()
                            if let vibe = player.currentVibe {
                                VibeDecalView(vibe: vibe, size: .medium)
                            }
                        }

                        ForEach(vibeCategories) { cat in
                            RatingCategoryCard(
                                icon: cat.icon,
                                label: cat.label,
                                description: cat.description,
                                labels: vibeRatingLabels,
                                selectedValue: viewModel.vibeValue(for: cat.id, playerIndex: playerIndex),
                                accentColor: viewModel.vibeAccentColor(playerIndex: playerIndex)
                            ) { value in
                                viewModel.setVibeRating(
                                    playerIndex: playerIndex,
                                    key: cat.id,
                                    value: value
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(NETRTheme.border)
                    .frame(height: 0.5)

                Button {
                    Task {
                        await viewModel.submitRating(for: playerIndex)
                        onDismiss()
                    }
                } label: {
                    HStack {
                        if viewModel.isSubmitting {
                            ProgressView().tint(NETRTheme.background)
                        } else {
                            Text("SUBMIT RATING")
                                .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                                .tracking(1.5)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundStyle(NETRTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(PressButtonStyle())
                .disabled(viewModel.isSubmitting)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .sensoryFeedback(.success, trigger: viewModel.isSubmitting)
            }
            .background(NETRTheme.background)
        }
    }
}

struct RatePlayerAvatar: View {
    let name: String
    let avatarUrl: String?
    let size: CGFloat

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        if let avatarUrl, let url = URL(string: avatarUrl) {
            NETRTheme.card
                .frame(width: size, height: size)
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
            Text(initials)
                .font(.system(size: size * 0.32, weight: .bold))
                .foregroundStyle(NETRTheme.neonGreen)
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
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(selectedValue != nil ? accentColor : NETRTheme.subtext)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(NETRTheme.text)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            onSelect(value)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(
                                    (selectedValue ?? 0) >= value
                                    ? accentColor
                                    : NETRTheme.muted
                                )
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Text("\(value)")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundStyle(
                                            (selectedValue ?? 0) >= value
                                            ? NETRTheme.background
                                            : NETRTheme.subtext
                                        )
                                }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            if let val = selectedValue, let labelText = labels[val] {
                Text(labelText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.10), in: .rect(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(16)
        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    selectedValue != nil
                    ? accentColor.opacity(0.25)
                    : NETRTheme.border,
                    lineWidth: 1
                )
        )
    }
}

struct HowItWorksRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.neonGreen)
                .frame(width: 28, height: 28)
                .background(NETRTheme.neonGreen.opacity(0.1), in: Circle())

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.subtext)

            Spacer()
        }
    }
}

struct RatingCompleteView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(NETRTheme.neonGreen)
                .neonGlow(radius: 16)
            Text("RATINGS IN")
                .font(NETRTheme.headingFont(size: .title))
                .foregroundStyle(NETRTheme.neonGreen)
            Text("Your ratings help build real reps.\nThe court remembers.")
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}
