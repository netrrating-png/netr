import SwiftUI
import Supabase
import PostgREST

struct LeagueDetailView: View {
    let entry: LeagueEntry
    @State private var vm = LeaguesViewModel()
    @State private var stats = LeagueAggrStats()
    @State private var upcomingGames: [LeagueGame] = []
    @State private var teamMap: [String: LeagueTeam] = [:]
    @Environment(\.dismiss) private var dismiss

    private var accent: Color {
        Color(hex: entry.league.accentColor ?? "#39FF14")
    }
    private var teamColor: Color {
        Color(hex: entry.team.color ?? "#39FF14")
    }
    private var record: String {
        guard let s = entry.standing else { return "—" }
        return "\(s.wins)-\(s.losses)"
    }

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0E").ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Divider().background(Color.white.opacity(0.08)).padding(.vertical, 20)
                    statsSection
                    Divider().background(Color.white.opacity(0.08)).padding(.vertical, 20)
                    upcomingSection
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(entry.league.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
            }
        }
        .task {
            stats = await vm.loadStats(leaguePlayerId: entry.leaguePlayer.id)
            upcomingGames = await vm.loadUpcomingGames(teamId: entry.team.id, leagueId: entry.league.id)
            await loadTeams()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                leagueLogo
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.league.name)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(accent)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(teamColor)
                            .frame(width: 10, height: 10)
                        Text(entry.team.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NETRTheme.text)
                    }
                    if let season = entry.league.season {
                        Text(season)
                            .font(.system(size: 12))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(record)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(NETRTheme.text)
                    Text("W-L")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
    }

    @ViewBuilder
    private var leagueLogo: some View {
        if let urlStr = entry.league.logoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                default:
                    defaultLeagueIcon
                }
            }
        } else {
            defaultLeagueIcon
        }
    }

    private var defaultLeagueIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(accent.opacity(0.15))
                .frame(width: 52, height: 52)
            Image(systemName: "trophy.fill")
                .font(.system(size: 22))
                .foregroundStyle(accent)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MY STATS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(NETRTheme.subtext)

            if stats.gamesPlayed == 0 {
                Text("No stats recorded yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.muted)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    LeagueStatPill(value: "\(stats.gamesPlayed)", label: "GP")
                    LeagueStatPill(value: stats.ppg, label: "PTS", accent: accent)
                    LeagueStatPill(value: stats.rpg, label: "REB")
                    LeagueStatPill(value: stats.apg, label: "AST")
                    LeagueStatPill(value: stats.spg, label: "STL")
                    LeagueStatPill(value: stats.bpg, label: "BLK")
                    LeagueStatPill(value: stats.fgPct, label: "FG%", accent: accent)
                    LeagueStatPill(value: stats.threePct, label: "3P%", accent: accent)
                    LeagueStatPill(value: stats.ftPct, label: "FT%")
                }
            }
        }
    }

    // MARK: - Upcoming Games

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UPCOMING GAMES")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(NETRTheme.subtext)

            if upcomingGames.isEmpty {
                Text("No upcoming games scheduled.")
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(upcomingGames) { game in
                        gameCard(game: game)
                    }
                }
            }
        }
    }

    private func gameCard(game: LeagueGame) -> some View {
        let isHome = game.homeTeamId == entry.team.id
        let opponentId = isHome ? game.awayTeamId : game.homeTeamId
        let opponent = teamMap[opponentId]
        let prefix = isHome ? "vs" : "@"
        let (dayStr, timeStr) = formatScheduledAt(game.scheduledAt)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayStr)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(NETRTheme.subtext)
                Text(timeStr)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(NETRTheme.text)
            }
            .frame(width: 72, alignment: .leading)

            Divider()
                .frame(height: 32)
                .background(Color.white.opacity(0.1))

            HStack(spacing: 6) {
                Text(prefix)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)
                if let opp = opponent {
                    Circle()
                        .fill(Color(hex: opp.color ?? "#555555"))
                        .frame(width: 10, height: 10)
                    Text(opp.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                } else {
                    Text("TBD")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer()

            if let loc = game.location {
                Text(loc)
                    .font(.system(size: 10))
                    .foregroundStyle(NETRTheme.muted)
                    .lineLimit(1)
                    .frame(maxWidth: 80, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "#0A0A0E"))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func loadTeams() async {
        let allTeamIds = Array(Set(upcomingGames.flatMap { [$0.homeTeamId, $0.awayTeamId] }))
        guard !allTeamIds.isEmpty else { return }
        guard let teams: [LeagueTeam] = try? await SupabaseManager.shared.client
            .from("league_teams")
            .select()
            .in("id", values: allTeamIds)
            .execute()
            .value
        else { return }
        teamMap = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
    }

    private func formatScheduledAt(_ iso: String?) -> (String, String) {
        guard let iso else { return ("TBD", "—") }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: iso)
        }()
        guard let date else { return ("TBD", "—") }
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEE · MMM d"
        dayFmt.locale = Locale(identifier: "en_US_POSIX")
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"
        timeFmt.locale = Locale(identifier: "en_US_POSIX")
        return (dayFmt.string(from: date).uppercased(), timeFmt.string(from: date))
    }
}

// MARK: - Stat Pill

private struct LeagueStatPill: View {
    let value: String
    let label: String
    var accent: Color = NETRTheme.text

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(NETRTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(NETRTheme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
    }
}
