import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var commentPost: SupabaseFeedPost?
    @State private var showComments: Bool = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                feedHeader
                searchBar
                tabBar
                feedContent
            }

            composeButton
        }
        .overlay {
            if viewModel.showSearchResults {
                searchOverlay
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
                    // Increment local comment count so it updates immediately in the feed
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
                    viewModel.searchUsers(query: newValue)
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
                // offset to position dropdown below search bar
                Spacer().frame(height: 108)

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
            if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } else {
                        searchInitialsAvatar(name: user.fullName)
                    }
                }
            } else {
                searchInitialsAvatar(name: user.fullName)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName ?? "Player")
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
                    Task { await viewModel.fetchFeed(tab: tab) }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .tracking(1.2)
                            .foregroundStyle(
                                viewModel.activeTab == tab
                                ? NETRTheme.neonGreen
                                : NETRTheme.subtext
                            )
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
                                Divider().background(NETRTheme.border)
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

    // MARK: - Empty States

    private var forYouEmptyState: some View {
        VStack(spacing: 16) {
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
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
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
}

// MARK: - Make String Identifiable for fullScreenCover

extension String: @retroactive Identifiable {
    public var id: String { self }
}
