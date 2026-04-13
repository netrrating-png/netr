import Foundation
import SwiftUI
import Supabase
import PostgREST

@Observable
@MainActor
final class DailyGameViewModel {

    // MARK: - State

    var todaysPuzzle: DailyPuzzle?
    var guesses: [DailyGameGuess] = []
    var status: DailyGameStatus = .playing
    var stats: DailyGameStats = DailyGameViewModel.loadStats()

    var isLoading: Bool = false
    var errorMessage: String?

    // Guess input
    var searchQuery: String = ""

    // MARK: - Constants

    static let maxGuesses = 5
    private static let statsKey = "NETR.dailyGame.stats.v1"
    private static func progressKey(for date: String) -> String {
        "NETR.dailyGame.progress.\(date)"
    }

    private let client = SupabaseManager.shared.client

    // MARK: - Derived

    /// Hints visible to the player right now: 0 before first guess, then
    /// one more per wrong guess, up to 5 total.
    var revealedHints: [HintStage] {
        let wrongCount = guesses.filter { !$0.isCorrect }.count
        let count = min(wrongCount, HintStage.allCases.count)
        return Array(HintStage.allCases.prefix(count))
    }

    var remainingGuesses: Int {
        max(0, Self.maxGuesses - guesses.count)
    }

    var isGameOver: Bool {
        if case .playing = status { return false }
        return true
    }

    /// Letters revealed so far — indices into the answer name that have been uncovered
    /// by matching positions from wrong guesses (Wheel of Fortune style).
    var revealedLetterIndices: Set<Int> {
        guard let answer = todaysPuzzle?.player.name else { return [] }
        var revealed = Set<Int>()
        let answerChars = Array(answer.lowercased())
        for guess in guesses where !guess.isCorrect {
            let guessChars = Array(guess.guessName.lowercased())
            for i in 0..<min(answerChars.count, guessChars.count) {
                if answerChars[i] == guessChars[i] {
                    revealed.insert(i)
                }
            }
        }
        return revealed
    }

    /// The answer name with unrevealed letters replaced by underscores,
    /// preserving spaces and grouping by word.
    var letterBoard: String {
        guard let answer = todaysPuzzle?.player.name else { return "" }
        let revealed = revealedLetterIndices
        let isOver = isGameOver
        return String(answer.enumerated().map { i, ch in
            if ch == " " { return ch }
            if isOver || revealed.contains(i) { return ch }
            return "_"
        })
    }

    /// Number of letters that matched in the last guess (for feedback)
    var lastGuessMatchCount: Int? {
        guard let last = guesses.last, !last.isCorrect,
              let answer = todaysPuzzle?.player.name else { return nil }
        let a = Array(answer.lowercased())
        let g = Array(last.guessName.lowercased())
        var count = 0
        for i in 0..<min(a.count, g.count) {
            if a[i] == g[i] && a[i] != " " { count += 1 }
        }
        return count
    }

    // MARK: - Loading

    /// Fetches today's puzzle and the full player pool from Supabase.
    /// Also restores any in-progress guesses from local storage.
    func loadTodaysGame() async {
        isLoading = true
        errorMessage = nil

        do {
            // 1. Today's puzzle via the helper view
            let puzzles: [DailyPuzzle] = try await client
                .from("nba_game_today")
                .select()
                .limit(1)
                .execute()
                .value

            guard let puzzle = puzzles.first else {
                errorMessage = "Today's puzzle isn't ready yet. Check back in a bit."
                isLoading = false
                return
            }
            self.todaysPuzzle = puzzle

            // 2. Restore in-progress guesses for today (if any)
            restoreProgress(for: puzzle.puzzleDate)

            isLoading = false
        } catch {
            print("[NETR DailyGame] load error: \(error)")
            errorMessage = "Couldn't load today's game. Pull to retry."
            isLoading = false
        }
    }

    // MARK: - Gameplay

    func submitGuess(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard case .playing = status, let puzzle = todaysPuzzle, !trimmed.isEmpty else { return }
        guard !guesses.contains(where: { $0.guessName.lowercased() == trimmed.lowercased() }) else { return }

        let isCorrect = trimmed.lowercased() == puzzle.player.name.lowercased()
        guesses.append(DailyGameGuess(name: trimmed, isCorrect: isCorrect))
        searchQuery = ""

        if isCorrect {
            status = .won(guessCount: guesses.count)
            recordResult(won: true, puzzleDate: puzzle.puzzleDate)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else if guesses.count >= Self.maxGuesses {
            status = .lost
            recordResult(won: false, puzzleDate: puzzle.puzzleDate)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        saveProgress(for: puzzle.puzzleDate)
    }

    // MARK: - Persistence (local progress + stats)

    private func saveProgress(for date: String) {
        let payload = ProgressSnapshot(
            guesses: guesses.map { ProgressSnapshot.GuessRow(guessName: $0.guessName, isCorrect: $0.isCorrect) },
            status: {
                switch status {
                case .playing: return "playing"
                case .won(let n): return "won:\(n)"
                case .lost: return "lost"
                }
            }()
        )
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: Self.progressKey(for: date))
        }
    }

    private func restoreProgress(for date: String) {
        guard let data = UserDefaults.standard.data(forKey: Self.progressKey(for: date)),
              let snap = try? JSONDecoder().decode(ProgressSnapshot.self, from: data) else {
            return
        }

        var restored: [DailyGameGuess] = []
        for row in snap.guesses {
            restored.append(DailyGameGuess(name: row.guessName, isCorrect: row.isCorrect))
        }
        self.guesses = restored

        if snap.status.hasPrefix("won:"), let n = Int(snap.status.dropFirst(4)) {
            self.status = .won(guessCount: n)
        } else if snap.status == "lost" {
            self.status = .lost
        } else {
            self.status = .playing
        }
    }

    private func recordResult(won: Bool, puzzleDate: String) {
        guard stats.lastPlayedDate != puzzleDate else { return }
        // 1. Update local stats
        var s = stats
        let wasConsecutive = (s.lastPlayedDate == previousDate(of: puzzleDate))
        s.totalPlayed += 1
        if won {
            s.totalWon += 1
            s.currentStreak = wasConsecutive ? s.currentStreak + 1 : 1
            s.maxStreak = max(s.maxStreak, s.currentStreak)
            s.guessDistribution["\(guesses.count)", default: 0] += 1
        } else {
            s.currentStreak = 0
        }
        s.lastPlayedDate = puzzleDate
        self.stats = s
        Self.saveStats(s)

        // 2. Push result to Supabase (fire and forget; local stats are source of truth anyway)
        Task { [guesses] in
            guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
            let payload = DailyGameResultPayload(
                userId: userId,
                puzzleDate: puzzleDate,
                guessCount: guesses.count,
                won: won
            )
            do {
                try await client
                    .from("nba_game_results")
                    .insert(payload)
                    .execute()
            } catch {
                // Silent fail - local stats still correct
                print("[NETR DailyGame] result upload failed: \(error)")
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

    private static func loadStats() -> DailyGameStats {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let decoded = try? JSONDecoder().decode(DailyGameStats.self, from: data) else {
            return DailyGameStats()
        }
        return decoded
    }

    private static func saveStats(_ stats: DailyGameStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }

    // MARK: - Private types

    private struct ProgressSnapshot: Codable {
        struct GuessRow: Codable {
            let guessName: String
            let isCorrect: Bool
        }
        let guesses: [GuessRow]
        let status: String
    }
}
