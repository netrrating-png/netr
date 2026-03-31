import Foundation

// MARK: - Feed Post

nonisolated struct SupabaseFeedPost: Identifiable, Sendable, Equatable {
    let id: String
    let authorId: String
    let content: String
    var likeCount: Int
    var commentCount: Int
    var repostCount: Int
    let courtTagId: String?
    let courtTagName: String?
    let repostOfId: String?
    let createdAt: String
    var author: FeedAuthor?
    // Local UI state
    var isLiked: Bool = false
    var isReposted: Bool = false
    var isBookmarked: Bool = false

    static func == (lhs: SupabaseFeedPost, rhs: SupabaseFeedPost) -> Bool {
        lhs.id == rhs.id && lhs.isLiked == rhs.isLiked && lhs.likeCount == rhs.likeCount && lhs.isBookmarked == rhs.isBookmarked && lhs.repostCount == rhs.repostCount
    }
}

extension SupabaseFeedPost: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case content
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case repostCount = "repost_count"
        case courtTagId = "court_tag_id"
        case courtTagName = "court_tag_name"
        case repostOfId = "repost_of_id"
        case createdAt = "created_at"
        case author = "profiles"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        content = try container.decode(String.self, forKey: .content)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        repostCount = try container.decodeIfPresent(Int.self, forKey: .repostCount) ?? 0
        courtTagId = try container.decodeIfPresent(String.self, forKey: .courtTagId)
        courtTagName = try container.decodeIfPresent(String.self, forKey: .courtTagName)
        repostOfId = try container.decodeIfPresent(String.self, forKey: .repostOfId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        author = try container.decodeIfPresent(FeedAuthor.self, forKey: .author)
    }
}

// MARK: - Feed Author

nonisolated struct FeedAuthor: Sendable, Equatable {
    let id: String
    let displayName: String?
    let username: String?
    let avatarUrl: String?
    let netrScore: Double?

    var name: String { displayName ?? username ?? "Player" }
    var handle: String { username.map { "@\($0)" } ?? "" }
}

extension FeedAuthor: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case displayName = "full_name"
        case username
        case avatarUrl = "avatar_url"
        case netrScore = "netr_score"
    }
}

// MARK: - Comment

nonisolated struct PostComment: Identifiable, Sendable {
    let id: String
    let postId: String
    let authorId: String
    let content: String
    var likeCount: Int
    let parentCommentId: String?
    let createdAt: String
    var author: FeedAuthor?
    // Local UI state
    var isLiked: Bool = false
    // Child replies (built client-side)
    var replies: [PostComment] = []
}

extension PostComment: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case authorId = "author_id"
        case content
        case likeCount = "like_count"
        case parentCommentId = "parent_comment_id"
        case createdAt = "created_at"
        case author = "profiles"
    }
}

// MARK: - Create Payloads

nonisolated struct CreateFeedPostPayload: Encodable, Sendable {
    let authorId: String
    let content: String
    let courtTagId: String?
    let courtTagName: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case content
        case courtTagId = "court_tag_id"
        case courtTagName = "court_tag_name"
    }
}

nonisolated struct CreateCommentPayload: Encodable, Sendable {
    let postId: String
    let authorId: String
    let content: String
    let parentCommentId: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case authorId = "author_id"
        case content
        case parentCommentId = "parent_comment_id"
    }
}

nonisolated struct FeedLikePayload: Encodable, Sendable {
    let postId: String
    let userId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
    }
}

nonisolated struct CommentLikePayload: Encodable, Sendable {
    let commentId: String
    let userId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case userId = "user_id"
    }
}

nonisolated struct BookmarkPayload: Encodable, Sendable {
    let postId: String
    let userId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
    }
}

nonisolated struct RepostPayload: Encodable, Sendable {
    let authorId: String
    let content: String
    let repostOfId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case content
        case repostOfId = "repost_of_id"
    }
}

