import SwiftUI
import Supabase

@Observable
class DMViewModel {

    var conversations: [DMConversation] = []
    var isLoading: Bool = false
    var totalUnread: Int = 0

    // New message search
    var searchResults: [UserSearchResult] = []
    var isSearching: Bool = false
    var showNewMessage: Bool = false

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    private var currentUserId: String? {
        SupabaseManager.shared.session?.user.id.uuidString.lowercased()
    }

    // MARK: - Load Conversations (grouped from direct_messages)

    func loadConversations() async {
        guard let userId = currentUserId else { return }
        isLoading = true

        do {
            // Fetch all messages where user is sender or recipient
            let sent: [DirectMessage] = try await client
                .from("direct_messages")
                .select("id, sender_id, recipient_id, content, read, created_at")
                .eq("sender_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let received: [DirectMessage] = try await client
                .from("direct_messages")
                .select("id, sender_id, recipient_id, content, read, created_at")
                .eq("recipient_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let allMessages = (sent + received).sorted { $0.createdAt > $1.createdAt }

            // Group by other user
            var convoMap: [String: DMConversation] = [:]

            for msg in allMessages {
                let otherId = msg.senderId == userId ? msg.recipientId : msg.senderId
                if convoMap[otherId] == nil {
                    convoMap[otherId] = DMConversation(
                        otherUserId: otherId,
                        lastMessage: msg.content,
                        lastMessageAt: msg.createdAt,
                        unreadCount: 0
                    )
                }
            }

            // Count unread (received messages where read == false)
            for msg in received where !msg.read {
                let otherId = msg.senderId
                convoMap[otherId]?.unreadCount += 1
            }

            // Load profiles for all other users
            var enriched: [DMConversation] = []
            for (otherId, var convo) in convoMap {
                convo.otherUser = await loadUserProfile(userId: otherId)
                enriched.append(convo)
            }

            // Sort by most recent
            enriched.sort { ($0.lastMessageAt ?? "") > ($1.lastMessageAt ?? "") }

            conversations = enriched
            totalUnread = enriched.reduce(0) { $0 + $1.unreadCount }
            isLoading = false
        } catch {
            isLoading = false
            print("Load conversations error: \(error)")
        }
    }

    // MARK: - Find or Create Conversation

    func findOrCreateConversation(with otherId: String) -> DMConversation? {
        if let existing = conversations.first(where: { $0.otherUserId == otherId }) {
            return existing
        }
        // Create a new empty conversation entry (no table row needed — first message creates it)
        let convo = DMConversation(otherUserId: otherId)
        conversations.insert(convo, at: 0)
        return convo
    }

    // MARK: - Mark as Read

    func markAsRead(otherUserId: String) async {
        guard let userId = currentUserId else { return }

        do {
            try await client
                .from("direct_messages")
                .update(MarkMessageReadPayload(read: true))
                .eq("sender_id", value: otherUserId)
                .eq("recipient_id", value: userId)
                .eq("read", value: false)
                .execute()

            if let idx = conversations.firstIndex(where: { $0.otherUserId == otherUserId }) {
                conversations[idx].unreadCount = 0
                totalUnread = conversations.reduce(0) { $0 + $1.unreadCount }
            }
        } catch {
            print("Mark read error: \(error)")
        }
    }

    // MARK: - User Search

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
        realtimeChannel = client.realtimeV2.channel("dm-inbox")
        guard let channel = realtimeChannel else { return }

        let messageChanges = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "direct_messages"
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
}

// MARK: - Chat ViewModel (single conversation thread)

@Observable
class ChatViewModel {

    let otherUserId: String
    var otherUser: FeedAuthor?
    var messages: [DirectMessage] = []
    var isLoading: Bool = false
    var isSending: Bool = false
    var messageText: String = ""
    var error: String?

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    private let maxChars = 500

    var currentUserId: String? {
        SupabaseManager.shared.session?.user.id.uuidString.lowercased()
    }

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && messageText.count <= maxChars
            && !isSending
    }

    var characterCount: Int { messageText.count }
    var showCharCount: Bool { messageText.count > 400 }

    init(otherUserId: String, otherUser: FeedAuthor? = nil) {
        self.otherUserId = otherUserId
        self.otherUser = otherUser
    }

    // MARK: - Load Messages

    func loadMessages() async {
        guard let userId = currentUserId else { return }
        isLoading = true

        do {
            // Messages sent by me to them
            let sent: [DirectMessage] = try await client
                .from("direct_messages")
                .select("id, sender_id, recipient_id, content, read, created_at")
                .eq("sender_id", value: userId)
                .eq("recipient_id", value: otherUserId)
                .order("created_at", ascending: true)
                .execute()
                .value

            // Messages sent by them to me
            let received: [DirectMessage] = try await client
                .from("direct_messages")
                .select("id, sender_id, recipient_id, content, read, created_at")
                .eq("sender_id", value: otherUserId)
                .eq("recipient_id", value: userId)
                .order("created_at", ascending: true)
                .execute()
                .value

            messages = (sent + received).sorted { $0.createdAt < $1.createdAt }
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
            let payload = SendDirectMessagePayload(
                senderId: userId,
                recipientId: otherUserId,
                content: text
            )

            let created: DirectMessage = try await client
                .from("direct_messages")
                .insert(payload)
                .select("id, sender_id, recipient_id, content, read, created_at")
                .single()
                .execute()
                .value

            messages.append(created)
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
        realtimeChannel = client.realtimeV2.channel("chat-\(otherUserId)")
        guard let channel = realtimeChannel else { return }

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "direct_messages"
        )

        await channel.subscribe()

        realtimeTask = Task {
            for await _ in insertions {
                await self.loadMessages()
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
