import SwiftUI
import Supabase

@Observable
class DMViewModel {

    var conversations: [DMConversation] = []
    var isLoading: Bool = false
    var totalUnread: Int = 0

    // New message search
    var searchText: String = ""
    var searchResults: [UserSearchResult] = []
    var isSearching: Bool = false
    var showNewMessage: Bool = false

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    private var currentUserId: String? {
        SupabaseManager.shared.session?.user.id.uuidString
    }

    // MARK: - Load Conversations

    func loadConversations() async {
        guard let userId = currentUserId else { return }
        isLoading = true

        do {
            let rows: [DMConversation] = try await client
                .from("conversations")
                .select("id, participant_ids, last_message_text, last_message_at, created_at")
                .contains("participant_ids", value: [userId])
                .order("last_message_at", ascending: false)
                .execute()
                .value

            // Load other user profiles and unread counts
            var enriched: [DMConversation] = []
            for var convo in rows {
                let otherId = convo.participantIds.first(where: { $0 != userId }) ?? userId
                convo.otherUser = await loadUserProfile(userId: otherId)
                convo.unreadCount = await getUnreadCount(conversationId: convo.id, userId: userId)
                enriched.append(convo)
            }

            conversations = enriched
            totalUnread = enriched.reduce(0) { $0 + $1.unreadCount }
            isLoading = false
        } catch {
            isLoading = false
            print("Load conversations error: \(error)")
        }
    }

    // MARK: - Find or Create Conversation

    func findOrCreateConversation(with otherId: String) async -> DMConversation? {
        guard let userId = currentUserId else { return nil }

        // Check if conversation already exists
        if let existing = conversations.first(where: { convo in
            convo.participantIds.contains(otherId) && convo.participantIds.contains(userId)
        }) {
            return existing
        }

        // Create new conversation
        do {
            let payload = CreateConversationPayload(participantIds: [userId, otherId])
            let created: DMConversation = try await client
                .from("conversations")
                .insert(payload)
                .select("id, participant_ids, last_message_text, last_message_at, created_at")
                .single()
                .execute()
                .value

            var convo = created
            convo.otherUser = await loadUserProfile(userId: otherId)
            conversations.insert(convo, at: 0)
            return convo
        } catch {
            print("Create conversation error: \(error)")
            return nil
        }
    }

    // MARK: - Mark as Read

