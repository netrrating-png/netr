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
    var hasMore: Bool = true

    var showCompose: Bool = false

    // Court search
    var courtResults: [FeedCourtSearchResult] = []

    // Follow state
    var followingIds: Set<String> = []
    var followingLoaded: Bool = false

    // Interaction sets for instant UI state
    var likedPostIds: Set<String> = []
    var repostedPostIds: Set<String> = []
    var bookmarkedPostIds: Set<String> = []

    // User search
    var userSearchText: String = ""
    var userSearchResults: [UserSearchResult] = []
    var isSearching: Bool = false
    var showSearchResults: Bool = false

    // Mention autocomplete
    var mentionResults: [UserSearchResult] = []
    var showMentionResults: Bool = false
    var activeMentionQuery: String = ""

    // Public profile navigation
    var selectedProfileUserId: String? = nil

    // Error toast
    var toastMessage: String?

    // Live tab — new posts pill
    var pendingNewPosts: Int = 0

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var mentionSearchTask: Task<Void, Never>?
    private let pageSize = 20

    private let selectQuery = """
        id, author_id, content, like_count, comment_count, repost_count,
        repost_of_id, court_tag_id, court_tag_name, created_at,
        profiles(id, display_name, username, avatar_url, netr_score)
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
        // Always include self so own posts appear in For You
        followingIds.insert(userId)
        followingLoaded = true
    }

    // MARK: - Load User Interaction State

    private func loadInteractionState() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        async let liked: [FeedLikeRow]? = try? client
            .from("likes")
            .select("post_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        async let bookmarked: [BookmarkRow]? = try? client
            .from("bookmarks")
            .select("post_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        let likedRows = await liked
        let bookmarkedRows = await bookmarked

        likedPostIds = Set(likedRows?.map { $0.postId } ?? [])
        bookmarkedPostIds = Set(bookmarkedRows?.map { $0.postId } ?? [])

        // Reposted = any feed_posts by me with repost_of_id set
        nonisolated struct RepostOfRow: Decodable, Sendable {
            let repostOfId: String
            nonisolated enum CodingKeys: String, CodingKey { case repostOfId = "repost_of_id" }
        }
        let repostRows: [RepostOfRow]? = try? await client
            .from("feed_posts")
            .select("repost_of_id")
            .eq("author_id", value: userId)
            .not("repost_of_id", operator: .is, value: "null")
            .execute()
            .value
        repostedPostIds = Set(repostRows?.map { $0.repostOfId } ?? [])
    }

    private func applyInteractionState(_ posts: inout [SupabaseFeedPost]) {
        for i in posts.indices {
            posts[i].isLiked = likedPostIds.contains(posts[i].id)
            posts[i].isReposted = repostedPostIds.contains(posts[i].id)
            posts[i].isBookmarked = bookmarkedPostIds.contains(posts[i].id)
        }
    }

    // MARK: - Fetch Feed

    func fetchFeed(tab: FeedTab, loadMore: Bool = false) async {
        if !loadMore {
            isLoading = true
        }

        if !followingLoaded {
            await loadFollowingIds()
        }

        if likedPostIds.isEmpty && bookmarkedPostIds.isEmpty {
            await loadInteractionState()
        }

        do {
            var fetched: [SupabaseFeedPost]

            switch tab {
            case .forYou:
                if followingIds.isEmpty {
                    fetched = []
                } else {
                    let filterQuery = client
                        .from("feed_posts")
                        .select(selectQuery)
                        .in("author_id", values: Array(followingIds))

                    let offset = loadMore ? posts.count : 0
                    fetched = try await filterQuery
                        .order("created_at", ascending: false)
                        .range(from: offset, to: offset + pageSize - 1)
                        .execute().value
                }

            case .live:
                let twentyFourHoursAgo = ISO8601DateFormatter().string(
                    from: Date().addingTimeInterval(-86400)
                )
                let filterQuery = client
                    .from("feed_posts")
                    .select(selectQuery)
                    .gte("created_at", value: twentyFourHoursAgo)

                let offset = loadMore ? posts.count : 0
                fetched = try await filterQuery
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute().value

            case .dm:
                fetched = []
            }

            applyInteractionState(&fetched)

            // Resolve original posts for reposts
            await resolveReposts(&fetched)

            if loadMore {
                posts.append(contentsOf: fetched)
            } else {
                posts = fetched
            }

            hasMore = fetched.count >= pageSize
            isLoading = false
            hasLoadedOnce = true
            pendingNewPosts = 0
        } catch {
            self.error = "Failed to load feed"
            isLoading = false
            hasLoadedOnce = true
            print("Feed fetch error: \(error)")
        }
    }

    func loadMoreIfNeeded(currentPost: SupabaseFeedPost) async {
        guard hasMore, !isLoading else { return }
        let thresholdIndex = max(posts.count - 3, 0)
        if let index = posts.firstIndex(where: { $0.id == currentPost.id }),
           index >= thresholdIndex {
            await fetchFeed(tab: activeTab, loadMore: true)
        }
    }

    // MARK: - Resolve Reposts

    private func resolveReposts(_ posts: inout [SupabaseFeedPost]) async {
        let repostIds = posts.compactMap { $0.repostOfId }
        guard !repostIds.isEmpty else { return }

        let originals: [EmbeddedPost]? = try? await client
            .from("feed_posts")
            .select("id, author_id, content, court_tag_name, created_at, profiles(id, display_name, username, avatar_url, netr_score)")
            .in("id", values: repostIds)
            .execute()
            .value

        guard let originals else { return }
        let lookup = Dictionary(uniqueKeysWithValues: originals.map { ($0.id, $0) })

        for i in posts.indices {
            if let repostOfId = posts[i].repostOfId {
                posts[i].originalPost = lookup[repostOfId]
            }
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
                    .select("id, username, display_name, avatar_url, netr_score")
                    .or("username.ilike.\(query)%,display_name.ilike.%\(query)%")
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

    // MARK: - Follow changed

    func onFollowChanged() async {
        followingLoaded = false
        await loadFollowingIds()
        if activeTab == .forYou {
            await fetchFeed(tab: .forYou)
        }
    }

    // MARK: - Mention Search

    func searchMentions(text: String, cursorPosition: Int) {
        mentionSearchTask?.cancel()

        let prefixText = String(text.prefix(cursorPosition))
        guard let atIndex = prefixText.lastIndex(of: "@") else {
            mentionResults = []
            showMentionResults = false
            activeMentionQuery = ""
            return
        }

        let queryStart = prefixText.index(after: atIndex)
        let query = String(prefixText[queryStart...])

        if query.contains(" ") || query.isEmpty {
            mentionResults = []
            showMentionResults = false
            activeMentionQuery = ""
            return
        }

        activeMentionQuery = query
        showMentionResults = true

        mentionSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }

            do {
                let results: [UserSearchResult] = try await client
                    .from("profiles")
                    .select("id, username, display_name, avatar_url, netr_score")
                    .ilike("username", pattern: "\(query)%")
                    .limit(5)
                    .execute()
                    .value

                guard !Task.isCancelled else { return }
                mentionResults = results
            } catch {
                guard !Task.isCancelled else { return }
                mentionResults = []
            }
        }
    }

    func dismissMentionSearch() {
        mentionResults = []
        showMentionResults = false
        activeMentionQuery = ""
        mentionSearchTask?.cancel()
    }

    // MARK: - Create Post

    func createPost(content: String, courtId: String? = nil, courtName: String? = nil) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        isPosting = true

        let payload = CreateFeedPostPayload(
            authorId: userId,
            content: content,
            courtTagId: courtId,
            courtTagName: courtName,
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
            showToast("Failed to create post")
            print("Create post error: \(error)")
        }
    }

    // MARK: - Like

    func toggleLike(post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        guard let i = posts.firstIndex(where: { $0.id == post.id }) else { return }

        let wasLiked = posts[i].isLiked
        posts[i].isLiked = !wasLiked
        posts[i].likeCount += wasLiked ? -1 : 1

        if wasLiked {
            likedPostIds.remove(post.id)
        } else {
            likedPostIds.insert(post.id)
        }

        do {
            if wasLiked {
                try await client
                    .from("likes")
                    .delete()
                    .eq("post_id", value: post.id)
                    .eq("user_id", value: userId)
                    .execute()
            } else {
                try await client
                    .from("likes")
                    .insert(FeedLikePayload(postId: post.id, userId: userId))
                    .execute()
            }
        } catch {
            // Revert
            if let j = posts.firstIndex(where: { $0.id == post.id }) {
                posts[j].isLiked = wasLiked
                posts[j].likeCount = post.likeCount
            }
            if wasLiked { likedPostIds.insert(post.id) } else { likedPostIds.remove(post.id) }
            showToast("Failed to update like")
            print("Like error: \(error)")
        }
    }

    // MARK: - Repost

    func repost(post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        guard let i = posts.firstIndex(where: { $0.id == post.id }) else { return }

        let wasReposted = posts[i].isReposted
        posts[i].isReposted = !wasReposted
        posts[i].repostCount += wasReposted ? -1 : 1

        if wasReposted {
            repostedPostIds.remove(post.id)
        } else {
            repostedPostIds.insert(post.id)
        }

        do {
            if wasReposted {
                // Undo repost — delete the feed_post row with repost_of_id
                try await client
                    .from("feed_posts")
                    .delete()
                    .eq("repost_of_id", value: post.id)
                    .eq("author_id", value: userId)
                    .execute()
            } else {
                try await client
                    .from("feed_posts")
                    .insert(CreateFeedPostPayload(
                        authorId: userId,
                        content: "",
                        courtTagId: nil,
                        courtTagName: nil,
                        repostOfId: post.id
                    ))
                    .execute()
            }
        } catch {
            if let j = posts.firstIndex(where: { $0.id == post.id }) {
                posts[j].isReposted = wasReposted
                posts[j].repostCount = post.repostCount
            }
            if wasReposted { repostedPostIds.insert(post.id) } else { repostedPostIds.remove(post.id) }
            showToast("Failed to update repost")
            print("Repost error: \(error)")
        }
    }

    // MARK: - Bookmark

    func toggleBookmark(post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        guard let i = posts.firstIndex(where: { $0.id == post.id }) else { return }

        let wasBookmarked = posts[i].isBookmarked
        posts[i].isBookmarked = !wasBookmarked

        if wasBookmarked {
            bookmarkedPostIds.remove(post.id)
        } else {
            bookmarkedPostIds.insert(post.id)
        }

        do {
            if wasBookmarked {
                try await client
                    .from("bookmarks")
                    .delete()
                    .eq("post_id", value: post.id)
                    .eq("user_id", value: userId)
                    .execute()
            } else {
                try await client
                    .from("bookmarks")
                    .insert(BookmarkPayload(postId: post.id, userId: userId))
                    .execute()
            }
        } catch {
            if let j = posts.firstIndex(where: { $0.id == post.id }) {
                posts[j].isBookmarked = wasBookmarked
            }
            if wasBookmarked { bookmarkedPostIds.insert(post.id) } else { bookmarkedPostIds.remove(post.id) }
            showToast("Failed to update bookmark")
            print("Bookmark error: \(error)")
        }
    }

    // MARK: - Delete

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
            showToast("Failed to delete post")
            print("Delete post error: \(error)")
        }
    }

    func blockUser(userId: String) async {
        posts.removeAll { $0.authorId == userId }
    }

    // MARK: - Court Search

    func searchCourts(query: String) async {
        guard query.count >= 1 else {
            courtResults = []
            return
        }

        do {
            let results: [FeedCourtSearchResult] = try await client
                .from("courts")
                .select("id, name, location")
                .or("name.ilike.%\(query)%,location.ilike.%\(query)%")
                .limit(10)
                .execute()
                .value

            courtResults = results
        } catch {
            print("Court search error: \(error)")
        }
    }

    // MARK: - Bookmarked Posts (for profile saved tab)

    func fetchBookmarkedPosts() async -> [SupabaseFeedPost] {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return [] }

        nonisolated struct BookmarkWithPost: Decodable, Sendable {
            let postId: String
            nonisolated enum CodingKeys: String, CodingKey { case postId = "post_id" }
        }

        let bookmarkRows: [BookmarkWithPost]? = try? await client
            .from("bookmarks")
            .select("post_id")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        guard let ids = bookmarkRows?.map({ $0.postId }), !ids.isEmpty else { return [] }

        var posts: [SupabaseFeedPost] = (try? await client
            .from("feed_posts")
            .select(selectQuery)
            .in("id", values: ids)
            .execute()
            .value) ?? []

        applyInteractionState(&posts)
        // Sort to match bookmark order
        let idOrder = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
        posts.sort { (idOrder[$0.id] ?? 0) < (idOrder[$1.id] ?? 0) }
        return posts
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

        let commentChanges = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "comments"
        )

        await channel.subscribe()

        realtimeTask = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in postChanges {
                        if self.activeTab == .live {
                            self.pendingNewPosts += 1
                        } else {
                            await self.fetchFeed(tab: self.activeTab)
                        }
                    }
                }
                group.addTask {
                    for await change in commentChanges {
                        if let postId = change.record["post_id"]?.stringValue,
                           let idx = self.posts.firstIndex(where: { $0.id == postId }) {
                            self.posts[idx].commentCount += 1
                        }
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

    // MARK: - Toast

    func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    // MARK: - Suggested Players

    func fetchSuggestedPlayers() async -> [UserSearchResult] {
        let results: [UserSearchResult]? = try? await client
            .from("profiles")
            .select("id, username, display_name, avatar_url, netr_score")
            .not("netr_score", operator: .is, value: "null")
            .order("netr_score", ascending: false)
            .limit(10)
            .execute()
            .value

        let currentUserId = SupabaseManager.shared.session?.user.id.uuidString
        return (results ?? []).filter { $0.id != currentUserId && !followingIds.contains($0.id) }
    }
}
