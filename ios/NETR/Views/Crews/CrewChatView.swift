import SwiftUI
import Supabase
import Auth
import PostgREST

struct CrewChatView: View {
    @Bindable var viewModel: CrewViewModel
    let crew: MyCrew
    @Environment(\.dismiss) private var dismiss

    @State private var messageText: String = ""
    @State private var isSending: Bool = false
    @State private var keyboardOffset: CGFloat = 0
    @FocusState private var inputFocused: Bool
    @Environment(\.openURL) private var openURL

    private var currentUserId: String {
        SupabaseManager.shared.session?.user.id.uuidString.lowercased() ?? ""
    }

    private var messages: [CrewMessage] { viewModel.messages }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                chatHeader
                Color(NETRTheme.border).frame(height: 0.5)
                messageList
                Color(NETRTheme.border).frame(height: 0.5)

                if let err = viewModel.errorMessage {
                    errorBanner(err)
                }

                inputBar
            }
            .padding(.bottom, keyboardOffset)
        }
        .ignoresSafeArea(.keyboard)
        .hideKeyboardOnTap()
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notif in
            guard let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first else { return }
            let screenH = window.bounds.height
            guard frame.maxY >= screenH - 10 else {
                withAnimation(.easeOut(duration: 0.25)) { keyboardOffset = 0 }
                return
            }
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardOffset = max(0, screenH - frame.minY)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardOffset = 0 }
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
                LucideIcon("arrow-left", size: 20)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 38, height: 38)
                    .background(NETRTheme.card, in: Circle())
                    .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    LucideIcon("users", size: 11)
                        .foregroundStyle(NETRTheme.subtext)
                    Text("Group Chat")
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(NETRTheme.surface)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading && messages.isEmpty {
                        ProgressView()
                            .tint(NETRTheme.neonGreen)
                            .padding(.top, 48)
                    } else if messages.isEmpty {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(NETRTheme.neonGreen.opacity(0.08))
                                    .frame(width: 72, height: 72)
                                LucideIcon(crew.icon, size: 30)
                                    .foregroundStyle(NETRTheme.neonGreen.opacity(0.6))
                            }
                            Text(crew.name)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(NETRTheme.text)
                            Text("Start the crew conversation")
                                .font(.subheadline)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 70)
                    } else {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            let isCurrentUser = message.senderId.lowercased() == currentUserId
                            let prevSenderId = index > 0 ? messages[index - 1].senderId.lowercased() : nil
                            let nextSenderId = index < messages.count - 1 ? messages[index + 1].senderId.lowercased() : nil
                            let isFirstInGroup = prevSenderId != message.senderId.lowercased()
                            let isLastInGroup = nextSenderId != message.senderId.lowercased()
                            let showTimestamp = shouldShowTimestamp(at: index)

                            if showTimestamp {
                                crewTimestampPill(formatTime(message.createdAt))
                            }

                            crewBubble(
                                message: message,
                                isCurrentUser: isCurrentUser,
                                isFirstInGroup: isFirstInGroup,
                                isLastInGroup: isLastInGroup
                            )
                            .id(message.id)
                            .padding(.top, isFirstInGroup && !showTimestamp ? 6 : 0)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .dismissKeyboardOnScroll()
            .onAppear { scrollToBottom(proxy: proxy, animated: false) }
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy: proxy, animated: true) }
        }
    }

    private func crewTimestampPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(NETRTheme.subtext)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(NETRTheme.card, in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    // MARK: - Crew Bubble

    @ViewBuilder
    private func crewBubble(
        message: CrewMessage,
        isCurrentUser: Bool,
        isFirstInGroup: Bool,
        isLastInGroup: Bool
    ) -> some View {
        let senderInfo = viewModel.senderProfiles[message.senderId.lowercased()]
        let senderName = senderInfo?.name ?? "Player"
        let senderAvatarUrl = senderInfo?.avatarUrl

        if message.isGameInvite {
            VStack(alignment: .leading, spacing: 4) {
                if isFirstInGroup {
                    Text(senderName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NETRTheme.subtext)
                        .padding(.leading, 2)
                }
                GameInviteCardView(message: message, viewModel: viewModel)
                if isLastInGroup {
                    Text(formatTime(message.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(NETRTheme.muted)
                        .padding(.leading, 2)
                        .padding(.bottom, 2)
                }
            }
            .padding(.vertical, isLastInGroup ? 1 : 0.5)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                if isCurrentUser {
                    Spacer(minLength: 56)

                    VStack(alignment: .trailing, spacing: 4) {
                        bubbleContent(
                            text: message.content,
                            isCurrentUser: true,
                            isLastInGroup: isLastInGroup
                        )

                        if isLastInGroup {
                            Text(formatTime(message.createdAt))
                                .font(.system(size: 10))
                                .foregroundStyle(NETRTheme.muted)
                                .padding(.trailing, 2)
                                .padding(.bottom, 2)
                        }
                    }

                } else {
                    if isLastInGroup {
                        AvatarView(url: senderAvatarUrl, name: senderName, size: 30)
                    } else {
                        Color.clear.frame(width: 30, height: 1)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if isFirstInGroup {
                            Text(senderName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(NETRTheme.subtext)
                                .padding(.leading, 2)
                        }

                        bubbleContent(
                            text: message.content,
                            isCurrentUser: false,
                            isLastInGroup: isLastInGroup
                        )

                        if isLastInGroup {
                            Text(formatTime(message.createdAt))
                                .font(.system(size: 10))
                                .foregroundStyle(NETRTheme.muted)
                                .padding(.leading, 2)
                                .padding(.bottom, 2)
                        }
                    }

                    Spacer(minLength: 56)
                }
            }
            .padding(.vertical, isLastInGroup ? 1 : 0.5)
        }
    }

    @ViewBuilder
    private func bubbleContent(text: String, isCurrentUser: Bool, isLastInGroup: Bool) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(isCurrentUser ? Color.white : NETRTheme.text)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background {
                if isLastInGroup {
                    ZStack {
                        BubbleShape(isCurrentUser: isCurrentUser).fill(.ultraThinMaterial)
                        BubbleShape(isCurrentUser: isCurrentUser)
                            .fill(isCurrentUser
                                  ? NETRTheme.neonGreen.opacity(0.25)
                                  : Color.white.opacity(0.06))
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isCurrentUser
                                  ? NETRTheme.neonGreen.opacity(0.25)
                                  : Color.white.opacity(0.06))
                    }
                }
            }
            .overlay {
                if isLastInGroup {
                    BubbleShape(isCurrentUser: isCurrentUser)
                        .stroke(
                            isCurrentUser
                                ? NETRTheme.neonGreen.opacity(0.4)
                                : Color.white.opacity(0.08),
                            lineWidth: 0.75
                        )
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isCurrentUser
                                ? NETRTheme.neonGreen.opacity(0.4)
                                : Color.white.opacity(0.08),
                            lineWidth: 0.75
                        )
                }
            }
            .shadow(
                color: isCurrentUser ? NETRTheme.neonGreen.opacity(0.1) : Color.black.opacity(0.2),
                radius: 4, x: 0, y: 2
            )
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                TextField("Message \(crew.name)...", text: $messageText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(NETRTheme.text)
                    .focused($inputFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NETRTheme.border, lineWidth: 1))

                if messageText.count > 1700 {
                    Text("\(2000 - messageText.count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(messageText.count > 1900 ? NETRTheme.red : NETRTheme.gold)
                        .padding(.trailing, 10)
                        .padding(.bottom, 11)
                }
            }

            Button {
                Task { await sendMessage() }
            } label: {
                Group {
                    if isSending {
                        ProgressView().tint(Color.black)
                    } else {
                        LucideIcon("arrow-up", size: 16)
                            .foregroundStyle(Color.black)
                    }
                }
                .frame(width: 36, height: 36)
                .background(
                    messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? NETRTheme.muted : NETRTheme.neonGreen,
                    in: Circle()
                )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .buttonStyle(PressButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(NETRTheme.surface)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            LucideIcon("alert-circle", size: 13)
                .foregroundStyle(NETRTheme.red)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(NETRTheme.red)
                .lineLimit(2)
            Spacer()
            Button { viewModel.errorMessage = nil } label: {
                LucideIcon("x", size: 11).foregroundStyle(NETRTheme.subtext)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(NETRTheme.red.opacity(0.08))
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(last.id, anchor: .bottom) }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        viewModel.sendText = content
        viewModel.errorMessage = nil
        messageText = ""
        isSending = true
        await viewModel.sendMessage(crewId: crew.id)
        if viewModel.errorMessage != nil {
            messageText = content
        }
        isSending = false
    }

    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return timeDiffMinutes(messages[index - 1].createdAt, messages[index].createdAt) > 15
    }

    private func timeDiffMinutes(_ a: String, _ b: String) -> Int {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fb = ISO8601DateFormatter()
        fb.formatOptions = [.withInternetDateTime]
        guard let da = fmt.date(from: a) ?? fb.date(from: a),
              let db = fmt.date(from: b) ?? fb.date(from: b) else { return 0 }
        return Int(abs(db.timeIntervalSince(da)) / 60)
    }

    private func formatTime(_ isoString: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fb = ISO8601DateFormatter()
        fb.formatOptions = [.withInternetDateTime]
        guard let date = fmt.date(from: isoString) ?? fb.date(from: isoString) else { return "" }
        let df = DateFormatter()
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            df.dateFormat = "h:mm a"
        } else if cal.isDateInYesterday(date) {
            df.dateFormat = "'Yesterday' h:mm a"
        } else {
            df.dateFormat = "MMM d, h:mm a"
        }
        return df.string(from: date)
    }
}