    func markAsRead(conversationId: String) async {
        guard let userId = currentUserId else { return }

        let now = ISO8601DateFormatter().string(from: Date())

        do {
            // Upsert the read marker
            try await client
                .from("conversation_reads")
                .upsert([
                    "conversation_id": AnyJSON.string(conversationId),
                    "user_id": AnyJSON.string(userId),
                    "read_at": AnyJSON.string(now)
                ])
                .execute()

            // Update local state
            if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
                conversations[idx].unreadCount = 0
                totalUnread = conversations.reduce(0) { $0 + $1.unreadCount }
            }
        } catch {
            print("Mark read error: \(error)")
        }
    }

    // MARK: - User Search (for new message)

    func searchUsers(query: String) {
        searchTask?.cancel()

        guard query.count >= 1 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            do {
                let results: [UserSearchResult] = try await client
                    .from("profiles")
                    .select("id, username, full_name, avatar_url, netr_score")
                    .ilike("username", pattern: "\(query)%")
                    .neq("id", value: currentUserId ?? "")
                    .limit(8)
                    .execute()
                    .value

                guard !Task.isCancelled else { return }
                searchResults = results
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                isSearching = false
                print("DM user search error: \(error)")
            }
        }
    }

    // MARK: - Realtime

    func subscribeToConversations() async {
        realtimeChannel = client.realtimeV2.channel("dm-conversations")
        guard let channel = realtimeChannel else { return }

        let messageChanges = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages"
        )

        await channel.subscribe()

        realtimeTask = Task {
            for await _ in messageChanges {
                await self.loadConversations()
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

    // MARK: - Helpers

    private func loadUserProfile(userId: String) async -> FeedAuthor? {
        try? await client
            .from("profiles")
            .select("id, full_name, username, avatar_url, netr_score, vibe_score")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    private func getUnreadCount(conversationId: String, userId: String) async -> Int {
        // Get the user's last read timestamp
        let readRow: ConversationReadRow? = try? await client
            .from("conversation_reads")
            .select("conversation_id, user_id, read_at")
            .eq("conversation_id", value: conversationId)
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value

        // Count messages after that timestamp from other users
        do {
            var query = client
                .from("messages")
                .select("conversation_id, created_at")
                .eq("conversation_id", value: conversationId)
                .neq("sender_id", value: userId)

            if let readAt = readRow?.readAt {
                query = query.gt("created_at", value: readAt)
            }

            let rows: [MessageCountRow] = try await query.execute().value
            return rows.count
        } catch {
            return 0
        }
    }
}

// MARK: - Chat ViewModel (for a single conversation thread)

@Observable
class ChatViewModel {

    let conversation: DMConversation
    var messages: [DMMessage] = []
    var isLoading: Bool = false
    var isSending: Bool = false
    var messageText: String = ""
    var error: String?

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    private let maxChars = 500

    var currentUserId: String? {
        SupabaseManager.shared.session?.user.id.uuidString
    }

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && messageText.count <= maxChars
            && !isSending
    }

    var characterCount: Int { messageText.count }
    var showCharCount: Bool { messageText.count > 400 }

    init(conversation: DMConversation) {
        self.conversation = conversation
    }

    // MARK: - Load Messages

    func loadMessages() async {
        isLoading = true

        do {
            let rows: [DMMessage] = try await client
                .from("messages")
                .select("id, conversation_id, sender_id, content, created_at, profiles(id, full_name, username, avatar_url, netr_score, vibe_score)")
                .eq("conversation_id", value: conversation.id)
                .order("created_at", ascending: true)
                .execute()
                .value

            messages = rows
            isLoading = false
        } catch {
            isLoading = false
            print("Load messages error: \(error)")
        }
    }

    // MARK: - Send Message

    func sendMessage() async {
        guard let userId = currentUserId else { return }
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= maxChars else { return }

        isSending = true
        let sentText = messageText
        messageText = ""

        do {
            let payload = CreateMessagePayload(
                conversationId: conversation.id,
                senderId: userId,
                content: text
            )

            let created: DMMessage = try await client
                .from("messages")
                .insert(payload)
                .select("id, conversation_id, sender_id, content, created_at, profiles(id, full_name, username, avatar_url, netr_score, vibe_score)")
                .single()
                .execute()
                .value

            messages.append(created)

            // Update conversation's last message
            let now = ISO8601DateFormatter().string(from: Date())
            try await client
                .from("conversations")
                .update(UpdateConversationLastMessage(lastMessageText: text, lastMessageAt: now))
                .eq("id", value: conversation.id)
                .execute()

            isSending = false
        } catch {
            isSending = false
            messageText = sentText
            self.error = "Failed to send message"
            print("Send message error: \(error)")
        }
    }

    // MARK: - Realtime

    func subscribeToMessages() async {
        realtimeChannel = client.realtimeV2.channel("chat-\(conversation.id)")
        guard let channel = realtimeChannel else { return }

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversation.id)"
        )

        await channel.subscribe()

        realtimeTask = Task {
            for await insert in insertions {
                // Only add if not already present (avoid duplicating our own sent messages)
                if let record = try? insert.decodeRecord(as: DMMessage.self, decoder: JSONDecoder()) {
                    if !self.messages.contains(where: { $0.id == record.id }) {
                        // Re-fetch to get full join data
                        await self.loadMessages()
                    }
                } else {
                    // Fallback: just reload
                    await self.loadMessages()
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
}
