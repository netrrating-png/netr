import SwiftUI

/// Content-only view for the NBA Connections game.
/// The outer ZStack, background, header, and mode selector are
/// provided by DailyGameView — this view just supplies the game content.
struct ConnectionsGameView: View {

    /// Injected from DailyGameView so the ViewModel persists when switching between game modes.
    var viewModel: ConnectionsGameViewModel
    @State private var shakingTileIds: Set<Int> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.puzzle == nil {
                loadingState
            } else if let msg = viewModel.errorMessage, viewModel.puzzle == nil {
                errorState(message: msg)
            } else if viewModel.puzzle != nil {
                gameContent
            } else {
                loadingState
            }
        }
        .task {
            if viewModel.puzzle == nil {
                await viewModel.loadTodaysPuzzle()
            }
        }
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
                Task { await viewModel.loadTodaysPuzzle() }
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

    // MARK: - Game Content

    @ViewBuilder
    private var gameContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    // Solved group rows (appear at top as groups are solved)
                    if !viewModel.solvedGroups.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(viewModel.solvedGroups, id: \.label) { group in
                                solvedGroupRow(group)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.solvedGroups.count)
                    }

                    // Unsolved tile grid
                    if !viewModel.unsolvedTiles.isEmpty {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(viewModel.unsolvedTiles) { tile in
                                playerTile(tile)
                            }
                        }
                    }

                    // Result card
                    if viewModel.isGameOver {
                        resultCard
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isGameOver)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 130)
            }

            // Fixed bottom controls
            VStack(spacing: 0) {
                Divider().background(NETRTheme.border)
                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 60) // tab bar clearance
            }
            .background(NETRTheme.background)
        }
    }

    // MARK: - Player Tile

    private func playerTile(_ tile: ConnectionsTile) -> some View {
        let isSelected = viewModel.selectedTileIds.contains(tile.id)
        let isShaking = shakingTileIds.contains(tile.id)

        return Button {
            guard !viewModel.isGameOver else { return }
            viewModel.toggleTile(id: tile.id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                AsyncImage(url: URL(string: tile.headshotUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        ZStack {
                            Circle().fill(NETRTheme.muted)
                            Text(String(tile.playerName.prefix(1)))
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    @unknown default:
                        Color(NETRTheme.muted)
                    }
                }
                .frame(width: 62, height: 62)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? NETRTheme.neonGreen : NETRTheme.border,
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )

                Text(tile.playerName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? NETRTheme.neonGreen : NETRTheme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .frame(height: 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? NETRTheme.neonGreen.opacity(0.1) : NETRTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? NETRTheme.neonGreen.opacity(0.6) : NETRTheme.border,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .offset(x: isShaking ? 5 : 0)
        .animation(
            isShaking
                ? Animation.easeInOut(duration: 0.07).repeatCount(5, autoreverses: true)
                : .default,
            value: isShaking
        )
    }

    // MARK: - Solved Group Row

    private func solvedGroupRow(_ group: ConnectionsGroup) -> some View {
        let color = Color(hex: group.colorHex)
        return VStack(spacing: 8) {
            Text(group.label.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Color.black)

            HStack(spacing: 12) {
                ForEach(Array(zip(group.playerNames, group.headshotUrls)), id: \.0) { name, urlStr in
                    VStack(spacing: 4) {
                        AsyncImage(url: URL(string: urlStr)) { phase in
                            if case .success(let img) = phase {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Circle().fill(color.opacity(0.4))
                            }
                        }
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())

                        Text(name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(color, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            mistakeIndicator
            submitButton
        }
    }

    private var mistakeIndicator: some View {
        HStack(spacing: 6) {
            Text("MISTAKES")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(NETRTheme.subtext)

            HStack(spacing: 6) {
                ForEach(0..<ConnectionsGameViewModel.maxMistakes, id: \.self) { idx in
                    Circle()
                        .fill(idx < viewModel.state.mistakeCount ? NETRTheme.red : NETRTheme.muted)
                        .frame(width: 10, height: 10)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.state.mistakeCount)
                }
            }
        }
    }

    private var submitButton: some View {
        Button {
            triggerSubmit()
        } label: {
            Text("SUBMIT")
                .font(.system(size: 15, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(viewModel.canSubmit ? Color.black : NETRTheme.subtext)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(viewModel.canSubmit ? NETRTheme.neonGreen : NETRTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    viewModel.canSubmit ? NETRTheme.neonGreen.opacity(0.6) : NETRTheme.border,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .disabled(!viewModel.canSubmit)
        .animation(.easeInOut(duration: 0.15), value: viewModel.canSubmit)
    }

    // MARK: - Submit Action

    private func triggerSubmit() {
        let submittedIds = viewModel.selectedTileIds  // capture before submitGroup() clears them
        let wasCorrect = viewModel.submitGroup()
        if !wasCorrect {
            shakingTileIds = submittedIds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakingTileIds = []
            }
        }
    }

    // MARK: - Result Card

    private var resultCard: some View {
        let won = viewModel.state.status == .won
        let accentColor = won ? NETRTheme.neonGreen : NETRTheme.red

        return VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text(won ? "🏀" : "💔")
                    .font(.system(size: 40))
                Text(won ? "YOU GOT IT!" : "BETTER LUCK TOMORROW")
                    .font(NETRTheme.headingFont(size: .title2))
                    .foregroundStyle(accentColor)
                    .neonGlow(accentColor, radius: 8)
                Text("\(viewModel.state.mistakeCount) mistake\(viewModel.state.mistakeCount == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NETRTheme.subtext)
            }

            HStack(spacing: 12) {
                statPill(value: "\(viewModel.stats.currentStreak)", label: "STREAK")
                statPill(value: "\(viewModel.stats.maxStreak)", label: "BEST")
                statPill(value: "\(viewModel.stats.winPercent)%", label: "WIN %")
            }

            ShareLink(item: shareText) {
                Label("SHARE RESULT", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(NETRTheme.neonGreen, in: Capsule())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(NETRTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accentColor.opacity(0.4), lineWidth: 1.5)
                )
        )
        .shadow(color: accentColor.opacity(0.15), radius: 20)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(NETRTheme.text)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(NETRTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(NETRTheme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
    }

    private var shareText: String {
        guard let puzzle = viewModel.puzzle else { return "" }
        let emojiForDifficulty: [Int: String] = [1: "🟨", 2: "🟩", 3: "🟦", 4: "🟪"]
        let rows = puzzle.categories.enumerated().map { idx, group -> String in
            let emoji = emojiForDifficulty[group.difficulty] ?? "⬜️"
            return viewModel.solvedGroupIndices.contains(idx) ? emoji : "⬛️"
        }
        return """
        NETR Connections \(puzzle.puzzleDate)
        \(rows.joined(separator: ""))
        Mistakes: \(viewModel.state.mistakeCount)
        \(viewModel.state.status == .won ? "Solved! 🏀" : "Better luck tomorrow!")
        """
    }
}