// MARK: - Game Invite Card

private struct GameInviteCardView: View {
    let message: CrewMessage
    let viewModel: CrewViewModel

    @State private var counts = CrewPollCounts()
    @Environment(\.openURL) private var openURL

    private var game: CrewGameInvite? { message.gameInvite }

    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            if game != nil {
                Divider().background(Color(NETRTheme.border))
                gameDetails
            }
            Divider().background(Color(NETRTheme.border))
            pollButtons
            if let game {
                Divider().background(Color(NETRTheme.border))
                joinButton(game: game)
            }
        }
        .background(NETRTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NETRTheme.border, lineWidth: 1)
        )
        .task(id: message.id) {
            counts = await viewModel.pollCounts(messageId: message.id)
        }
    }

    private var cardHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(NETRTheme.neonGreen.opacity(0.12))
                    .frame(width: 34, height: 34)
                Text("🏀").font(.system(size: 17))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("GAME INVITE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .tracking(1.5)
                Text(game?.courtName ?? "Unknown Court")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)
            }
            Spacer()
            if game?.isPrivate == true {
                LucideIcon("lock", size: 14)
                    .foregroundStyle(NETRTheme.gold)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var gameDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let format = game?.format {
                detailRow(icon: "activity", text: format)
            }
            if let scheduledAt = game?.scheduledAt {
                detailRow(icon: "calendar", text: formatScheduledAt(scheduledAt))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            LucideIcon(icon, size: 12)
                .foregroundStyle(NETRTheme.subtext)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(NETRTheme.text)
        }
    }

    private var pollButtons: some View {
        HStack(spacing: 6) {
            pollButton(emoji: "✅", label: "IN",    count: counts.inCount,    response: "in")
            pollButton(emoji: "❌", label: "OUT",   count: counts.outCount,   response: "out")
            pollButton(emoji: "🤔", label: "MAYBE", count: counts.maybeCount, response: "maybe")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func pollButton(emoji: String, label: String, count: Int, response: String) -> some View {
        let selected = counts.myResponse == response
        return Button {
            Task {
                await viewModel.submitPollResponse(messageId: message.id, response: response)
                counts = await viewModel.pollCounts(messageId: message.id)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(emoji) \(count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(selected ? Color.black : NETRTheme.text)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selected ? Color.black.opacity(0.6) : NETRTheme.subtext)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? NETRTheme.neonGreen : NETRTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? NETRTheme.neonGreen : NETRTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
    }

    private func joinButton(game: CrewGameInvite) -> some View {
        Button {
            if let url = URL(string: "netr://join/\(game.joinCode)") {
                openURL(url)
            }
        } label: {
            Text("Open in NETR")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(NETRTheme.neonGreen)
        }
        .buttonStyle(PressButtonStyle())
    }

    private func formatScheduledAt(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fb = ISO8601DateFormatter()
        fb.formatOptions = [.withInternetDateTime]
        guard let date = fmt.date(from: iso) ?? fb.date(from: iso) else { return iso }
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d · h:mm a"
        return df.string(from: date)
    }
}
