import SwiftUI
import Supabase
import PostgREST

@Observable
class LeaguesViewModel {
    var entries: [LeagueEntry] = []
    var isLoading: Bool = false

    private let client = SupabaseManager.shared.client

    func load(profileId: String) async {
        isLoading = true
        defer { isLoading = false }

        guard let players: [LeaguePlayer] = try? await client
            .from("league_players")
            .select()
            .eq("profile_id", value: profileId)
            .eq("is_claimed", value: true)
            .execute()
            .value,
            !players.isEmpty
        else { return }

        let leagueIds = Array(Set(players.map { $0.leagueId }))
        let teamIds = Array(Set(players.map { $0.teamId }))

        let leagues: [League] = (try? await client
            .from("leagues")
            .select()
            .in("id", values: leagueIds)
            .execute()
            .value) ?? []

        let teams: [LeagueTeam] = (try? await client
            .from("league_teams")
            .select()
            .in("id", values: teamIds)
            .execute()
            .value) ?? []

        let standings: [LeagueStanding] = (try? await client
            .from("league_standings")
            .select()
            .in("team_id", values: teamIds)
            .execute()
            .value) ?? []

        let leagueMap = Dictionary(uniqueKeysWithValues: leagues.map { ($0.id, $0) })
        let teamMap = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
        let standingMap = Dictionary(uniqueKeysWithValues: standings.map { ($0.teamId, $0) })

        entries = players.compactMap { lp in
            guard let league = leagueMap[lp.leagueId],
                  let team = teamMap[lp.teamId] else { return nil }
            return LeagueEntry(
                id: lp.id,
                leaguePlayer: lp,
                league: league,
                team: team,
                standing: standingMap[lp.teamId]
            )
        }
    }

    func loadStats(leaguePlayerId: String) async -> LeagueAggrStats {
        guard let rows: [LeaguePlayerStats] = try? await client
            .from("league_player_stats")
            .select()
            .eq("player_id", value: leaguePlayerId)
            .execute()
            .value,
            !rows.isEmpty
        else { return LeagueAggrStats() }

        var aggr = LeagueAggrStats()
        aggr.gamesPlayed = Set(rows.map { $0.gameId }).count
        for row in rows {
            aggr.totalPoints += Double(row.points ?? 0)
            aggr.totalRebounds += Double(row.rebounds ?? 0)
            aggr.totalAssists += Double(row.assists ?? 0)
            aggr.totalSteals += Double(row.steals ?? 0)
            aggr.totalBlocks += Double(row.blocks ?? 0)
            aggr.fgMade += row.fieldGoalsMade ?? 0
            aggr.fgAttempted += row.fieldGoalsAttempted ?? 0
            aggr.threeMade += row.threePointersMade ?? 0
            aggr.threeAttempted += row.threePointersAttempted ?? 0
            aggr.ftMade += row.freeThrowsMade ?? 0
            aggr.ftAttempted += row.freeThrowsAttempted ?? 0
        }
        return aggr
    }

    func loadUpcomingGames(teamId: String, leagueId: String) async -> [LeagueGame] {
        return (try? await client
            .from("league_games")
            .select()
            .or("home_team_id.eq.\(teamId),away_team_id.eq.\(teamId)")
            .eq("status", value: "scheduled")
            .eq("league_id", value: leagueId)
            .order("scheduled_at", ascending: true)
            .limit(5)
            .execute()
            .value) ?? []
    }
}
