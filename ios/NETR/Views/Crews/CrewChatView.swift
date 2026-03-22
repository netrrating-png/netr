import SwiftUI
import Auth

struct CrewChatView: View {
    @Bindable var viewModel: CrewViewModel
    let crew: MyCrew
    @Environment(\.dismiss) private var dismiss

    @State private var messageText: String = ""
    @State private var isSending: Bool = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    private var currentUserId: String {
        SupabaseManager.shared.session?.user.id.uuidString ?? ""
    }

    private var messages: [CrewMessage] {
        viewModel.messages
    }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                chatHeader

                NETRTheme.border.frame(height: 1)

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(messages) { message in
                                messageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: messages.count) { _, _ in
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }

                NETRTheme.border.frame(height: 1)

                // Input Bar
                inputBar
            }
        }
        .task {
            await viewModel.loadMessages(crewId: crew.id)
            await viewModel.subscribeToMessages(crewId: crew.id)
        }
        .onDisappear {
            Task { await viewModel.unsubscribe() }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(NETRTheme.card)
                        .frame(width: 36, height: 36)
                    LucideIcon("arrow-left", size: 16)
                        .foregroundStyle(NETRTheme.text)
                }
            }
            .buttonStyle(PressButtonStyle())

            ZStack {
                Circle()
                    .fill(NETRTheme.neonGreen.opacity(0.12))
                    .frame(width: 40, height: 40)
                LucideIcon(crew.icon, size: 18)
                    .foregroundStyle(NETRTheme.neonGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(crew.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    LucideIcon("users", size: 11)
                        .foregroundStyle(NETRTheme.subtext)
                    Text("Group Chat")
                        .font(.system(size: 11))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(message: CrewMessage) -> some View {
        let isCurrentUser = message.senderId.lowercased() == currentUserId.lowercased()
        let senderInfo = viewModel.senderProfiles[message.senderId.lowercased()]
        let senderName = senderInfo?.name ?? "Player"
        let senderAvatarUrl = senderInfo?.avatarUrl

        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 60)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(NETRTheme.neonGreen.opacity(0.15), in: .rect(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1)
                        )

                    Text(formatTime(message.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(NETRTheme.muted)
                        .padding(.trailing, 4)
                }
            } else {
                // Avatar circle
                ZStack {
                    Circle().fill(NETRTheme.surface).frame(width: 30, height: 30)
                    if let urlStr = senderAvatarUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Text(initials(from: senderName)).font(.system(size: 10, weight: .bold)).foregroundStyle(NETRTheme.subtext)
                        }
                        .frame(width: 30, height: 30).clipShape(Circle())
                    } else {
                        Text(initials(from: senderName)).font(.system(size: 10, weight: .bold)).foregroundStyle(NETRTheme.subtext)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(senderName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NETRTheme.subtext)
                        .padding(.leading, 4)

                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(NETRTheme.card, in: .rect(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(NETRTheme.border, lineWidth: 1)
                        )

                    Text(formatTime(message.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(NETRTheme.muted)
                        .padding(.leading, 4)
                }

                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message \(crew.name)...", text: $messageText, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.text)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(NETRTheme.card, in: .rect(cornerRadius: 20))
                .overlay(Capsule().stroke(NETRTheme.border, lineWidth: 1))

            Button {
                Task { await sendMessage() }
            } label: {
                ZStack {
                    Circle()
                        .fill(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NETRTheme.muted : NETRTheme.neonGreen)
                        .frame(width: 38, height: 38)
                    LucideIcon("arrow-up", size: 16)
                        .foregroundStyle(NETRTheme.background)
                }
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .buttonStyle(PressButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(NETRTheme.background)
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMessage = messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    private func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        viewModel.sendText = content
        messageText = ""
        isSending = true
        await viewModel.sendMessage(crewId: crew.id)
        isSending = false
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else { return "" }
        let display = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            display.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            display.dateFormat = "'Yesterday' h:mm a"
        } else {
            display.dateFormat = "MMM d, h:mm a"
        }
        return display.string(from: date)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
