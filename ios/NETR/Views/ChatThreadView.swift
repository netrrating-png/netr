import SwiftUI

struct ChatThreadView: View {
    let otherUserId: String
    let otherUser: FeedAuthor?
    @State private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    init(otherUserId: String, otherUser: FeedAuthor?) {
        self.otherUserId = otherUserId
        self.otherUser = otherUser
        self._viewModel = State(initialValue: ChatViewModel(otherUserId: otherUserId, otherUser: otherUser))
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider().background(NETRTheme.border)
            messageList
            chatInput
        }
        .background(Color.black)
        .hideKeyboardOnTap()
        .task {
            await viewModel.loadMessages()
            await viewModel.subscribeToMessages()
            // Mark messages from this user as read
            await DMViewModel().markAsRead(otherUserId: otherUserId)
        }
        .onDisappear {
            Task { await viewModel.unsubscribe() }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                LucideIcon("arrow-left", size: 18)
                    .foregroundStyle(NETRTheme.text)
            }

            chatAvatar(name: otherUser?.displayName ?? "?", url: otherUser?.avatarUrl, size: 34)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(otherUser?.displayName ?? "Player")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NETRTheme.text)
                        .lineLimit(1)

                    if let score = otherUser?.netrScore {
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(NETRRating.color(for: score))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(NETRRating.color(for: score).opacity(0.12), in: .rect(cornerRadius: 3))
                    }
                }
                if let handle = otherUser?.handle, !handle.isEmpty {
                    Text(handle)
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(NETRTheme.surface)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(NETRTheme.neonGreen)
                            .padding(.top, 40)
                    } else if viewModel.messages.isEmpty {
                        VStack(spacing: 12) {
                            chatAvatar(name: otherUser?.displayName ?? "?", url: otherUser?.avatarUrl, size: 56)
                            Text(otherUser?.displayName ?? "Player")
                                .font(.headline)
                                .foregroundStyle(NETRTheme.text)
                            Text("Send a message to start the conversation")
                                .font(.caption)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let showTimestamp = shouldShowTimestamp(at: index)
                            if showTimestamp {
                                Text(formatGroupTimestamp(message.createdAt))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(NETRTheme.subtext)
                                    .padding(.top, 16)
                                    .padding(.bottom, 4)
                            }
                            MessageBubble(
                                message: message,
                                isCurrentUser: message.senderId == viewModel.currentUserId
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .dismissKeyboardOnScroll()
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let lastId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input

    private var chatInput: some View {
        VStack(spacing: 0) {
            Divider().background(NETRTheme.border)

            if viewModel.showCharCount {
                HStack {
                    Spacer()
                    Text("\(viewModel.characterCount)/500")
                        .font(.system(size: 10))
                        .foregroundStyle(viewModel.characterCount > 500 ? NETRTheme.red : NETRTheme.subtext)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            HStack(spacing: 8) {
                TextField("Message...", text: $viewModel.messageText, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.text)
                    .focused($inputFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NETRTheme.border, lineWidth: 1))
                    .onSubmit {
                        if viewModel.canSend {
                            Task { await viewModel.sendMessage() }
                        }
                    }

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Group {
                        if viewModel.isSending {
                            ProgressView()
                                .tint(NETRTheme.background)
                        } else {
                            LucideIcon("arrow-up", size: 14)
                                .foregroundStyle(NETRTheme.background)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .background(
                        viewModel.canSend ? NETRTheme.neonGreen : NETRTheme.muted,
                        in: Circle()
                    )
                }
                .disabled(!viewModel.canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(NETRTheme.surface)
        }
    }

    // MARK: - Helpers

    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = viewModel.messages[index].createdAt
        let previous = viewModel.messages[index - 1].createdAt
        return timeDiffMinutes(previous, current) > 15
    }

    private func timeDiffMinutes(_ a: String, _ b: String) -> Int {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmtFallback = ISO8601DateFormatter()
        fmtFallback.formatOptions = [.withInternetDateTime]

        guard let da = fmt.date(from: a) ?? fmtFallback.date(from: a),
              let db = fmt.date(from: b) ?? fmtFallback.date(from: b) else { return 0 }
        return Int(abs(db.timeIntervalSince(da)) / 60)
    }

    private func formatGroupTimestamp(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmtFallback = ISO8601DateFormatter()
        fmtFallback.formatOptions = [.withInternetDateTime]

        guard let date = fmt.date(from: iso) ?? fmtFallback.date(from: iso) else { return "" }

        let cal = Calendar.current
        let df = DateFormatter()

        if cal.isDateInToday(date) {
            df.dateFormat = "h:mm a"
            return "Today \(df.string(from: date))"
        } else if cal.isDateInYesterday(date) {
            df.dateFormat = "h:mm a"
            return "Yesterday \(df.string(from: date))"
        } else {
            df.dateFormat = "MMM d, h:mm a"
            return df.string(from: date)
        }
    }

    private func chatAvatar(name: String, url: String?, size: CGFloat) -> some View {
        Group {
            if let url, let imageUrl = URL(string: url) {
                NETRTheme.card
                    .frame(width: size, height: size)
                    .overlay {
                        AsyncImage(url: imageUrl) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                            }
                        }
                    }
                    .clipShape(Circle())
            } else {
                let parts = name.split(separator: " ")
                let initials = parts.count >= 2
                    ? "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
                    : String(name.prefix(2)).uppercased()
                Text(initials)
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .frame(width: size, height: size)
                    .background(NETRTheme.card, in: Circle())
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DirectMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 3) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(isCurrentUser ? Color.black : NETRTheme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isCurrentUser ? NETRTheme.neonGreen : NETRTheme.card,
                        in: BubbleShape(isCurrentUser: isCurrentUser)
                    )

                Text(message.createdAt.relativeTimeFromISO)
                    .font(.system(size: 9))
                    .foregroundStyle(NETRTheme.muted)
                    .padding(.horizontal, 4)
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isCurrentUser
                ? [.topLeft, .topRight, .bottomLeft]
                : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
