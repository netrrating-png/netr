import SwiftUI
import PostgREST

struct PublicPlayerProfileView: View {
    let userId: String
    var onFollowChanged: (() -> Void)? = nil

    @State private var viewModel = ProfileViewModel()
    @State private var ratingAnimated: Bool = false
    @State private var commentPost: SupabaseFeedPost?
    @State private var showComments: Bool = false
    @State private var showDMChat: Bool = false
    @State private var mentionProfileUserId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.player == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(NETRTheme.neonGreen)
                        .scaleEffect(1.2)
                    Text("Loading profile...")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                }
            } else if let user = viewModel.player {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerGradient(user: user)
                        profileContent(user: user)
                    }
                }
            } else if viewModel.error != nil {
                VStack(spacing: 16) {
                    LucideIcon("triangle-alert", size: 40)
                        .foregroundStyle(NETRTheme.red)
                    Text("Could not load profile")
                        .font(.headline)
                        .foregroundStyle(NETRTheme.text)
                    Button("Try Again") {
                        Task { await viewModel.loadProfile(userId: userId) }
                    }
                    .foregroundStyle(NETRTheme.neonGreen)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                LucideIcon("arrow-left", size: 18)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .task {
            await viewModel.loadProfile(userId: userId)
            await viewModel.loadUserPosts()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { ratingAnimated = true }
            }
        }
        .onChange(of: commentPost) { _, newPost in
            if newPost != nil { showComments = true }
        }
        .sheet(isPresented: $showComments, onDismiss: { commentPost = nil }) {
            if let post = commentPost {
                CommentsView(post: post)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NETRTheme.surface)
            }
        }
        .fullScreenCover(isPresented: $showDMChat) {
            if let player = viewModel.player {
                let otherUser = FeedAuthor(
                    id: userId,
                    displayName: player.name,
                    username: player.username.hasPrefix("@") ? String(player.username.dropFirst()) : player.username,
                    avatarUrl: player.avatarUrl,
                    netrScore: player.rating
                )
                ChatThreadView(otherUserId: userId, otherUser: otherUser)
            }
        }
        .fullScreenCover(item: $mentionProfileUserId) { uid in
            PublicPlayerProfileView(userId: uid)
        }
    }

    private func lookupMentionProfile(username: String) {
        Task {
            nonisolated struct IdRow: Decodable, Sendable { let id: String }
            let rows: [IdRow]? = try? await SupabaseManager.shared.client
                .from("profiles")
                .select("id")
                .eq("username", value: username)
                .limit(1)
                .execute()
                .value
            if let user = rows?.first {
                mentionProfileUserId = user.id
            }
        }
    }

    // MARK: - Header

    private func headerGradient(user: Player) -> some View {
        ZStack(alignment: .bottom) {
            if let bannerUrlStr = user.bannerUrl, let url = URL(string: bannerUrlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, NETRTheme.background]),
                                    startPoint: .center, endPoint: .bottom
                                )
                            )
                    } else {
                        defaultGradient(user: user)
                    }
                }
            } else {
                defaultGradient(user: user)
            }
        }
        .frame(height: 140)
    }

    private func defaultGradient(user: Player) -> some View {
        LinearGradient(
            gradient: Gradient(colors: [
                NETRRating.color(for: user.rating).opacity(0.18),
                NETRTheme.background,
            ]),
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 140)
    }

    // MARK: - Profile Content

    private func profileContent(user: Player) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            avatarFollowRow(user: user)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            nameSection(user: user)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            if let bio = viewModel.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundStyle(NETRTheme.text)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            socialCountsRow(user: user)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

            Divider().background(NETRTheme.border).padding(.horizontal, 20).padding(.bottom, 20)

            ratingSection(user: user)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

            Divider().background(NETRTheme.border).padding(.horizontal, 20).padding(.bottom, 20)

            radarSection(user: user)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

            Divider().background(NETRTheme.border).padding(.horizontal, 20).padding(.bottom, 20)

            if !viewModel.userPosts.isEmpty {
                recentPostsSection
                    .padding(.bottom, 40)
            }

            Spacer(minLength: 100)
        }
        .background(NETRTheme.background)
    }

    // MARK: - Avatar + Follow

    private func avatarFollowRow(user: Player) -> some View {
        let color = NETRRating.color(for: user.rating)

        return HStack(alignment: .bottom) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [color.opacity(0.2), color.opacity(0.05)]),
                        center: .center, startRadius: 0, endRadius: 40
                    ))
                    .frame(width: 84, height: 84)

                AvatarView(
                    url: user.avatarUrl,
                    name: user.name,
                    size: 76,
                    borderColor: color.opacity(user.isVerified ? 0.6 : 0.25),
                    borderWidth: 2
                )
            }
            .shadow(color: color.opacity(user.isVerified ? 0.3 : 0.1), radius: 20)
            .offset(y: -28)

            Spacer()

            if !viewModel.isCurrentUser {
                HStack(spacing: 8) {
                    Button {
                        showDMChat = true
                    } label: {
                        LucideIcon("message-circle", size: 15)
                            .foregroundStyle(NETRTheme.subtext)
                            .frame(width: 36, height: 36)
                            .background(NETRTheme.card)
                            .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
                            .clipShape(Circle())
                    }

                    Button {
                        Task {
                            await viewModel.toggleFollow()
                            onFollowChanged?()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            LucideIcon(viewModel.isFollowing ? "check" : "user-plus", size: 13)
                            Text(viewModel.isFollowing ? "Following" : "Follow")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(viewModel.isFollowing ? NETRTheme.text : NETRTheme.background)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewModel.isFollowing ? NETRTheme.card : NETRTheme.neonGreen)
                        .overlay(Capsule().stroke(viewModel.isFollowing ? NETRTheme.border : Color.clear, lineWidth: 1))
                        .clipShape(Capsule())
                    }
                    .sensoryFeedback(.selection, trigger: viewModel.isFollowing)
                }
            }
        }
    }

    // MARK: - Name

    private func nameSection(user: Player) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(user.name)
                    .font(.system(.title2, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)

                if user.isVerified {
                    LucideIcon("badge-check", size: 14)
                        .foregroundStyle(NETRTheme.neonGreen)
                }

                if user.isProspect {
                    Text("PROSPECT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NETRTheme.purple)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(NETRTheme.purple.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(NETRTheme.purple.opacity(0.4), lineWidth: 1))
                        .clipShape(.rect(cornerRadius: 5))
                }
            }

            HStack(spacing: 8) {
                Text(user.username)
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.subtext)
                Text("·")
                    .foregroundStyle(NETRTheme.muted)
                // Position + optional age badge
                HStack(spacing: 4) {
                    Text(user.position.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NETRRating.color(for: user.rating))
                    let showAge = viewModel.userProfile?.showAge ?? false
                    let age = user.age
                    if showAge && age > 0 {
                        Text("·")
                            .foregroundStyle(NETRTheme.muted)
                            .font(.system(size: 12))
                        Text("\(age)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                if !user.city.isEmpty {
                    Text("·")
                        .foregroundStyle(NETRTheme.muted)
                    LucideIcon("map-pin", size: 11)
                        .foregroundStyle(NETRTheme.muted)
                    Text(user.city)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
    }

    // MARK: - Social Counts

    private func socialCountsRow(user: Player) -> some View {
        HStack(spacing: 24) {
            socialStat(count: viewModel.followerCount, label: viewModel.followerCount == 1 ? "Follower" : "Followers")

            Rectangle()
                .fill(NETRTheme.muted)
                .frame(width: 1, height: 28)

            socialStat(count: viewModel.followingCount, label: "Following")

            Rectangle()
                .fill(NETRTheme.muted)
                .frame(width: 1, height: 28)

            socialStat(count: user.games, label: "Games")

            Rectangle()
                .fill(NETRTheme.muted)
                .frame(width: 1, height: 28)

            socialStat(count: user.reviews, label: "Ratings")

            Spacer()
        }
        .padding(.top, 14)
    }

    private func socialStat(count: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(count >= 1000 ? String(format: "%.1fK", Double(count) / 1000) : "\(count)")
                .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                .foregroundStyle(NETRTheme.text)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(NETRTheme.subtext)
        }
    }

    // MARK: - Rating

    private func ratingSection(user: Player) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NETR RATING")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1.5)
                NETRTierPill(score: user.rating)
                if user.isVerified {
                    Text("\(user.reviews) peer ratings")
                        .font(.system(size: 11))
                        .foregroundStyle(NETRRating.color(for: user.rating).opacity(0.7))
                } else {
                    Text(user.rating == nil ? "Not yet rated" : "Self-assessed")
                        .font(.system(size: 11))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
            Spacer()

            NETRBadge(score: user.rating, size: .xl)
                .scaleEffect(ratingAnimated ? 1.0 : 0.8)
                .opacity(ratingAnimated ? 1.0 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.7), value: ratingAnimated)
        }
    }

    // MARK: - Radar Chart

    private func radarSection(user: Player) -> some View {
        let skills = buildRadarSkills(from: user.skills)
        let hasRatings = skills.contains { $0.raw > 2.5 }

        return VStack(alignment: .leading, spacing: 12) {
            if hasRatings {
                ArchetypeBadge(
                    archetypeName: viewModel.userProfile?.archetypeName,
                    archetypeKey: viewModel.userProfile?.archetypeKey,
                    skills: skills
                )
            }

            Text("SKILL BREAKDOWN")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1.5)

            if hasRatings {
                SkillRadarView(
                    skills: skills,
                    size: 280,
                    animated: true,
                    tierColor: NETRRating.color(for: user.rating)
                )
            } else {
                VStack(spacing: 12) {
                    SkillRadarView(
                        skills: skills,
                        size: 220,
                        animated: false,
                        tierColor: NETRTheme.muted
                    )
                    .opacity(0.4)

                    Text("Play games to unlock your radar")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Recent Posts

    private var recentPostsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT POSTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1.5)
                .padding(.horizontal, 20)

            LazyVStack(spacing: 0) {
                ForEach(viewModel.userPosts) { post in
                    PostCardView(
                        post: post,
                        isOwnPost: false,
                        onLike: {},
                        onComment: { commentPost = post },
                        onDelete: {},
                        onBlock: {},
                        onMentionTap: { username in lookupMentionProfile(username: username) }
                    )
                    Divider().background(NETRTheme.border)
                }
            }
        }
    }

}
