import SwiftUI
import Combine

/// The top-level Daily Game tab. Shows two cards — Mystery Player and Connections —
/// and lets the user drill into either. A completed game shows a live countdown
/// to the next puzzle (12 UTC cutoff).
struct DailyGameHubView: View {
    @Bindable var dmViewModel: DMViewModel

    // Live countdown tick
    @State private var tick: Int = 0
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // Completion state computed fresh on each render (cheap — UserDefaults read)
    private var mysteryDone: Bool {
        guard let data = UserDefaults.standard.data(forKey: "NETR.dailyGame.stats.v1"),
              let stats = try? JSONDecoder().decode(DailyGameStats.self, from: data)
        else { return false }
        return stats.lastPlayedDate == ConnectionsGameViewModel.todayUTCDateString()
    }
    private var connectionsDone: Bool { ConnectionsGameViewModel.didCompleteToday() }

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

                    Spacer()
                }
            }
            .onReceive(ticker) { _ in tick &+= 1 }
        }
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

