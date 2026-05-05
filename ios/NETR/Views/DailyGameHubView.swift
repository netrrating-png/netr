import SwiftUI
import Combine
import Supabase
import Auth
import PostgREST

/// The top-level Daily Game tab. Shows two cards — Mystery Player and Connections —
/// and lets the user drill into either. A completed game shows a live countdown
/// to the next puzzle (12 UTC cutoff).
struct DailyGameHubView: View {
    @Bindable var dmViewModel: DMViewModel

    // Live countdown tick
    @State private var tick: Int = 0
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // Completion state — per-user, sourced from Supabase so it doesn't leak
    // across accounts on the same device.
    @State private var mysteryDone: Bool = false
    @State private var connectionsDone: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()
                RadialGradient(
                    colors: [NETRTheme.neonGreen.opacity(0.10), .clear],
                    center: .top, startRadius: 20, endRadius: 420
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    header

                    Spacer(minLength: 0)

                    VStack(spacing: 14) {
                        NavigationLink {
                            DailyGameView(dmViewModel: dmViewModel)
                        } label: {
                            gameCard(
                                title: "MYSTERY PLAYER",
                                subtitle: "Guess today's NBA player from 5 hints",
                                icon: "user-search",
                                accent: NETRTheme.neonGreen,
                                done: mysteryDone
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ConnectionsGameView()
                        } label: {
                            gameCard(
                                title: "CONNECTIONS",
                                subtitle: "Find 4 groups of 4 NBA players",
                                icon: "grid-2x2",
                                accent: NETRTheme.purple,
                                done: connectionsDone
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 0)
                }
            }
            .onReceive(ticker) { _ in tick &+= 1 }
            .task(id: SupabaseManager.shared.session?.user.id.uuidString) {
                await refreshCompletion()
            }
        }
    }

    /// Queries Supabase for today's result rows for the signed-in user.
    /// Single source of truth — avoids the device-global UserDefaults problem
    /// where a completed game bleeds across accounts on the same device.
    private func refreshCompletion() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else {
            mysteryDone = false
            connectionsDone = false
            return
        }
        let today = ConnectionsGameViewModel.todayUTCDateString()
        let client = SupabaseManager.shared.client

        struct RowCount: Decodable { let puzzle_date: String }
        async let mystery: [RowCount] = (try? await client
            .from("nba_game_results")
            .select("puzzle_date")
            .eq("user_id", value: userId)
            .eq("puzzle_date", value: today)
            .limit(1)
            .execute()
            .value) ?? []
        async let connections: [RowCount] = (try? await client
            .from("nba_connections_results")
            .select("puzzle_date")
            .eq("user_id", value: userId)
            .eq("puzzle_date", value: today)
            .limit(1)
            .execute()
            .value) ?? []

        let (m, c) = await (mystery, connections)
        mysteryDone = !m.isEmpty
        connectionsDone = !c.isEmpty
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DAILY")
                    .font(NETRTheme.headingFont(size: .largeTitle))
                    .foregroundStyle(NETRTheme.text)
                    .neonGlow(NETRTheme.neonGreen, radius: 6)
                Text("Pick your game")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NETRTheme.subtext)
            }
            Spacer()
            DMHeaderButton(dmViewModel: dmViewModel)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: Card

    private func gameCard(
        title: String, subtitle: String,
        icon: String, accent: Color, done: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accent.opacity(0.15))
                    .frame(width: 64, height: 64)
                LucideIcon(icon, size: 30)
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(NETRTheme.text)
                    .tracking(0.6)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NETRTheme.subtext)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if done {
                    HStack(spacing: 4) {
                        LucideIcon("check-circle-2", size: 11)
                            .foregroundStyle(accent)
                        Text("Done · next " + CountdownFormatter.friendlyTimeToNextUTCDay())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                            .id(tick)    // force re-render on ticker
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()

            LucideIcon(done ? "lock" : "chevron-right", size: 18)
                .foregroundStyle(done ? NETRTheme.subtext : NETRTheme.text)
        }
        .padding(14)
        .background(NETRTheme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(done ? accent.opacity(0.35) : NETRTheme.border, lineWidth: 1)
        )
        .opacity(done ? 0.88 : 1)
    }
}

