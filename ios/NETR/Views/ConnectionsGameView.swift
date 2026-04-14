import SwiftUI

/// NYT Connections-style game with NBA players. 4×4 grid, 4 hidden groups of 4,
/// 4 mistakes allowed. Tap up to 4 players and submit. Solved groups collapse
/// to a colored row at the top. Difficulty colors come from NETRTheme so this
/// reuses the same palette as the rest of the app.
struct ConnectionsGameView: View {

    @State private var viewModel = ConnectionsGameViewModel()
    @Environment(\.dismiss) private var dismiss

    private let gridSpacing: CGFloat = 6

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            RadialGradient(
                colors: [NETRTheme.neonGreen.opacity(0.08), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header

                if viewModel.isLoading && viewModel.puzzle == nil {
                    Spacer()
                    ProgressView()
                        .tint(NETRTheme.neonGreen)
                        .scaleEffect(1.2)
                    Spacer()
                } else if let msg = viewModel.errorMessage, viewModel.puzzle == nil {
                    Spacer()
                    Text(msg)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(NETRTheme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                } else if viewModel.puzzle != nil {
                    gameContent
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.puzzle == nil { await viewModel.loadTodaysGame() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { dismiss() } label: {
                LucideIcon("chevron-left", size: 20)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 38, height: 38)
                    .background(NETRTheme.card, in: Circle())
                    .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("CONNECTIONS")
                    .font(NETRTheme.headingFont(size: .title2))
                    .foregroundStyle(NETRTheme.text)
                    .neonGlow(NETRTheme.neonGreen, radius: 5)
                Text("Find 4 groups of 4 NBA players")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NETRTheme.subtext)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: Game content

    private var gameContent: some View {
        VStack(spacing: 14) {
            solvedRows
            if viewModel.status == .playing || !viewModel.boardOrder.isEmpty {
                boardGrid
            }
            feedbackBar
            mistakesRow
            if viewModel.status == .playing {
                actionRow
            } else {
                Spacer(minLength: 8)
                endGameCTA
            }
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 14)
    }

    // MARK: Solved rows

    @ViewBuilder
    private var solvedRows: some View {
        if !viewModel.solvedGroups.isEmpty {
            VStack(spacing: 6) {
                ForEach(viewModel.solvedGroups) { g in
                    solvedRowView(g)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: viewModel.solvedGroups.count)
        }
    }

    private func solvedRowView(_ g: ConnectionsGroup) -> some View {
        let color = g.difficulty.color
        let names: [String] = g.playerIds.compactMap { viewModel.puzzle?.players[$0]?.name }
        return VStack(alignment: .center, spacing: 4) {
            Text(g.label.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.black)
                .tracking(0.5)
            Text(names.joined(separator: ", "))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(color, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Board grid

    private var boardGrid: some View {
        GeometryReader { proxy in
            let cols = 4
            let totalSpacing = gridSpacing * CGFloat(cols - 1)
            let tileW = (proxy.size.width - totalSpacing) / CGFloat(cols)
            let tileH = max(96, tileW * 1.30)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: cols),
                spacing: gridSpacing
            ) {
                ForEach(viewModel.boardOrder, id: \.self) { id in
                    if let player = viewModel.puzzle?.players[id] {
                        playerTile(player, size: CGSize(width: tileW, height: tileH))
                            .onTapGesture { viewModel.toggle(id) }
                    }
                }
            }
        }
        .frame(height: boardHeight)
    }

    private var boardHeight: CGFloat {
        // Approximate 4-row height; when rows are solved and removed the grid shrinks.
        let rows = max(1, Int(ceil(Double(viewModel.boardOrder.count) / 4.0)))
        let tileH: CGFloat = 108
        return CGFloat(rows) * tileH + CGFloat(max(0, rows - 1)) * gridSpacing
    }

    private func playerTile(_ p: ConnectionsPlayer, size: CGSize) -> some View {
        let isSelected = viewModel.selected.contains(p.id)
        let url = URL(string: p.headshotUrl ?? "")
            ?? URL(string: "https://cdn.nba.com/headshots/nba/latest/1040x760/\(p.id).png")
        return VStack(spacing: 4) {
            ZStack {
                // Consistent white circle behind every photo so NBA-CDN (white bg)
                // and BBR (transparent bg) headshots look identical.
                Circle().fill(Color.white)

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                    default:
                        ZStack {
                            Circle().fill(NETRTheme.muted)
                            Text(initials(p.name))
                                .font(.system(size: size.height * 0.22, weight: .heavy))
                                .foregroundStyle(NETRTheme.text)
                        }
                    }
                }
            }
            .frame(width: size.height * 0.62, height: size.height * 0.62)
            .clipShape(Circle())

            Text(p.name)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isSelected ? .black : NETRTheme.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 3)
        }
        .frame(width: size.width, height: size.height)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? NETRTheme.neonGreen : NETRTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? NETRTheme.neonGreen : NETRTheme.border, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    /// First+last initials for the fallback avatar.
    private func initials(_ full: String) -> String {
        let parts = full.split(separator: " ").filter {
            !["Jr.", "Sr.", "II", "III", "IV"].contains(String($0))
        }
        let first = parts.first?.first.map { String($0) } ?? ""
        let last  = parts.count > 1 ? (parts.last?.first.map { String($0) } ?? "") : ""
        return (first + last).uppercased()
    }

    // MARK: Feedback + mistakes

    @ViewBuilder
    private var feedbackBar: some View {
        if let f = viewModel.lastFeedback {
            Text(feedbackText(for: f))
                .font(.system(size: 12, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(feedbackColor(for: f))
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(feedbackColor(for: f).opacity(0.15),
                            in: Capsule())
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            Color.clear.frame(height: 2)
        }
    }

    private func feedbackText(for f: ConnectionsGuessFeedback) -> String {
        switch f {
        case .correct: return "NICE!"
        case .oneAway: return "ONE AWAY"
        case .wrong:   return "NOPE"
        }
    }

    private func feedbackColor(for f: ConnectionsGuessFeedback) -> Color {
        switch f {
        case .correct: return NETRTheme.neonGreen
        case .oneAway: return NETRTheme.gold
        case .wrong:   return NETRTheme.red
        }
    }

    private var mistakesRow: some View {
        HStack(spacing: 8) {
            Text("Mistakes remaining:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NETRTheme.subtext)
            HStack(spacing: 6) {
                ForEach(0 ..< ConnectionsGameViewModel.maxMistakes, id: \.self) { i in
                    Circle()
                        .fill(i < viewModel.mistakesRemaining ? NETRTheme.neonGreen : NETRTheme.muted)
                        .frame(width: 10, height: 10)
                }
            }
            Spacer()
        }
    }

    // MARK: Action row

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.shuffle()
            } label: {
                Text("SHUFFLE")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(NETRTheme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(NETRTheme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.border, lineWidth: 1))
            }
            Button {
                viewModel.deselectAll()
            } label: {
                Text("DESELECT")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(NETRTheme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(NETRTheme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.border, lineWidth: 1))
            }
            .disabled(viewModel.selected.isEmpty)
            .opacity(viewModel.selected.isEmpty ? 0.4 : 1)

            Button {
                viewModel.submit()
            } label: {
                Text("SUBMIT")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(viewModel.canSubmit ? .black : NETRTheme.subtext)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.canSubmit ? NETRTheme.neonGreen : NETRTheme.card,
                                in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(viewModel.canSubmit ? NETRTheme.neonGreen : NETRTheme.border, lineWidth: 1))
            }
            .disabled(!viewModel.canSubmit)
        }
    }

    // MARK: End game

    private var endGameCTA: some View {
        VStack(spacing: 10) {
            Text(viewModel.status == .won ? "YOU GOT IT" : "BETTER LUCK TOMORROW")
                .font(NETRTheme.headingFont(size: .title3))
                .foregroundStyle(viewModel.status == .won ? NETRTheme.neonGreen : NETRTheme.red)
            Text("Next puzzle " + CountdownFormatter.friendlyTimeToNextUTCDay())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NETRTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(NETRTheme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
    }
}

// MARK: - Countdown helper (shared with hub)

enum CountdownFormatter {
    /// Time until next UTC midnight. "4h 12m" or "59m" or "under a minute".
    static func friendlyTimeToNextUTCDay(now: Date = Date()) -> String {
        let (h, m, _) = timeToNextUTCDay(now: now)
        if h > 0 { return "in \(h)h \(m)m" }
        if m > 0 { return "in \(m)m" }
        return "in under a minute"
    }

    static func timeToNextUTCDay(now: Date = Date()) -> (Int, Int, Int) {
        var utc = Calendar(identifier: .iso8601)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let start = utc.startOfDay(for: now)
        guard let next = utc.date(byAdding: .day, value: 1, to: start) else { return (0, 0, 0) }
        let delta = Int(next.timeIntervalSince(now))
        let h = delta / 3600
        let m = (delta % 3600) / 60
        let s = delta % 60
        return (max(0, h), max(0, m), max(0, s))
    }
}
