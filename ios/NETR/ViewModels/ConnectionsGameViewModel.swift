import Foundation
import SwiftUI
import Supabase
import PostgREST

// MARK: - Models

enum ConnectionsDifficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard, tricky

    /// Map to NETRTheme colors (see workflows/scrape_bbr_player_details.md for palette choice).
    var color: Color {
        switch self {
        case .easy:   return NETRTheme.gold
        case .medium: return NETRTheme.neonGreen
        case .hard:   return NETRTheme.blue
        case .tricky: return NETRTheme.purple
        }
    }

    /// For stable ordering when displaying solved rows (easy → tricky).
    var rank: Int {
        switch self {
        case .easy: return 0; case .medium: return 1
        case .hard: return 2; case .tricky: return 3
        }
    }
}

struct ConnectionsPlayer: Identifiable, Hashable, Sendable, Codable {
    let id: Int64
    let name: String
    let headshotUrl: String?
    let tier: String?

    enum CodingKeys: String, CodingKey {
        case id, name, tier
        case headshotUrl = "headshot_url"
    }
}

struct ConnectionsGroup: Identifiable, Sendable, Codable {
    let categoryId: Int64
    let label: String
    let difficulty: ConnectionsDifficulty
    let playerIds: [Int64]

    var id: Int64 { categoryId }

    enum CodingKeys: String, CodingKey {
        case categoryId  = "category_id"
        case label, difficulty
        case playerIds   = "player_ids"
    }
}

struct ConnectionsPuzzle: Sendable {
    let puzzleDate: String
    let groups: [ConnectionsGroup]
    let players: [Int64: ConnectionsPlayer]    // keyed by player id

    /// All 16 player IDs in the puzzle (in the authoritative group order).
    var allPlayerIds: [Int64] {
        groups.flatMap(\.playerIds)
    }
}

enum ConnectionsStatus: Sendable, Equatable {
    case playing
    case won
    case lost
}

enum ConnectionsGuessFeedback: Sendable, Equatable {
    case correct
    case oneAway
    case wrong
}

// MARK: - View Model

@Observable
@MainActor
final class ConnectionsGameViewModel {

    // MARK: State

    var puzzle: ConnectionsPuzzle?
    /// Player IDs still on the board (shuffled display order).
    var boardOrder: [Int64] = []
    var selected: Set<Int64> = []
    var solvedGroups: [ConnectionsGroup] = []
    var mistakesRemaining: Int = ConnectionsGameViewModel.maxMistakes
    var status: ConnectionsStatus = .playing

    /// Transient feedback shown after the most recent guess. Cleared after ~2s.
    var lastFeedback: ConnectionsGuessFeedback?

    var isLoading = false
    var errorMessage: String?

    static let maxMistakes = 4

    // MARK: Persistence keys

    private static func progressKey(for date: String) -> String {
        "NETR.connections.progress.\(date)"
    }
    private static let statsKey = "NETR.connections.stats.v1"

    // MARK: Derived

    var isGameOver: Bool { status != .playing }
    var canSubmit: Bool  { selected.count == 4 && !isGameOver }

    private let client = SupabaseManager.shared.client

    // MARK: Loading

    /// Fetches today's puzzle from the `nba_connections_today` Supabase view and
    /// restores any local in-progress state keyed by puzzle_date.
    func loadTodaysGame() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        struct Row: Decodable {
            let puzzle_date: String
            let groups: [ConnectionsGroup]
            // Supabase returns players as a { "<id>": {...} } object
            let players: [String: ConnectionsPlayer]
        }

