import Foundation

nonisolated struct SupabaseFeedPost: Identifiable, Sendable, Equatable {
    let id: String
    let authorId: String
    let content: String
    let hashtags: [String]
    let mentionedUserIds: [String]
    let courtId: String?
    let gameId: String?
    let repostOfId: String?
    let quoteOfId: String?
    let photoUrl: String?
    var likeCount: Int
    var commentCount: Int
    var repostCount: Int
    let createdAt: String
    var author: FeedAuthor?
    var taggedCourt: FeedCourt?
    var isLiked: Bool = false
    var isReposted: Bool = false

    static func == (lhs: SupabaseFeedPost, rhs: SupabaseFeedPost) -> Bool {
        lhs.id == rhs.id && lhs.isLiked == rhs.isLiked && lhs.likeCount == rhs.likeCount && lhs.isReposted == rhs.isReposted
    }
}

extension SupabaseFeedPost: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case content
        case hashtags
        case mentionedUserIds = "mentioned_user_ids"
        case courtId = "court_id"
        case gameId = "game_id"
        case repostOfId = "repost_of_id"
        case quoteOfId = "quote_of_id"
        case photoUrl = "photo_url"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case repostCount = "repost_count"
        case createdAt = "created_at"
        case author = "profiles"
        case taggedCourt = "courts"
    }
}

nonisolated struct FeedAuthor: Sendable {
    let id: String
    let fullName: String?
    let username: String?
    let avatarUrl: String?
    let netrScore: Double?
    let vibeScore: Double?

    var displayName: String { fullName ?? username ?? "Player" }
    var handle: String { username.map { "@\($0)" } ?? "" }
}

extension FeedAuthor: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case username
        case avatarUrl = "avatar_url"
        case netrScore = "netr_score"
        case vibeScore = "vibe_score"
    }
}

nonisolated struct FeedCourt: Sendable {
    let id: String
    let name: String
    let neighborhood: String?
    let verified: Bool?
}

extension FeedCourt: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, verified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        name = try container.decode(String.self, forKey: .name)
        neighborhood = try container.decodeIfPresent(String.self, forKey: .neighborhood)
        verified = try container.decodeIfPresent(Bool.self, forKey: .verified)
    }
}

nonisolated struct PostComment: Identifiable, Sendable {
    let id: String
    let postId: String
    let userId: String
    let content: String
    let likeCount: Int
    let createdAt: String
    var author: FeedAuthor?
}

extension PostComment: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case content
        case likeCount = "like_count"
        case createdAt = "created_at"
        case author = "profiles"
    }
}

nonisolated struct CreateFeedPostPayload: Encodable, Sendable {
    let authorId: String
    let content: String
    let hashtags: [String]
    let mentionedUserIds: [String]
    let courtId: String?
    let gameId: String?
    let quoteOfId: String?
    let repostOfId: String?
    let photoUrl: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case content
        case hashtags
        case mentionedUserIds = "mentioned_user_ids"
        case courtId = "court_id"
        case gameId = "game_id"
        case quoteOfId = "quote_of_id"
        case repostOfId = "repost_of_id"
        case photoUrl = "photo_url"
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

nonisolated struct FeedRepostPayload: Encodable, Sendable {
    let postId: String
    let userId: String

    nonisolated enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
    }
}

nonisolated struct CreateCommentPayload: Encodable, Sendable {
    let postId: String
    let userId: String
    let content: String

    nonisolated enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
        case content
    }
}

nonisolated struct FeedLikeRow: Decodable, Sendable {
    let postId: String
    nonisolated enum CodingKeys: String, CodingKey { case postId = "post_id" }
}

nonisolated struct FeedRepostRow: Decodable, Sendable {
    let postId: String
    nonisolated enum CodingKeys: String, CodingKey { case postId = "post_id" }
}

nonisolated struct HashtagRow: Decodable, Sendable {
    let hashtags: [String]
}

nonisolated struct FeedCourtSearchResult: Sendable {
    let id: String
    let name: String
    let neighborhood: String?
    let verified: Bool?
}

extension FeedCourtSearchResult: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, verified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        name = try container.decode(String.self, forKey: .name)
        neighborhood = try container.decodeIfPresent(String.self, forKey: .neighborhood)
        verified = try container.decodeIfPresent(Bool.self, forKey: .verified)
    }
}

enum FeedTab: String, CaseIterable {
    case forYou = "For You"
    case all = "All"
    case trending = "Trending"
}

nonisolated struct CourtPhoto: Identifiable, Sendable {
    let id: String
    let courtId: String
    let userId: String
    let photoUrl: String
    let createdAt: String
    var uploader: FeedAuthor?
}

extension CourtPhoto: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case courtId = "court_id"
        case userId = "user_id"
        case photoUrl = "photo_url"
        case createdAt = "created_at"
        case uploader = "profiles"
    }
}

nonisolated struct CreateCourtPhotoPayload: Encodable, Sendable {
    let courtId: String
    let userId: String
    let photoUrl: String

    nonisolated enum CodingKeys: String, CodingKey {
        case courtId = "court_id"
        case userId = "user_id"
        case photoUrl = "photo_url"
    }
}

nonisolated struct FollowingIdRow: Decodable, Sendable {
    let followingId: String
    nonisolated enum CodingKeys: String, CodingKey { case followingId = "following_id" }
}

func extractHashtags(from text: String) -> [String] {
    let pattern = #"#(\w+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).compactMap {
        Range($0.range(at: 1), in: text).map { String(text[$0]).lowercased() }
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
