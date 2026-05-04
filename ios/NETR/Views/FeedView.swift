import SwiftUI
import Auth
import Supabase
import PostgREST

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showNotifications: Bool = false
    @State private var commentPost: SupabaseFeedPost?
    @State private var showComments: Bool = false
    @State private var quotePost: SupabaseFeedPost?
    @State private var suggestedPlayers: [UserSearchResult] = []
    @Binding var scrollToTopTrigger: Bool
    @Bindable var dmViewModel: DMViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                feedHeader
                tabBar
                if viewModel.activeTab == .live {
                    HStack(spacing: 4) {
                        LucideIcon("clock", size: 10)
                            .foregroundStyle(NETRTheme.subtext)
                        Text("Posts from the last 24 hours")
                            .font(.system(size: 11))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(NETRTheme.surface)
                }
                searchBar
                feedContent
            }

            composeButton

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
        .sheet(isPresented: $viewModel.showCompose, onDismiss: { quotePost = nil }) {
            ComposePostView(viewModel: viewModel, quotePost: quotePost)
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
        .task {
            await viewModel.fetchFeed(tab: viewModel.activeTab)
            await viewModel.subscribeToFeed()
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.background)
        }
        .onDisappear {
            Task { await viewModel.unsubscribe() }
        }
    }

    // MARK: - Header

    private var feedHeader: some View {
        HStack(spacing: 12) {
            Text("FEED")
                .font(NETRTheme.headingFont(size: .title2))
                .foregroundStyle(NETRTheme.text)
            Spacer()
            Button {
                showNotifications = true
            } label: {
                LucideIcon("bell", size: 18)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
            }
            DMHeaderButton(dmViewModel: dmViewModel)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            LucideIcon("search", size: 14)
                .foregroundStyle(NETRTheme.subtext)

            TextField("Search players...", text: $viewModel.userSearchText)
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
                Spacer().frame(height: 100)

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
                    } else if viewModel.userSearchResults.isEmpty && !viewModel.userSearchText.isEmpty {
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
                }
                .background(NETRTheme.surface)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
                .padding(.horizontal, 16)
            }
        }
    }

    private func searchResultRow(user: UserSearchResult) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarUrl, name: user.displayName, size: 36)

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
            if user.id != SupabaseManager.shared.currentProfile?.id {
                let isFollowing = viewModel.followingIds.contains(user.id)
                Button {
                    Task {
                        guard let currentId = SupabaseManager.shared.currentProfile?.id else { return }
                        do {
                            if isFollowing {
                                try await SupabaseManager.shared.client
                                    .from("follows")
                                    .delete()
                                    .eq("follower_id", value: currentId)
                                    .eq("following_id", value: user.id)
                                    .execute()
                                viewModel.followingIds.remove(user.id)
                            } else {
                                try await SupabaseManager.shared.client
                                    .from("follows")
                                    .insert(["follower_id": currentId, "following_id": user.id])
                                    .execute()
                                viewModel.followingIds.insert(user.id)
                            }
                        } catch {
                            print("[NETR] Follow toggle error: \(error)")
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



    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(FeedTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.activeTab = tab
                    }
                    Task { await viewModel.fetchFeed(tab: tab) }
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
        if viewModel.activeTab == .discover {
            discoverContent
        } else if let feedError = viewModel.error, viewModel.posts.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                LucideIcon("wifi-off", size: 36)
                    .foregroundStyle(NETRTheme.muted)
                Text("Couldn't load feed")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
                Text(feedError)
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.subtext)
                Button {
                    Task { await viewModel.fetchFeed(tab: viewModel.activeTab) }
                } label: {
                    Text("Try Again")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(NETRTheme.background)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(NETRTheme.neonGreen, in: .capsule)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if !viewModel.hasLoadedOnce {
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Invisible anchor for scroll-to-top
                        Color.clear.frame(height: 0).id("feedTop")

                        if viewModel.posts.isEmpty {
                            if viewModel.activeTab == .forYou {
                                forYouEmptyState
                            } else {
                                emptyFeedState
                            }
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.posts) { post in
                                    SwipeToDeleteWrapper(
                                        enabled: viewModel.isOwnPost(post),
                                        onDelete: { Task { await viewModel.deletePost(post) } }
                                    ) {
                                        postCard(for: post)
                                    }
                                    Divider().background(NETRTheme.border)
                                        .onAppear {
                                            Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                                        }
                                }

                                if viewModel.isLoading && viewModel.hasLoadedOnce {
                                    ProgressView()
                                        .tint(NETRTheme.neonGreen)
                                        .padding(.vertical, 20)
                                } else if !viewModel.hasMore && viewModel.hasLoadedOnce && !viewModel.posts.isEmpty {
                                    VStack(spacing: 6) {
                                        LucideIcon("check-circle", size: 16)
                                            .foregroundStyle(NETRTheme.muted)
                                        Text("You're all caught up")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(NETRTheme.subtext)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
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
                .onChange(of: scrollToTopTrigger) { _, _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        proxy.scrollTo("feedTop", anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Discover Content

    private var discoverContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoadingNearby {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .tint(NETRTheme.neonGreen)
                            .scaleEffect(1.2)
                        Text("Finding players near you...")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else if viewModel.nearbyUsers.isEmpty {
                    VStack(spacing: 16) {
                        LucideIcon("users", size: 44)
                            .foregroundStyle(NETRTheme.muted)
                        Text("No players nearby")
                            .font(.headline)
                            .foregroundStyle(NETRTheme.text)
                        Text("No players found within 5 miles.\nCheck back later!")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    Text("PLAYERS NEAR YOU")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NETRTheme.subtext)
                        .tracking(1.5)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(viewModel.nearbyUsers) { player in
                            suggestedPlayerCard(player)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            viewModel.userLocation = nil
            viewModel.requestDiscoverLocation()
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
            onRepost: {
                Task { await viewModel.repost(post: post) }
            },
            onUndoRepost: {
                Task { await viewModel.undoRepost(post: post) }
            },
            onQuotePost: {
                quotePost = post
                viewModel.showCompose = true
            },
            onBookmark: {
                Task { await viewModel.toggleBookmark(post: post) }
            },
            onDelete: {
                Task { await viewModel.deletePost(post) }
            },
            onBlock: {
                Task { await viewModel.blockUser(userId: post.authorId) }
            },
            onProfileTap: { authorId in
                viewModel.selectedProfileUserId = authorId
            },
            onMentionTap: { username in
                Task { await viewModel.openProfile(username: username) }
            }
        )
    }

    // MARK: - Empty States

    // MARK: - For You Empty State (P5)

    private var forYouEmptyState: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                LucideIcon("users", size: 48)
                    .foregroundStyle(NETRTheme.neonGreen)

                Text("Your feed is empty.\nLet's fix that.")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
                    .multilineTextAlignment(.center)

                Text("Follow players to see their posts, ratings, and game activity.")
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if !suggestedPlayers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PLAYERS YOU MIGHT KNOW")
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

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.activeTab = .discover
                }
                viewModel.requestDiscoverLocation()
            } label: {
                HStack(spacing: 8) {
                    LucideIcon("search", size: 14)
                    Text("FIND PLAYERS")
                        .font(.system(.subheadline, design: .default, weight: .bold).width(.compressed))
                        .tracking(1)
                }
                .foregroundStyle(NETRTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(PressButtonStyle())
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .task {
            suggestedPlayers = await viewModel.fetchSuggestedPlayers()
        }
    }

    // MARK: - Suggested Player Card

    private func suggestedPlayerCard(_ player: UserSearchResult) -> some View {
        let isFollowing = viewModel.followingIds.contains(player.id)
        return VStack(spacing: 8) {
            Button {
                viewModel.selectedProfileUserId = player.id
            } label: {
                VStack(spacing: 6) {
                    AvatarView(url: player.avatarUrl, name: player.displayName, size: 52)

                    Text(player.displayName ?? "Player")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                        .lineLimit(1)

                    if let score = player.netrScore {
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(NETRRating.color(for: score))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(NETRRating.color(for: score).opacity(0.12), in: .rect(cornerRadius: 4))
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    let sessionId = SupabaseManager.shared.session?.user.id.uuidString
                    let profileId = SupabaseManager.shared.currentProfile?.id
                    print("[NETR] Follow debug — session.user.id: \(sessionId ?? "nil"), currentProfile.id: \(profileId ?? "nil"), target: \(player.id)")
                    guard let currentId = profileId else {
                        print("[NETR] Follow blocked — currentProfile is nil")
                        return
                    }
                    do {
                        if isFollowing {
                            try await SupabaseManager.shared.client
                                .from("follows")
                                .delete()
                                .eq("follower_id", value: currentId)
                                .eq("following_id", value: player.id)
                                .execute()
                            viewModel.followingIds.remove(player.id)
                        } else {
                            try await SupabaseManager.shared.client
                                .from("follows")
                                .insert(["follower_id": currentId, "following_id": player.id])
                                .execute()
                            viewModel.followingIds.insert(player.id)
                        }
                    } catch {
                        print("[NETR] Discover follow error: \(error)")
                    }
                }
            } label: {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isFollowing ? NETRTheme.subtext : NETRTheme.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        isFollowing ? NETRTheme.card : NETRTheme.neonGreen,
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(isFollowing ? NETRTheme.border : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 100)
        .padding(.vertical, 12)
        .background(NETRTheme.card, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
    }

    // MARK: - Live Empty State (P5)

    private var emptyFeedState: some View {
        VStack(spacing: 20) {
            LucideIcon("messages-square", size: 44)
                .foregroundStyle(NETRTheme.muted)
            Text("No posts in the last 24 hours")
                .font(.headline)
                .foregroundStyle(NETRTheme.text)
            Text("Be the first to post.")
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)
            Button {
                viewModel.showCompose = true
            } label: {
                HStack(spacing: 6) {
                    LucideIcon("pencil", size: 12)
                    Text("POST")
                        .font(.system(.caption, design: .default, weight: .black).width(.compressed))
                        .tracking(1)
                }
                .foregroundStyle(NETRTheme.background)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(NETRTheme.neonGreen, in: Capsule())
            }
            .buttonStyle(PressButtonStyle())
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

// MARK: - Swipe to Delete (Apple-style)

struct SwipeToDeleteWrapper<Content: View>: View {
    let enabled: Bool
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var showDelete = false

    private let deleteWidth: CGFloat = 80

    var body: some View {
        if enabled {
            ZStack(alignment: .trailing) {
                // Delete button behind
                if showDelete || offset < 0 {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                                showDelete = false
                            }
                            onDelete()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Delete")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(width: deleteWidth)
                            .frame(maxHeight: .infinity)
                            .background(Color.red)
                        }
                    }
                }

                // Post content
                content()
                    .offset(x: offset)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { value in
                                let translation = value.translation.width
                                // Only allow left swipe
                                if translation < 0 {
                                    offset = max(translation, -deleteWidth - 20)
                                } else if showDelete {
                                    offset = min(translation - deleteWidth, 0)
                                }
                            }
                            .onEnded { value in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if offset < -deleteWidth / 2 {
                                        offset = -deleteWidth
                                        showDelete = true
                                    } else {
                                        offset = 0
                                        showDelete = false
                                    }
                                }
                            }
                    )
            }
            .clipped()
        } else {
            content()
        }
    }
}

