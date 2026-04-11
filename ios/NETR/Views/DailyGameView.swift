import SwiftUI

struct DailyGameView: View {

    @State private var viewModel = DailyGameViewModel()
    @Bindable var dmViewModel: DMViewModel
    @FocusState private var searchFocused: Bool
    @State private var showStats: Bool = false

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            // Subtle radial neon glow behind everything
            RadialGradient(
                colors: [NETRTheme.neonGreen.opacity(0.10), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

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
        .onChange(of: viewModel.isGameOver) { _, isOver in
            if isOver { searchFocused = false }
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DAILY")
                    .font(NETRTheme.headingFont(size: .largeTitle))
                    .foregroundStyle(NETRTheme.text)
                    .neonGlow(NETRTheme.neonGreen, radius: 6)
                Text("Guess today's mystery NBA player")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NETRTheme.subtext)
            }
            Spacer()
            HStack(spacing: 10) {
                Button {
                    showStats = true
                } label: {
                    LucideIcon("bar-chart-3", size: 18)
                        .foregroundStyle(NETRTheme.text)
                        .frame(width: 38, height: 38)
                        .background(NETRTheme.card, in: Circle())
                        .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
                }
                DMHeaderButton(dmViewModel: dmViewModel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: - Loading / Error

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(NETRTheme.neonGreen)
                .scaleEffect(1.2)
            Text("Loading today's puzzle…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NETRTheme.subtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 14) {
            LucideIcon("triangle-alert", size: 36)
                .foregroundStyle(NETRTheme.subtext)
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(NETRTheme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await viewModel.loadTodaysGame() }
            } label: {
                Text("RETRY")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(NETRTheme.neonGreen, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Game content

    @ViewBuilder
    private var gameContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard

                    if !viewModel.revealedHints.isEmpty {
                        revealedCluesSection
                    }

                    if !viewModel.isGameOver && hasMoreCluesToReveal {
                        nextClueTeaser
                    }

                    if !viewModel.guesses.isEmpty {
                        previousGuessesSection
                    }

                    if viewModel.isGameOver {
                        resultCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            if !viewModel.isGameOver {
                guessInput
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .background(NETRTheme.background)
            }
        }
    }

    // MARK: - Hero Card (Mystery Player + Progress)

    private var heroCard: some View {
        VStack(spacing: 18) {
            // Mystery silhouette (smaller to make room for letter board)
            ZStack {
                Circle()
                    .fill(NETRTheme.neonGreen.opacity(0.08))
                    .frame(width: 72, height: 72)
                Circle()
                    .stroke(NETRTheme.neonGreen.opacity(0.4), lineWidth: 2)
                    .frame(width: 72, height: 72)
                Text("?")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .neonGlow(NETRTheme.neonGreen, radius: 10)
            }
            .padding(.top, 6)

            Text("MYSTERY PLAYER")
                .font(.system(size: 11, weight: .heavy))
                .tracking(2.0)
                .foregroundStyle(NETRTheme.subtext)

            // Letter board — Wheel of Fortune style
            letterBoardView

            Text(bigGuessText)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(NETRTheme.text)
                .monospacedDigit()

            // Segmented guess track
            HStack(spacing: 6) {
                ForEach(0..<DailyGameViewModel.maxGuesses, id: \.self) { idx in
                    segmentPill(for: idx)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(NETRTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(NETRTheme.neonGreen.opacity(0.35), lineWidth: 1.5)
                )
        )
        .shadow(color: NETRTheme.neonGreen.opacity(0.18), radius: 20, x: 0, y: 0)
    }

    // MARK: - Letter Board (Wheel of Fortune)

    private var letterBoardView: some View {
        let answer = viewModel.todaysPuzzle?.player.name ?? ""
        let revealed = viewModel.revealedLetterIndices
        let isOver = viewModel.isGameOver
        let words = answer.split(separator: " ", omittingEmptySubsequences: false)
        let letterCount = answer.filter { $0 != " " }.count

        return VStack(spacing: 10) {
            ForEach(Array(words.enumerated()), id: \.offset) { wordIdx, word in
                HStack(spacing: 4) {
                    let startIndex = charOffset(for: wordIdx, in: words)
                    ForEach(Array(word.enumerated()), id: \.offset) { charIdx, character in
                        let globalIdx = startIndex + charIdx
                        let isRevealed = isOver || revealed.contains(globalIdx)
                        letterTile(
                            character: character,
                            isRevealed: isRevealed,
                            isCorrectReveal: isOver && !revealed.contains(globalIdx)
                        )
                    }
                }
            }

            if !isOver && !viewModel.guesses.isEmpty {
                Text("\(revealed.count)/\(letterCount) letters revealed")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NETRTheme.neonGreen.opacity(0.8))
            } else if !isOver {
                Text("\(letterCount) letters \u{2022} \(words.count) word\(words.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: revealed)
    }

    private func charOffset(for wordIndex: Int, in words: [Substring]) -> Int {
        var offset = 0
        for i in 0..<wordIndex {
            offset += words[i].count + 1
        }
        return offset
    }

    private var tileSize: CGFloat {
        let answer = viewModel.todaysPuzzle?.player.name ?? ""
        let longestWord = answer.split(separator: " ").map(\.count).max() ?? 6
        if longestWord > 12 { return 20 }
        if longestWord > 9 { return 24 }
        return 28
    }

    @ViewBuilder
    private func letterTile(character: Character, isRevealed: Bool, isCorrectReveal: Bool) -> some View {
        let size = tileSize
        let fontSize: CGFloat = size > 24 ? 18 : (size > 20 ? 14 : 12)
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isRevealed ? NETRTheme.neonGreen.opacity(0.15) : NETRTheme.muted.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isRevealed ? NETRTheme.neonGreen.opacity(0.6) : NETRTheme.border,
                            lineWidth: isRevealed ? 1.5 : 1
                        )
                )

            if isRevealed {
                Text(String(character).uppercased())
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .foregroundStyle(isCorrectReveal ? NETRTheme.text : NETRTheme.neonGreen)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size + 8)
        .shadow(
            color: isRevealed ? NETRTheme.neonGreen.opacity(0.3) : .clear,
            radius: 4
        )
    }

    private var bigGuessText: String {
        if case .won(let n) = viewModel.status {
            return "SOLVED IN \(n)"
        }
        if case .lost = viewModel.status {
            return "OUT OF GUESSES"
        }
        let n = viewModel.remainingGuesses
        return "\(n) \(n == 1 ? "GUESS" : "GUESSES") LEFT"
    }

    @ViewBuilder
    private func segmentPill(for index: Int) -> some View {
        let used = index < viewModel.guesses.count
        let isCorrect = used && viewModel.guesses[index].isCorrect

        RoundedRectangle(cornerRadius: 3)
            .fill(
                isCorrect
                    ? NETRTheme.neonGreen
                    : (used ? NETRTheme.subtext.opacity(0.55) : NETRTheme.muted.opacity(0.5))
            )
            .frame(height: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(
                        isCorrect ? NETRTheme.neonGreen : NETRTheme.border,
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isCorrect ? NETRTheme.neonGreen.opacity(0.6) : .clear,
                radius: 4
            )
    }

    // MARK: - Revealed Clues

    private var revealedCluesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                LucideIcon("lightbulb", size: 12)
                    .foregroundStyle(NETRTheme.neonGreen)
                Text("CLUES UNLOCKED")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(NETRTheme.subtext)
                Spacer()
                Text("\(viewModel.revealedHints.count)/\(HintStage.allCases.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(HintStage.allCases.filter { viewModel.revealedHints.contains($0) }, id: \.rawValue) { stage in
                    revealedClueCard(stage: stage)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: viewModel.revealedHints)
    }

    private func revealedClueCard(stage: HintStage) -> some View {
        HStack(spacing: 0) {
            // Left neon accent stripe
            Rectangle()
                .fill(NETRTheme.neonGreen)
                .frame(width: 4)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(NETRTheme.neonGreen.opacity(0.15))
                        .frame(width: 42, height: 42)
                    LucideIcon(icon(for: stage), size: 18)
                        .foregroundStyle(NETRTheme.neonGreen)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(stage.title.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(NETRTheme.subtext)

                    if let puzzle = viewModel.todaysPuzzle {
                        Text(puzzle.player.hintText(for: stage))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(NETRTheme.text)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                LucideIcon("check", size: 14)
                    .foregroundStyle(NETRTheme.neonGreen)
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(NETRTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func matchedLetterCount(guess: String) -> Int {
        guard let answer = viewModel.todaysPuzzle?.player.name else { return 0 }
        let a = Array(answer.lowercased())
        let g = Array(guess.lowercased())
        var count = 0
        for i in 0..<min(a.count, g.count) {
            if a[i] == g[i] && a[i] != " " { count += 1 }
        }
        return count
    }

    private func icon(for stage: HintStage) -> String {
        switch stage {
        case .retiredStatus: return "zap"
        case .yearsActive:   return "calendar"
        case .draftTeam:     return "star"
        case .allTeams:      return "users"
        case .funFact:       return "lightbulb"
        }
    }

    // MARK: - Next Clue Teaser

    private var hasMoreCluesToReveal: Bool {
        viewModel.revealedHints.count < HintStage.allCases.count
    }

    private var nextClueTeaser: some View {
        let nextIndex = viewModel.revealedHints.count
        let total = HintStage.allCases.count
        let isFirst = viewModel.guesses.isEmpty

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(NETRTheme.muted.opacity(0.4))
                    .frame(width: 38, height: 38)
                LucideIcon("lock", size: 15)
                    .foregroundStyle(NETRTheme.subtext)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("CLUE \(nextIndex + 1) OF \(total)")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(NETRTheme.subtext)
                Text(isFirst ? "Take your first guess to unlock" : "Guess again to unlock the next clue")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NETRTheme.subtext.opacity(0.8))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(NETRTheme.surface.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            NETRTheme.border,
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                )
        )
    }

    // MARK: - Previous guesses

    private var previousGuessesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                LucideIcon("x-circle", size: 12)
                    .foregroundStyle(NETRTheme.subtext)
                Text("YOUR GUESSES")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(NETRTheme.subtext)
                Spacer()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(viewModel.guesses) { guess in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill((guess.isCorrect ? NETRTheme.neonGreen : NETRTheme.subtext).opacity(0.15))
                                .frame(width: 32, height: 32)
                            LucideIcon(guess.isCorrect ? "check" : "x", size: 14)
                                .foregroundStyle(guess.isCorrect ? NETRTheme.neonGreen : NETRTheme.subtext)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(guess.player.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(NETRTheme.text)
                                .strikethrough(!guess.isCorrect, color: NETRTheme.subtext.opacity(0.5))

                            if !guess.isCorrect {
                                let matched = matchedLetterCount(guess: guess.player.name)
                                if matched > 0 {
                                    Text("\(matched) letter\(matched == 1 ? "" : "s") revealed")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(NETRTheme.neonGreen)
                                } else {
                                    Text("No matching positions")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(NETRTheme.subtext)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(guess.isCorrect ? NETRTheme.neonGreen.opacity(0.1) : NETRTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        guess.isCorrect ? NETRTheme.neonGreen.opacity(0.4) : NETRTheme.border,
                                        lineWidth: 1
                                    )
                            )
                    )
                }
            }
        }
    }

    // MARK: - Guess input

    @State private var guessError: String?

    private var guessInput: some View {
        VStack(spacing: 10) {
            if let error = guessError {
                Text(error)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NETRTheme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }

            HStack(spacing: 10) {
                TextField("", text: $viewModel.searchQuery, prompt: Text("Enter player name…").foregroundColor(NETRTheme.subtext.opacity(0.6)))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(NETRTheme.text)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.go)
                    .onSubmit { submitTypedGuess() }
                    .onChange(of: viewModel.searchQuery) { _, _ in
                        guessError = nil
                    }

                Button {
                    submitTypedGuess()
                } label: {
                    Text("GUESS")
                        .font(.system(size: 15, weight: .black))
                        .tracking(1)
                        .foregroundStyle(viewModel.searchQuery.isEmpty ? NETRTheme.muted : Color.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.searchQuery.isEmpty ? NETRTheme.card : NETRTheme.neonGreen,
                            in: .rect(cornerRadius: 12)
                        )
                }
                .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(NETRTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                searchFocused ? NETRTheme.neonGreen.opacity(0.6) : NETRTheme.border,
                                lineWidth: searchFocused ? 1.5 : 1
                            )
                    )
            )
        }
        .animation(.easeOut(duration: 0.2), value: guessError)
    }

    private func submitTypedGuess() {
        let query = viewModel.searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return }

        // Find matching player in the pool (case-insensitive)
        let guessedIds = Set(viewModel.guesses.map { $0.player.id })
        guard let match = viewModel.playerPool.first(where: {
            !guessedIds.contains($0.id) && $0.name.lowercased() == query
        }) else {
            // Check if it's a player they already guessed
            if viewModel.guesses.contains(where: { $0.player.name.lowercased() == query }) {
                guessError = "You already guessed that player."
            } else {
                guessError = "Player not found. Check the spelling."
            }
            return
        }

        // Validate against revealed letters
        let revealed = viewModel.revealedLetterIndices
        if let answer = viewModel.todaysPuzzle?.player.name {
            let answerChars = Array(answer.lowercased())
            let guessChars = Array(match.name.lowercased())
            for idx in revealed {
                if idx < answerChars.count && idx < guessChars.count {
                    if answerChars[idx] != guessChars[idx] {
                        guessError = "Doesn't match the revealed letters."
                        return
                    }
                }
            }
        }

        guessError = nil
        viewModel.submitGuess(match)
        viewModel.searchQuery = ""
        searchFocused = false
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
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(NETRTheme.neonGreen.opacity(0.18))
                    .frame(width: 72, height: 72)
                LucideIcon("trophy", size: 34)
                    .foregroundStyle(NETRTheme.neonGreen)
                    .neonGlow(NETRTheme.neonGreen, radius: 10)
            }

            VStack(spacing: 4) {
                Text("YOU GOT IT!")
                    .font(NETRTheme.headingFont(size: .title))
                    .foregroundStyle(NETRTheme.text)
                    .neonGlow(NETRTheme.neonGreen, radius: 6)
                Text("Solved in \(guessCount) \(guessCount == 1 ? "guess" : "guesses")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)
            }

            answerReveal
            shareButton
            Divider().background(NETRTheme.border).padding(.horizontal, 40)
            countdownToNext
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(NETRTheme.neonGreen.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(NETRTheme.neonGreen.opacity(0.5), lineWidth: 1.5)
                )
        )
        .shadow(color: NETRTheme.neonGreen.opacity(0.25), radius: 20)
        .padding(.top, 8)
    }

    private var lostCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(NETRTheme.muted.opacity(0.4))
                    .frame(width: 72, height: 72)
                LucideIcon("x-circle", size: 34)
                    .foregroundStyle(NETRTheme.subtext)
            }

            VStack(spacing: 4) {
                Text("OUT OF GUESSES")
                    .font(NETRTheme.headingFont(size: .title))
                    .foregroundStyle(NETRTheme.text)
                Text("Try again tomorrow")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)
            }

            answerReveal
            shareButton
            Divider().background(NETRTheme.border).padding(.horizontal, 40)
            countdownToNext
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(NETRTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(NETRTheme.border, lineWidth: 1)
                )
        )
        .padding(.top, 8)
    }

    // MARK: - Share

    private var shareText: String {
        let total = DailyGameViewModel.maxGuesses
        let dateLabel: String = {
            guard let puzzleDate = viewModel.todaysPuzzle?.puzzleDate else {
                let df = DateFormatter()
                df.dateFormat = "MMM d"
                return df.string(from: Date()).uppercased()
            }
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone(identifier: "UTC")
            guard let date = df.date(from: puzzleDate) else { return puzzleDate.uppercased() }
            df.dateFormat = "MMM d"
            return df.string(from: date).uppercased()
        }()

        let guessSquares = viewModel.guesses.map { $0.isCorrect ? "🟩" : "⬛" }.joined()
        let remaining = max(0, total - viewModel.guesses.count)
        let emptySquares = String(repeating: "⬜", count: remaining)
        let grid = guessSquares + emptySquares

        let cluesUsed = viewModel.revealedHints.count
        let clueText = cluesUsed > 0 ? "Used \(cluesUsed)/5 clues" : "No clues needed"

        let letterCount = viewModel.todaysPuzzle?.player.name.filter({ $0 != " " }).count ?? 0
        let wordCount = viewModel.todaysPuzzle?.player.name.split(separator: " ").count ?? 0
        let letterInfo = "\(letterCount) letters, \(wordCount) word\(wordCount == 1 ? "" : "s")"
        let revealedCount = viewModel.revealedLetterIndices.count

        if case .won(let count) = viewModel.status {
            return """
            NETR DAILY \u{1F3C0} — \(dateLabel)

            \(grid)

            Solved in \(count)/\(total) guesses
            \(letterInfo) \u{2022} \(revealedCount) letters revealed before solving
            \(clueText)

            Think you can beat me? \u{1F525}
            """
        }
        if case .lost = viewModel.status {
            return """
            NETR DAILY \u{1F3C0} — \(dateLabel)

            \(grid)

            Stumped \u{1F62D} \(total)/\(total)
            \(letterInfo) \u{2022} \(revealedCount)/\(letterCount) letters revealed
            Used all 5 clues

            Can you do better?
            """
        }
        return "NETR DAILY \u{1F3C0} — \(dateLabel)"
    }

    private var shareButton: some View {
        ShareLink(
            item: shareText,
            subject: Text("NETR Daily"),
            message: Text("Guess today's mystery NBA player")
        ) {
            HStack(spacing: 8) {
                LucideIcon("arrow-up-right", size: 14)
                Text("SHARE RESULT")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.3)
            }
            .foregroundStyle(Color.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(NETRTheme.neonGreen, in: Capsule())
            .shadow(color: NETRTheme.neonGreen.opacity(0.35), radius: 10)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    private var answerReveal: some View {
        VStack(spacing: 12) {
            if let url = viewModel.todaysPuzzle?.player.headshotUrl,
               let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(NETRTheme.neonGreen, lineWidth: 2))
                            .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 12)
                    default:
                        Circle()
                            .fill(NETRTheme.surface)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(String(viewModel.todaysPuzzle?.player.name.prefix(2) ?? "??").uppercased())
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundStyle(NETRTheme.neonGreen)
                            )
                    }
                }
            }

            Text("TODAY'S ANSWER")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(NETRTheme.subtext)
            Text(viewModel.todaysPuzzle?.player.name ?? "—")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(NETRTheme.text)
        }
        .padding(.top, 4)
    }

    private var countdownToNext: some View {
        HStack(spacing: 6) {
            LucideIcon("clock", size: 12)
                .foregroundStyle(NETRTheme.subtext.opacity(0.7))
            Text("Next puzzle at UTC midnight")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NETRTheme.subtext.opacity(0.7))
        }
    }

    // MARK: - Stats sheet

    private var statsSheet: some View {
        VStack(spacing: 22) {
            Text("YOUR STATS")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.top, 22)

            HStack(spacing: 24) {
                statTile(value: "\(viewModel.stats.totalPlayed)", label: "Played")
                statTile(value: "\(viewModel.stats.winPercent)%", label: "Win %")
                statTile(value: "\(viewModel.stats.currentStreak)", label: "Streak")
                statTile(value: "\(viewModel.stats.maxStreak)", label: "Max")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("GUESS DISTRIBUTION")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(NETRTheme.subtext)

                ForEach(1...4, id: \.self) { n in
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
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(NETRTheme.text)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NETRTheme.subtext)
        }
    }

    private func distributionRow(guessCount: Int) -> some View {
        let count = viewModel.stats.guessDistribution["\(guessCount)"] ?? 0
        let maxCount = max(1, viewModel.stats.guessDistribution.values.max() ?? 1)
        let ratio = CGFloat(count) / CGFloat(maxCount)

        return HStack(spacing: 10) {
            Text("\(guessCount)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(NETRTheme.subtext)
                .frame(width: 16)

            GeometryReader { geo in
                let filledWidth = max(28, geo.size.width * ratio)
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
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.black)
                        .padding(.leading, 8)
                }
            }
            .frame(height: 22)
        }
    }
}
