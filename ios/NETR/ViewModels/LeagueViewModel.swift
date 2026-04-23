import Foundation
import Supabase

@Observable
class LeagueViewModel {

    // MARK: - Profile list state
    var myLeagues: [MyLeague] = []
    var isLoadingMyLeagues: Bool = false

    // MARK: - Detail view state
    var standings: [LeagueStanding] = []
    var games: [LeagueGame] = []
    var allPlayers: [LeaguePlayer] = []
    var allStats: [LeaguePlayerStat] = []
    var allTeams: [LeagueTeam] = []
    /// gameId → 'yes' | 'no' | 'maybe'
    var attendance: [String: String] = [:]
    /// gameId → confirmed ("yes") count
    var attendanceCounts: [String: Int] = [:]
    var isLoadingDetail: Bool = false
    var errorMessage: String? = nil

    private let client = SupabaseManager.shared.client

    var currentUserId: String? {
        SupabaseManager.shared.session?.user.id.uuidString.lowercased()
    }

    // MARK: - Load My Leagues (profile section)

    func loadMyLeagues() async {
        guard let userId = currentUserId else { return }
        isLoadingMyLeagues = true
        defer { isLoadingMyLeagues = false }

        do {
            // 1. Player rows for current user
            let playerRows: [LeaguePlayer] = try await client
                .from("league_players")
                .select()
                .eq("profile_id", value: userId)
                .execute()
                .value

            guard !playerRows.isEmpty else { myLeagues = []; return }

            // 2. Active leagues
            let leagueIds = Array(Set(playerRows.map { $0.leagueId }))
            let leagues: [League] = try await client
                .from("leagues")
                .select()
                .in("id", values: leagueIds)
                .eq("is_active", value: true)
                .execute()
                .value

            // 3. Teams
            let teamIds = Array(Set(playerRows.map { $0.teamId }))
            let teams: [LeagueTeam] = try await client
                .from("league_teams")
                .select()
                .in("id", values: teamIds)
                .execute()
                .value

            // 4. Combine
            let leagueMap = Dictionary(uniqueKeysWithValues: leagues.map { ($0.id, $0) })
            let teamMap   = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })

