import SwiftUI
import Supabase

@MainActor @Observable
class RateTabViewModel {
    var sessions: [RecentGameSession] = []
    var isLoading: Bool = true
    var isEmpty: Bool = false
    var errorMessage: String?

    private let supabase = SupabaseManager.shared

    func load() async {
        isLoading = true
        errorMessage = nil

        guard let userId = supabase.session?.user.id.uuidString else {
            isLoading = false
            isEmpty = true
            return
        }

        do {
            let cutoff = ISO8601DateFormatter().string(
                from: Date().addingTimeInterval(-24 * 60 * 60)
            )

            let gamesResponse: [RateGameRow] = try await supabase.client
                .from("games")
                .select("id, players, created_at, court_id, status")
                .eq("status", value: "completed")
                .gte("created_at", value: cutoff)
                .contains("players", value: [userId])
                .order("created_at", ascending: false)
                .execute()
                .value

            if gamesResponse.isEmpty {
                isEmpty = true
                isLoading = false
                return
            }

            var gamePlayerMap: [(gameId: String, courtId: String?, createdAt: String, playerIds: [String])] = []

            for game in gamesResponse {
                let opponents = (game.players ?? []).filter { $0 != userId }
                if !opponents.isEmpty {
                    gamePlayerMap.append((
                        gameId: game.id,
                        courtId: game.courtId,
                        createdAt: game.createdAt,
                        playerIds: opponents
                    ))
                }
            }

            let allPlayerIds = Array(Set(gamePlayerMap.flatMap { $0.playerIds }))

            guard !allPlayerIds.isEmpty else {
                isEmpty = true
                isLoading = false
                return
            }

            let profiles: [RateProfileRow] = try await supabase.client
                .from("profiles")
                .select("id, full_name, username, netr_score, vibe_score, position, provisional")
                .in("id", values: allPlayerIds)
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            let courtIds = Array(Set(gamePlayerMap.compactMap { $0.courtId }))
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

            let gameIds = gamePlayerMap.map { $0.gameId }
            let ratedRows: [RatedRow] = try await supabase.client
                .from("ratings")
                .select("rated_id, game_id")
                .eq("rater_id", value: userId)
                .in("game_id", values: gameIds)
                .execute()
                .value

            let alreadyRatedSet = Set(ratedRows.map { "\($0.gameId)|\($0.ratedId)" })

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            var builtSessions: [RecentGameSession] = []

            for entry in gamePlayerMap {
                var players: [RateablePlayer] = []

                for pid in entry.playerIds {
                    guard let profile = profileMap[pid] else { continue }
                    let rated = alreadyRatedSet.contains("\(entry.gameId)|\(pid)")
                    players.append(RateablePlayer(
                        id: profile.id,
                        fullName: profile.fullName ?? "Player",
                        username: profile.username ?? "",
                        netrScore: profile.netrScore,
                        vibeScore: profile.vibeScore,
                        position: profile.position,
                        provisional: profile.provisional ?? false,
                        gameId: entry.gameId,
                        alreadyRated: rated
                    ))
                }

                players.sort { !$0.alreadyRated && $1.alreadyRated }

                let playedAt = formatter.date(from: entry.createdAt) ?? Date()
                let courtName = entry.courtId.flatMap { courtMap[$0] } ?? "Unknown Court"

                builtSessions.append(RecentGameSession(
                    id: entry.gameId,
                    courtName: courtName,
                    playedAt: playedAt,
                    players: players
                ))
            }

            sessions = builtSessions
            isEmpty = builtSessions.isEmpty
            isLoading = false

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
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
