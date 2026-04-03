import SwiftUI

struct NotificationsView: View {
    @State private var viewModel = NotificationViewModel()
    @State private var navigateToProfile: String?
    @State private var navigateToPost: SupabaseFeedPost?
    @State private var navigateToDM: String?
    @State private var showPublicProfile: Bool = false
    @State private var showDMThread: Bool = false
    @State private var showPostComments: Bool = false
    @State private var dmSender: FeedAuthor?

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
        .onDisappear {
            Task { await viewModel.unsubscribe() }
        }
        .sheet(isPresented: $showPostComments, onDismiss: { navigateToPost = nil }) {
            if let post = navigateToPost {
                CommentsView(post: post)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NETRTheme.surface)
            }
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
                        .foregroundStyle(NETRTheme.neonGreen)
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
                .tint(NETRTheme.neonGreen)
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
                    .fill(NETRTheme.neonGreen.opacity(0.08))
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
                    .fill(isUnread ? NETRTheme.neonGreen : Color.clear)
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
                    ? NETRTheme.neonGreen.opacity(0.04)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sender Avatar

    private func senderAvatar(_ sender: FeedAuthor?) -> some View {
        AvatarView(url: sender?.avatarUrl, name: sender?.displayName ?? "?", size: 40)
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
            case .scoreUpdated: return ("trending-up", NETRTheme.neonGreen)
            case .gameStarting, .gameNearby, .gameAtHomeCourt, .gameAtFavoriteCourt:
                return ("map-pin", NETRTheme.neonGreen)
            case .gameInvite: return ("user-plus", NETRTheme.neonGreen)
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
            // Navigate to the post via data field containing post_id
            if let dataStr = item.notification.data, let postId = parsePostId(from: dataStr) {
                Task { await loadAndShowPost(postId: postId) }
            }

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
            break
        }
    }

    // MARK: - Post Navigation Helpers

    private func parsePostId(from dataString: String) -> String? {
        guard let data = dataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let postId = json["post_id"] as? String else {
            return nil
        }
        return postId
    }

    private func loadAndShowPost(postId: String) async {
        let selectQuery = "id, author_id, content, like_count, comment_count, repost_count, court_tag_id, court_tag_name, repost_of_id, created_at, profiles(id, full_name, username, avatar_url, netr_score)"
        do {
            let post: SupabaseFeedPost = try await SupabaseManager.shared.client
                .from("feed_posts")
                .select(selectQuery)
                .eq("id", value: postId)
                .single()
                .execute()
                .value
            navigateToPost = post
            showPostComments = true
        } catch {
            print("[NETR] Load post for notification error: \(error)")
        }
    }
}
