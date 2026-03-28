import Foundation

// MARK: - Direct Message (maps to direct_messages table)

nonisolated struct DirectMessage: Identifiable, Sendable, Equatable {
    let id: String
    let senderId: String
    let recipientId: String
    let content: String
    let read: Bool
    let courtTagId: String?
    let courtTagName: String?
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
        case courtTagId = "court_tag_id"
        case courtTagName = "court_tag_name"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        senderId = try container.decode(String.self, forKey: .senderId)
        recipientId = try container.decode(String.self, forKey: .recipientId)
        content = try container.decode(String.self, forKey: .content)
        read = try container.decodeIfPresent(Bool.self, forKey: .read) ?? false
        courtTagId = try container.decodeIfPresent(String.self, forKey: .courtTagId)
        courtTagName = try container.decodeIfPresent(String.self, forKey: .courtTagName)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}

// MARK: - Send Message Payload

nonisolated struct SendDirectMessagePayload: Encodable, Sendable {
    let senderId: String
    let recipientId: String
    let content: String
    let courtTagId: String?
    let courtTagName: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case content
        case courtTagId = "court_tag_id"
        case courtTagName = "court_tag_name"
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
