import Foundation

// MARK: - Team Balancer
// Brute-forces all C(N, N/2) player splits (max C(10,5) = 252) and picks the
// assignment with the smallest combined NETR delta + position imbalance penalty.

struct TeamBalancer {

    struct BalancedTeams {
        let teamA: [LobbyPlayer]
        let teamB: [LobbyPlayer]
        /// Absolute avg-NETR difference between the two teams (for display)
        let netrDiff: Double
    }

    // Default NETR assumed for players who have no score yet
    private static let defaultNetr: Double = 500.0
    // How much each "misplaced" player by position costs (vs 1 point of NETR diff)
    private static let positionWeight: Double = 80.0

    // MARK: - Public

    /// Returns the best balanced split, or nil if the player count is invalid.
    static func balance(players: [LobbyPlayer]) -> BalancedTeams? {
        let n = players.count
        guard n >= 4, n % 2 == 0 else { return nil }
        let half = n / 2

        var bestScore = Double.infinity
        var bestMaskA: Int = 0   // bitmask of which indices go to Team A

        // Iterate every combination of `half` indices chosen from 0..<n
        for combo in combinations(n: n, k: half) {
            let mask = combo.reduce(0) { $0 | (1 << $1) }
            let teamA = combo.map { players[$0] }
            let teamB = (0..<n).filter { (mask >> $0 & 1) == 0 }.map { players[$0] }
            let s = score(teamA: teamA, teamB: teamB)
            if s < bestScore {
                bestScore = s
                bestMaskA = mask
            }
        }

        let teamA = (0..<n).filter { (bestMaskA >> $0 & 1) == 1 }.map { players[$0] }
        let teamB = (0..<n).filter { (bestMaskA >> $0 & 1) == 0 }.map { players[$0] }
        let diff  = abs(avgNetr(teamA) - avgNetr(teamB))
        return BalancedTeams(teamA: teamA, teamB: teamB, netrDiff: diff)
    }

    // MARK: - Scoring

    private static func avgNetr(_ team: [LobbyPlayer]) -> Double {
        guard !team.isEmpty else { return defaultNetr }
        let total = team.map { $0.profile.netrScore ?? defaultNetr }.reduce(0, +)
        return total / Double(team.count)
    }

    private static func score(teamA: [LobbyPlayer], teamB: [LobbyPlayer]) -> Double {
        // 1. NETR balance
        let netrDiff = abs(avgNetr(teamA) - avgNetr(teamB))

        // 2. Position balance — penalise uneven splits of each position
        let allPlayers = teamA + teamB
        let allPositions = Set(allPlayers.compactMap {
            $0.profile.position?.trimmingCharacters(in: .whitespaces).uppercased()
        }.filter { !$0.isEmpty })

        var posPenalty = 0.0
        for pos in allPositions {
            let cA = Double(teamA.filter { ($0.profile.position?.uppercased().trimmingCharacters(in: .whitespaces) ?? "") == pos }.count)
            let cB = Double(teamB.filter { ($0.profile.position?.uppercased().trimmingCharacters(in: .whitespaces) ?? "") == pos }.count)
            let total = cA + cB
            // Ideal: equal split. Penalty = deviation from ideal.
            posPenalty += abs(cA - total / 2.0)
        }

        return netrDiff + posPenalty * positionWeight
    }

    // MARK: - Combinatorics
    // Returns all combinations of `k` distinct indices from [0, n)

    private static func combinations(n: Int, k: Int) -> [[Int]] {
        var result: [[Int]] = []
        var current: [Int] = []
        func recurse(_ start: Int) {
            if current.count == k {
                result.append(current)
                return
            }
            let remaining = k - current.count
            guard start + remaining <= n else { return }
            for i in start...(n - remaining) {
                current.append(i)
                recurse(i + 1)
                current.removeLast()
            }
        }
        recurse(0)
        return result
    }
}
