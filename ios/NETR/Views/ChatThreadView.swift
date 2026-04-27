import SwiftUI
import Supabase
import PostgREST

struct ChatThreadView: View {
    let otherUserId: String
    let otherUser: FeedAuthor?
    var dmViewModel: DMViewModel?
    @State private var viewModel: ChatViewModel
    @State private var showCourtPicker: Bool = false
    @State private var showOtherProfile: Bool = false
    @State private var mentionProfileUserId: String?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    init(otherUserId: String, otherUser: FeedAuthor?, dmViewModel: DMViewModel? = nil) {
        self.otherUserId = otherUserId
        self.otherUser = otherUser
        self.dmViewModel = dmViewModel
        let chatVM = ChatViewModel(otherUserId: otherUserId, otherUser: otherUser)
        chatVM.dmViewModel = dmViewModel
        self._viewModel = State(initialValue: chatVM)
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
            // Fix 4: Mark messages as read using shared DMViewModel
            if let dm = dmViewModel {
                await dm.markAsRead(otherUserId: otherUserId)
            } else {
                // Fallback: create temporary instance for standalone usage
                await DMViewModel().markAsRead(otherUserId: otherUserId)
            }
            // Track active conversation so banners don't show for this chat
            dmViewModel?.notificationManager.activeConversationUserId = otherUserId
        }
        .onDisappear {
            Task { await viewModel.unsubscribe() }
            dmViewModel?.notificationManager.activeConversationUserId = nil
        }
        .fullScreenCover(isPresented: $showOtherProfile) {
            PublicPlayerProfileView(userId: otherUserId)
        }
        .fullScreenCover(item: $mentionProfileUserId) { userId in
            PublicPlayerProfileView(userId: userId)
        }
    }

    private func lookupMention(username: String) {
        Task {
            nonisolated struct IdRow: Decodable, Sendable { let id: String }
            let rows: [IdRow]? = try? await SupabaseManager.shared.client
                .from("profiles")
                .select("id")
                .eq("username", value: username)
                .limit(1)
                .execute()
                .value
            if let user = rows?.first {
                mentionProfileUserId = user.id
            }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                LucideIcon("arrow-left", size: 18)
                    .foregroundStyle(NETRTheme.text)
            }

            Button { showOtherProfile = true } label: {
                HStack(spacing: 10) {
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
                                isCurrentUser: message.senderId == viewModel.currentUserId,
                                onMentionTap: { username in lookupMention(username: username) }
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

            // Court tag preview
            if let court = viewModel.courtTag {
                HStack(spacing: 8) {
                    LucideIcon("map-pin", size: 12)
                        .foregroundStyle(NETRTheme.neonGreen)
                    Text(court.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NETRTheme.neonGreen)
                    if !court.locationLabel.isEmpty {
                        Text("· \(court.locationLabel)")
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                    Spacer()
                    Button { viewModel.courtTag = nil } label: {
                        LucideIcon("x", size: 10)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(NETRTheme.surface)
            }

            HStack {
                Spacer()
                Text("\(viewModel.charsRemaining)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(
                        viewModel.charsRemaining < 0    ? NETRTheme.red  :
                        viewModel.charsRemaining < 100  ? NETRTheme.red  :
                        viewModel.charsRemaining < 200  ? NETRTheme.gold :
                        NETRTheme.muted
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)

            HStack(spacing: 8) {
                // Court tag button
                Button { showCourtPicker = true } label: {
                    LucideIcon("map-pin", size: 16)
                        .foregroundStyle(viewModel.courtTag != nil ? NETRTheme.neonGreen : NETRTheme.subtext)
                }

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
        .sheet(isPresented: $showCourtPicker) {
            CourtTagPickerView(selectedCourt: $viewModel.courtTag)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
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
        AvatarView(url: url, name: name, size: size)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DirectMessage
    let isCurrentUser: Bool
    var onMentionTap: ((String) -> Void)? = nil

    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 3) {
                // Text content with tappable @mentions
                if !message.content.isEmpty {
                    MentionTextView(
                        text: message.content,
                        textColor: isCurrentUser ? .white : NETRTheme.text,
                        mentionColor: NETRTheme.neonGreen,
                        onMentionTap: onMentionTap
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background {
                        ZStack {
                            BubbleShape(isCurrentUser: isCurrentUser)
                                .fill(.ultraThinMaterial)
                            BubbleShape(isCurrentUser: isCurrentUser)
                                .fill(
                                    isCurrentUser
                                        ? NETRTheme.neonGreen.opacity(0.22)
                                        : Color.black.opacity(0.5)
                                )
                        }
                    }
                    .overlay(
                        BubbleShape(isCurrentUser: isCurrentUser)
                            .stroke(
                                isCurrentUser
                                    ? NETRTheme.neonGreen.opacity(0.35)
                                    : Color.white.opacity(0.07),
                                lineWidth: 0.75
                            )
                    )
                    .shadow(
                        color: isCurrentUser
                            ? NETRTheme.neonGreen.opacity(0.12)
                            : Color.black.opacity(0.25),
                        radius: 6, x: 0, y: 3
                    )
                }

                // Court tag card (if attached)
                if let courtName = message.courtTagName {
                    HStack(spacing: 8) {
                        LucideIcon("map-pin", size: 14)
                            .foregroundStyle(NETRTheme.neonGreen)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(courtName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NETRTheme.text)
                        }
                    }
                    .padding(10)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1)
                    )
                }

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
        let bigR: CGFloat = 20
        let smallR: CGFloat = 6
        // All corners are fully rounded except the tail corner
        let tl = isCurrentUser ? bigR : bigR
        let tr = isCurrentUser ? bigR : bigR
        let bl = isCurrentUser ? bigR : smallR
        let br = isCurrentUser ? smallR : bigR

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                     tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr), radius: tr)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY), radius: br)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl), radius: bl)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                     tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY), radius: tl)
        path.closeSubpath()
        return path
    }
}
