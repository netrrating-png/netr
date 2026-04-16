import Foundation
import UserNotifications

/// Schedules local notifications that fire on the user's device without any server.
/// Works immediately — no APNs setup, no Apple Developer account needed.
///
/// Categories of local notifications:
/// - Daily game reminder (9am if not played today)
/// - Streak at-risk reminder (8pm if still not played)
/// - Game start reminder (30min before scheduled game)
/// - Rating window reminder (15min after game ends)
/// - Connections puzzle reminder (new puzzle available)
enum LocalNotificationScheduler {

    // ─── Identifiers (so we can cancel / replace) ──────────────────────
    private enum ID {
        static let dailyMorning = "netr.daily.morning"
        static let streakEvening = "netr.daily.streak_risk"
        static let connectionsMorning = "netr.connections.morning"
        static func gameStart(_ gameId: String) -> String { "netr.game.start.\(gameId)" }
        static func ratingWindow(_ gameId: String) -> String { "netr.game.rating.\(gameId)" }
    }

    // MARK: - Recurring daily reminders

    /// Call this on app launch (after permission granted) to schedule
    /// recurring daily reminders. Safe to call repeatedly — it cancels
    /// prior schedules first.
    static func scheduleRecurringReminders() {
        cancelRecurring()
        scheduleDailyPuzzleReminder()
        scheduleStreakAtRiskReminder()
        scheduleConnectionsReminder()
    }

    static func cancelRecurring() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            ID.dailyMorning, ID.streakEvening, ID.connectionsMorning
        ])
    }

    /// Fires at 9:00 AM local time every day.
    private static func scheduleDailyPuzzleReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Today's NBA puzzle is live"
        content.body = "Jump in before your friends solve it 🏀"
        content.sound = .default
        content.userInfo = ["type": "daily_game_ready"]

        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        schedule(id: ID.dailyMorning, content: content, trigger: trigger)
    }

    /// Fires at 8:00 PM local time — reminds user to preserve streak.
    /// The PushNotificationManager should cancel this when the user plays.
    private static func scheduleStreakAtRiskReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Your streak is on the line 🔥"
        content.body = "Solve today's puzzle before midnight."
        content.sound = .default
        content.userInfo = ["type": "daily_game_streak"]

        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        schedule(id: ID.streakEvening, content: content, trigger: trigger)
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
