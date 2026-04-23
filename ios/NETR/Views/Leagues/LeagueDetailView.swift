import SwiftUI

// MARK: - Color+Hex helper (used throughout league views)

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let rgb = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >>  8) & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

private extension League {
    var accent: Color {
        if let hex = accentColor, !hex.isEmpty, let c = Color(hex: hex) { return c }
        return NETRTheme.neonGreen
    }
}

// MARK: - Tab enum

private enum LeagueTab: CaseIterable {
    case overview, schedule, stats, teams
    var title: String {
        switch self {
        case .overview: return "OVERVIEW"
        case .schedule: return "SCHEDULE"
        case .stats:    return "STATS"
        case .teams:    return "TEAMS"
        }
    }
}

// MARK: - LeagueDetailView

struct LeagueDetailView: View {
    let myLeague: MyLeague
    @State private var vm = LeagueViewModel()
    @State private var tab: LeagueTab = .overview
    @State private var boxScoreGame: LeagueGame? = nil
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { myLeague.league.accent }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                headerBar
                NETRTheme.border.frame(height: 1)
                tabBar
                NETRTheme.border.frame(height: 1)
                Group {
                    switch tab {
                    case .overview: overviewTab
                    case .schedule: scheduleTab
                    case .stats:    statsTab
                    case .teams:    teamsTab
                    }
                }
            }
        }
        .task {
            await vm.loadLeagueDetail(
                leagueId:   myLeague.league.id,
                myPlayerId: myLeague.player.id
            )
        }
        .sheet(item: $boxScoreGame) { game in
            BoxScoreView(game: game, vm: vm, myLeague: myLeague)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.background)
        }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                ZStack {
                    Circle().fill(NETRTheme.card).frame(width: 36, height: 36)
                    LucideIcon("arrow-left", size: 16).foregroundStyle(NETRTheme.text)
                }
            }
            .buttonStyle(PressButtonStyle())

            if let logoUrl = myLeague.league.logoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                            .frame(width: 32, height: 32).clipShape(Circle())
                    } else {
                        Circle().fill(NETRTheme.card).frame(width: 32, height: 32)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(myLeague.league.name.uppercased())
                    .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)
                Text("\(myLeague.league.sport.capitalized) · \(myLeague.team.name.uppercased())")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NETRTheme.subtext)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(NETRTheme.surface)
    }

    // MARK: Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LeagueTab.allCases, id: \.self) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { tab = t }
                } label: {
                    VStack(spacing: 0) {
                        Text(t.title)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(tab == t ? accent : NETRTheme.subtext)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        Rectangle()
                            .fill(tab == t ? accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(PressButtonStyle())
            }
        }
        .background(NETRTheme.surface)
    }

    // MARK: - OVERVIEW TAB

    private var overviewTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                if let note = myLeague.league.announcement {
                    announcementBanner(note)
                }

                standingsSection
                Divider().background(NETRTheme.border).padding(.vertical, 20)
                resultsAndUpcomingSection
                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
    }

    private func announcementBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            LucideIcon("megaphone", size: 14).foregroundStyle(accent)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(NETRTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(14)
        .background(accent.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.2), lineWidth: 1))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: Standings

    private var standingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("STANDINGS")
                .padding(.horizontal, 20)

            if vm.standings.isEmpty {
                emptyRow("No standings yet")
            } else {
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        Text("#").frame(width: 28, alignment: .center)
                        Text("TEAM").frame(maxWidth: .infinity, alignment: .leading)
                        Text("W").frame(width: 32, alignment: .center)
                        Text("L").frame(width: 32, alignment: .center)
                        Text("PCT").frame(width: 48, alignment: .center)
                        Text("PF").frame(width: 40, alignment: .center)
                        Text("PA").frame(width: 40, alignment: .center)
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(0.8)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(NETRTheme.card)

                    ForEach(Array(vm.standings.enumerated()), id: \.element.id) { idx, row in
                        let isMyTeam = row.teamId == myLeague.team.id
                        HStack(spacing: 0) {
                            // Rank
                            Group {
                                if idx == 0 {
                                    Text("🏆").font(.system(size: 13))
                                } else {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(NETRTheme.subtext)
                                }
                            }
                            .frame(width: 28, alignment: .center)

                            // Color dot + name
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: row.color) ?? NETRTheme.subtext)
                                    .frame(width: 8, height: 8)
                                Text(row.teamName.uppercased())
                                    .font(.system(size: 12, weight: isMyTeam ? .black : .semibold)
                                        .width(.compressed))
                                    .foregroundStyle(isMyTeam ? accent : NETRTheme.text)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            statCell("\(row.wins)", width: 32)
                            statCell("\(row.losses)", width: 32)
                            statCell(row.pctString, width: 48)
                            statCell(row.ptsFor.map { String(Int($0)) } ?? "—", width: 40)
                            statCell(row.ptsAgainst.map { String(Int($0)) } ?? "—", width: 40)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isMyTeam ? accent.opacity(0.06) : Color.clear)
                        .overlay(alignment: .bottom) {
                            if idx < vm.standings.count - 1 {
                                NETRTheme.border.frame(height: 1)
                            }
                        }
                    }
                }
                .background(NETRTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 12))
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: Results + Upcoming

    private var resultsAndUpcomingSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // Recent Results
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("RECENT RESULTS")
                let finals = vm.games.filter { $0.isFinal }.suffix(5)
                if finals.isEmpty {
                    emptyRow("No results yet")
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(finals)) { game in
                            recentResultRow(game)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Upcoming
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("UPCOMING")
                let upcoming = vm.games.filter { $0.isScheduled }.prefix(5)
                if upcoming.isEmpty {
                    emptyRow("No upcoming games")
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(upcoming)) { game in
                            upcomingGameRow(game)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
    }

    private func recentResultRow(_ game: LeagueGame) -> some View {
        let home = teamName(game.homeTeamId)
        let away = teamName(game.awayTeamId)
        let homeWon = (game.homeScore ?? 0) > (game.awayScore ?? 0)

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(home.uppercased())
                    .font(.system(size: 10, weight: .black).width(.compressed))
                    .foregroundStyle(homeWon ? NETRTheme.text : NETRTheme.subtext)
                Spacer()
                Text("\(game.homeScore ?? 0)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(homeWon ? accent : NETRTheme.subtext)
            }
            HStack(spacing: 4) {
                Text(away.uppercased())
                    .font(.system(size: 10, weight: .black).width(.compressed))
                    .foregroundStyle(!homeWon ? NETRTheme.text : NETRTheme.subtext)
                Spacer()
                Text("\(game.awayScore ?? 0)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(!homeWon ? accent : NETRTheme.subtext)
            }
            Text(game.formattedDate)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(NETRTheme.subtext)
        }
        .padding(8)
        .background(NETRTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(NETRTheme.border, lineWidth: 1))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func upcomingGameRow(_ game: LeagueGame) -> some View {
        let isMyGame = game.homeTeamId == myLeague.team.id || game.awayTeamId == myLeague.team.id
        let confirmedCount = vm.attendanceCounts[game.id] ?? 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(teamName(game.homeTeamId).uppercased())
                    .font(.system(size: 10, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)
                Text("vs")
                    .font(.system(size: 9))
                    .foregroundStyle(NETRTheme.subtext)
                Text(teamName(game.awayTeamId).uppercased())
                    .font(.system(size: 10, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)
                Spacer()
            }
            Text("\(game.formattedDate) · \(game.formattedTime)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(NETRTheme.subtext)

            if confirmedCount > 0 {
                Text("\(confirmedCount) confirmed")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent)
            }

            if isMyGame {
                rsvpButtons(game: game)
            }
        }
        .padding(8)
        .background(isMyGame ? accent.opacity(0.05) : NETRTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
            isMyGame ? accent.opacity(0.2) : NETRTheme.border, lineWidth: 1))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func rsvpButtons(game: LeagueGame) -> some View {
        let current = vm.attendance[game.id]
        return HStack(spacing: 6) {
            rsvpPill(gameId: game.id, status: "yes",   label: "✓ In",    current: current)
            rsvpPill(gameId: game.id, status: "no",    label: "✕ Out",   current: current)
            rsvpPill(gameId: game.id, status: "maybe", label: "? Maybe", current: current)
        }
        .padding(.top, 2)
    }

    private func rsvpPill(gameId: String, status: String, label: String, current: String?) -> some View {
        let isActive = current == status
        return Button {
            Task {
                await vm.upsertAttendance(
                    gameId:    gameId,
                    playerId:  myLeague.player.id,
                    newStatus: status
                )
            }
        } label: {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isActive ? NETRTheme.background : NETRTheme.subtext)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? accent : NETRTheme.muted, in: Capsule())
        }
        .buttonStyle(PressButtonStyle())
    }

    // MARK: - SCHEDULE TAB

    private var scheduleTab: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: []) {
                if vm.games.isEmpty {
                    emptyRow("No games scheduled").padding(20)
                } else {
                    ForEach(vm.games) { game in
                        scheduleRow(game)
                        NETRTheme.border.frame(height: 1)
                    }
                }
            }
            .padding(.top, 8)
            Spacer(minLength: 40)
        }
    }

    private func scheduleRow(_ game: LeagueGame) -> some View {
        Button {
            if game.isFinal { boxScoreGame = game }
        } label: {
            HStack(spacing: 12) {
                // Date column
                VStack(alignment: .center, spacing: 2) {
                    Text(game.formattedDate)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(NETRTheme.subtext)
                    Text(game.formattedTime)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(NETRTheme.subtext)
                }
                .frame(width: 72)

                // Matchup
                VStack(alignment: .leading, spacing: 3) {
                    teamScoreRow(
                        name:  teamName(game.homeTeamId),
                        score: game.homeScore,
                        won:   game.isFinal && (game.homeScore ?? 0) > (game.awayScore ?? 0),
                        accent: accent
                    )
                    teamScoreRow(
                        name:  teamName(game.awayTeamId),
                        score: game.awayScore,
                        won:   game.isFinal && (game.awayScore ?? 0) > (game.homeScore ?? 0),
                        accent: accent
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Status / chevron
                if game.isFinal {
                    LucideIcon("chevron-right", size: 14).foregroundStyle(NETRTheme.subtext)
                } else {
                    Text(game.status.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(NETRTheme.subtext)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(NETRTheme.muted, in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .disabled(!game.isFinal)
    }

    private func teamScoreRow(name: String, score: Int?, won: Bool, accent: Color) -> some View {
        HStack(spacing: 8) {
            Text(name.uppercased())
                .font(.system(size: 13, weight: .black).width(.compressed))
                .foregroundStyle(won ? NETRTheme.text : NETRTheme.subtext)
            Spacer()
            if let s = score {
                Text("\(s)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(won ? accent : NETRTheme.subtext)
            }
        }
    }

    // MARK: - STATS TAB

    @State private var statSort: StatSort = .pts

    enum StatSort: String, CaseIterable {
        case pts = "PTS", reb = "REB", ast = "AST", stl = "STL", blk = "BLK"
    }

    private var statsTab: some View {
        let leaderboard = sortedLeaderboard
        let myId = myLeague.player.id

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                    Text("GP").frame(width: 32, alignment: .center)
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(NETRTheme.subtext).tracking(0.8)
                    ForEach(StatSort.allCases, id: \.self) { col in
                        Button { withAnimation { statSort = col } } label: {
                            HStack(spacing: 2) {
                                Text(col.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(statSort == col ? accent : NETRTheme.subtext)
                                    .tracking(0.8)
                                if statSort == col {
                                    LucideIcon("chevron-down", size: 8).foregroundStyle(accent)
                                }
                            }
                        }
                        .frame(width: 42, alignment: .center)
                        .buttonStyle(PressButtonStyle())
                    }
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(NETRTheme.card)

                NETRTheme.border.frame(height: 1)

                if leaderboard.isEmpty {
                    emptyRow("No stats recorded yet").padding(20)
                } else {
                    ForEach(Array(leaderboard.enumerated()), id: \.element.id) { idx, line in
                        let isMe = line.player.id == myId
                        HStack(spacing: 0) {
                            // Player + team
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color(hex: line.team.color) ?? NETRTheme.subtext)
                                        .frame(width: 6, height: 6)
                                    Text(line.player.displayName.uppercased())
                                        .font(.system(size: 12, weight: isMe ? .black : .semibold)
                                            .width(.compressed))
                                        .foregroundStyle(isMe ? accent : NETRTheme.text)
                                        .lineLimit(1)
                                }
                                Text(line.team.name.uppercased())
                                    .font(.system(size: 10, weight: .medium).width(.compressed))
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            statCell("\(line.gamesPlayed)", width: 32)
                            statCell(String(format: "%.1f", line.ppg), width: 42, highlight: statSort == .pts && isMe)
                            statCell(String(format: "%.1f", line.rpg), width: 42, highlight: statSort == .reb && isMe)
                            statCell(String(format: "%.1f", line.apg), width: 42, highlight: statSort == .ast && isMe)
                            statCell(String(format: "%.1f", line.spg), width: 42, highlight: statSort == .stl && isMe)
                            statCell(String(format: "%.1f", line.bpg), width: 42, highlight: statSort == .blk && isMe)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(isMe ? accent.opacity(0.06) : Color.clear)
                        .overlay(alignment: .bottom) {
                            if idx < leaderboard.count - 1 {
                                NETRTheme.border.frame(height: 1)
                            }
                        }
                    }
                }
            }
            .padding(.top, 8)
            Spacer(minLength: 40)
        }
    }

    private var sortedLeaderboard: [PlayerStatLine] {
        let board = vm.buildStatLeaderboard()
        switch statSort {
        case .pts: return board.sorted { $0.ppg > $1.ppg }
        case .reb: return board.sorted { $0.rpg > $1.rpg }
        case .ast: return board.sorted { $0.apg > $1.apg }
        case .stl: return board.sorted { $0.spg > $1.spg }
        case .blk: return board.sorted { $0.bpg > $1.bpg }
        }
    }

    // MARK: - TEAMS TAB

    private var teamsTab: some View {
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return ScrollView(showsIndicators: false) {
            if vm.allTeams.isEmpty {
                emptyRow("No teams").padding(20)
            } else {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(vm.allTeams) { team in
                        teamCard(team)
                    }
                }
                .padding(20)
            }
            Spacer(minLength: 40)
        }
    }

    private func teamCard(_ team: LeagueTeam) -> some View {
        let standing = vm.standings.first { $0.teamId == team.id }
        let roster   = vm.allPlayers.filter { $0.teamId == team.id }
        let isMyTeam = team.id == myLeague.team.id
        let tColor   = Color(hex: team.color) ?? NETRTheme.subtext

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(tColor)
                    .frame(width: 28, height: 28)
                Text(team.name.uppercased())
                    .font(.system(size: 13, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            if let s = standing {
                Text("\(s.wins)-\(s.losses)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(NETRTheme.subtext)
            }

            Text("\(roster.count) player\(roster.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(NETRTheme.subtext)

            // Roster list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(roster) { p in
                    HStack(spacing: 6) {
                        if let num = p.jerseyNumber {
                            Text("#\(num)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(tColor)
                                .frame(width: 22, alignment: .trailing)
                        }
                        Text(p.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NETRTheme.text)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NETRTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
            isMyTeam ? tColor.opacity(0.4) : NETRTheme.border, lineWidth: isMyTeam ? 1.5 : 1))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func teamName(_ teamId: String) -> String {
        vm.allTeams.first { $0.id == teamId }?.name
            ?? myLeague.league.name
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(NETRTheme.subtext)
            .tracking(1.5)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(NETRTheme.subtext)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }

    private func statCell(_ value: String, width: CGFloat, highlight: Bool = false) -> some View {
        Text(value)
            .font(.system(size: 11, weight: highlight ? .bold : .regular, design: .monospaced))
            .foregroundStyle(highlight ? accent : NETRTheme.text)
            .frame(width: width, alignment: .center)
    }
}

// MARK: - BoxScoreView

struct BoxScoreView: View {
    let game: LeagueGame
    let vm: LeagueViewModel
    let myLeague: MyLeague
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { myLeague.league.accent }

    private var homeTeam: LeagueTeam? { vm.allTeams.first { $0.id == game.homeTeamId } }
    private var awayTeam: LeagueTeam? { vm.allTeams.first { $0.id == game.awayTeamId } }

    private var homeScore: Int { game.homeScore ?? 0 }
    private var awayScore: Int { game.awayScore ?? 0 }
    private var homeWon: Bool  { homeScore > awayScore }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle().fill(NETRTheme.card).frame(width: 36, height: 36)
                            LucideIcon("x", size: 16).foregroundStyle(NETRTheme.text)
                        }
                    }
                    .buttonStyle(PressButtonStyle())
                    Spacer()
                    Text("BOX SCORE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(NETRTheme.subtext)
                        .tracking(1.5)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                NETRTheme.border.frame(height: 1)

                // Final score hero
                HStack(spacing: 0) {
                    scoreHero(
                        name:  homeTeam?.name ?? "HOME",
                        score: homeScore,
                        won:   homeWon
                    )
                    Text("FINAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NETRTheme.subtext)
                        .tracking(1.5)
                        .frame(width: 50)
                    scoreHero(
                        name:  awayTeam?.name ?? "AWAY",
                        score: awayScore,
                        won:   !homeWon
                    )
                }
                .padding(.vertical, 20)
                .background(NETRTheme.surface)

                NETRTheme.border.frame(height: 1)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if let home = homeTeam {
                            teamBoxSection(team: home)
                            NETRTheme.border.frame(height: 8)
                        }
                        if let away = awayTeam {
                            teamBoxSection(team: away)
                        }
                    }
                    Spacer(minLength: 40)
                }
            }
        }
    }

    private func scoreHero(name: String, score: Int, won: Bool) -> some View {
        VStack(spacing: 4) {
            Text(name.uppercased())
                .font(.system(size: 13, weight: .black).width(.compressed))
                .foregroundStyle(won ? NETRTheme.text : NETRTheme.subtext)
                .lineLimit(1)
            Text("\(score)")
                .font(.system(size: 40, weight: .black, design: .monospaced))
                .foregroundStyle(won ? accent : NETRTheme.subtext)
        }
        .frame(maxWidth: .infinity)
    }

    private func teamBoxSection(team: LeagueTeam) -> some View {
        let stats  = vm.boxScoreStats(gameId: game.id).filter { $0.teamId == team.id }
        let myId   = myLeague.player.id

        return VStack(spacing: 0) {
            // Team header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: team.color) ?? NETRTheme.subtext)
                    .frame(width: 10, height: 10)
                Text(team.name.uppercased())
                    .font(.system(size: 12, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(NETRTheme.card)

            NETRTheme.border.frame(height: 1)

            // Column headers
            boxHeader

            NETRTheme.border.frame(height: 1)

            if stats.isEmpty {
                Text("No stats recorded")
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
                    .padding(16)
            } else {
                ForEach(Array(stats.enumerated()), id: \.element.id) { idx, stat in
                    let isMe = stat.playerId == myId
                    let player = vm.allPlayers.first { $0.id == stat.playerId }
                    boxRow(stat: stat, playerName: player?.displayName ?? "—", isMe: isMe)
                    if idx < stats.count - 1 {
                        NETRTheme.border.frame(height: 1)
                    }
                }
            }
        }
    }

    private var boxHeader: some View {
        HStack(spacing: 0) {
            Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(["PTS","REB","AST","STL","BLK","TO","FG","3P","FT"], id: \.self) { col in
                Text(col)
                    .frame(width: boxColWidth(col), alignment: .center)
            }
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(NETRTheme.subtext)
        .tracking(0.6)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(NETRTheme.surface)
    }

    private func boxRow(stat: LeaguePlayerStat, playerName: String, isMe: Bool) -> some View {
        HStack(spacing: 0) {
            Text(playerName.uppercased())
                .font(.system(size: 11, weight: isMe ? .black : .medium).width(.compressed))
                .foregroundStyle(isMe ? accent : NETRTheme.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            boxCell("\(stat.points)",    "PTS", isMe)
            boxCell("\(stat.rebounds)",  "REB", isMe)
            boxCell("\(stat.assists)",   "AST", isMe)
            boxCell("\(stat.steals)",    "STL", isMe)
            boxCell("\(stat.blocks)",    "BLK", isMe)
            boxCell("\(stat.turnovers)", "TO",  isMe)
            boxCell(stat.fgString,       "FG",  isMe)
            boxCell(stat.tpString,       "3P",  isMe)
            boxCell(stat.ftString,       "FT",  isMe)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(isMe ? accent.opacity(0.06) : Color.clear)
    }

    private func boxCell(_ value: String, _ col: String, _ isMe: Bool) -> some View {
        Text(value)
            .font(.system(size: 10, weight: isMe ? .bold : .regular, design: .monospaced))
            .foregroundStyle(isMe ? accent : NETRTheme.text)
            .frame(width: boxColWidth(col), alignment: .center)
    }

    private func boxColWidth(_ col: String) -> CGFloat {
        switch col {
        case "FG", "3P", "FT": return 38
        default: return 28
        }
    }
}
