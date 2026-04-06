import SwiftUI
import PostgREST

struct FollowListView: View {
    enum Mode { case followers, following }

    let userId: String
    let mode: Mode
    let initialCount: Int

    @Environment(\.dismiss) private var dismiss
    @State private var players: [FollowPlayer] = []
    @State private var filteredPlayers: [FollowPlayer] = []
    @State private var searchText: String = ""
    @State private var isLoading = true
    @State private var selectedUserId: String?
    @State private var showUnfollowConfirm = false
    @State private var unfollowTarget: FollowPlayer?
    @State private var appearedIds: Set<String> = []
    @State private var hasLoadedAll = false
    @State private var page = 0

    private let pageSize = 30
    private let client = SupabaseManager.shared.client
    private var currentUserId: String? {
        SupabaseManager.shared.session?.user.id.uuidString.lowercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                if isLoading && players.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(NETRTheme.neonGreen)
                            .scaleEffect(1.2)
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                } else if players.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        searchBar
                        playerList
                    }
                }
            }
            .navigationTitle(mode == .followers ? "Followers" : "Following")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(mode == .followers ? "Followers" : "Following")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(NETRTheme.text)
                        Text("\(initialCount) \(mode == .followers ? (initialCount == 1 ? "follower" : "followers") : "following")")
                            .font(.system(size: 11))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NETRTheme.neonGreen)
                }
            }
            .toolbarBackground(NETRTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationBackground(NETRTheme.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await loadPage() }
        .fullScreenCover(item: $selectedUserId) { uid in
            PublicPlayerProfileView(userId: uid)
        }
        .alert("Unfollow \(unfollowTarget?.displayHandle ?? "")?", isPresented: $showUnfollowConfirm) {
            Button("Unfollow", role: .destructive) {
                if let target = unfollowTarget {
                    Task { await toggleFollow(target) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: searchText) { _, newValue in
            filterPlayers(query: newValue)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            LucideIcon("search", size: 16)
                .foregroundStyle(NETRTheme.subtext)

            TextField("Search by name or username", text: $searchText)
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.text)
                .tint(NETRTheme.neonGreen)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    LucideIcon("x", size: 14)
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
        .clipShape(.rect(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Player List

    private var playerList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredPlayers.enumerated()), id: \.element.id) { index, player in
                    VStack(spacing: 0) {
                        FollowPlayerRowView(
                            player: player,
                            isFollowing: player.isFollowing,
                            showFollowButton: currentUserId != nil && currentUserId != player.id,
                            onFollowTap: {
                                if player.isFollowing && mode == .following {
                                    unfollowTarget = player
                                    showUnfollowConfirm = true
                                } else {
                                    Task { await toggleFollow(player) }
                                }
                            },
                            onRowTap: {
                                selectedUserId = player.id
                            }
                        )
                        .opacity(appearedIds.contains(player.id) ? 1 : 0)
                        .offset(y: appearedIds.contains(player.id) ? 0 : 8)
                        .onAppear {
                            // Staggered animation
                            let delay = Double(index) * 0.03
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(delay)) {
                                appearedIds.insert(player.id)
                            }

                            // Infinite scroll
                            if player.id == filteredPlayers.last?.id && !hasLoadedAll && !isLoading {
                                Task { await loadPage() }
                            }
                        }

                        Rectangle()
                            .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .frame(height: 0.5)
                            .padding(.leading, 86)
                    }
                }

                if isLoading && !players.isEmpty {
                    ProgressView()
                        .tint(NETRTheme.neonGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
        .refreshable {
            page = 0
            hasLoadedAll = false
            players = []
            filteredPlayers = []
            appearedIds = []
            await loadPage()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            LucideIcon(mode == .followers ? "users" : "user-search", size: 40)
                .foregroundStyle(NETRTheme.muted)

            Text(mode == .followers
                ? "No followers yet"
                : "Not following anyone yet")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(NETRTheme.text)

            Text(mode == .followers
                ? "Share your profile to get found."
                : "Discover players on the feed.")
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search Filter

    private func filterPlayers(query: String) {
        if query.isEmpty {
            filteredPlayers = players
        } else {
            let q = query.lowercased()
            filteredPlayers = players.filter {
                $0.displayName.lowercased().contains(q) ||
                $0.username.lowercased().contains(q)
            }
        }
    }

    // MARK: - Data Loading

    private func loadPage() async {
        isLoading = true
        defer { isLoading = false }

        nonisolated struct FollowRow: Decodable, Sendable {
            let followerId: String?
            let followingId: String?
            nonisolated enum CodingKeys: String, CodingKey {
                case followerId = "follower_id"
                case followingId = "following_id"
            }
        }

        // Step 1: get IDs from follows table with pagination
        let targetIds: [String]
        do {
            let offset = page * pageSize
            if mode == .followers {
                let rows: [FollowRow] = try await client
                    .from("follows")
                    .select("follower_id")
                    .eq("following_id", value: userId)
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute()
                    .value
                targetIds = rows.compactMap { $0.followerId }
            } else {
                let rows: [FollowRow] = try await client
                    .from("follows")
                    .select("following_id")
                    .eq("follower_id", value: userId)
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute()
                    .value
                targetIds = rows.compactMap { $0.followingId }
            }
        } catch {
            print("[NETR FollowList] Fetch error: \(error)")
            return
        }

        if targetIds.count < pageSize {
            hasLoadedAll = true
        }

        guard !targetIds.isEmpty else { return }

        // Step 2: fetch profiles
        nonisolated struct SlimProfile: Decodable, Sendable {
            let id: String
            let fullName: String?
            let username: String?
            let avatarUrl: String?
            let netrScore: Double?
            nonisolated enum CodingKeys: String, CodingKey {
                case id
                case fullName = "full_name"
                case username
                case avatarUrl = "avatar_url"
                case netrScore = "netr_score"
            }
        }

        let profiles: [SlimProfile]
        do {
            profiles = try await client
                .from("profiles")
                .select("id, full_name, username, avatar_url, netr_score")
                .in("id", values: targetIds)
                .execute()
                .value
        } catch {
            print("[NETR FollowList] Profiles fetch error: \(error)")
            return
        }

        // Step 3: check which ones the viewer follows (for follow button state)
        var viewerFollowingSet: Set<String> = []
        if let currentId = currentUserId, !profiles.isEmpty {
            nonisolated struct FRow: Decodable, Sendable {
                let followingId: String
                nonisolated enum CodingKeys: String, CodingKey { case followingId = "following_id" }
            }
            if let rows: [FRow] = try? await client
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: currentId)
                .in("following_id", values: profiles.map { $0.id })
                .execute()
                .value {
                viewerFollowingSet = Set(rows.map { $0.followingId })
            }
        }

        // Step 4: for followers mode, check mutual follows
        var mutualSet: Set<String> = []
        if mode == .followers, let currentId = currentUserId ?? Optional(userId) {
            nonisolated struct MRow: Decodable, Sendable {
                let followingId: String
                nonisolated enum CodingKeys: String, CodingKey { case followingId = "following_id" }
            }
            if let rows: [MRow] = try? await client
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: userId)
                .in("following_id", values: targetIds)
                .execute()
                .value {
                mutualSet = Set(rows.map { $0.followingId })
            }
        }

        // Build FollowPlayer models preserving order from targetIds
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        let newPlayers: [FollowPlayer] = targetIds.compactMap { id -> FollowPlayer? in
            guard let p = profileMap[id] else { return nil }
            let score = p.netrScore
            return FollowPlayer(
                id: p.id,
                displayName: p.fullName ?? p.username ?? "Player",
                username: p.username ?? "player",
                avatarUrl: p.avatarUrl,
                netrScore: score,
                tierName: NETRRating.tierName(for: score),
                tierColor: NETRRating.color(for: score),
                isFollowing: viewerFollowingSet.contains(p.id),
                isMutual: mutualSet.contains(p.id)
            )
        }

        // Sort: mutual first (followers mode), then alphabetical
        let sorted: [FollowPlayer]
        if mode == .followers {
            sorted = newPlayers.sorted { a, b in
                if a.isMutual != b.isMutual { return a.isMutual }
                return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
            }
        } else {
            sorted = newPlayers // keep original order (most recent) for following
        }

        players.append(contentsOf: sorted)
        page += 1
        filterPlayers(query: searchText)
    }

    // MARK: - Toggle Follow

    private func toggleFollow(_ player: FollowPlayer) async {
        guard let currentId = currentUserId, currentId != player.id else { return }

        nonisolated struct FollowPayload: Encodable, Sendable {
            let followerId: String
            let followingId: String
            nonisolated enum CodingKeys: String, CodingKey {
                case followerId = "follower_id"
                case followingId = "following_id"
            }
        }

        guard let idx = players.firstIndex(where: { $0.id == player.id }) else { return }
        let wasFollowing = players[idx].isFollowing
        players[idx].isFollowing = !wasFollowing
        filterPlayers(query: searchText)

        do {
            if wasFollowing {
                try await client
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: currentId)
                    .eq("following_id", value: player.id)
                    .execute()
            } else {
                try await client
                    .from("follows")
                    .insert(FollowPayload(followerId: currentId, followingId: player.id))
                    .execute()
            }
        } catch {
            players[idx].isFollowing = wasFollowing
            filterPlayers(query: searchText)
            print("[NETR FollowList] Follow toggle error: \(error)")
        }
    }
}

