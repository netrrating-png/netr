import SwiftUI
import Supabase
import Auth
import PostgREST

@Observable
class RateTabViewModel {
    var sessions: [RecentGameSession] = []
    var ratingsReceivedToday: Int = 0
    var isLoading: Bool = false
    var isEmpty: Bool = false
    var errorMessage: String?

    private let supabase = SupabaseManager.shared

    func load() async {
        isLoading = true
        errorMessage = nil

        guard let userId = supabase.session?.user.id.uuidString else {
            sessions = []
            isEmpty = true
            isLoading = false
            return
        }

        do {
            // 24-hour rating window from when the game was *completed*
            let cutoff = ISO8601DateFormatter().string(
                from: Date().addingTimeInterval(-24 * 60 * 60)
            )

            // ── Step 1: All game_ids the current user participated in ──
            let myGameIdRows: [MyGameIdRow] = try await supabase.client
                .from("game_players")
                .select("game_id")
                .eq("user_id", value: userId)
                .execute()
                .value

            let myGameIds = myGameIdRows.map { $0.gameId }

            guard !myGameIds.isEmpty else {
                sessions = []
                isEmpty = true
                isLoading = false
                await loadRatedByCount(userId: userId)
                return
            }

            // ── Step 2: Filter to completed games from last 24h ──
            // Filter on completed_at (when host ended game) so long games aren't
            // excluded just because they were created >24h ago.
            // Fall back to created_at for older games that don't have completed_at yet.
            let games: [RateGameRow] = try await supabase.client
                .from("games")
                .select("id, court_id, created_at, completed_at, status")
                .in("id", values: myGameIds)
                .eq("status", value: "completed")
                .or("completed_at.gte.\(cutoff),and(completed_at.is.null,created_at.gte.\(cutoff))")
                .order("completed_at", ascending: false)
                .execute()
                .value

            guard !games.isEmpty else {
                sessions = []
                isEmpty = true
                isLoading = false
                await loadRatedByCount(userId: userId)
                return
            }

            let completedGameIds = games.map { $0.id }

            // ── Step 3: Other players in those games (checked-in, not removed) ──
            nonisolated struct RateOtherPlayerRow: Decodable, Sendable {
                let userId: String
                let gameId: String
                let checkedInAt: String?
                let removed: Bool?
                nonisolated enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case gameId = "game_id"
                    case checkedInAt = "checked_in_at"
                    case removed
                }
            }

            let rawOtherPlayers: [RateOtherPlayerRow] = try await supabase.client
                .from("game_players")
                .select("user_id, game_id, checked_in_at, removed")
                .in("game_id", values: completedGameIds)
                .neq("user_id", value: userId)
                .execute()
                .value

            // Only include players who checked in and were not removed
            let otherPlayerRows: [OtherPlayerRow] = rawOtherPlayers
                .filter { $0.checkedInAt != nil && !($0.removed ?? false) }
                .map { OtherPlayerRow(userId: $0.userId, gameId: $0.gameId) }

            let allPlayerIds = Array(Set(otherPlayerRows.map { $0.userId }))
            guard !allPlayerIds.isEmpty else {
                sessions = []
                isEmpty = true
                isLoading = false
                await loadRatedByCount(userId: userId)
                return
            }

            // ── Step 4: Load profiles ──
            let profiles: [RateProfileRow] = try await supabase.client
                .from("profiles")
                .select("id, full_name, username, netr_score, vibe_score, position")
                .in("id", values: allPlayerIds)
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            // ── Step 5: Load court names ──
            let courtIds = Array(Set(games.compactMap { $0.courtId }))
            var courtMap: [String: String] = [:]
            if !courtIds.isEmpty {
                let courts: [RateCourtNameRow] = try await supabase.client
                    .from("courts")
                    .select("id, name")
                    .in("id", values: courtIds)
                    .execute()
                    .value
                courtMap = Dictionary(uniqueKeysWithValues: courts.map { ($0.id, $0.name) })
            }

            // ── Step 6: Which players are already rated ──
            let ratedRows: [RatedRow] = try await supabase.client
                .from("ratings")
                .select("rated_id, game_id")
                .eq("rater_id", value: userId)
                .in("game_id", values: completedGameIds)
                .execute()
                .value

            let alreadyRatedSet = Set(ratedRows.map { "\($0.gameId)|\($0.ratedId)" })

            // ── Step 7: Build sessions ──
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            var builtSessions: [RecentGameSession] = []
            for game in games {
                let gamePlayers = otherPlayerRows.filter { $0.gameId == game.id }
                var players: [RateablePlayer] = []

                for row in gamePlayers {
                    guard let profile = profileMap[row.userId] else { continue }
                    let rated = alreadyRatedSet.contains("\(game.id)|\(row.userId)")
                    players.append(RateablePlayer(
                        id:          profile.id,
                        fullName:    profile.fullName ?? "Player",
                        username:    profile.username ?? "",
                        netrScore:   profile.netrScore,
                        vibeScore:   profile.vibeScore,
                        position:    profile.position,
                        gameId:      game.id,
                        alreadyRated: rated
                    ))
                }

                players.sort { !$0.alreadyRated && $1.alreadyRated }
                guard !players.isEmpty else { continue }

                // Use completed_at if available (more accurate "played at"), else created_at
                let playedAt = game.completedAt.flatMap { formatter.date(from: $0) }
                    ?? formatter.date(from: game.createdAt)
                    ?? Date()
                let courtName = game.courtId.flatMap { courtMap[$0] } ?? "Unknown Court"

                builtSessions.append(RecentGameSession(
                    id: game.id,
                    courtName: courtName,
                    playedAt: playedAt,
                    players: players
                ))
            }

            sessions = builtSessions
            isEmpty = builtSessions.isEmpty
            isLoading = false

            await loadRatedByCount(userId: userId)

        } catch {
            sessions = []
            isEmpty = true
            isLoading = false
        }
    }

    private func loadRatedByCount(userId: String) async {
        let todayStr = ISO8601DateFormatter().string(
            from: Calendar.current.startOfDay(for: Date())
        )
        do {
            let rows: [RatingCountRow] = try await supabase.client
                .from("ratings")
                .select("id")
                .eq("rated_id", value: userId)
                .gte("created_at", value: todayStr)
                .execute()
                .value
            ratingsReceivedToday = rows.count
        } catch {
            ratingsReceivedToday = 0
        }
    }

    func markRated(playerId: String, gameId: String) {
        for si in sessions.indices {
            for pi in sessions[si].players.indices {
                if sessions[si].players[pi].id == playerId &&
                    sessions[si].players[pi].gameId == gameId {
                    sessions[si].players[pi].alreadyRated = true
                }
            }
        }
    }
}
