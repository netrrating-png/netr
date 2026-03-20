import Foundation

// MARK: - Conversation

nonisolated struct DMConversation: Identifiable, Sendable, Equatable {
    let id: String
    let participantIds: [String]
    let lastMessageText: String?
    let lastMessageAt: String?
    let createdAt: String
    var otherUser: FeedAuthor?
    var unreadCount: Int = 0

    static func == (lhs: DMConversation, rhs: DMConversation) -> Bool {
        lhs.id == rhs.id && lhs.lastMessageAt == rhs.lastMessageAt && lhs.unreadCount == rhs.unreadCount
    }
}

extension DMConversation: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case participantIds = "participant_ids"
        case lastMessageText = "last_message_text"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        participantIds = try container.decode([String].self, forKey: .participantIds)
        lastMessageText = try container.decodeIfPresent(String.self, forKey: .lastMessageText)
        lastMessageAt = try container.decodeIfPresent(String.self, forKey: .lastMessageAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}

// MARK: - Message

nonisolated struct DMMessage: Identifiable, Sendable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let createdAt: String
    var sender: FeedAuthor?

    static func == (lhs: DMMessage, rhs: DMMessage) -> Bool {
        lhs.id == rhs.id
    }
}

extension DMMessage: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case createdAt = "created_at"
        case sender = "profiles"
    }
}

// MARK: - Payloads

nonisolated struct CreateConversationPayload: Encodable, Sendable {
    let participantIds: [String]

    nonisolated enum CodingKeys: String, CodingKey {
        case participantIds = "participant_ids"
    }
}

nonisolated struct CreateMessagePayload: Encodable, Sendable {
    let conversationId: String
    let senderId: String
    let content: String

    nonisolated enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
    }
}

nonisolated struct UpdateConversationLastMessage: Encodable, Sendable {
    let lastMessageText: String
    let lastMessageAt: String

    nonisolated enum CodingKeys: String, CodingKey {
        case lastMessageText = "last_message_text"
        case lastMessageAt = "last_message_at"
    }
}

nonisolated struct MarkReadPayload: Encodable, Sendable {
    let readAt: String

    nonisolated enum CodingKeys: String, CodingKey {
        case readAt = "read_at"
    }
}

// MARK: - Unread tracking row

nonisolated struct ConversationReadRow: Decodable, Sendable {
    let conversationId: String
    let userId: String
    let readAt: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
        case readAt = "read_at"
    }
}

nonisolated struct MessageCountRow: Decodable, Sendable {
    let conversationId: String
    let createdAt: String

    nonisolated enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case createdAt = "created_at"
    }
}
