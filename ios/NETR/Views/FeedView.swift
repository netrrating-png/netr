import SwiftUI
import Auth
import Supabase
import PostgREST

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var dmViewModel = DMViewModel()
    @State private var commentPost: SupabaseFeedPost?
    @State private var showComments: Bool = false
    @State private var suggestedPlayers: [UserSearchResult] = []
    @State private var selectedCourtResult: FeedCourtSearchResult?
    @State private var selectedCourtFull: Court?
    @State private var courtsVMForDetail = CourtsViewModel()
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.activeTab != .dm {
                    feedHeader
                }
                tabBar

                if viewModel.activeTab == .dm {
                    DMInboxView(viewModel: dmViewModel)
                } else {
                    searchBar
                    feedContent
                }
            }

            if viewModel.activeTab != .dm {
                composeButton
            }

            // New posts pill (Live tab)
            if viewModel.pendingNewPosts > 0 && viewModel.activeTab == .live {
                newPostsPill
            }
        }
        .overlay {
            if viewModel.showSearchResults {
                searchOverlay
            }
        }
        // Error toast
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toastMessage {
                toastView(toast)
            }
        }
        .sheet(isPresented: $viewModel.showCompose) {
            ComposePostView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
        }
        .fullScreenCover(item: $viewModel.selectedProfileUserId) { userId in
            PublicPlayerProfileView(userId: userId) {
                Task { await viewModel.onFollowChanged() }
            }
        }
        .onChange(of: commentPost) { _, newPost in
            if newPost != nil {
                showComments = true
            }
        }
        .sheet(isPresented: $showComments, onDismiss: {
            commentPost = nil
        }) {
            if let post = commentPost {
                CommentsView(post: post, onCommentAdded: {
                    if let idx = viewModel.posts.firstIndex(where: { $0.id == post.id }) {
                        viewModel.posts[idx].commentCount += 1
                    }
                })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
            }
        }
        .onChange(of: selectedCourtResult) { _, newCourt in
            guard let court = newCourt else { return }
            Task {
                // Fetch full Court object for CourtDetailView
                let full: Court? = try? await SupabaseManager.shared.client
                    .from("courts")
                    .select("id, name, address, neighborhood, city, lat, lng, surface, lights, indoor, full_court, verified, tags, court_rating, submitted_by")
                    .eq("id", value: court.id)
                    .single()
                    .execute()
                    .value
                if let full {
                    selectedCourtFull = full
                }
                selectedCourtResult = nil
            }
        }
        .sheet(item: $selectedCourtFull) { court in
            NavigationStack {
                CourtDetailView(court: court, viewModel: courtsVMForDetail)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NETRTheme.background)
        }
        .task {
            await viewModel.fetchFeed(tab: viewModel.activeTab)
            await viewModel.subscribeToFeed()
        }
        .onDisappear {
            Task { await viewModel.unsubscribe() }
        }
    }

    // MARK: - Header

    private var feedHeader: some View {
        HStack {
            Text("FEED")
                .font(NETRTheme.headingFont(size: .title2))
                .foregroundStyle(NETRTheme.text)
            Spacer()
            Button {} label: {
                LucideIcon("bell")
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                LucideIcon("search", size: 14)
                    .foregroundStyle(NETRTheme.subtext)

                TextField(
                    viewModel.searchMode == .players ? "Search players..." : "Search courts...",
                    text: $viewModel.userSearchText
                )
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.text)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { searchFocused = false }
                .onChange(of: viewModel.userSearchText) { _, newValue in
                    viewModel.performSearch(query: newValue)
                }

                if !viewModel.userSearchText.isEmpty {
                    Button {
                        viewModel.dismissSearch()
                        searchFocused = false
                    } label: {
                        LucideIcon("x", size: 12)
                            .foregroundStyle(NETRTheme.subtext)
                            .frame(width: 20, height: 20)
                            .background(NETRTheme.muted, in: Circle())
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(NETRTheme.card, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.border, lineWidth: 1))

            // Players / Courts toggle
            HStack(spacing: 0) {
                ForEach(FeedViewModel.SearchMode.allCases, id: \.rawValue) { mode in
                    Button {
                        viewModel.searchMode = mode
                        if !viewModel.userSearchText.isEmpty {
                            viewModel.performSearch(query: viewModel.userSearchText)
                        }
                    } label: {
                        Text(mode.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(viewModel.searchMode == mode ? NETRTheme.background : NETRTheme.subtext)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.searchMode == mode ? NETRTheme.neonGreen : Color.clear,
                                in: .rect(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(NETRTheme.card, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(NETRTheme.border, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Search Overlay

    private var searchOverlay: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismissSearch()
                    searchFocused = false
                }

            VStack(spacing: 0) {
                Spacer().frame(height: 140)

                VStack(spacing: 0) {
                    if viewModel.isSearching {
                        HStack {
                            ProgressView()
                                .tint(NETRTheme.neonGreen)
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.system(size: 13))
                                .foregroundStyle(NETRTheme.subtext)
                            Spacer()
                        }
                        .padding(12)
                    } else if viewModel.searchMode == .players {
                        if viewModel.userSearchResults.isEmpty && !viewModel.userSearchText.isEmpty {
                            HStack {
                                Text("No players found")
                                    .font(.system(size: 13))
                                    .foregroundStyle(NETRTheme.subtext)
                                Spacer()
                            }
                            .padding(12)
                        } else {
                            ForEach(viewModel.userSearchResults) { user in
                                Button {
                                    viewModel.dismissSearch()
                                    searchFocused = false
                                    viewModel.selectedProfileUserId = user.id
                                } label: {
                                    searchResultRow(user: user)
                                }
                                .buttonStyle(.plain)

                                if user.id != viewModel.userSearchResults.last?.id {
                                    Divider().background(NETRTheme.border)
                                }
                            }
                        }
                    } else {
                        // Court results
                        if viewModel.courtSearchResults.isEmpty && !viewModel.userSearchText.isEmpty {
                            HStack {
                                Text("No courts found")
                                    .font(.system(size: 13))
                                    .foregroundStyle(NETRTheme.subtext)
                                Spacer()
                            }
                            .padding(12)
                        } else {
                            ForEach(viewModel.courtSearchResults) { court in
                                Button {
                                    viewModel.dismissSearch()
                                    searchFocused = false
                                    selectedCourtResult = court
                                } label: {
                                    courtSearchResultRow(court: court)
                                }
                                .buttonStyle(.plain)

                                if court.id != viewModel.courtSearchResults.last?.id {
                                    Divider().background(NETRTheme.border)
                                }
                            }
                        }
                    }
                }
                .background(NETRTheme.surface)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
                .padding(.horizontal, 16)
            }
        }
    }

    private func courtSearchResultRow(court: FeedCourtSearchResult) -> some View {
        HStack(spacing: 12) {
            LucideIcon("map-pin", size: 16)
                .foregroundStyle(NETRTheme.neonGreen)
                .frame(width: 36, height: 36)
                .background(NETRTheme.neonGreen.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(court.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)
                if !court.locationLabel.isEmpty {
                    Text(court.locationLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("View")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NETRTheme.neonGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(NETRTheme.neonGreen.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func searchResultRow(user: UserSearchResult) -> some View {
        HStack(spacing: 12) {
            if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } else {
                        searchInitialsAvatar(name: user.displayName)
                    }
                }
            } else {
                searchInitialsAvatar(name: user.displayName)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? "Player")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)
                if let username = user.username {
                    Text("@\(username)")
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let score = user.netrScore {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(NETRRating.color(for: score))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(NETRRating.color(for: score).opacity(0.12), in: .rect(cornerRadius: 4))
            }

            // Follow button (only for non-self users)
            if user.id != SupabaseManager.shared.session?.user.id.uuidString {
                let isFollowing = viewModel.followingIds.contains(user.id)
                Button {
                    Task {
                        if isFollowing {
                            try? await SupabaseManager.shared.client
                                .from("follows")
                                .delete()
                                .eq("follower_id", value: SupabaseManager.shared.session?.user.id.uuidString ?? "")
                                .eq("following_id", value: user.id)
                                .execute()
                            viewModel.followingIds.remove(user.id)
                        } else {
                            try? await SupabaseManager.shared.client
                                .from("follows")
                                .insert(["follower_id": SupabaseManager.shared.session?.user.id.uuidString ?? "", "following_id": user.id])
                                .execute()
                            viewModel.followingIds.insert(user.id)
                        }
                    }
                } label: {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isFollowing ? NETRTheme.subtext : NETRTheme.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            isFollowing ? NETRTheme.card : NETRTheme.neonGreen,
                            in: Capsule()
                        )
                        .overlay(Capsule().stroke(isFollowing ? NETRTheme.border : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func searchInitialsAvatar(name: String?) -> some View {
        let initials: String = {
            guard let name = name else { return "?" }
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }()

        return Text(initials)
            .font(.caption.weight(.bold))
            .foregroundStyle(NETRTheme.subtext)
            .frame(width: 36, height: 36)
            .background(NETRTheme.card, in: Circle())
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(FeedTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.activeTab = tab
                    }
                    if tab != .dm {
                        Task { await viewModel.fetchFeed(tab: tab) }
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue.uppercased())
                                .font(.system(size: 11, weight: .black))
                                .tracking(1.2)
                                .foregroundStyle(
                                    viewModel.activeTab == tab
                                    ? NETRTheme.neonGreen
                                    : NETRTheme.subtext
                                )

                            if tab == .dm && dmViewModel.totalUnread > 0 {
                                Text("\(dmViewModel.totalUnread)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(NETRTheme.background)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(NETRTheme.neonGreen, in: Circle())
                            }
                        }
                        Rectangle()
                            .fill(
                                viewModel.activeTab == tab
                                ? NETRTheme.neonGreen
                                : Color.clear
                            )
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Feed Content

    @ViewBuilder
    private var feedContent: some View {
        if !viewModel.hasLoadedOnce && viewModel.isLoading {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .tint(NETRTheme.neonGreen)
                    .scaleEffect(1.2)
                Text("Loading feed...")
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.posts.isEmpty {
                        if viewModel.activeTab == .forYou {
                            forYouEmptyState
                        } else {
                            emptyFeedState
                        }
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.posts) { post in
                                postCard(for: post)
                                Divider().background(NETRTheme.border)
                                    .onAppear {
                                        Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                                    }
                            }

                            if viewModel.isLoading && viewModel.hasLoadedOnce {
                                ProgressView()
                                    .tint(NETRTheme.neonGreen)
                                    .padding(.vertical, 20)
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .dismissKeyboardOnScroll()
            .refreshable {
                await viewModel.fetchFeed(tab: viewModel.activeTab)
            }
        }
    }

    private func postCard(for post: SupabaseFeedPost) -> some View {
        PostCardView(
            post: post,
            isOwnPost: viewModel.isOwnPost(post),
            onLike: {
                Task { await viewModel.toggleLike(post: post) }
            },
            onComment: {
                commentPost = post
            },
            onDelete: {
                Task { await viewModel.deletePost(post) }
            },
            onBlock: {
                Task { await viewModel.blockUser(userId: post.authorId) }
            },
            onProfileTap: { authorId in
                viewModel.selectedProfileUserId = authorId
            }
        )
    }

    // MARK: - Empty States

    private var forYouEmptyState: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                LucideIcon("users", size: 44)
                    .foregroundStyle(NETRTheme.muted)
                Text("Your feed is empty")
                    .font(.headline)
                    .foregroundStyle(NETRTheme.text)
                Text("Follow players to see their posts here.")
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
                    .multilineTextAlignment(.center)
            }

            if !suggestedPlayers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("DISCOVER PLAYERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NETRTheme.subtext)
                        .tracking(1.5)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(suggestedPlayers) { player in
                                suggestedPlayerCard(player)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .task {
            suggestedPlayers = await viewModel.fetchSuggestedPlayers()
        }
    }

    private func suggestedPlayerCard(_ player: UserSearchResult) -> some View {
        Button {
            viewModel.selectedProfileUserId = player.id
        } label: {
            VStack(spacing: 8) {
                if let avatarUrl = player.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                        } else {
                            searchInitialsAvatar(name: player.displayName)
                                .frame(width: 56, height: 56)
                        }
                    }
                } else {
                    searchInitialsAvatar(name: player.displayName)
                        .frame(width: 56, height: 56)
                }

                Text(player.displayName ?? "Player")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)

                if let score = player.netrScore {
                    Text(String(format: "%.1f", score))
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(NETRRating.color(for: score))
                }
            }
            .frame(width: 90)
            .padding(.vertical, 12)
            .background(NETRTheme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var emptyFeedState: some View {
        VStack(spacing: 16) {
            LucideIcon("messages-square", size: 44)
                .foregroundStyle(NETRTheme.muted)
            Text("Nothing here yet")
                .font(.headline)
                .foregroundStyle(NETRTheme.text)
            Text("Be the first to post about the run")
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - New Posts Pill

    private var newPostsPill: some View {
        VStack {
            Button {
                Task { await viewModel.fetchFeed(tab: .live) }
            } label: {
                HStack(spacing: 6) {
                    LucideIcon("arrow-up", size: 12)
                    Text("\(viewModel.pendingNewPosts) new post\(viewModel.pendingNewPosts == 1 ? "" : "s")")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(NETRTheme.background)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(NETRTheme.neonGreen, in: Capsule())
                .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 12)
            }
            .buttonStyle(PressButtonStyle())
            .padding(.bottom, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 180)
    }

    // MARK: - Compose

    private var composeButton: some View {
        Button {
            viewModel.showCompose = true
        } label: {
            LucideIcon("plus", size: 20)
                .foregroundStyle(NETRTheme.background)
                .frame(width: 56, height: 56)
                .background(NETRTheme.neonGreen, in: Circle())
                .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 12)
        }
        .buttonStyle(PressButtonStyle())
        .padding(.trailing, 16)
        .padding(.bottom, 96)
    }

    // MARK: - Toast

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(.caption.weight(.semibold))
            .foregroundStyle(NETRTheme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(NETRTheme.card, in: Capsule())
            .overlay(Capsule().stroke(NETRTheme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 10)
            .padding(.bottom, 100)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3), value: viewModel.toastMessage)
            .onTapGesture { viewModel.toastMessage = nil }
    }
}

// MARK: - Make String Identifiable for fullScreenCover

extension String: @retroactive Identifiable {
    public var id: String { self }
}
