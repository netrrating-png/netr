import SwiftUI
import Supabase
import Auth
import PostgREST
import CoreLocation

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

    // Follow state
    var followingIds: Set<String> = []
    var followingLoaded: Bool = false

    // Interaction sets for instant UI state
    var likedPostIds: Set<String> = []
    var bookmarkedPostIds: Set<String> = []
    var repostedPostIds: Set<String> = []

    // Search
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

    // Discover tab
    var nearbyUsers: [UserSearchResult] = []
    var isLoadingNearby: Bool = false
    var userLocation: CLLocationCoordinate2D?

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var mentionSearchTask: Task<Void, Never>?
    private let pageSize = 20
    private var discoverLocationHelper: DiscoverLocationHelper?

    private let selectQuery = """
        id, author_id, content, like_count, comment_count, repost_count,
        court_tag_id, court_tag_name, repost_of_id, created_at,
        profiles(id, full_name, username, avatar_url, netr_score)
    """

    // MARK: - Follow IDs

    func loadFollowingIds() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return }
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
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return }

        let likedRows: [FeedLikeRow]? = try? await client
            .from("likes")
            .select("post_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        likedPostIds = Set(likedRows?.map { $0.postId } ?? [])

        let bookmarkRows: [BookmarkRow]? = try? await client
            .from("bookmarks")
            .select("post_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        bookmarkedPostIds = Set(bookmarkRows?.map { $0.postId } ?? [])

        let repostRows: [RepostRow]? = try? await client
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
            posts[i].isBookmarked = bookmarkedPostIds.contains(posts[i].id)
            posts[i].isReposted = repostedPostIds.contains(posts[i].id)
        }
    }

    // MARK: - Fetch Feed

    func fetchFeed(tab: FeedTab, loadMore: Bool = false) async {
        if tab == .discover {
            requestDiscoverLocation()
            hasLoadedOnce = true
            return
        }
        if !loadMore {
            isLoading = true
        }

        if !followingLoaded {
            await loadFollowingIds()
        }

        if likedPostIds.isEmpty {
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
                let offset = loadMore ? posts.count : 0
                fetched = try await client
                    .from("feed_posts")
                    .select(selectQuery)
                    .gte("created_at", value: twentyFourHoursAgo)
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute().value

            case .discover:
                fetched = []
            }

            applyInteractionState(&fetched)

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
            print("[NETR] Feed fetch error: \(error)")
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

    // MARK: - Search (Players)

    func performSearch(query: String) {
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
                    .or("username.ilike.\(query)%,full_name.ilike.%\(query)%")
                    .limit(8)
                    .execute()
                    .value

                guard !Task.isCancelled else { return }
                userSearchResults = results
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                isSearching = false
                print("[NETR] User search error: \(error)")
            }
        }
    }

    func searchUsers(query: String) {
        performSearch(query: query)
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
                    .select("id, username, full_name, avatar_url, netr_score")
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
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return }
        isPosting = true

        let payload = CreateFeedPostPayload(
            authorId: userId,
            content: content,
            courtTagId: courtId,
            courtTagName: courtName
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
            print("[NETR] Create post error: \(error)")
            if let localizedError = error as? LocalizedError {
                print("[NETR] Create post detail: \(localizedError.errorDescription ?? "none")")
            }
        }
    }

    // MARK: - Like

    func toggleLike(post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return }
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
            print("[NETR] Like error: \(error)")
        }
    }

    // MARK: - Bookmark

    func toggleBookmark(post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return }
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
            print("[NETR] Bookmark error: \(error)")
        }
    }

    // MARK: - Repost

    func repost(post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return }
        guard let i = posts.firstIndex(where: { $0.id == post.id }) else { return }

        posts[i].isReposted = true
        posts[i].repostCount += 1
        repostedPostIds.insert(post.id)

        do {
            let payload = RepostPayload(authorId: userId, content: post.content, repostOfId: post.id)
            let created: SupabaseFeedPost = try await client
                .from("feed_posts")
                .insert(payload)
                .select(selectQuery)
                .single()
                .execute()
                .value

            posts.insert(created, at: 0)
        } catch {
            if let j = posts.firstIndex(where: { $0.id == post.id }) {
                posts[j].isReposted = false
                posts[j].repostCount = post.repostCount
            }
            repostedPostIds.remove(post.id)
            showToast("Failed to repost")
            print("[NETR] Repost error: \(error)")
        }
    }

    func undoRepost(post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return }
        guard let i = posts.firstIndex(where: { $0.id == post.id }) else { return }

        posts[i].isReposted = false
        posts[i].repostCount = max(0, posts[i].repostCount - 1)
        repostedPostIds.remove(post.id)

        do {
            try await client
                .from("feed_posts")
                .delete()
                .eq("author_id", value: userId)
                .eq("repost_of_id", value: post.id)
                .execute()

            posts.removeAll { $0.repostOfId == post.id && $0.authorId == userId }
        } catch {
            if let j = posts.firstIndex(where: { $0.id == post.id }) {
                posts[j].isReposted = true
                posts[j].repostCount = post.repostCount
            }
            repostedPostIds.insert(post.id)
            showToast("Failed to undo repost")
            print("[NETR] Undo repost error: \(error)")
        }
    }

    // MARK: - Delete

    func deletePost(_ post: SupabaseFeedPost) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased(),
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
            print("[NETR] Delete post error: \(error)")
        }
    }

    func blockUser(userId: String) async {
        posts.removeAll { $0.authorId == userId }
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
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return false }
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
        let currentUserId = SupabaseManager.shared.session?.user.id.uuidString.lowercased()

        // Fetch all users — don't filter by netr_score (most testers won't have one yet)
        // Order: scored users first (by score DESC), then unscored by newest
        let results: [UserSearchResult]? = try? await client
            .from("profiles")
            .select("id, username, full_name, avatar_url, netr_score")
            .neq("id", value: currentUserId ?? "")
            .order("netr_score", ascending: false, nullsFirst: false)
            .order("created_at", ascending: false)
            .limit(30)
            .execute()
            .value

        return (results ?? []).filter { !followingIds.contains($0.id) }
            .prefix(20)
            .map { $0 }
    }

    // MARK: - Open Profile by Username (for mention taps)

    func openProfile(username: String) async {
        let results: [UserSearchResult]? = try? await client
            .from("profiles")
            .select("id, username, full_name, avatar_url, netr_score")
            .eq("username", value: username)
            .limit(1)
            .execute()
            .value
        if let user = results?.first {
            selectedProfileUserId = user.id
        }
    }

    // MARK: - Discover (Nearby Users)

    func requestDiscoverLocation() {
        if let loc = userLocation {
            Task { await fetchNearbyUsers(at: loc) }
            return
        }
        isLoadingNearby = true
        discoverLocationHelper = DiscoverLocationHelper { [weak self] location in
            Task { @MainActor [weak self] in
                self?.userLocation = location
                await self?.fetchNearbyUsers(at: location)
            }
        }
        discoverLocationHelper?.requestLocation()
    }

    func fetchNearbyUsers(at loc: CLLocationCoordinate2D) async {
        isLoadingNearby = true
        let currentUserId = SupabaseManager.shared.session?.user.id.uuidString.lowercased()

        // Update current user's location in profiles so they show up for others
        if let uid = currentUserId {
            try? await client
                .from("profiles")
                .update(["lat": AnyJSON.double(loc.latitude), "lng": AnyJSON.double(loc.longitude)])
                .eq("id", value: uid)
                .execute()
        }

        // Bounding box: ~5 miles in each direction
        let latDelta = 0.0725
        let lngDelta = 0.0725 / max(cos(loc.latitude * .pi / 180), 0.01)

        let results: [UserSearchResult]? = try? await client
            .from("profiles")
            .select("id, username, full_name, avatar_url, netr_score, lat, lng")
            .not("lat", operator: .is, value: "null")
            .gte("lat", value: loc.latitude - latDelta)
            .lte("lat", value: loc.latitude + latDelta)
            .gte("lng", value: loc.longitude - lngDelta)
            .lte("lng", value: loc.longitude + lngDelta)
            .limit(50)
            .execute()
            .value

        let userLoc = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        let maxMeters = 5.0 * 1609.34

        nearbyUsers = (results ?? [])
            .filter { user in
                guard let uLat = user.lat, let uLng = user.lng,
                      user.id != currentUserId else { return false }
                return CLLocation(latitude: uLat, longitude: uLng).distance(from: userLoc) <= maxMeters
            }
            .sorted { a, b in
                let dA: Double
                let dB: Double
                if let aLat = a.lat, let aLng = a.lng {
                    dA = CLLocation(latitude: aLat, longitude: aLng).distance(from: userLoc)
                } else { dA = .greatestFiniteMagnitude }
                if let bLat = b.lat, let bLng = b.lng {
                    dB = CLLocation(latitude: bLat, longitude: bLng).distance(from: userLoc)
                } else { dB = .greatestFiniteMagnitude }
                return dA < dB
            }

        isLoadingNearby = false
    }
}

// MARK: - Location helper for Discover tab

private final class DiscoverLocationHelper: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let onLocation: (CLLocationCoordinate2D) -> Void

    init(onLocation: @escaping (CLLocationCoordinate2D) -> Void) {
        self.onLocation = onLocation
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let coord = locations.first?.coordinate {
            onLocation(coord)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[NETR Discover] Location error: \(error.localizedDescription)")
    }
}
