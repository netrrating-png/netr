import SwiftUI

struct DailyGameView: View {

    @State private var viewModel = DailyGameViewModel()
    @Bindable var dmViewModel: DMViewModel
    @FocusState private var searchFocused: Bool
    @State private var showStats: Bool = false

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if viewModel.isLoading && viewModel.todaysPuzzle == nil {
                    loadingState
                } else if let msg = viewModel.errorMessage, viewModel.todaysPuzzle == nil {
                    errorState(message: msg)
                } else if viewModel.todaysPuzzle != nil {
                    gameContent
                }

                Spacer(minLength: 0)
            }
        }
        .task {
            if viewModel.todaysPuzzle == nil {
                await viewModel.loadTodaysGame()
            }
        }
        .sheet(isPresented: $showStats) {
            statsSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("DAILY")
                    .font(NETRTheme.headingFont(size: .title2))
                    .foregroundStyle(NETRTheme.text)
                Text("Guess today's mystery NBA player")
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
            }
            Spacer()
            Button {
                showStats = true
            } label: {
                LucideIcon("bar-chart-3", size: 18)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
            }
            DMHeaderButton(dmViewModel: dmViewModel)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Loading / Error

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(NETRTheme.neonGreen)
            Text("Loading today's puzzle…")
                .font(.system(size: 13))
                .foregroundStyle(NETRTheme.subtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            LucideIcon("triangle-alert", size: 32)
                .foregroundStyle(NETRTheme.subtext)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NETRTheme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await viewModel.loadTodaysGame() }
            } label: {
                Text("Retry")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(NETRTheme.neonGreen, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Game content

    @ViewBuilder
    private var gameContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                guessCounter
                hintsSection

                if !viewModel.guesses.isEmpty {
                    previousGuessesSection
                }

                if viewModel.isGameOver {
                    resultCard
                } else {
                    guessInput
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120) // room for tab bar
        }
    }

    // MARK: - Guess counter dots

    private var guessCounter: some View {
        HStack(spacing: 6) {
            ForEach(0..<DailyGameViewModel.maxGuesses, id: \.self) { idx in
                Circle()
                    .fill(color(for: idx))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(NETRTheme.border, lineWidth: 0.5)
                    )
            }
            Spacer()
            Text("\(viewModel.remainingGuesses) \(viewModel.remainingGuesses == 1 ? "guess" : "guesses") left")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NETRTheme.subtext)
                .monospacedDigit()
        }
        .padding(.top, 4)
    }

    private func color(for index: Int) -> Color {
        guard index < viewModel.guesses.count else { return NETRTheme.muted }
        return viewModel.guesses[index].isCorrect ? NETRTheme.neonGreen : NETRTheme.subtext.opacity(0.6)
    }

    // MARK: - Hints section

    private var hintsSection: some View {
        VStack(spacing: 10) {
            ForEach(HintStage.allCases, id: \.rawValue) { stage in
                hintCard(stage: stage, revealed: viewModel.revealedHints.contains(stage))
            }
        }
    }

    private func hintCard(stage: HintStage, revealed: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(revealed ? NETRTheme.neonGreen.opacity(0.15) : NETRTheme.muted)
                    .frame(width: 32, height: 32)
                Text("\(stage.rawValue + 1)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(revealed ? NETRTheme.neonGreen : NETRTheme.subtext)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stage.title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(NETRTheme.subtext)

                if revealed, let puzzle = viewModel.todaysPuzzle {
                    Text(puzzle.player.hintText(for: stage))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NETRTheme.text)
                        .lineLimit(2)
                } else {
                    Text(stage == HintStage.allCases.first ? "Take a guess to reveal" : "Locked")
                        .font(.system(size: 13))
                        .foregroundStyle(NETRTheme.subtext.opacity(0.6))
                        .italic()
                }
            }
            Spacer(minLength: 0)

            if !revealed {
                LucideIcon("lock", size: 14)
                    .foregroundStyle(NETRTheme.subtext.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(NETRTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(revealed ? NETRTheme.neonGreen.opacity(0.3) : NETRTheme.border, lineWidth: 1)
                )
        )
        .animation(.easeOut(duration: 0.3), value: revealed)
    }

    // MARK: - Previous guesses

    private var previousGuessesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR GUESSES")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(NETRTheme.subtext)

            VStack(spacing: 6) {
                ForEach(viewModel.guesses) { guess in
                    HStack(spacing: 10) {
                        LucideIcon(guess.isCorrect ? "check" : "x", size: 14)
                            .foregroundStyle(guess.isCorrect ? NETRTheme.neonGreen : NETRTheme.subtext)

                        Text(guess.player.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NETRTheme.text)
                            .strikethrough(!guess.isCorrect, color: NETRTheme.subtext.opacity(0.6))

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(guess.isCorrect ? NETRTheme.neonGreen.opacity(0.1) : NETRTheme.surface)
                    )
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Guess input

    private var guessInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LucideIcon("search", size: 14)
                    .foregroundStyle(NETRTheme.subtext)

                TextField("Type a player's name…", text: $viewModel.searchQuery)
                    .font(.system(size: 14))
                    .foregroundStyle(NETRTheme.text)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        LucideIcon("x", size: 12)
                            .foregroundStyle(NETRTheme.subtext)
                            .frame(width: 20, height: 20)
                            .background(NETRTheme.muted, in: Circle())
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(NETRTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(searchFocused ? NETRTheme.neonGreen.opacity(0.5) : NETRTheme.border, lineWidth: 1)
                    )
            )

            if !viewModel.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { player in
                        Button {
                            viewModel.submitGuess(player)
                            searchFocused = false
                        } label: {
                            HStack {
                                Text(player.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(NETRTheme.text)
                                Spacer()
                                LucideIcon("chevron-right", size: 12)
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if player.id != viewModel.searchResults.last?.id {
                            Divider().background(NETRTheme.border)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(NETRTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(NETRTheme.border, lineWidth: 1)
                        )
                )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Result card

    @ViewBuilder
    private var resultCard: some View {
        if case .won(let count) = viewModel.status {
            wonCard(guessCount: count)
        } else if case .lost = viewModel.status {
            lostCard
        }
    }

    private func wonCard(guessCount: Int) -> some View {
        VStack(spacing: 10) {
            LucideIcon("trophy", size: 28)
                .foregroundStyle(NETRTheme.neonGreen)
            Text("You got it!")
                .font(NETRTheme.headingFont(size: .title3))
                .foregroundStyle(NETRTheme.text)
            Text("Solved in \(guessCount) \(guessCount == 1 ? "guess" : "guesses")")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NETRTheme.subtext)
            answerReveal
            countdownToNext
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(NETRTheme.neonGreen.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(NETRTheme.neonGreen.opacity(0.4), lineWidth: 1)
                )
        )
        .padding(.top, 12)
    }

    private var lostCard: some View {
        VStack(spacing: 10) {
            LucideIcon("x-circle", size: 28)
                .foregroundStyle(NETRTheme.subtext)
            Text("Out of guesses")
                .font(NETRTheme.headingFont(size: .title3))
                .foregroundStyle(NETRTheme.text)
            Text("Try again tomorrow")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NETRTheme.subtext)
            answerReveal
            countdownToNext
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(NETRTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(NETRTheme.border, lineWidth: 1)
                )
        )
        .padding(.top, 12)
    }

    private var answerReveal: some View {
        VStack(spacing: 4) {
            Text("TODAY'S ANSWER")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(NETRTheme.subtext)
            Text(viewModel.todaysPuzzle?.player.name ?? "—")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(NETRTheme.text)
        }
        .padding(.top, 6)
    }

    private var countdownToNext: some View {
        Text("Next puzzle at UTC midnight")
            .font(.system(size: 11))
            .foregroundStyle(NETRTheme.subtext.opacity(0.7))
            .padding(.top, 4)
    }

    // MARK: - Stats sheet

    private var statsSheet: some View {
        VStack(spacing: 20) {
            Text("YOUR STATS")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.top, 20)

            HStack(spacing: 24) {
                statTile(value: "\(viewModel.stats.totalPlayed)", label: "Played")
                statTile(value: "\(viewModel.stats.winPercent)%", label: "Win %")
                statTile(value: "\(viewModel.stats.currentStreak)", label: "Streak")
                statTile(value: "\(viewModel.stats.maxStreak)", label: "Max")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("GUESS DISTRIBUTION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(NETRTheme.subtext)

                ForEach(1...DailyGameViewModel.maxGuesses, id: \.self) { n in
                    distributionRow(guessCount: n)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(NETRTheme.text)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NETRTheme.subtext)
        }
    }

    private func distributionRow(guessCount: Int) -> some View {
        let count = viewModel.stats.guessDistribution[guessCount] ?? 0
        let maxCount = max(1, viewModel.stats.guessDistribution.values.max() ?? 1)
        let ratio = CGFloat(count) / CGFloat(maxCount)

        return HStack(spacing: 8) {
            Text("\(guessCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .frame(width: 14)

            GeometryReader { geo in
                let filledWidth = max(24, geo.size.width * ratio)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NETRTheme.muted.opacity(0.3))
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(NETRTheme.neonGreen)
                            .frame(width: filledWidth)
                        Spacer(minLength: 0)
                    }
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.leading, 8)
                }
            }
            .frame(height: 20)
        }
    }
}
