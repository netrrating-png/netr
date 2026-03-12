import SwiftUI
import Supabase

@Observable
class FeedViewModel {

    var posts: [SupabaseFeedPost] = []
    var trendingTags: [String] = []
    var isLoading: Bool = false
    var isPosting: Bool = false
    var activeTab: FeedTab = .forYou
    var error: String?
    var hasLoadedOnce: Bool = false

    var showCompose: Bool = false
    var showCommentsPost: SupabaseFeedPost? = nil

    var courtSearchText: String = ""
    var courtResults: [FeedCourtSearchResult] = []

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    private let selectQuery = """
        id, author_id, content, hashtags, mentioned_user_ids,
        court_id, game_id, repost_of_id, quote_of_id,
        like_count, comment_count, repost_count, created_at,
        profiles(id, full_name, username, avatar_url, netr_score, vibe_score),
        courts(id, name, neighborhood, verified)
    """

    func fetchFeed(tab: FeedTab) async {
        isLoading = true

        do {
            let fetched: [SupabaseFeedPost]

            switch tab {
            case .forYou:
                fetched = try await client
                    .from("feed_posts")
                    .select(selectQuery)
                    .is("repost_of_id", value: nil)
                    .order("created_at", ascending: false)
                    .limit(30)
                    .execute()
                    .value

            case .local:
                fetched = try await client
                    .from("feed_posts")
                    .select(selectQuery)
                    .not("court_id", operator: .is, value: "null")
                    .order("created_at", ascending: false)
                    .limit(30)
                    .execute()
                    .value

            case .trending:
                fetched = try await client
                    .from("feed_posts")
                    .select(selectQuery)
                    .is("repost_of_id", value: nil)
                    .order("like_count", ascending: false)
                    .limit(30)
                    .execute()
                    .value

                await fetchTrendingTags()
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

    func createPost(
        content: String,
        courtId: String? = nil,
        gameId: String? = nil,
        quoteOf: String? = nil
    ) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        isPosting = true

        let tags = extractHashtags(from: content)
        let mentions = extractMentions(from: content)
        let mentionedIds = await resolveMentions(mentions)

        let payload = CreateFeedPostPayload(
            authorId: userId,
            content: content,
            hashtags: tags,
            mentionedUserIds: mentionedIds,
            courtId: courtId,
            gameId: gameId,
            quoteOfId: quoteOf,
            repostOfId: nil
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
            repostOfId: post.id
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

    func fetchTrendingTags() async {
        guard let rows: [HashtagRow] = try? await client
            .from("feed_posts")
            .select("hashtags")
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
        else { return }

        var counts: [String: Int] = [:]
        for row in rows {
            for tag in row.hashtags { counts[tag, default: 0] += 1 }
        }
        let sorted = counts.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
        trendingTags = sorted
    }

    func subscribeToFeed() async {
        realtimeChannel = client.realtimeV2.channel("feed-live")
        guard let channel = realtimeChannel else { return }

        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "feed_posts"
        )

        await channel.subscribe()

        realtimeTask = Task {
            for await _ in changes {
                await fetchFeed(tab: activeTab)
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