        do {
            let rows: [Row] = try await client
                .from("nba_connections_today")
                .select()
                .limit(1)
                .execute()
                .value

            guard let row = rows.first else {
                errorMessage = "Today's Connections puzzle isn't ready yet."
                return
            }

            // Re-key players dict from String → Int64
            var playersById: [Int64: ConnectionsPlayer] = [:]
            for (k, v) in row.players {
                if let id = Int64(k) { playersById[id] = v }
            }

            let puz = ConnectionsPuzzle(
                puzzleDate: row.puzzle_date,
                groups: row.groups,
                players: playersById
            )
            self.puzzle = puz

            // Restore local progress if any
            if let snap = loadSnapshot(for: puz.puzzleDate) {
                self.solvedGroups      = snap.solvedGroups
                self.mistakesRemaining = snap.mistakesRemaining
                self.status            = snap.status
                self.boardOrder        = snap.boardOrder
            } else {
                self.boardOrder        = puz.allPlayerIds.shuffled()
                self.solvedGroups      = []
                self.mistakesRemaining = Self.maxMistakes
                self.status            = .playing
            }
        } catch {
            errorMessage = "Couldn't load today's puzzle — try again in a moment."
            #if DEBUG
            print("Connections load error: \(error)")
            #endif
        }
    }

    // MARK: Interaction

    func toggle(_ id: Int64) {
        guard !isGameOver else { return }
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count < 4 {
            selected.insert(id)
        }
    }

    func shuffle() {
        boardOrder.shuffle()
    }

    func deselectAll() {
        selected.removeAll()
    }

    /// Submit the 4 currently-selected players as a guess.
    func submit() {
        guard let puzzle, canSubmit else { return }

        // Check if selection matches any unsolved group exactly
        let solvedIds = Set(solvedGroups.flatMap(\.playerIds))
        let unsolved = puzzle.groups.filter { !solvedIds.contains($0.playerIds.first ?? -1) }
        let sel = selected

        if let match = unsolved.first(where: { Set($0.playerIds) == sel }) {
            // Correct!
            solvedGroups.append(match)
            solvedGroups.sort { $0.difficulty.rank < $1.difficulty.rank }
            boardOrder.removeAll { sel.contains($0) }
            selected.removeAll()
            lastFeedback = .correct

            if solvedGroups.count == 4 {
                status = .won
                recordResult(won: true)
            }
        } else {
            mistakesRemaining -= 1

            // "One away" — does any unsolved group overlap 3 of 4?
            let oneAway = unsolved.contains { g in
                Set(g.playerIds).intersection(sel).count == 3
            }
            lastFeedback = oneAway ? .oneAway : .wrong

            if mistakesRemaining <= 0 {
                // Reveal remaining groups
                for g in unsolved {
                    if !solvedGroups.contains(where: { $0.categoryId == g.categoryId }) {
                        solvedGroups.append(g)
                    }
                }
                solvedGroups.sort { $0.difficulty.rank < $1.difficulty.rank }
                boardOrder.removeAll()
                selected.removeAll()
                status = .lost
                recordResult(won: false)
            }
        }

        saveSnapshot()

        // Clear feedback after a short delay
        let current = lastFeedback
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if self.lastFeedback == current { self.lastFeedback = nil }
        }
    }

    // MARK: - Persistence

    private struct ProgressSnapshot: Codable {
        let puzzleDate: String
        let boardOrder: [Int64]
        let solvedGroups: [ConnectionsGroup]
        let mistakesRemaining: Int
        let status: String

        var statusEnum: ConnectionsStatus {
            switch status {
            case "won":  return .won
            case "lost": return .lost
            default:     return .playing
            }
        }
    }

    private func saveSnapshot() {
        guard let puzzle else { return }
        let statusStr: String = {
            switch status {
            case .won: return "won"; case .lost: return "lost"; case .playing: return "playing"
            }
        }()
        let snap = ProgressSnapshot(
            puzzleDate: puzzle.puzzleDate,
            boardOrder: boardOrder,
            solvedGroups: solvedGroups,
            mistakesRemaining: mistakesRemaining,
            status: statusStr
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.progressKey(for: puzzle.puzzleDate))
        }
    }

    private func loadSnapshot(for date: String) -> (boardOrder: [Int64],
                                                    solvedGroups: [ConnectionsGroup],
                                                    mistakesRemaining: Int,
                                                    status: ConnectionsStatus)? {
        guard
            let data = UserDefaults.standard.data(forKey: Self.progressKey(for: date)),
            let snap = try? JSONDecoder().decode(ProgressSnapshot.self, from: data)
        else { return nil }
        return (snap.boardOrder, snap.solvedGroups, snap.mistakesRemaining, snap.statusEnum)
    }

    private func recordResult(won: Bool) {
        // Local stats update
        var stats = Self.loadStats()
        let today = puzzle?.puzzleDate ?? ""
        guard stats.lastPlayedDate != today else { return }

        let wasConsecutive = (stats.lastPlayedDate == previousDate(of: today))
        stats.totalPlayed += 1
        if won {
            stats.totalWon   += 1
            stats.currentStreak = wasConsecutive ? stats.currentStreak + 1 : 1
            stats.maxStreak  = max(stats.maxStreak, stats.currentStreak)
        } else {
            stats.currentStreak = 0
        }
        stats.lastPlayedDate = today
        stats.mistakeDistribution[String(Self.maxMistakes - mistakesRemaining), default: 0] += 1
        Self.saveStats(stats)

        // Fire-and-forget upload
        let payload = ConnectionsResultPayload(
            userId: SupabaseManager.shared.session?.user.id.uuidString ?? "",
            puzzleDate: puzzle?.puzzleDate ?? "",
            mistakesUsed: Self.maxMistakes - mistakesRemaining,
            solvedGroups: solvedGroups.count,
            won: won
        )
        Task {
            guard !payload.userId.isEmpty, !payload.puzzleDate.isEmpty else { return }
            do {
                try await client.from("nba_connections_results").insert(payload).execute()
            } catch {
                #if DEBUG
                print("Connections result upload failed: \(error)")
                #endif
            }
        }
    }

    private struct ConnectionsResultPayload: Encodable {
        let userId: String
        let puzzleDate: String
        let mistakesUsed: Int
        let solvedGroups: Int
        let won: Bool

        enum CodingKeys: String, CodingKey {
            case userId       = "user_id"
            case puzzleDate   = "puzzle_date"
            case mistakesUsed = "mistakes_used"
            case solvedGroups = "solved_groups"
            case won
        }
    }

    private func previousDate(of isoDate: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        guard let d = df.date(from: isoDate),
              let prev = Calendar(identifier: .iso8601).date(byAdding: .day, value: -1, to: d)
        else { return "" }
        return df.string(from: prev)
    }

    // MARK: Stats

    struct Stats: Codable {
        var currentStreak: Int = 0
        var maxStreak: Int = 0
        var totalPlayed: Int = 0
        var totalWon: Int = 0
        var mistakeDistribution: [String: Int] = [:]   // "0"..."4" mistakes → count
        var lastPlayedDate: String = ""
    }

    static func loadStats() -> Stats {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let s = try? JSONDecoder().decode(Stats.self, from: data)
        else { return Stats() }
        return s
    }

    static func saveStats(_ s: Stats) {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }

    // MARK: Hub integration

    /// Cheap completion check used by DailyGameHubView — just inspects local stats.
    static func didCompleteToday() -> Bool {
        let today = todayUTCDateString()
        return loadStats().lastPlayedDate == today
    }

    static func todayUTCDateString() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        return df.string(from: Date())
    }
}
