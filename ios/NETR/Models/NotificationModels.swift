import Foundation

// MARK: - Notification Type

enum NotificationType: String, Codable, Sendable {
    case follow
    case like
    case comment
    case dm
    case ratingReceived = "rating_received"
    case ratingMilestone = "rating_milestone"
    case scoreUpdated = "score_updated"
    case gameStarting = "game_starting"
    case gameNearby = "game_nearby"
    case gameAtHomeCourt = "game_at_home_court"
    case gameAtFavoriteCourt = "game_at_favorite_court"
    case gameInvite = "game_invite"
    case gameCancelled = "game_cancelled"
    case gameReminder = "game_reminder"
    case mention
    case repost
}

// MARK: - Notification (maps to notifications table)

nonisolated struct AppNotification: Identifiable, Sendable, Equatable {
    let id: String
    let recipientId: String
    let senderId: String?
    let type: String
    let title: String?
    let body: String?
    let data: String?
    var read: Bool
    let createdAt: String

    var notificationType: NotificationType? {
        NotificationType(rawValue: type)
    }

    var relativeTime: String {
        createdAt.relativeTimeFromISO
    }

    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool {
        lhs.id == rhs.id && lhs.read == rhs.read
    }
}

extension AppNotification: Decodable {
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case recipientId = "recipient_id"
        case senderId = "sender_id"
        case type
        case title
        case body
        case data
        case read
        case createdAt = "created_at"
    }
}

// MARK: - Notification with Sender Profile

struct NotificationWithSender: Identifiable, Equatable {
    var id: String { notification.id }
    var notification: AppNotification
    var sender: FeedAuthor?

    var displayMessage: String {
        if let body = notification.body, !body.isEmpty { return body }
        guard let t = notification.notificationType else { return "New notification" }
        switch t {
        case .follow: return "\(senderName) started following you"
        case .like: return "\(senderName) liked your post"
        case .comment: return "\(senderName) commented on your post"
        case .dm: return "\(senderName) sent you a message"
        case .ratingReceived: return "\(senderName) rated your game"
        case .ratingMilestone: return notification.title ?? "You hit a rating milestone!"
        case .scoreUpdated: return "Your NETR score has been updated"
        case .gameStarting: return "A game is starting soon!"
        case .gameNearby: return "There's a game starting nearby"
        case .gameAtHomeCourt: return "A game is starting at your home court"
        case .gameAtFavoriteCourt: return "A game is starting at one of your favorite courts"
        case .gameInvite: return "\(senderName) invited you to a game"
        case .gameCancelled: return "A game you joined was cancelled"
        case .gameReminder: return "Your game starts in 30 minutes"
        case .mention: return "\(senderName) mentioned you in a post"
        case .repost: return "\(senderName) reposted your post"
        }
    }

    private var senderName: String {
        sender?.displayName ?? "Someone"
    }

    static func == (lhs: NotificationWithSender, rhs: NotificationWithSender) -> Bool {
        lhs.notification == rhs.notification && lhs.sender?.id == rhs.sender?.id
    }
}

// MARK: - Mark Read Payload

nonisolated struct MarkNotificationReadPayload: Encodable, Sendable {
    let read: Bool
}

// MARK: - Notification Preferences (maps to notification_preferences table)

