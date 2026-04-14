import Foundation
import SwiftUI
import Supabase

@Observable
@MainActor
final class ConnectionsGameViewModel {

    // MARK: - State

    var puzzle: ConnectionsPuzzle?
    var tiles: [ConnectionsTile] = []        // shuffled flat list of all 12 tiles
    var state: ConnectionsGameState = ConnectionsGameState()
    var stats: ConnectionsGameStats = ConnectionsGameViewModel.loadStats()

    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Constants

    static let maxMistakes = 4
    private static let statsKey = "NETR.connections.stats.v1"
    private static func progressKey(for date: String) -> String {
        "NETR.connections.progress.\(date)"
    }

    private let client = SupabaseManager.shared.client

    // MARK: - Derived

    var selectedTileIds: Set<Int> {
        Set(state.selectedTileIds)
    }

    var solvedGroupIndices: Set<Int> {
        Set(state.solvedGroupIndices)
    }

    var isGameOver: Bool {
        state.status != .playing
    }

    var canSubmit: Bool {
        !isGameOver && selectedTileIds.count == 3
    }

    /// Tiles not yet solved (eligible for selection).
    var unsolvedTiles: [ConnectionsTile] {
        tiles.filter { !solvedGroupIndices.contains($0.groupIndex) }
    }

    /// Groups that have been solved, in difficulty order (Yellow → Purple).
    var solvedGroups: [ConnectionsGroup] {
        guard let puzzle else { return [] }
        return state.solvedGroupIndices
            .compactMap { puzzle.categories[safe: $0] }
            .sorted { $0.difficulty < $1.difficulty }
    }

    // MARK: - Loading

    func loadTodaysPuzzle() async {
        isLoading = true
        errorMessage = nil

        do {
            let rows: [ConnectionsPuzzle] = try await client
                .from("nba_connections_today")
                .select()
                .limit(1)
                .execute()
                .value

            guard let loaded = rows.first else {
                errorMessage = "Today's puzzle isn't ready yet. Check back later."
                isLoading = false
                return
            }

            self.puzzle = loaded
            self.tiles = buildTiles(from: loaded)
            restoreProgress(for: loaded.puzzleDate)

            isLoading = false
        } catch {
            print("[NETR Connections] load error: \(error)")
            errorMessage = "Couldn't load today's Connections puzzle. Pull to retry."
            isLoading = false
        }
    }

    // MARK: - Gameplay

    func toggleTile(id: Int) {
        guard !isGameOver else { return }
        guard !solvedGroupIndices.contains(tiles[safe: id]?.groupIndex ?? -1) else { return }

        var selected = Set(state.selectedTileIds)
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count < 3 {
            selected.insert(id)
        }
        state.selectedTileIds = Array(selected).sorted()
        saveProgress()
    }

    /// Returns true if the submitted group was correct, false if wrong.
    @discardableResult
    func submitGroup() -> Bool {
        guard canSubmit, let puzzle else { return false }

        let selectedIds = selectedTileIds
        let groupIndices = selectedIds.compactMap { tiles[safe: $0]?.groupIndex }
        let allSameGroup = Set(groupIndices).count == 1

        if allSameGroup, let groupIndex = groupIndices.first {
            // Correct guess
            var newSolved = state.solvedGroupIndices
            newSolved.append(groupIndex)
            state.solvedGroupIndices = newSolved
            state.selectedTileIds = []
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            if newSolved.count == puzzle.categories.count {
                // All groups solved — win!
                state.status = .won
                recordResult(won: true, puzzleDate: puzzle.puzzleDate)
            }
            saveProgress()
            return true
        } else {
            // Wrong guess
            state.mistakeCount += 1
            state.selectedTileIds = []
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

            if state.mistakeCount >= Self.maxMistakes {
                state.status = .lost
                recordResult(won: false, puzzleDate: puzzle.puzzleDate)
                // Reveal all unsolved groups
                let allIndices = Array(0..<puzzle.categories.count)
                state.solvedGroupIndices = allIndices
            }
            saveProgress()
            return false
        }
    }

    // MARK: - Tile building

    private func buildTiles(from puzzle: ConnectionsPuzzle) -> [ConnectionsTile] {
        // Build a flat array of (groupIndex, playerName, headshotUrl) then shuffle
        var raw: [(groupIndex: Int, playerName: String, headshotUrl: String)] = []
        for (gi, group) in puzzle.categories.enumerated() {
            for (pi, name) in group.playerNames.enumerated() {
                let url = group.headshotUrls[safe: pi] ?? ""
                raw.append((gi, name, url))
            }
        }
        // Shuffle deterministically by puzzle date so everyone sees same order
        var rng = SeededRNG(seed: puzzleDateSeed(puzzle.puzzleDate))
        raw.shuffle(using: &rng)

        return raw.enumerated().map { idx, item in
            ConnectionsTile(
                id: idx,
                groupIndex: item.groupIndex,
                playerName: item.playerName,
                headshotUrl: item.headshotUrl
            )
        }
    }

    private func puzzleDateSeed(_ dateString: String) -> UInt64 {
        // Convert "2026-04-14" to a deterministic integer seed
        let stripped = dateString.replacingOccurrences(of: "-", with: "")
        return UInt64(stripped) ?? 20260414
    }

    // MARK: - Persistence (local progress + stats)

    private func saveProgress() {
        guard let puzzle else { return }
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.progressKey(for: puzzle.puzzleDate))
        }
    }

    private func restoreProgress(for date: String) {
        guard let data = UserDefaults.standard.data(forKey: Self.progressKey(for: date)),
              let saved = try? JSONDecoder().decode(ConnectionsGameState.self, from: data) else {
            return
        }
        self.state = saved
    }

    private func recordResult(won: Bool, puzzleDate: String) {
        guard stats.lastPlayedDate != puzzleDate else { return }

        var s = stats
        let wasConsecutive = (s.lastPlayedDate == previousDate(of: puzzleDate))
        s.totalPlayed += 1
        if won {
            s.totalWon += 1
            s.currentStreak = wasConsecutive ? s.currentStreak + 1 : 1
            s.maxStreak = max(s.maxStreak, s.currentStreak)
        } else {
            s.currentStreak = 0
        }
        s.lastPlayedDate = puzzleDate
        self.stats = s
        Self.saveStats(s)

        // Push result to Supabase (fire-and-forget; local stats are source of truth)
        let mistakes = state.mistakeCount
        Task {
            guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
            let payload = ConnectionsResultPayload(
                userId: userId,
                puzzleDate: puzzleDate,
                won: won,
                mistakes: mistakes
            )
            do {
                try await client
                    .from("nba_connections_results")
                    .insert(payload)
                    .execute()
            } catch {
                print("[NETR Connections] result upload failed: \(error)")
            }
        }
    }

    private func previousDate(of dateString: String) -> String? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let date = fmt.date(from: dateString),
              let prev = cal.date(byAdding: .day, value: -1, to: date) else {
            return nil
        }
        return fmt.string(from: prev)
    }

    private static func loadStats() -> ConnectionsGameStats {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let decoded = try? JSONDecoder().decode(ConnectionsGameStats.self, from: data) else {
            return ConnectionsGameStats()
        }
        return decoded
    }

    private static func saveStats(_ stats: ConnectionsGameStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }
}

// MARK: - Seeded RNG (deterministic shuffle)

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Safe subscript helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
