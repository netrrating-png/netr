import SwiftUI
import Supabase
import Auth
import PostgREST

// Shared leaderboard player model used by CourtLeaderboardView and CourtDetailView
nonisolated struct LeaderboardEntry: Identifiable, Decodable, Sendable {
    let id: String
    let fullName: String?
    let username: String?
    let avatarUrl: String?
    let netrScore: Double?
    let position: String?
    let vibeScore: Double?

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case username
        case avatarUrl = "avatar_url"
        case netrScore = "netr_score"
        case position
        case vibeScore = "vibe_score"
    }

    var displayName: String { fullName ?? username ?? "Player" }

    nonisolated static func load(courtId: String) async -> [LeaderboardEntry] {
        let client = SupabaseManager.shared.client

        nonisolated struct UserIdRow: Decodable, Sendable {
            let userId: String
            nonisolated enum CodingKeys: String, CodingKey { case userId = "user_id" }
        }

        do {
            let favs: [UserIdRow] = try await client
                .from("court_favorites")
                .select("user_id")
                .eq("court_id", value: courtId)
                .eq("is_home_court", value: true)
                .execute()
                .value

            let userIds = favs.map { $0.userId }
            guard !userIds.isEmpty else { return [] }

            let entries: [LeaderboardEntry] = try await client
                .from("profiles")
                .select("id, full_name, username, avatar_url, netr_score, position, vibe_score")
                .in("id", values: userIds)
                .order("netr_score", ascending: false, nullsFirst: false)
                .limit(20)
                .execute()
                .value

            return entries
        } catch {
            print("[NETR] Leaderboard load error: \(error)")
            return []
        }
    }
}

// MARK: - Standalone leaderboard sheet (opened from profile home court row)

struct CourtLeaderboardView: View {
    let court: Court
    @State private var players: [LeaderboardEntry] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(NETRTheme.neonGreen)
                } else if players.isEmpty {
                    VStack(spacing: 16) {
                        LucideIcon("trophy", size: 40)
                            .foregroundStyle(NETRTheme.muted)
                        Text("No players yet")
                            .font(.headline)
                            .foregroundStyle(NETRTheme.text)
                        Text("Be the first to set this as your Home Court")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    leaderboardContent
                }
            }
            .navigationTitle("Top Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        LucideIcon("x-circle").foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
        }
        .task { await load() }
    }

    private var leaderboardContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                leaderboardHeader
                if players.count >= 3 {
                    podiumView.padding(.horizontal, 16).padding(.top, 16)
                }
                LazyVStack(spacing: 0) {
                    ForEach(Array(players.enumerated()), id: \.element.id) { idx, player in
                        LeaderboardRowView(player: player, rank: idx + 1, showIfTopThree: players.count >= 3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var leaderboardHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                LucideIcon("house", size: 13)
                    .foregroundStyle(NETRTheme.neonGreen)
                Text("HOME COURT LEADERBOARD")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(NETRTheme.subtext)
            }
            Text(court.name)
                .font(.system(.title2, design: .default, weight: .black).width(.compressed))
                .foregroundStyle(NETRTheme.text)
            Text(court.neighborhood)
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)

            HStack(spacing: 6) {
                Circle()
                    .fill(NETRTheme.gold)
                    .frame(width: 6, height: 6)
                Text("\(players.count) players claim this court")
                    .font(.caption)
                    .foregroundStyle(NETRTheme.subtext)
            }
            .padding(.top, 2)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PodiumPlayerView(player: players[1], rank: 2, podiumHeight: 70)
            PodiumPlayerView(player: players[0], rank: 1, podiumHeight: 90)
            PodiumPlayerView(player: players[2], rank: 3, podiumHeight: 55)
        }
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        isLoading = true
        players = await LeaderboardEntry.load(courtId: court.id)
        isLoading = false
    }
}

// MARK: - Podium card (top 3)

struct PodiumPlayerView: View {
    let player: LeaderboardEntry
    let rank: Int
    let podiumHeight: CGFloat

    private var rankColor: Color {
        switch rank {
        case 1: return NETRTheme.gold
        case 2: return Color(hex: "#C0C0C0")
        default: return Color(hex: "#CD7F32")
        }
    }

    private var avatarSize: CGFloat { rank == 1 ? 60 : 48 }

    var body: some View {
        VStack(spacing: 6) {
            AvatarView(url: player.avatarUrl, name: player.displayName, size: avatarSize, borderColor: rankColor, borderWidth: 2)

            Text(player.displayName.components(separatedBy: " ").first ?? player.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NETRTheme.text)
                .lineLimit(1)

            if let score = player.netrScore {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(NETRRating.color(for: score))
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(rankColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(rankColor.opacity(0.4), lineWidth: 1))
                Text("#\(rank)")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(rankColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: podiumHeight)
        }
        .frame(maxWidth: .infinity)
    }

}

// MARK: - Single leaderboard row (reused in CourtDetailView tab)

struct LeaderboardRowView: View {
    let player: LeaderboardEntry
    let rank: Int
    let showIfTopThree: Bool // if true, rows 1-3 are hidden (shown in podium)

    private var vibeTier: VibeTier { VibeTier.display(score: player.vibeScore) }
    private var vibeColor: Color { Color(red: vibeTier.color.red, green: vibeTier.color.green, blue: vibeTier.color.blue) }

    var body: some View {
        if showIfTopThree && rank <= 3 {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("#\(rank)")
                        .font(.system(size: 13, weight: .black).width(.compressed))
                        .foregroundStyle(NETRTheme.subtext)
                        .frame(width: 28, alignment: .center)

                    AvatarView(url: player.avatarUrl, name: player.displayName, size: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NETRTheme.text)
                        if let pos = player.position {
                            Text(pos.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(NETRTheme.subtext)
                                .tracking(0.8)
                        }
                    }

                    Spacer()

                    Circle()
                        .fill(vibeColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: vibeColor, radius: 4)

                    if let score = player.netrScore {
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(NETRRating.color(for: score))
                    } else {
                        Text("--")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)

                Divider().background(NETRTheme.border)
            }
        }
    }
}