nonisolated struct NotificationPreferences: Codable, Sendable {
    var userId: String
    var pushEnabled: Bool
    var follows: Bool
    var likes: Bool
    var comments: Bool
    var directMessages: Bool
    var ratingReceived: Bool
    var ratingMilestones: Bool
    var scoreUpdated: Bool
    var gameInvites: Bool
    var gameReminders: Bool
    var gameStarting: Bool
    var gameNearby: Bool
    var nearbyRadiusMiles: Int
    var gameAtHomeCourt: Bool
    var gameAtFavoriteCourt: Bool
    var mentions: Bool
    var reposts: Bool
    /// Controls the local Daily Games reminders (Mystery Player +
    /// Connections, scheduled by LocalNotificationScheduler at 9am/9:15am/8pm).
    var dailyGames: Bool

    nonisolated enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case pushEnabled = "push_enabled"
        case follows
        case likes
        case comments
        case directMessages = "direct_messages"
        case ratingReceived = "rating_received"
        case ratingMilestones = "rating_milestones"
        case scoreUpdated = "score_updated"
        case gameInvites = "game_invites"
        case gameReminders = "game_reminders"
        case gameStarting = "game_starting"
        case gameNearby = "game_nearby"
        case nearbyRadiusMiles = "nearby_radius_miles"
        case gameAtHomeCourt = "game_at_home_court"
        case gameAtFavoriteCourt = "game_at_favorite_court"
        case mentions
        case reposts
        case dailyGames = "daily_games"
    }

    init(
        userId: String, pushEnabled: Bool, follows: Bool, likes: Bool,
        comments: Bool, directMessages: Bool, ratingReceived: Bool,
        ratingMilestones: Bool, scoreUpdated: Bool, gameInvites: Bool,
        gameReminders: Bool, gameStarting: Bool, gameNearby: Bool,
        nearbyRadiusMiles: Int, gameAtHomeCourt: Bool,
        gameAtFavoriteCourt: Bool, mentions: Bool, reposts: Bool,
        dailyGames: Bool
    ) {
        self.userId = userId
        self.pushEnabled = pushEnabled
        self.follows = follows
        self.likes = likes
        self.comments = comments
        self.directMessages = directMessages
        self.ratingReceived = ratingReceived
        self.ratingMilestones = ratingMilestones
        self.scoreUpdated = scoreUpdated
        self.gameInvites = gameInvites
        self.gameReminders = gameReminders
        self.gameStarting = gameStarting
        self.gameNearby = gameNearby
        self.nearbyRadiusMiles = nearbyRadiusMiles
        self.gameAtHomeCourt = gameAtHomeCourt
        self.gameAtFavoriteCourt = gameAtFavoriteCourt
        self.mentions = mentions
        self.reposts = reposts
        self.dailyGames = dailyGames
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        pushEnabled = try c.decodeIfPresent(Bool.self, forKey: .pushEnabled) ?? true
        follows = try c.decodeIfPresent(Bool.self, forKey: .follows) ?? true
        likes = try c.decodeIfPresent(Bool.self, forKey: .likes) ?? true
        comments = try c.decodeIfPresent(Bool.self, forKey: .comments) ?? true
        directMessages = try c.decodeIfPresent(Bool.self, forKey: .directMessages) ?? true
        ratingReceived = try c.decodeIfPresent(Bool.self, forKey: .ratingReceived) ?? true
        ratingMilestones = try c.decodeIfPresent(Bool.self, forKey: .ratingMilestones) ?? true
        scoreUpdated = try c.decodeIfPresent(Bool.self, forKey: .scoreUpdated) ?? true
        gameInvites = try c.decodeIfPresent(Bool.self, forKey: .gameInvites) ?? true
        gameReminders = try c.decodeIfPresent(Bool.self, forKey: .gameReminders) ?? true
        gameStarting = try c.decodeIfPresent(Bool.self, forKey: .gameStarting) ?? true
        gameNearby = try c.decodeIfPresent(Bool.self, forKey: .gameNearby) ?? true
        nearbyRadiusMiles = try c.decodeIfPresent(Int.self, forKey: .nearbyRadiusMiles) ?? 5
        gameAtHomeCourt = try c.decodeIfPresent(Bool.self, forKey: .gameAtHomeCourt) ?? true
        gameAtFavoriteCourt = try c.decodeIfPresent(Bool.self, forKey: .gameAtFavoriteCourt) ?? true
        mentions = try c.decodeIfPresent(Bool.self, forKey: .mentions) ?? true
        reposts = try c.decodeIfPresent(Bool.self, forKey: .reposts) ?? true
        // Default true so existing rows (no daily_games column yet) keep
        // getting Daily Games reminders until the user opts out explicitly.
        dailyGames = try c.decodeIfPresent(Bool.self, forKey: .dailyGames) ?? true
    }

    static func defaultPreferences(userId: String) -> NotificationPreferences {
        NotificationPreferences(
            userId: userId,
            pushEnabled: true,
            follows: true,
            likes: true,
            comments: true,
            directMessages: true,
            ratingReceived: true,
            ratingMilestones: true,
            scoreUpdated: true,
            gameInvites: true,
            gameReminders: true,
            gameStarting: true,
            gameNearby: true,
            nearbyRadiusMiles: 5,
            gameAtHomeCourt: true,
            gameAtFavoriteCourt: true,
            mentions: true,
            reposts: true,
            dailyGames: true
        )
    }
}
