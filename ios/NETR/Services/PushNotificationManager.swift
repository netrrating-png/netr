import SwiftUI
import UserNotifications
import Supabase
import Auth
import PostgREST

@Observable
class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    var deviceToken: String?
    var permissionGranted: Bool = false

    private let client = SupabaseManager.shared.client

    // MARK: - Request Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.permissionGranted = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            if let error {
                print("[NETR] Push permission error: \(error)")
            }
        }
    }

    // MARK: - Store Token

    func didRegisterForRemoteNotifications(deviceToken data: Data) {
        let token = data.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        Task { await saveTokenToProfile(token) }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[NETR] APNs registration failed: \(error)")
    }

    private func saveTokenToProfile(_ token: String) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        do {
            try await client
                .from("profiles")
                .update(["apns_token": AnyJSON.string(token)])
                .eq("id", value: userId)
                .execute()
        } catch {
            print("[NETR] Save APNs token error: \(error)")
        }
    }

    // MARK: - Refresh Token on Launch

    func refreshTokenIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.permissionGranted = settings.authorizationStatus == .authorized
                if self.permissionGranted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    // MARK: - Fire Local Notification

    func fireLocalNotification(title: String, body: String, type: String, data: [String: String] = [:]) {
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["type": type].merging(data) { _, new in new }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Handle Deep Link from Push

    func handleNotificationResponse(_ response: UNNotificationResponse) -> (type: String, data: [AnyHashable: Any])? {
        let userInfo = response.notification.request.content.userInfo
        guard let type = userInfo["type"] as? String else { return nil }
        return (type: type, data: userInfo)
    }

    // MARK: - Check Preferences Before Firing

    func shouldFireNotification(type: NotificationType, prefs: NotificationPreferences) -> Bool {
        guard prefs.pushEnabled else { return false }

        switch type {
        case .follow: return prefs.follows
        case .like: return prefs.likes
        case .comment: return prefs.comments
        case .dm: return prefs.directMessages
        case .ratingReceived: return prefs.ratingReceived
        case .ratingMilestone: return prefs.ratingMilestones
        case .scoreUpdated: return prefs.scoreUpdated
        case .gameStarting: return prefs.gameStarting
        case .gameNearby: return prefs.gameNearby
        case .gameAtHomeCourt: return prefs.gameAtHomeCourt
        case .gameAtFavoriteCourt: return prefs.gameAtFavoriteCourt
        case .gameInvite: return prefs.gameInvites
        case .gameCancelled: return true
        case .gameReminder: return prefs.gameReminders
        case .mention: return prefs.mentions
        case .repost: return prefs.reposts
        }
    }
}
