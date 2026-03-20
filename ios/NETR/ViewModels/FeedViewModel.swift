import SwiftUI
import Supabase
import Auth

@Observable
class FeedViewModel {

    var posts: [SupabaseFeedPost] = []
    var isLoading: Bool = false
    var isPosting: Bool = false
    var activeTab: FeedTab = .forYou
    var error: String?
    var hasLoadedOnce: Bool = false

    var showCompose: Bool = false

    var courtSearchText: String = ""
    var courtResults: [FeedCourtSearchResult] = []

    var followingIds: Set<String> = []
    var followingLoaded: Bool = false

    // User search
    var userSearchText: String = ""
    var userSearchResults: [UserSearchResult] = []
    var isSearching: Bool = false
    var showSearchResults: Bool = false

    // Public profile navigation
    var selectedProfileUserId: String? = nil

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    private let selectQuery = """
        id, author_id, content, hashtags, mentioned_user_ids,
        court_id, game_id, repost_of_id, quote_of_id, photo_url,
        like_count, comment_count, repost_count, created_at,
        profiles(id, full_name, username, avatar_url, netr_score, vibe_score),
        courts(id, name, neighborhood, verified)
    """

    // MARK: - Follow IDs

    func loadFollowingIds() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        let rows: [FollowingIdRow]? = try? await client
            .from("follows")
            .select("following_id")
            .eq("follower_id", value: userId)
            .execute()
            .value
        followingIds = Set(rows?.map { $0.followingId } ?? [])
        followingLoaded = true
    }

    // MARK: - Fetch

    func fetchFeed(tab: FeedTab) async {
        isLoading = true

        if !followingLoaded {
            await loadFollowingIds()
        }

        do {
            let fetched: [SupabaseFeedPost]

            switch tab {
            case .forYou:
                if followingIds.isEmpty {
                    fetched = []
                } else {
                    fetched = try await client
                        .from("feed_posts")
                        .select(selectQuery)
                        .is("repost_of_id", value: nil)
                        .in("author_id", values: Array(followingIds))
                        .order("created_at", ascending: false)
                        .limit(30)
                        .execute()
                        .value
                }

            case .live:
                fetched = try await client
                    .from("feed_posts")
                    .select(selectQuery)
                    .is("repost_of_id", value: nil)
                    .order("created_at", ascending: false)
                    .limit(30)
                    .execute()
                    .value
            }

            var results = fetched
            if let userId = SupabaseManager.shared.session?.user.id.uuidString {
                let likedIds = await fetchLikedPostIds(userId: userId)
                let repostedIds = await fetchRepostedPostIds(userId: userId)
                results = results.map { post in
                    var p = post
                    p.isLiked = likedIds.contains(post.id)
                    p.isReposted = repostedIds.contains(post.id)
                    return p
                }
            }

            posts = results
            isLoading = false
            hasLoadedOnce = true
        } catch {
            self.error = "Failed to load feed"
            isLoading = false
            hasLoadedOnce = true
            print("Feed fetch error: \(error)")
        }
    }

    // MARK: - User Search

    func searchUsers(query: String) {
        searchTask?.cancel()

        guard query.count >= 1 else {
            userSearchResults = []
            showSearchResults = false
            isSearching = false
            return
        }

        isSearching = true
        showSearchResults = true

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            do {
                let results: [UserSearchResult] = try await client
                    .from("profiles")
                    .select("id, username, full_name, avatar_url, netr_score")
                    .ilike("username", pattern: "\(query)%")
                    .limit(8)
                    .execute()
                    .value

                guard !Task.isCancelled else { return }
                userSearchResults = results
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                isSearching = false
                print("User search error: \(error)")
            }
        }
    }

    func dismissSearch() {
        userSearchText = ""
        userSearchResults = []
        showSearchResults = false
        isSearching = false
        searchTask?.cancel()
    }

    // MARK: - Follow changed - refresh For You

    func onFollowChanged() async {
        followingLoaded = false
        await loadFollowingIds()
        if activeTab == .forYou {
            await fetchFeed(tab: .forYou)
        }
    }

    // MARK: - Create Post

    func createPost(
        content: String,
        courtId: String? = nil,
        gameId: String? = nil,
        quoteOf: String? = nil,
        photoImage: UIImage? = nil
    ) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        isPosting = true

        let tags = extractHashtags(from: content)
        let mentions = extractMentions(from: content)
        let mentionedIds = await resolveMentions(mentions)

        var photoUrl: String? = nil
        if let image = photoImage {
            photoUrl = await uploadFeedPhoto(image: image, userId: userId)
        }

        let payload = CreateFeedPostPayload(
            authorId: userId,
            content: content,
            hashtags: tags,
            mentionedUserIds: mentionedIds,
            courtId: courtId,
            gameId: gameId,
            quoteOfId: quoteOf,
            repostOfId: nil,
            photoUrl: photoUrl
        )

        do {
            let created: SupabaseFeedPost = try await client
                .from("feed_posts")
                .insert(payload)
                .select(selectQuery)
                .single()
                .execute()
                .value

            posts.insert(created, at: 0)
            isPosting = false
            showCompose = false
        } catch {
            isPosting = false
            print("Create post error: \(error)")
        }
    }

    // MARK: - Photo Upload

    private func uploadFeedPhoto(image: UIImage, userId: String) async -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "\(userId)/\(timestamp).jpg"

        do {
            try await client.storage
                .from("feed-photos")
                .upload(path, data: data, options: FileOptions(
                    cacheControl: "3600", contentType: "image/jpeg", upsert: true
                ))
            let url = try client.storage
                .from("feed-photos")
                .getPublicURL(path: path)
            return url.absoluteString
        } catch {
            print("Feed photo upload error: \(error)")
            return nil
        }
    }

    // MARK: - Like / Repost / Delete

    func toggleLike(post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        guard let i = posts.firstIndex(where: { $0.id == post.id }) else { return }

        let wasLiked = posts[i].isLiked
        posts[i].isLiked = !wasLiked
        posts[i].likeCount += wasLiked ? -1 : 1

        do {
            if wasLiked {
                try await client
                    .from("post_likes")
                    .delete()
                    .eq("post_id", value: post.id)
                    .eq("user_id", value: userId)
                    .execute()
            } else {
                try await client
                    .from("post_likes")
                    .insert(FeedLikePayload(postId: post.id, userId: userId))
                    .execute()
            }
        } catch {
            if let i = posts.firstIndex(where: { $0.id == post.id }) {
                posts[i].isLiked = wasLiked
                posts[i].likeCount = post.likeCount
            }
        }
    }

    func repost(post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        let repostFeedPayload = CreateFeedPostPayload(
            authorId: userId,
            content: "",
            hashtags: [],
            mentionedUserIds: [],
            courtId: nil,
            gameId: nil,
            quoteOfId: nil,
            repostOfId: post.id,
            photoUrl: nil
        )

        do {
            try await client
                .from("post_reposts")
                .insert(FeedRepostPayload(postId: post.id, userId: userId))
                .execute()
            try await client
                .from("feed_posts")
                .insert(repostFeedPayload)
                .execute()

            if let i = posts.firstIndex(where: { $0.id == post.id }) {
                posts[i].isReposted = true
                posts[i].repostCount += 1
            }
        } catch {
            print("Repost error: \(error)")
        }
    }

    func deletePost(_ post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString,
              userId == post.authorId else { return }

        do {
            try await client
                .from("feed_posts")
                .delete()
                .eq("id", value: post.id)
                .execute()

            posts.removeAll { $0.id == post.id }
        } catch {
            print("Delete post error: \(error)")
        }
    }

    func blockUser(userId: String) async {
        posts.removeAll { $0.authorId == userId }
    }

    // MARK: - Court Search

    func searchCourts(query: String) async {
        guard query.count >= 2 else {
            courtResults = []
            return
        }

        do {
            let results: [FeedCourtSearchResult] = try await client
                .from("courts")
                .select("id, name, neighborhood, verified")
                .ilike("name", pattern: "%\(query)%")
                .limit(8)
                .execute()
                .value

            courtResults = results
        } catch {
            print("Court search error: \(error)")
        }
    }

    // MARK: - Realtime

    func subscribeToFeed() async {
        realtimeChannel = client.realtimeV2.channel("feed-live")
        guard let channel = realtimeChannel else { return }

        let postChanges = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "feed_posts"
        )

        let likeChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "post_likes"
        )

        let commentChanges = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "post_comments"
        )

        await channel.subscribe()

        realtimeTask = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in postChanges {
                        await self.fetchFeed(tab: self.activeTab)
                    }
                }
                group.addTask {
                    for await _ in likeChanges {
                        await self.fetchFeed(tab: self.activeTab)
                    }
                }
                group.addTask {
                    for await _ in commentChanges {
                        await self.fetchFeed(tab: self.activeTab)
                    }
                }
            }
        }
    }

    func unsubscribe() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel = realtimeChannel {
            await client.realtimeV2.removeChannel(channel)
        }
        realtimeChannel = nil
    }

    func isOwnPost(_ post: SupabaseFeedPost) -> Bool {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return false }
        return post.authorId == userId
    }

    // MARK: - Helpers

    private func fetchLikedPostIds(userId: String) async -> Set<String> {
        let rows: [FeedLikeRow]? = try? await client
            .from("post_likes")
            .select("post_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        return Set(rows?.map { $0.postId } ?? [])
    }

    private func fetchRepostedPostIds(userId: String) async -> Set<String> {
        let rows: [FeedRepostRow]? = try? await client
            .from("post_reposts")
            .select("post_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        return Set(rows?.map { $0.postId } ?? [])
    }

    private func resolveMentions(_ usernames: [String]) async -> [String] {
        guard !usernames.isEmpty else { return [] }

        nonisolated struct UserRow: Decodable, Sendable {
            let id: String
        }

        let rows: [UserRow]? = try? await client
            .from("profiles")
            .select("id")
            .in("username", values: usernames)
            .execute()
            .value
        return rows?.map { $0.id } ?? []
    }
}
