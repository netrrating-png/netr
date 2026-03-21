import Foundation

// MARK: - Direct Message (maps to direct_messages table)

nonisolated struct DirectMessage: Identifiable, Sendable, Equatable {
    let id: String
    let senderId: String
    let recipientId: String
    let content: String
    let read: Bool
    let createdAt: String

    static func == (lhs: DirectMessage, rhs: DirectMessage) -> Bool {
        lhs.id == rhs.id && lhs.read == rhs.read
    }
}

extension DirectMessage: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case content
        case read
        case createdAt = "created_at"
    }
}

// MARK: - Send Message Payload

nonisolated struct SendDirectMessagePayload: Encodable, Sendable {
    let senderId: String
    let recipientId: String
    let content: String

    nonisolated enum CodingKeys: String, CodingKey {
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case content
    }
}

// MARK: - Mark Read Update

nonisolated struct MarkMessageReadPayload: Encodable, Sendable {
    let read: Bool
}

// MARK: - Conversation (computed from direct_messages, not a table)

struct DMConversation: Identifiable, Equatable {
    var id: String { otherUserId }
    let otherUserId: String
    var otherUser: FeedAuthor?
    var lastMessage: String?
    var lastMessageAt: String?
    var unreadCount: Int = 0

    static func == (lhs: DMConversation, rhs: DMConversation) -> Bool {
        lhs.otherUserId == rhs.otherUserId
            && lhs.lastMessageAt == rhs.lastMessageAt
            && lhs.unreadCount == rhs.unreadCount
    }
}