            myLeagues = playerRows.compactMap { player in
                guard let league = leagueMap[player.leagueId],
                      let team   = teamMap[player.teamId] else { return nil }
                return MyLeague(league: league, team: team, player: player)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("[NETR Leagues] loadMyLeagues error: \(error)")
        }
    }

    // MARK: - Load League Detail

    func loadLeagueDetail(leagueId: String, myPlayerId: String) async {
        isLoadingDetail = true
        defer { isLoadingDetail = false }

        do {
            // Parallel fetches for standings, games, players, teams
            async let standingsReq: [LeagueStanding] = client
                .from("league_standings")
                .select()
                .eq("league_id", value: leagueId)
                .order("wins", ascending: false)
                .execute()
                .value

            async let gamesReq: [LeagueGame] = client
                .from("league_games")
                .select()
                .eq("league_id", value: leagueId)
                .order("scheduled_at", ascending: true)
                .execute()
                .value

            async let playersReq: [LeaguePlayer] = client
                .from("league_players")
                .select()
                .eq("league_id", value: leagueId)
                .execute()
                .value

            async let teamsReq: [LeagueTeam] = client
                .from("league_teams")
                .select()
                .eq("league_id", value: leagueId)
                .execute()
                .value

            let (loadedStandings, loadedGames, loadedPlayers, loadedTeams) =
                try await (standingsReq, gamesReq, playersReq, teamsReq)

            standings  = loadedStandings
            games      = loadedGames
            allPlayers = loadedPlayers
            allTeams   = loadedTeams

            // Stats for all players in this league
            if !loadedPlayers.isEmpty {
                let playerIds = loadedPlayers.map { $0.id }
                let stats: [LeaguePlayerStat] = try await client
                    .from("league_player_stats")
                    .select()
                    .in("player_id", values: playerIds)
                    .execute()
                    .value
                allStats = stats
            }

            // My RSVP status for upcoming games
            let upcomingIds = loadedGames.filter { $0.isScheduled }.map { $0.id }
            if !upcomingIds.isEmpty {
                let myAttendance: [LeagueGameAttendance] = try await client
                    .from("league_game_attendance")
                    .select()
                    .eq("player_id", value: myPlayerId)
                    .in("game_id", values: upcomingIds)
                    .execute()
                    .value
                attendance = Dictionary(uniqueKeysWithValues: myAttendance.map { ($0.gameId, $0.status) })

                // Confirmed counts (status = 'yes') for each upcoming game
                nonisolated struct AttCount: Decodable, Sendable {
                    let gameId: String
                    enum CodingKeys: String, CodingKey { case gameId = "game_id" }
                }
                let confirmed: [AttCount] = try await client
                    .from("league_game_attendance")
                    .select("game_id")
                    .in("game_id", values: upcomingIds)
                    .eq("status", value: "yes")
                    .execute()
                    .value
                var counts: [String: Int] = [:]
                for row in confirmed { counts[row.gameId, default: 0] += 1 }
                attendanceCounts = counts
            }
        } catch {
            errorMessage = error.localizedDescription
            print("[NETR Leagues] loadLeagueDetail error: \(error)")
        }
    }

    // MARK: - RSVP

    func upsertAttendance(gameId: String, playerId: String, newStatus: String) async {
        let previousStatus = attendance[gameId]

        // Optimistic update
        attendance[gameId] = newStatus
        adjustConfirmedCount(gameId: gameId, from: previousStatus, to: newStatus)

        do {
            struct AttendanceUpsert: Encodable {
                let game_id: String
                let player_id: String
                let status: String
                let updated_at: String
            }
            try await client
                .from("league_game_attendance")
                .upsert(
                    AttendanceUpsert(
                        game_id: gameId,
                        player_id: playerId,
                        status: newStatus,
                        updated_at: ISO8601DateFormatter().string(from: Date())
                    ),
                    onConflict: "game_id,player_id"
                )
                .execute()
        } catch {
            // Revert optimistic update
            if let prev = previousStatus {
                attendance[gameId] = prev
            } else {
                attendance.removeValue(forKey: gameId)
            }
            adjustConfirmedCount(gameId: gameId, from: newStatus, to: previousStatus)
            print("[NETR Leagues] RSVP error: \(error)")
        }
    }

    private func adjustConfirmedCount(gameId: String, from: String?, to: String?) {
        let wasYes = from == "yes"
        let isYes  = to   == "yes"
        if !wasYes && isYes  { attendanceCounts[gameId, default: 0] += 1 }
        if  wasYes && !isYes { attendanceCounts[gameId, default: 0]  =
            max(0, (attendanceCounts[gameId] ?? 1) - 1) }
    }

    // MARK: - Derived: Stats Leaderboard

    func buildStatLeaderboard() -> [PlayerStatLine] {
        let playerMap = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0) })
        let teamMap   = Dictionary(uniqueKeysWithValues: allTeams.map { ($0.id, $0) })

        var grouped: [String: [LeaguePlayerStat]] = [:]
        for stat in allStats { grouped[stat.playerId, default: []].append(stat) }

        return grouped.compactMap { playerId, stats in
            guard let player = playerMap[playerId],
                  let team   = teamMap[player.teamId] else { return nil }
            return PlayerStatLine(
                player:        player,
                team:          team,
                gamesPlayed:   stats.count,
                totalPoints:   stats.reduce(0) { $0 + $1.points   },
                totalRebounds: stats.reduce(0) { $0 + $1.rebounds  },
                totalAssists:  stats.reduce(0) { $0 + $1.assists   },
                totalSteals:   stats.reduce(0) { $0 + $1.steals    },
                totalBlocks:   stats.reduce(0) { $0 + $1.blocks    }
            )
        }
        .sorted { $0.ppg > $1.ppg }
    }

    // MARK: - Derived: Box Score for a game

    func boxScoreStats(gameId: String) -> [LeaguePlayerStat] {
        allStats.filter { $0.gameId == gameId }
    }
}
