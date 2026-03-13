import Foundation

nonisolated struct MockPostAuthor: Equatable, Sendable {
    let name: String
    let username: String
    let avatar: String
    let rating: Double?
    let verified: Bool
}

struct MockFeedPost: Identifiable, Equatable {
    let id: Int
    let author: MockPostAuthor
    let time: String
    let content: String
    let tags: [String]
    let court: String?
    let isGame: Bool
    let joinCode: String?
    var likes: Int
    var comments: Int
    var reposts: Int
    var liked: Bool
    var bookmarked: Bool

    static func == (lhs: MockFeedPost, rhs: MockFeedPost) -> Bool {
        lhs.id == rhs.id && lhs.liked == rhs.liked && lhs.bookmarked == rhs.bookmarked && lhs.likes == rhs.likes
    }
}
