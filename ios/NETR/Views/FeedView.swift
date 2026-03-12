import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                feedHeader
                tabBar
                feedContent
            }

            composeButton
        }
        .sheet(isPresented: $viewModel.showCompose) {
            ComposePostView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
        }
        .sheet(item: $viewModel.showCommentsPost) { post in
            CommentsView(post: post)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
        }
        .task {
            await viewModel.fetchFeed(tab: viewModel.activeTab)
            await viewModel.subscribeToFeed()
        }
    }

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
                    if viewModel.activeTab == .trending && !viewModel.trendingTags.isEmpty {
                        trendingTagsSection
                    }

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
                                        viewModel.showCommentsPost = post
                                    },
                                    onRepost: {
                                        Task { await viewModel.repost(post: post) }
                                    },
                                    onDelete: {
                                        Task { await viewModel.deletePost(post) }
                                    },
                                    onBlock: {
                                        Task { await viewModel.blockUser(userId: post.authorId) }
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
            .refreshable {
                await viewModel.fetchFeed(tab: viewModel.activeTab)
            }
        }
    }

    private var trendingTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRENDING")
                .font(.system(size: 10, weight: .black))
                .tracking(1.5)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(viewModel.trendingTags, id: \.self) { tag in
                        Button {
                        } label: {
                            Text("#\(tag)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NETRTheme.neonGreen)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(NETRTheme.neonGreen.opacity(0.08), in: Capsule())
                                .overlay(Capsule().stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, 12)
    }

    private var forYouEmptyState: some View {
        VStack(spacing: 16) {
            LucideIcon("users", size: 44)
                .foregroundStyle(NETRTheme.muted)
            Text("Your feed is empty")
                .font(.headline)
                .foregroundStyle(NETRTheme.text)
            Text("Follow players to see their posts here.\nFind ballers on the courts tab.")
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