nonisolated struct MentionPayload: Encodable, Sendable {
    let commentId: String
    let postId: String
    let mentionedUserId: String
    let mentioningUserId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case postId = "post_id"
        case mentionedUserId = "mentioned_user_id"
        case mentioningUserId = "mentioning_user_id"
    }
}

// MARK: - Helper Row Types

nonisolated struct FeedLikeRow: Decodable, Sendable {
    let postId: String
    nonisolated enum CodingKeys: String, CodingKey { case postId = "post_id" }
}

nonisolated struct CommentLikeRow: Decodable, Sendable {
    let commentId: String
    nonisolated enum CodingKeys: String, CodingKey { case commentId = "comment_id" }
}

nonisolated struct FollowingIdRow: Decodable, Sendable {
    let followingId: String
    nonisolated enum CodingKeys: String, CodingKey { case followingId = "following_id" }
}

nonisolated struct BookmarkRow: Decodable, Sendable {
    let postId: String
    nonisolated enum CodingKeys: String, CodingKey { case postId = "post_id" }
}

nonisolated struct RepostRow: Decodable, Sendable {
    let repostOfId: String
    nonisolated enum CodingKeys: String, CodingKey { case repostOfId = "repost_of_id" }
}

// MARK: - Court Search

nonisolated struct FeedCourtSearchResult: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let neighborhood: String?
    let city: String?

    var locationLabel: String {
        [neighborhood, city].compactMap { $0 }.joined(separator: ", ")
    }
}

extension FeedCourtSearchResult: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, city
    }
}

// MARK: - Feed Tab

enum FeedTab: String, CaseIterable {
    case forYou = "For You"
    case live = "Live"
}

// MARK: - User Search

nonisolated struct UserSearchResult: Identifiable, Sendable {
    let id: String
    let username: String?
    let displayName: String?
    let avatarUrl: String?
    let netrScore: Double?
}

extension UserSearchResult: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "full_name"
        case avatarUrl = "avatar_url"
        case netrScore = "netr_score"
    }
}

// MARK: - String Helpers

extension Date {
    var relativeShort: String {
        let seconds = Int(-timeIntervalSinceNow)
        if seconds < 60 { return "\(max(seconds, 1))s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        if seconds < 604800 { return "\(seconds / 86400)d" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}

extension String {
    var relativeTimeFromISO: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: self) {
            return date.relativeShort
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        if let date = fallback.date(from: self) {
            return date.relativeShort
        }
        return ""
    }
}

// MARK: - Court Photos

nonisolated struct CourtPhoto: Identifiable, Sendable {
    let id: String
    let courtId: String
    let userId: String
    let photoUrl: String
    let caption: String?
    let isApproved: Bool
    let createdAt: String
    var uploader: FeedAuthor?
}

extension CourtPhoto: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case courtId = "court_id"
        case userId = "user_id"
        case photoUrl = "photo_url"
        case caption
        case isApproved = "is_approved"
        case createdAt = "created_at"
        case uploader = "profiles"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        courtId = try container.decode(String.self, forKey: .courtId)
        userId = try container.decode(String.self, forKey: .userId)
        photoUrl = try container.decode(String.self, forKey: .photoUrl)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        isApproved = try container.decodeIfPresent(Bool.self, forKey: .isApproved) ?? true
        createdAt = try container.decode(String.self, forKey: .createdAt)
        uploader = try container.decodeIfPresent(FeedAuthor.self, forKey: .uploader)
    }
}

nonisolated struct CreateCourtPhotoPayload: Encodable, Sendable {
    let courtId: String
    let userId: String
    let photoUrl: String
    let caption: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case courtId = "court_id"
        case userId = "user_id"
        case photoUrl = "photo_url"
        case caption
    }
}

func extractMentions(from text: String) -> [String] {
    let pattern = #"@(\w+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).compactMap {
        Range($0.range(at: 1), in: text).map { String(text[$0]).lowercased() }
    }
}
