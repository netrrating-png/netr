import SwiftUI
import Supabase
import Auth
import PostgREST

@Observable
class DMViewModel {

    var conversations: [DMConversation] = []
    var isLoading: Bool = false
    var totalUnread: Int = 0

    // New message search
    var searchResults: [UserSearchResult] = []
    var isSearching: Bool = false
    var showNewMessage: Bool = false

    // Notification manager for DM banners
    var notificationManager = DMNotificationManager()

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
                .select("id, sender_id, recipient_id, content, read, court_tag_id, court_tag_name, created_at")
                .eq("sender_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let received: [DirectMessage] = try await client
                .from("direct_messages")
                .select("id, sender_id, recipient_id, content, read, court_tag_id, court_tag_name, created_at")
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
            print("[NETR DM] Load conversations error: \(error)")
        }
    }

    // MARK: - Load Unread Count Only (lightweight)

    func loadUnreadCount() async {
        guard let userId = currentUserId else { return }

        do {
            let unread: [DirectMessage] = try await client
                .from("direct_messages")
                .select("id, sender_id, recipient_id, content, read, court_tag_id, court_tag_name, created_at")
                .eq("recipient_id", value: userId)
                .eq("read", value: false)
                .execute()
                .value

            totalUnread = unread.count
        } catch {
            print("[NETR DM] Load unread count error: \(error)")
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

    // MARK: - Auto-populate Conversation After Send (Fix 3)

    func ensureConversationExists(
        recipientId: String,
        recipientName: String?,
        recipientAvatar: String?,
        recipientScore: Double?,
        messageContent: String
    ) {
        if let idx = conversations.firstIndex(where: { $0.otherUserId == recipientId }) {
            // Update existing conversation with latest message
            conversations[idx].lastMessage = messageContent
            conversations[idx].lastMessageAt = ISO8601DateFormatter().string(from: Date())
            // Move to top
            let convo = conversations.remove(at: idx)
            conversations.insert(convo, at: 0)
        } else {
            // Create new local conversation immediately
            var newConvo = DMConversation(
                otherUserId: recipientId,
                lastMessage: messageContent,
                lastMessageAt: ISO8601DateFormatter().string(from: Date()),
                unreadCount: 0
            )
            newConvo.otherUser = FeedAuthor(
                id: recipientId,
                displayName: recipientName,
                username: nil,
                avatarUrl: recipientAvatar,
                netrScore: recipientScore
            )
            conversations.insert(newConvo, at: 0)
        }
    }

    // MARK: - Mark as Read (Fix 4)

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
                let previousUnread = conversations[idx].unreadCount
                conversations[idx].unreadCount = 0
                totalUnread = max(0, totalUnread - previousUnread)
            }
        } catch {
            print("[NETR DM] Mark read error: \(error)")
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
                print("[NETR DM] User search error: \(error)")
            }
        }
    }

    // MARK: - Realtime

    func subscribeToConversations() async {
        guard let userId = currentUserId else { return }
        realtimeChannel = client.realtimeV2.channel("dm-inbox")
        guard let channel = realtimeChannel else { return }

        let messageChanges = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "direct_messages"
        )

        await channel.subscribe()

        realtimeTask = Task {
            for await insert in messageChanges {
                // Try to decode the new message for notification
                do {
                    let msg = try insert.decodeRecord(as: DirectMessage.self, decoder: JSONDecoder.supabaseDecoder)

                    // Only notify for messages sent TO us (not our own sends)
                    if msg.recipientId == userId {
                        let senderId = msg.senderId
                        // Look up sender profile (check local cache first)
                        let senderProfile: FeedAuthor?
                        if let existing = self.conversations.first(where: { $0.otherUserId == senderId })?.otherUser {
                            senderProfile = existing
                        } else {
                            senderProfile = await self.loadUserProfile(userId: senderId)
                        }

                        let notification = DMNotificationInfo(
                            senderUserId: senderId,
                            senderName: senderProfile?.name ?? "Player",
                            senderAvatarUrl: senderProfile?.avatarUrl,
                            messagePreview: msg.content,
                            timestamp: Date()
                        )
                        self.notificationManager.enqueue(notification)
                    }
                } catch {
                    print("[NETR DM] Decode realtime insert error: \(error)")
                }

                // Reload conversations and unread count
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
        do {
            let profile: FeedAuthor = try await client
                .from("profiles")
                .select("id, full_name, username, avatar_url, netr_score")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            return profile
        } catch {
            print("[NETR DM] Load profile error: \(error)")
            return nil
        }
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

    /// Reference to parent DM view model for auto-populating inbox
    weak var dmViewModel: DMViewModel?

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    private let maxChars = 2000

    var currentUserId: String? {
        SupabaseManager.shared.session?.user.id.uuidString.lowercased()
    }

    // Court tag for next message
    var courtTag: FeedCourtSearchResult? = nil

    // @-mention court autocomplete
    var courtMentionQuery: String? = nil
    var courtMentionResults: [FeedCourtSearchResult] = []
    private var courtMentionTask: Task<Void, Never>?

    func searchCourts(query: String) {
        courtMentionTask?.cancel()
        guard !query.isEmpty else {
            courtMentionResults = []
            return
        }
        courtMentionTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            let results: [FeedCourtSearchResult] = (try? await client
                .from("courts")
                .select("id, name, neighborhood, city")
                .or("name.ilike.%\(query)%,neighborhood.ilike.%\(query)%")
                .limit(6)
                .execute()
                .value) ?? []
            guard !Task.isCancelled else { return }
            courtMentionResults = results
        }
    }

    func clearCourtMention() {
        courtMentionTask?.cancel()
        courtMentionQuery = nil
        courtMentionResults = []
    }

    var canSend: Bool {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCourt = courtTag != nil
        return (hasText || hasCourt)
            && messageText.count <= maxChars
            && !isSending
    }

    var characterCount: Int { messageText.count }
    var charsRemaining: Int { maxChars - messageText.count }

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
                .select("id, sender_id, recipient_id, content, read, court_tag_id, court_tag_name, created_at")
                .eq("sender_id", value: userId)
                .eq("recipient_id", value: otherUserId)
                .order("created_at", ascending: true)
                .execute()
                .value

            // Messages sent by them to me
            let received: [DirectMessage] = try await client
                .from("direct_messages")
                .select("id, sender_id, recipient_id, content, read, court_tag_id, court_tag_name, created_at")
                .eq("sender_id", value: otherUserId)
                .eq("recipient_id", value: userId)
                .order("created_at", ascending: true)
                .execute()
                .value

            messages = (sent + received).sorted { $0.createdAt < $1.createdAt }
            isLoading = false
        } catch {
            isLoading = false
            print("[NETR DM] Load messages error: \(error)")
        }
    }

    // MARK: - Send Message

    func sendMessage() async {
        guard let userId = currentUserId else { return }
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasCourt = courtTag != nil
        guard !text.isEmpty || hasCourt else { return }
        guard text.count <= maxChars else { return }

        isSending = true
        let sentText = messageText
        let sentCourt = courtTag
        messageText = ""
        courtTag = nil

        do {
            let payload = SendDirectMessagePayload(
                senderId: userId,
                recipientId: otherUserId,
                content: text,
                courtTagId: sentCourt?.id,
                courtTagName: sentCourt?.name
            )

            let created: DirectMessage = try await client
                .from("direct_messages")
                .insert(payload)
                .select("id, sender_id, recipient_id, content, read, court_tag_id, court_tag_name, created_at")
                .single()
                .execute()
                .value

            messages.append(created)
            isSending = false

            // Fix 3: Auto-populate conversation in DM inbox
            dmViewModel?.ensureConversationExists(
                recipientId: otherUserId,
                recipientName: otherUser?.displayName,
                recipientAvatar: otherUser?.avatarUrl,
                recipientScore: otherUser?.netrScore,
                messageContent: text
            )
        } catch {
            isSending = false
            messageText = sentText
            courtTag = sentCourt
            self.error = "Failed to send message"
            print("[NETR DM] Send message error: \(error)")
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

// MARK: - Supabase JSON Decoder Helper

private extension JSONDecoder {
    /// Plain decoder — DirectMessage already has CodingKeys for snake_case mapping
    static var supabaseDecoder: JSONDecoder {
        JSONDecoder()
    }
}
