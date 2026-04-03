import SwiftUI
import Combine

// MARK: - Notification Data

struct DMNotificationInfo: Identifiable, Equatable {
    let id = UUID()
    let senderUserId: String
    let senderName: String
    let senderAvatarUrl: String?
    let messagePreview: String
    let timestamp: Date
}

// MARK: - Notification Banner Manager

@Observable
class DMNotificationManager {
    var currentNotification: DMNotificationInfo?
    var isShowing: Bool = false

    private var queue: [DMNotificationInfo] = []
    private var dismissTask: Task<Void, Never>?

    /// Which conversation the user currently has open (nil = not in any DM)
    var activeConversationUserId: String?

    func enqueue(_ notification: DMNotificationInfo) {
        // Don't show if user is already in that conversation
        if activeConversationUserId == notification.senderUserId { return }

        queue.append(notification)
        if !isShowing {
            showNext()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isShowing = false
        }
        // Show next queued notification after dismiss animation
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            self.currentNotification = nil
            self.showNext()
        }
    }

    private func showNext() {
        guard !queue.isEmpty else { return }
        let next = queue.removeFirst()
        currentNotification = next

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isShowing = true
        }

        // Auto-dismiss after 4 seconds
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self.dismiss()
        }
    }
}

// MARK: - Notification Banner View

struct DMNotificationBanner: View {
    let notification: DMNotificationInfo
    var onTap: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Sender avatar
            AvatarView(
                url: notification.senderAvatarUrl,
                name: notification.senderName,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    // App logo indicator
                    Text("N")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color.black)
                        .frame(width: 14, height: 14)
                        .background(NETRTheme.neonGreen, in: RoundedRectangle(cornerRadius: 3))

                    Text("NETR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NETRTheme.subtext)
                        .tracking(0.5)
                }

                Text(notification.senderName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(notification.messagePreview)
                    .font(.caption)
                    .foregroundStyle(Color.gray)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.85))

                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.5))
            }
        )
        .overlay(
            // Lime green left accent border
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(NETRTheme.neonGreen)
                    .frame(width: 3)
                    .padding(.vertical, 6)
                Spacer()
            }
            .padding(.leading, 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if value.translation.height < -20 {
                        onDismiss()
                    }
                }
        )
    }
}

// MARK: - Banner Overlay Modifier

struct DMNotificationOverlay: ViewModifier {
    @Bindable var manager: DMNotificationManager
    var onOpenConversation: (String) -> Void

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let notification = manager.currentNotification, manager.isShowing {
                DMNotificationBanner(
                    notification: notification,
                    onTap: {
                        manager.dismiss()
                        onOpenConversation(notification.senderUserId)
                    },
                    onDismiss: {
                        manager.dismiss()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
        }
    }
}
