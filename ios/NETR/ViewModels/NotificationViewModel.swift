import SwiftUI
import Supabase
import Auth
import PostgREST

@Observable
class NotificationViewModel {

    var notifications: [NotificationWithSender] = []
    var isLoading: Bool = false
    var error: String?

    var unreadCount: Int {
        notifications.filter { !$0.notification.read }.count
    }

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    private var currentUserId: String? {
        SupabaseManager.shared.session?.user.id.uuidString
    }

    // MARK: - Fetch Notifications

    func fetchNotifications() async {
        guard let userId = currentUserId else { return }
        isLoading = true

        do {
            let rows: [AppNotification] = try await client
                .from("notifications")
                .select("id, recipient_id, sender_id, type, title, body, data, read, created_at")
                .eq("recipient_id", value: userId)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value

            // Collect unique sender IDs
            let senderIds = Set(rows.compactMap { $0.senderId })
            var senderMap: [String: FeedAuthor] = [:]

            for senderId in senderIds {
                if let author: FeedAuthor = try? await client
                    .from("profiles")
                    .select("id, full_name, username, avatar_url, netr_score")
                    .eq("id", value: senderId)
                    .single()
                    .execute()
                    .value {
                    senderMap[senderId] = author
                }
            }

            notifications = rows.map { notif in
                NotificationWithSender(
                    notification: notif,
                    sender: notif.senderId.flatMap { senderMap[$0] }
                )
            }

            isLoading = false
        } catch {
            isLoading = false
            self.error = "Failed to load notifications"
            print("Fetch notifications error: \(error)")
        }
    }

    // MARK: - Mark as Read

    func markAsRead(_ notification: AppNotification) async {
        guard !notification.read else { return }

        // Optimistic update
        if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[idx].notification.read = true
        }

        do {
            try await client
                .from("notifications")
                .update(MarkNotificationReadPayload(read: true))
                .eq("id", value: notification.id)
                .execute()
        } catch {
            // Revert on error
            if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[idx].notification.read = false
            }
            print("Mark read error: \(error)")
        }
    }

    // MARK: - Mark All as Read

    func markAllAsRead() async {
        guard let userId = currentUserId else { return }

        // Optimistic update
        let previous = notifications
        for i in notifications.indices {
            notifications[i].notification.read = true
        }

        do {
            try await client
                .from("notifications")
                .update(MarkNotificationReadPayload(read: true))
                .eq("recipient_id", value: userId)
                .eq("read", value: false)
                .execute()
        } catch {
            notifications = previous
            print("Mark all read error: \(error)")
        }
    }

    // MARK: - Realtime

    func subscribeToNotifications() async {
        guard let userId = currentUserId else { return }

        realtimeChannel = client.realtimeV2.channel("notifications-\(userId)")
        guard let channel = realtimeChannel else { return }

        let insertions = channel.postgresChange(
            InsertAction.self,
            table: "notifications",
            filter: .eq("recipient_id", value: userId)
        )

        try? await channel.subscribe()

        realtimeTask = Task {
            for await _ in insertions {
                await self.fetchNotifications()
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

    // MARK: - Preferences

    func loadPreferences() async -> NotificationPreferences? {
        guard let userId = currentUserId else { return nil }

        do {
            let prefs: NotificationPreferences = try await client
                .from("notification_preferences")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            return prefs
        } catch {
            // Auto-create if missing
            let defaults = NotificationPreferences.defaultPreferences(userId: userId)
            do {
                try await client
                    .from("notification_preferences")
                    .upsert(defaults)
                    .execute()
                return defaults
            } catch {
                print("Create default preferences error: \(error)")
                return defaults
            }
        }
    }

    func savePreferences(_ prefs: NotificationPreferences) async {
        do {
            try await client
                .from("notification_preferences")
                .upsert(prefs)
                .execute()
        } catch {
            print("Save preferences error: \(error)")
        }
    }
}
