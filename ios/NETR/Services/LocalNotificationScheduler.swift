import Foundation
import UserNotifications

/// Schedules local notifications that fire on the user's device without any server.
/// Works immediately — no APNs setup, no Apple Developer account needed.
///
/// Categories of local notifications:
/// - Daily Games morning reminder (9am — new puzzles available)
/// - Daily Games evening reminder (8pm — last call)
/// - Game start reminder (30min before scheduled game)
/// - Rating window reminder (15min after game ends)
/// - Connections puzzle reminder (new puzzle available)
enum LocalNotificationScheduler {

    // ─── Identifiers (so we can cancel / replace) ──────────────────────
    private enum ID {
        static let dailyMorning = "netr.daily.morning"
        static let dailyEvening = "netr.daily.evening"
        static let connectionsMorning = "netr.connections.morning"
        static func gameStart(_ gameId: String) -> String { "netr.game.start.\(gameId)" }
        static func ratingWindow(_ gameId: String) -> String { "netr.game.rating.\(gameId)" }
    }

    // MARK: - Recurring daily reminders

    /// Call this on app launch (after permission granted) to schedule
    /// recurring daily reminders. Safe to call repeatedly — it cancels
    /// prior schedules first.
    ///
    /// Pass `dailyGamesEnabled: false` to opt out of the Daily Games
    /// (Mystery Player + Connections) reminders. The user controls this
    /// from NotificationPreferencesView.
    static func scheduleRecurringReminders(dailyGamesEnabled: Bool = true) {
        cancelRecurring()
        guard dailyGamesEnabled else { return }
        scheduleDailyPuzzleReminder()
        scheduleDailyEveningReminder()
        scheduleConnectionsReminder()
    }

    static func cancelRecurring() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            ID.dailyMorning, ID.dailyEvening, ID.connectionsMorning
        ])
    }

    /// Fires at 9:00 AM local time every day.
    private static func scheduleDailyPuzzleReminder() {
        let content = UNMutableNotificationContent()
        content.title = "New Daily Games are available"
        content.body = "Mystery Player + Connections — fresh puzzles dropped 🏀"
        content.sound = .default
        content.userInfo = ["type": "daily_game_ready"]

        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        schedule(id: ID.dailyMorning, content: content, trigger: trigger)
    }

    /// Fires at 8:00 PM local time — last call for today's puzzles.
    /// Previously this was a "your streak is on the line" reminder, but
    /// Daily Games don't track streaks, so the copy was misleading.
    private static func scheduleDailyEveningReminder() {
        let content = UNMutableNotificationContent()
        content.title = "New Daily Games are available"
        content.body = "Last call for today's Mystery Player + Connections."
        content.sound = .default
        content.userInfo = ["type": "daily_game_evening"]

        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        schedule(id: ID.dailyEvening, content: content, trigger: trigger)
    }

    /// Fires at 9:15 AM — a few minutes after the daily puzzle reminder.
    private static func scheduleConnectionsReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Connections is ready"
        content.body = "4 categories, 16 players. Can you find them all?"
        content.sound = .default
        content.userInfo = ["type": "connections_ready"]

        var components = DateComponents()
        components.hour = 9
        components.minute = 15
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        schedule(id: ID.connectionsMorning, content: content, trigger: trigger)
    }

    // MARK: - Game-specific reminders

    /// Schedules a one-off notification to fire 30 minutes before a scheduled game.
    /// Call when the user joins a scheduled game. Pass the ISO8601 scheduled_at.
    static func scheduleGameStartReminder(gameId: String, scheduledAt: Date, courtName: String?) {
        cancelGameStartReminder(gameId: gameId)

        let fireDate = scheduledAt.addingTimeInterval(-30 * 60)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your game starts in 30 minutes"
        content.body = courtName.map { "See you at \($0)" } ?? "Tap to see details"
        content.sound = .default
        content.userInfo = ["type": "game_starting", "game_id": gameId]

        let interval = fireDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        schedule(id: ID.gameStart(gameId), content: content, trigger: trigger)
    }

    static func cancelGameStartReminder(gameId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [ID.gameStart(gameId)]
        )
    }

    /// Schedules a reminder 15 minutes after a game ends telling the user
    /// they can still rate teammates (within the 24h rating window).
    static func scheduleRatingWindowReminder(gameId: String, gameEndedAt: Date) {
        cancelRatingWindowReminder(gameId: gameId)

        let fireDate = gameEndedAt.addingTimeInterval(15 * 60)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rate your teammates"
        content.body = "Your game just wrapped. Drop ratings while it's fresh."
        content.sound = .default
        content.userInfo = ["type": "rating_window", "game_id": gameId]

        let interval = fireDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        schedule(id: ID.ratingWindow(gameId), content: content, trigger: trigger)
    }

    static func cancelRatingWindowReminder(gameId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [ID.ratingWindow(gameId)]
        )
    }

    // MARK: - Private helper

    private static func schedule(
        id: String,
        content: UNNotificationContent,
        trigger: UNNotificationTrigger
    ) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NETR Notifications] Failed to schedule \(id): \(error)")
            }
        }
    }
}
