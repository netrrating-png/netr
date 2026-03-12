import SwiftUI
import CoreLocation

struct CreateGameView: View {
    @Bindable var viewModel: CourtsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 0
    @State private var selectedCourt: Court?
    @State private var selectedFormat: GameFormat = .fiveVFive
    @State private var selectedSkill: SkillFilter = .any
    @State private var gameViewModel = GameViewModel()
    @State private var showLobby: Bool = false
    @State private var isCreating: Bool = false
    @State private var courtSearchQuery: String = ""
    @State private var courtSearchResults: [Court] = []
    @FocusState private var searchFocused: Bool

    // Scheduling
    @State private var scheduleForLater: Bool = false
    @State private var scheduledDate: Date = {
        let cal = Calendar.current
        let now = Date()
        let rounded = cal.date(bySetting: .minute, value: (cal.component(.minute, from: now) / 15 + 1) * 15, of: now) ?? now.addingTimeInterval(900)
        return rounded
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                if showLobby {
                    GameLobbyView(viewModel: gameViewModel, onDismiss: { dismiss() })
                } else {
                    VStack(spacing: 0) {
                        stepIndicator
                        stepContent
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(NETRTheme.muted.opacity(0.6))
                                .frame(width: 30, height: 30)
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }
                }
            }
        }
    }

    private var stepIndicator: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { idx in
                    Capsule()
                        .fill(idx == step ? NETRTheme.neonGreen : NETRTheme.muted)
                        .frame(width: idx == step ? 24 : 6, height: 4)
                        .animation(.spring(response: 0.3), value: step)
                }
            }
            Text(stepLabel)
                .font(NETRTheme.headingFont(size: .title3))
                .foregroundStyle(NETRTheme.text)
                .tracking(1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var stepLabel: String {
        switch step {
        case 0: return "SELECT COURT"
        case 1: return "SELECT FORMAT"
        case 2: return "SKILL LEVEL"
        default: return ""
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: courtSelection
        case 1: formatSelection
        case 2: skillSelection
        default: EmptyView()
        }
    }

    private var courtSelection: some View {
        VStack(spacing: 0) {
            courtSearchBar
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            if !courtSearchQuery.isEmpty {
                courtSearchResultsView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        courtSectionView(
                            title: "NEAREST TO YOU",
                            icon: "location.fill",
                            iconColor: NETRTheme.neonGreen,
                            courts: viewModel.nearestCourts,
                            emptyMessage: nearestEmptyMessage
                        )

                        courtSectionView(
                            title: "YOUR FAVORITES",
                            icon: "star.fill",
                            iconColor: NETRTheme.gold,
                            courts: viewModel.favoriteCourtsOnly,
                            emptyMessage: "Star a court to pin it here for quick access."
                        )

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundStyle(NETRTheme.muted)
                            Text("Search above to find any other court")
                                .font(.system(size: 13))
                                .foregroundStyle(NETRTheme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
        }
    }

    private var nearestEmptyMessage: String {
        if viewModel.userLocation == nil {
            return "Allow location access to see courts nearest to you."
        }
        return "Finding courts near you\u{2026}"
    }

    private var courtSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(courtSearchQuery.isEmpty ? NETRTheme.muted : NETRTheme.neonGreen)

            TextField("Search all courts\u{2026}", text: $courtSearchQuery)
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.text)
                .tint(NETRTheme.neonGreen)
                .focused($searchFocused)
                .onChange(of: courtSearchQuery) { _, newValue in
                    courtSearchResults = viewModel.searchCourts(query: newValue)
                }

            if !courtSearchQuery.isEmpty {
                Button {
                    courtSearchQuery = ""
                    courtSearchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.muted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(NETRTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    courtSearchQuery.isEmpty ? NETRTheme.border : NETRTheme.neonGreen.opacity(0.4),
                    lineWidth: 1
                )
        )
        .clipShape(.rect(cornerRadius: 12))
    }

    @ViewBuilder
    private func courtSectionView(
        title: String, icon: String, iconColor: Color,
        courts: [Court], emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1.3)
            }

            if courts.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: icon == "location.fill" ? "location.slash" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.muted)
                    Text(emptyMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(NETRTheme.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(NETRTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(courts.enumerated()), id: \.element.id) { idx, court in
                        courtRow(court: court)
                        if idx < courts.count - 1 {
                            Divider()
                                .background(NETRTheme.border)
                                .padding(.leading, 66)
                        }
                    }
                }
                .background(NETRTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private func courtRow(court: Court) -> some View {
        Button {
            withAnimation(.snappy) {
                selectedCourt = court
                step = 1
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(NETRTheme.neonGreen.opacity(court.verified ? 0.15 : 0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: "basketball.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(court.verified ? NETRTheme.neonGreen : NETRTheme.muted)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(court.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NETRTheme.text)
                            .lineLimit(1)
                        if court.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(NETRTheme.neonGreen)
                        }
                    }
                    HStack(spacing: 4) {
                        Text(court.neighborhood.isEmpty ? court.city : court.neighborhood)
                            .font(.system(size: 12))
                            .foregroundStyle(NETRTheme.subtext)
                        if viewModel.userLocation != nil {
                            Text("\u{00B7}")
                                .foregroundStyle(NETRTheme.muted)
                            Text(viewModel.distanceString(for: court))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }
                }

                Spacer()

                Button {
                    Task { await viewModel.toggleFavorite(courtId: court.id) }
                } label: {
                    Image(systemName: viewModel.isFavorite(court.id) ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(viewModel.isFavorite(court.id) ? NETRTheme.gold : NETRTheme.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .highPriorityGesture(TapGesture().onEnded {
                    Task { await viewModel.toggleFavorite(courtId: court.id) }
                })

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NETRTheme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
    }

    private var courtSearchResultsView: some View {
        Group {
            if courtSearchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(NETRTheme.muted)
                    Text("No courts found")
                        .font(NETRTheme.headingFont(size: .title3))
                        .foregroundStyle(NETRTheme.text)
                    Text("Try a different name or neighborhood.")
                        .font(.system(size: 13))
                        .foregroundStyle(NETRTheme.subtext)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(courtSearchResults.count) courts found")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NETRTheme.subtext)
                            .tracking(1.2)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(Array(courtSearchResults.enumerated()), id: \.element.id) { idx, court in
                                courtRow(court: court)
                                if idx < courtSearchResults.count - 1 {
                                    Divider()
                                        .background(NETRTheme.border)
                                        .padding(.leading, 66)
                                }
                            }
                        }
                        .background(NETRTheme.card)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
                        .clipShape(.rect(cornerRadius: 14))
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var formatSelection: some View {
        VStack(spacing: 24) {
            if let court = selectedCourt {
                Text(court.name)
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
            }

            VStack(spacing: 12) {
                ForEach(GameFormat.allCases) { format in
                    Button {
                        withAnimation(.snappy) {
                            selectedFormat = format
                            step = 2
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.rawValue)
                                    .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                                    .foregroundStyle(NETRTheme.text)
                                Text("Max \(format.maxPlayers) players")
                                    .font(.caption)
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .padding(16)
                        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private var skillSelection: some View {
        VStack(spacing: 24) {
            Text("Filter who can join")
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)

            VStack(spacing: 8) {
                ForEach(SkillFilter.allCases) { skill in
                    Button {
                        withAnimation(.snappy) { selectedSkill = skill }
                    } label: {
                        HStack {
                            Text(skill.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedSkill == skill ? NETRTheme.neonGreen : NETRTheme.text)
                            Spacer()
                            if selectedSkill == skill {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(NETRTheme.neonGreen)
                            }
                        }
                        .padding(14)
                        .background(
                            selectedSkill == skill ? NETRTheme.neonGreen.opacity(0.08) : NETRTheme.card,
                            in: .rect(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedSkill == skill ? NETRTheme.neonGreen : NETRTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
            .padding(.horizontal, 16)

            // Scheduling toggle
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(scheduleForLater ? NETRTheme.neonGreen : NETRTheme.muted)
                    Text("Schedule for later")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NETRTheme.text)
                    Spacer()
                    Toggle("", isOn: $scheduleForLater)
                        .tint(NETRTheme.neonGreen)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)

                if scheduleForLater {
                    DatePicker(
                        "Start time",
                        selection: $scheduledDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .tint(NETRTheme.neonGreen)
                    .colorScheme(.dark)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            .padding(.horizontal, 16)

            Spacer()

            Button {
                isCreating = true
                Task {
                    do {
                        _ = try await gameViewModel.createGame(
                            courtId: selectedCourt?.id,
                            format: selectedFormat.rawValue,
                            skillLevel: selectedSkill.rawValue,
                            scheduledAt: scheduleForLater ? scheduledDate : nil
                        )
                        isCreating = false
                        withAnimation(.snappy) { showLobby = true }
                    } catch {
                        isCreating = false
                        print("Create game error: \(error)")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isCreating {
                        ProgressView().tint(NETRTheme.background)
                    } else {
                        Text(scheduleForLater ? "SCHEDULE GAME" : "CREATE GAME")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                    }
                }
                .foregroundStyle(NETRTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressButtonStyle())
            .disabled(isCreating)
            .sensoryFeedback(.success, trigger: showLobby)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Game Lobby

struct GameLobbyView: View {
    @Bindable var viewModel: GameViewModel
    let onDismiss: () -> Void
    @State private var showRateSheet: Bool = false
    @State private var countdownTimer: Timer?
    @State private var timeRemaining: TimeInterval = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("GAME LOBBY")
                        .font(NETRTheme.headingFont(size: .title2))
                        .foregroundStyle(NETRTheme.text)
                    Text(viewModel.game?.format ?? "")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                }
                .padding(.top, 16)

                // Countdown for scheduled games
                if viewModel.isScheduled, let remaining = viewModel.timeUntilStart, remaining > 0 {
                    scheduledCountdownView(remaining: timeRemaining > 0 ? timeRemaining : remaining)
                }

                VStack(spacing: 8) {
                    Text("JOIN CODE")
                        .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                        .tracking(2)
                        .foregroundStyle(NETRTheme.subtext)

                    Text(viewModel.game?.joinCode ?? "------")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundStyle(NETRTheme.neonGreen)
                        .neonGlow(radius: 12)
                        .tracking(8)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(NETRTheme.card, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 16)

                Image(systemName: "qrcode")
                    .font(.system(size: 80))
                    .foregroundStyle(NETRTheme.subtext)
                    .frame(width: 120, height: 120)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 12))

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(viewModel.game?.format ?? "")
                            .font(.headline.weight(.black))
                            .foregroundStyle(NETRTheme.text)
                        Text("Format")
                            .font(.caption2)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                    Divider().frame(height: 30).background(NETRTheme.border)
                    VStack(spacing: 2) {
                        Text("\(viewModel.players.count)/\(viewModel.game?.maxPlayers ?? 0)")
                            .font(.headline.weight(.black))
                            .foregroundStyle(NETRTheme.text)
                        Text("Players")
                            .font(.caption2)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                    Divider().frame(height: 30).background(NETRTheme.border)
                    VStack(spacing: 2) {
                        Text(viewModel.game?.skillLevel ?? "")
                            .font(.headline.weight(.black))
                            .foregroundStyle(NETRTheme.text)
                        Text("Level")
                            .font(.caption2)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                .padding(12)
                .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                .padding(.horizontal, 16)

                if viewModel.game?.status == "active" {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(NETRTheme.neonGreen)
                            .frame(width: 8, height: 8)
                        Text("GAME IN PROGRESS")
                            .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                            .tracking(1.5)
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(NETRTheme.neonGreen.opacity(0.1), in: .capsule)
                }

                // Checkout reminder banner
                if viewModel.game?.status == "active" && viewModel.uncheckedOutCount > 0 && !viewModel.currentUserCheckedOut {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 16))
                            .foregroundStyle(NETRTheme.gold)
                        Text("Don't forget to check out when you're done to rate your teammates.")
                            .font(.system(size: 12))
                            .foregroundStyle(NETRTheme.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(NETRTheme.gold.opacity(0.08), in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.gold.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("PLAYERS")
                        .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(NETRTheme.subtext)

                    if viewModel.players.isEmpty {
                        HStack {
                            ProgressView().tint(NETRTheme.neonGreen)
                            Text("Waiting for players...")
                                .font(.subheadline)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(viewModel.players) { player in
                            LobbyPlayerRow(player: player, isHost: player.userId == viewModel.game?.hostId)
                        }
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 40)

                VStack(spacing: 12) {
                    if viewModel.game?.status == "waiting" {
                        Button {
                            Task { await viewModel.startGame() }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isStarting {
                                    ProgressView().tint(NETRTheme.background)
                                } else {
                                    Text("START GAME")
                                        .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                        .tracking(1)
                                }
                            }
                            .foregroundStyle(NETRTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                viewModel.canStart ? NETRTheme.neonGreen : NETRTheme.neonGreen.opacity(0.3),
                                in: .rect(cornerRadius: 14)
                            )
                        }
                        .buttonStyle(PressButtonStyle())
                        .disabled(!viewModel.canStart || viewModel.isStarting)
                    }

                    // Check Out button (active game, not yet checked out)
                    if viewModel.game?.status == "active" && !viewModel.currentUserCheckedOut {
                        Button {
                            Task { await viewModel.checkOut() }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isCheckingOut {
                                    ProgressView().tint(NETRTheme.background)
                                } else {
                                    Image(systemName: "arrow.right.square")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("CHECK OUT")
                                        .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                        .tracking(1)
                                }
                            }
                            .foregroundStyle(NETRTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(PressButtonStyle())
                        .disabled(viewModel.isCheckingOut)
                        .sensoryFeedback(.success, trigger: viewModel.currentUserCheckedOut)
                    }

                    // Already checked out indicator
                    if viewModel.currentUserCheckedOut {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(NETRTheme.neonGreen)
                            Text("You've checked out")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NETRTheme.neonGreen)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NETRTheme.neonGreen.opacity(0.08), in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1))
                    }

                    // End Game (host only)
                    if viewModel.isHost {
                        Button {
                            Task { await viewModel.endGame() }
                        } label: {
                            Text("END GAME")
                                .font(.system(.subheadline, design: .default, weight: .bold).width(.compressed))
                                .tracking(1)
                                .foregroundStyle(NETRTheme.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(NETRTheme.red.opacity(0.1), in: .rect(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.red.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .background(NETRTheme.background)
        .onAppear {
            if let gameId = viewModel.game?.id {
                Task { await viewModel.loadPlayers(gameId: gameId) }
            }
            startCountdownIfNeeded()
        }
        .onDisappear {
            countdownTimer?.invalidate()
            Task { await viewModel.unsubscribe() }
        }
        .onChange(of: viewModel.showRateScreen) { _, show in
            if show { showRateSheet = true }
        }
        .sheet(isPresented: $showRateSheet, onDismiss: { onDismiss() }) {
            if let _ = viewModel.completedGameId {
                RateView()
            }
        }
    }

    private func scheduledCountdownView(remaining: TimeInterval) -> some View {
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60

        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.gold)
                Text("SCHEDULED START")
                    .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(NETRTheme.gold)
            }

            if let date = viewModel.scheduledDate {
                Text(date, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
                + Text(" at ")
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
                + Text(date, style: .time)
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
            }

            HStack(spacing: 12) {
                countdownUnit(value: hours, label: "HR")
                Text(":")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(NETRTheme.gold.opacity(0.5))
                countdownUnit(value: minutes, label: "MIN")
                Text(":")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(NETRTheme.gold.opacity(0.5))
                countdownUnit(value: seconds, label: "SEC")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(NETRTheme.gold.opacity(0.06), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.gold.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(NETRTheme.gold)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1)
        }
    }

    private func startCountdownIfNeeded() {
        guard let remaining = viewModel.timeUntilStart, remaining > 0 else { return }
        timeRemaining = remaining
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let remaining = viewModel.timeUntilStart, remaining > 0 {
                timeRemaining = remaining
            } else {
                countdownTimer?.invalidate()
                timeRemaining = 0
            }
        }
    }
}

// MARK: - Lobby Player Row

struct LobbyPlayerRow: View {
    let player: LobbyPlayer
    var isHost: Bool = false

    private var displayName: String {
        player.profile.fullName ?? player.profile.username ?? "Player"
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let avatarUrl = player.profile.avatarUrl, let url = URL(string: avatarUrl) {
                NETRTheme.card
                    .frame(width: 40, height: 40)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                            }
                        }
                    }
                    .clipShape(Circle())
                    .overlay(Circle().stroke(
                        player.isCheckedOut ? NETRTheme.muted.opacity(0.3) : NETRTheme.neonGreen.opacity(0.3),
                        lineWidth: 1.5
                    ))
                    .opacity(player.isCheckedOut ? 0.5 : 1)
            } else {
                Text(initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(player.isCheckedOut ? NETRTheme.muted : NETRTheme.neonGreen)
                    .frame(width: 40, height: 40)
                    .background(NETRTheme.card, in: Circle())
                    .overlay(Circle().stroke(
                        player.isCheckedOut ? NETRTheme.muted.opacity(0.3) : NETRTheme.neonGreen.opacity(0.3),
                        lineWidth: 1.5
                    ))
                    .opacity(player.isCheckedOut ? 0.5 : 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(player.isCheckedOut ? NETRTheme.muted : NETRTheme.text)
                    if isHost {
                        Text("HOST")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(NETRTheme.neonGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(NETRTheme.neonGreen.opacity(0.12), in: .capsule)
                    }
                    if player.isCheckedOut {
                        Text("LEFT")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(NETRTheme.muted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(NETRTheme.muted.opacity(0.12), in: .capsule)
                    }
                }
                Text(player.profile.position ?? "PG")
                    .font(.caption)
                    .foregroundStyle(NETRTheme.subtext)
            }

            Spacer()

            HStack(spacing: 8) {
                if let vibe = player.profile.vibeScore {
                    VibeDecalView(vibe: vibe, size: .small)
                }

                if let r = player.profile.netrScore {
                    Text(String(format: "%.1f", r))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NETRTheme.ratingColor(for: r))
                }
            }
        }
        .padding(10)
        .background(NETRTheme.surface, in: .rect(cornerRadius: 10))
    }
}
