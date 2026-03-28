import SwiftUI
import Supabase
import Auth
import PostgREST

@Observable
class MyGamesViewModel {
    var activeGames: [DiscoverableGame] = []
    var upcomingGames: [DiscoverableGame] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let client = SupabaseManager.shared.client

    func load() async {
        isLoading = true
        errorMessage = nil

        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else {
            isLoading = false
            return
        }

        do {
            nonisolated struct JoinedGameRow: Decodable, Sendable {
                let gameId: String
                let removed: Bool?
                nonisolated enum CodingKeys: String, CodingKey {
                    case gameId = "game_id"
                    case removed
                }
            }

            let joined: [JoinedGameRow] = try await client
                .from("game_players")
                .select("game_id, removed")
                .eq("user_id", value: userId)
                .execute()
                .value

            let gameIds = joined.filter { !($0.removed ?? false) }.map { $0.gameId }

            if gameIds.isEmpty {
                activeGames = []
                upcomingGames = []
                isLoading = false
                return
            }

            // Three-level fallback: strip FK joins if PostgREST schema cache is stale
            // or FK constraints aren't set up yet.
            let queryLevels = [
                // Level 1: full joins (requires host_id→profiles FK + court_id→courts FK in PostgREST cache)
                """
                id, court_id, host_id, join_code, format, skill_level, status, max_players, created_at, scheduled_at,
                courts(name),
                host:profiles!games_host_id_fkey(full_name, username),
                game_players(count)
                """,
                // Level 2: courts only (requires court_id→courts FK)
                """
                id, court_id, host_id, join_code, format, skill_level, status, max_players, created_at, scheduled_at,
                courts(name),
                game_players(count)
                """,
                // Level 3: bare — no FK joins at all
                "id, court_id, host_id, join_code, format, skill_level, status, max_players, created_at, scheduled_at",
            ]

            var allGames: [DiscoverableGame] = []
            for (i, selectQuery) in queryLevels.enumerated() {
                do {
                    allGames = try await client
                        .from("games")
                        .select(selectQuery)
                        .in("id", values: gameIds)
                        .in("status", values: ["live", "active", "waiting", "scheduled"])
                        .order("created_at", ascending: false)
                        .execute()
                        .value
                    print("[MyGames] level \(i+1) succeeded: \(allGames.count) games")
                    break
                } catch {
                    print("[MyGames] level \(i+1) failed: \(error.localizedDescription)")
                    if i == queryLevels.count - 1 { throw error }
                }
            }

            activeGames = allGames.filter { $0.status == "live" || $0.status == "active" || $0.status == "waiting" }
            upcomingGames = allGames.filter { $0.status == "scheduled" }
                .sorted { ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture) }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct MyGamesView: View {
    @State private var vm = MyGamesViewModel()
    @State private var gameViewModel = GameViewModel()
    @State private var showLobby: Bool = false

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            if vm.isLoading {
                VStack(spacing: 14) {
                    ProgressView().tint(NETRTheme.neonGreen).scaleEffect(1.2)
                    Text("Loading your games\u{2026}")
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.subtext)
                }
            } else if vm.activeGames.isEmpty && vm.upcomingGames.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MY GAMES")
                                .font(NETRTheme.headingFont(size: .title2))
                                .foregroundStyle(NETRTheme.text)
                            Text("Games you created or joined")
                                .font(.subheadline)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .padding(.horizontal, 20)

                        if !vm.activeGames.isEmpty {
                            sectionHeader(title: "ACTIVE", icon: "circle-dot", color: NETRTheme.neonGreen, count: vm.activeGames.count)

                            ForEach(vm.activeGames) { game in
                                MyGameCard(game: game, isActive: true) {
                                    Task { await openGame(game) }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        if !vm.upcomingGames.isEmpty {
                            sectionHeader(title: "UPCOMING", icon: "clock", color: NETRTheme.gold, count: vm.upcomingGames.count)

                            ForEach(vm.upcomingGames) { game in
                                MyGameCard(game: game, isActive: false) {
                                    Task { await openGame(game) }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, 16)
                }
                .refreshable { await vm.load() }
            }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showLobby) {
            GameLobbyView(viewModel: gameViewModel, onDismiss: {
                showLobby = false
                Task { await vm.load() }
            })
        }
    }

    private func openGame(_ game: DiscoverableGame) async {
        // User is already in this game — just fetch it and open the lobby, don't try to join again
        do {
            let found: SupabaseGame = try await SupabaseManager.shared.client
                .from("games")
                .select()
                .eq("id", value: game.id)
                .single()
                .execute()
                .value
            gameViewModel.game = found
        } catch {
            return
        }
        await gameViewModel.subscribeToLobby(gameId: game.id)
        await gameViewModel.loadPlayers(gameId: game.id)
        showLobby = true
    }

    private func sectionHeader(title: String, icon: String, color: Color, count: Int) -> some View {
        HStack(spacing: 6) {
            LucideIcon(icon, size: 12)
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1.3)
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.12), in: .capsule)
        }
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(NETRTheme.muted.opacity(0.3)).frame(width: 80, height: 80)
                LucideIcon("trophy", size: 36)
                    .foregroundStyle(NETRTheme.muted)
            }
            VStack(spacing: 8) {
                Text("NO GAMES YET")
                    .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)
                Text("Create or join a game to see it here.")
                    .font(.system(size: 14))
                    .foregroundStyle(NETRTheme.subtext)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - My Game Card

private struct MyGameCard: View {
    let game: DiscoverableGame
    let isActive: Bool
    let onTap: () -> Void

    private var scheduledTimeText: String {
        guard let date = game.scheduledDate else { return "" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((isActive ? NETRTheme.neonGreen : NETRTheme.gold).opacity(0.15))
                        .frame(width: 44, height: 44)
                    if isActive {
                        LucideIcon("circle-dot", size: 20)
                            .foregroundStyle(NETRTheme.neonGreen)
                    } else {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(NETRTheme.gold)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(game.courtName)
                        .font(.system(.body, design: .default, weight: .black).width(.compressed))
                        .foregroundStyle(NETRTheme.text)

                    HStack(spacing: 6) {
                        if let fmt = game.format {
                            Text(fmt)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isActive ? NETRTheme.neonGreen : NETRTheme.gold)
                        }
                        Text("\u{00B7}").foregroundStyle(NETRTheme.muted)
                        HStack(spacing: 4) {
                            LucideIcon("users", size: 10)
                                .foregroundStyle(NETRTheme.subtext)
                            Text("\(game.joinedCount)/\(game.maxPlayers ?? 10)")
                                .font(.system(size: 12))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }

                    if !isActive {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundStyle(NETRTheme.gold)
                            Text(scheduledTimeText)
                                .font(.system(size: 12))
                                .foregroundStyle(NETRTheme.gold)
                        }
                    } else {
                        Text(game.startedAgo)
                            .font(.system(size: 12))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }

                Spacer()

                LucideIcon("chevron-right", size: 14)
                    .foregroundStyle(NETRTheme.muted)
            }
            .padding(14)
            .background(NETRTheme.card, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isActive ? NETRTheme.neonGreen.opacity(0.3) : NETRTheme.gold.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PressButtonStyle())
    }
}
