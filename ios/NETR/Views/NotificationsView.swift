import SwiftUI

struct NotificationsView: View {
    @State private var viewModel = NotificationViewModel()
    @State private var navigateToProfile: String?
    @State private var navigateToPost: String?
    @State private var navigateToDM: String?
    @State private var navigateToCourt: String?
    @State private var showPublicProfile: Bool = false
    @State private var showDMThread: Bool = false
    @State private var dmSender: FeedAuthor?

    private let limeGreen = Color(red: 0.784, green: 1.0, blue: 0.0)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
            }
        }
        .task {
            await viewModel.fetchNotifications()
            await viewModel.subscribeToNotifications()
        }
        .sheet(isPresented: $showPublicProfile) {
            if let userId = navigateToProfile {
                NavigationStack {
                    PublicPlayerProfileView(userId: userId)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
            }
        }
        .sheet(isPresented: $showDMThread) {
            if let otherId = navigateToDM {
                NavigationStack {
                    ChatThreadView(otherUserId: otherId, otherUser: dmSender)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("NOTIFICATIONS")
                .font(NETRTheme.headingFont(size: .title2))
                .foregroundStyle(NETRTheme.text)

            Spacer()

            if viewModel.unreadCount > 0 {
                Button {
                    Task { await viewModel.markAllAsRead() }
                } label: {
                    Text("Mark all read")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(limeGreen)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.notifications.isEmpty {
            Spacer()
            ProgressView()
                .tint(limeGreen)
            Spacer()
        } else if viewModel.notifications.isEmpty {
            emptyState
        } else {
            notificationList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(limeGreen.opacity(0.08))
                    .frame(width: 80, height: 80)

                LucideIcon("bell", size: 32)
                    .foregroundStyle(NETRTheme.subtext)
            }

            Text("No notifications yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(NETRTheme.text)

            Text("When someone follows you, likes your posts, or invites you to a game, you'll see it here.")
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Notification List

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.notifications) { item in
                    notificationRow(item)
                }
            }
            .padding(.bottom, 120)
        }
        .refreshable {
            await viewModel.fetchNotifications()
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Notification Row

    private func notificationRow(_ item: NotificationWithSender) -> some View {
        let isUnread = !item.notification.read

        return Button {
            Task { await viewModel.markAsRead(item.notification) }
            handleNavigation(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Unread indicator
                Circle()
                    .fill(isUnread ? limeGreen : Color.clear)
                    .frame(width: 8, height: 8)
                    .padding(.top, 8)

                // Avatar
                senderAvatar(item.sender)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayMessage)
                        .font(.system(size: 14, weight: isUnread ? .semibold : .regular))
                        .foregroundStyle(isUnread ? NETRTheme.text : NETRTheme.subtext)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(item.notification.relativeTime)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext.opacity(0.7))
                }

                Spacer(minLength: 4)

                // Notification type icon
                notificationIcon(item.notification.notificationType)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isUnread
                    ? limeGreen.opacity(0.04)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sender Avatar

    private func senderAvatar(_ sender: FeedAuthor?) -> some View {
        ZStack {
            if let urlStr = sender?.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        initialsCircle(sender)
                    }
                }
            } else {
                initialsCircle(sender)
            }
        }
    }

    private func initialsCircle(_ sender: FeedAuthor?) -> some View {
        let initials = sender.map { author in
            let parts = (author.displayName ?? "").split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            } else if let first = parts.first {
                return String(first.prefix(2)).uppercased()
            }
            return "?"
        } ?? "?"

        return Text(initials)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(NETRTheme.text)
            .frame(width: 40, height: 40)
            .background(NETRTheme.card, in: Circle())
            .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
    }

    // MARK: - Notification Icon

    private func notificationIcon(_ type: NotificationType?) -> some View {
        let (icon, color): (String, Color) = {
            guard let t = type else { return ("bell", NETRTheme.subtext) }
            switch t {
            case .follow: return ("user-plus", NETRTheme.blue)
            case .like: return ("heart", NETRTheme.red)
            case .comment: return ("message-circle", NETRTheme.blue)
            case .dm: return ("messages-square", NETRTheme.purple)
            case .ratingReceived: return ("star", NETRTheme.gold)
            case .ratingMilestone: return ("trophy", NETRTheme.gold)
            case .scoreUpdated: return ("trending-up", limeGreen)
            case .gameStarting, .gameNearby, .gameAtHomeCourt, .gameAtFavoriteCourt:
                return ("map-pin", limeGreen)
            case .gameInvite: return ("user-plus", limeGreen)
            case .gameCancelled: return ("x", NETRTheme.red)
            case .gameReminder: return ("clock", NETRTheme.gold)
            case .mention: return ("at-sign", NETRTheme.blue)
            case .repost: return ("repeat", NETRTheme.purple)
            }
        }()

        return LucideIcon(icon, size: 14)
            .foregroundStyle(color.opacity(0.6))
    }

    // MARK: - Navigation

    private func handleNavigation(_ item: NotificationWithSender) {
        guard let type = item.notification.notificationType else { return }

        switch type {
        case .follow:
            if let senderId = item.notification.senderId {
                navigateToProfile = senderId
                showPublicProfile = true
            }

        case .like, .comment, .repost, .mention:
            // Navigate to the post — data field may contain post_id
            break

        case .dm:
            if let senderId = item.notification.senderId {
                navigateToDM = senderId
                dmSender = item.sender
                showDMThread = true
            }

        case .ratingReceived, .scoreUpdated, .ratingMilestone:
            // Navigate to own profile score section
            break

        case .gameStarting, .gameNearby, .gameAtHomeCourt, .gameAtFavoriteCourt,
             .gameInvite, .gameCancelled, .gameReminder:
            // Navigate to the court/game screen
            break
        }
    }
}
