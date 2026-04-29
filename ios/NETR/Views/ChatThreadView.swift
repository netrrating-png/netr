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
    @State private var tappedCourt: Court? = nil
    @State private var showCourtDetail: Bool = false
    @State private var courtsViewModel = CourtsViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool
    @State private var keyboardOffset: CGFloat = 0

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
            Color(NETRTheme.border).frame(height: 0.5)
            messageList
            courtMentionDropdown
            chatInput
        }
        .padding(.bottom, keyboardOffset)
        .background(Color.black)
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
            await viewModel.loadMessages()
            await viewModel.subscribeToMessages()
            if let dm = dmViewModel {
                await dm.markAsRead(otherUserId: otherUserId)
            } else {
                await DMViewModel().markAsRead(otherUserId: otherUserId)
            }
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
        .sheet(isPresented: $showCourtDetail) {
            if let court = tappedCourt {
                CourtDetailView(court: court, viewModel: courtsViewModel)
            }
        }
        .onChange(of: viewModel.messageText) { _, text in
            detectCourtMention(in: text)
        }
    }

    // MARK: - @ Mention Detection

    private func detectCourtMention(in text: String) {
        let words = text.components(separatedBy: CharacterSet(charactersIn: " \n\t"))
        guard let lastWord = words.last,
              lastWord.hasPrefix("@"),
              lastWord.count >= 2 else {
            if viewModel.courtMentionQuery != nil { viewModel.clearCourtMention() }
            return
        }
        let query = String(lastWord.dropFirst())
        if query != viewModel.courtMentionQuery {
            viewModel.courtMentionQuery = query
            viewModel.searchCourts(query: query)
        }
    }

    private func selectCourtFromMention(_ court: FeedCourtSearchResult) {
        var text = viewModel.messageText
        if let atRange = text.range(of: "@", options: .backwards) {
            text = String(text[..<atRange.lowerBound])
        }
        viewModel.messageText = text
        viewModel.courtTag = court
        viewModel.clearCourtMention()
    }

    private func openCourtDetail(id: String?, name: String?) {
        guard id != nil || name != nil else { return }
        Task {
            let selectCols = "id, name, address, neighborhood, city, lat, lng, surface, lights, indoor, full_court, verified, tags, court_rating, submitted_by, photo_count"
            let client = SupabaseManager.shared.client
            var court: Court?

            if let courtId = id {
                court = try? await client
                    .from("courts")
                    .select(selectCols)
                    .eq("id", value: courtId)
                    .single()
                    .execute()
                    .value
            }

            if court == nil, let courtName = name {
                let results: [Court]? = try? await client
                    .from("courts")
                    .select(selectCols)
                    .ilike("name", pattern: "%\(courtName)%")
                    .limit(1)
                    .execute()
                    .value
                court = results?.first
            }

            if let court {
                tappedCourt = court
                showCourtDetail = true
            }
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
                LucideIcon("arrow-left", size: 20)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 38, height: 38)
                    .background(NETRTheme.card, in: Circle())
                    .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
            }

            Button { showOtherProfile = true } label: {
                HStack(spacing: 10) {
                    AvatarView(url: otherUser?.avatarUrl, name: otherUser?.displayName ?? "?", size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(otherUser?.displayName ?? "Player")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(NETRTheme.text)
                                .lineLimit(1)

                            if let score = otherUser?.netrScore {
                                Text(String(format: "%.1f", score))
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(NETRRating.color(for: score))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(NETRRating.color(for: score).opacity(0.12), in: .rect(cornerRadius: 4))
                            }
                        }
                        if let handle = otherUser?.handle, !handle.isEmpty {
                            Text(handle)
                                .font(.system(size: 12))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }
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
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(NETRTheme.neonGreen)
                            .padding(.top, 48)
                    } else if viewModel.messages.isEmpty {
                        VStack(spacing: 14) {
                            AvatarView(url: otherUser?.avatarUrl, name: otherUser?.displayName ?? "?", size: 64)
                            Text(otherUser?.displayName ?? "Player")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(NETRTheme.text)
                            Text("Send a message to start the conversation")
                                .font(.subheadline)
                                .foregroundStyle(NETRTheme.subtext)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 70)
                        .padding(.horizontal, 32)
                    } else {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let isCurrentUser = message.senderId == viewModel.currentUserId
                            let prevSame = index > 0 && viewModel.messages[index - 1].senderId == message.senderId
                            let nextSame = index < viewModel.messages.count - 1 && viewModel.messages[index + 1].senderId == message.senderId
                            let isFirstInGroup = !prevSame
                            let isLastInGroup = !nextSame
                            let showTimestamp = shouldShowTimestamp(at: index)

                            if showTimestamp {
                                timestampPill(formatGroupTimestamp(message.createdAt))
                            }

                            MessageBubble(
                                message: message,
                                isCurrentUser: isCurrentUser,
                                isFirstInGroup: isFirstInGroup,
                                isLastInGroup: isLastInGroup,
                                onMentionTap: { username in lookupMention(username: username) },
                                onCourtTap: { courtId, courtName in openCourtDetail(id: courtId, name: courtName) }
                            )
                            .id(message.id)
                            .padding(.top, isFirstInGroup && !showTimestamp ? 6 : 0)
                        }

                        Color.clear.frame(height: 1).id("__bottom__")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .dismissKeyboardOnScroll()
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("__bottom__", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                guard !isLoading else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo("__bottom__", anchor: .bottom)
                }
            }
        }
    }

    private func timestampPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(NETRTheme.subtext)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(NETRTheme.card, in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    // MARK: - Court Mention Dropdown

    @ViewBuilder
    private var courtMentionDropdown: some View {
        if let query = viewModel.courtMentionQuery {
            VStack(spacing: 0) {
                Color(NETRTheme.border).frame(height: 0.5)

                if viewModel.courtMentionResults.isEmpty {
                    HStack(spacing: 8) {
                        LucideIcon("map-pin", size: 13)
                            .foregroundStyle(NETRTheme.muted)
                        Text(query.isEmpty ? "Type to search courts…" : "No courts found for \"\(query)\"")
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.subtext)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(NETRTheme.surface)
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            ForEach(viewModel.courtMentionResults) { court in
                                Button {
                                    selectCourtFromMention(court)
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(NETRTheme.neonGreen.opacity(0.12))
                                                .frame(width: 32, height: 32)
                                            LucideIcon("map-pin", size: 13)
                                                .foregroundStyle(NETRTheme.neonGreen)
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(court.name)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(NETRTheme.text)
                                                .lineLimit(1)
                                            if !court.locationLabel.isEmpty {
                                                Text(court.locationLabel)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(NETRTheme.subtext)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        LucideIcon("plus", size: 12)
                                            .foregroundStyle(NETRTheme.subtext)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if court.id != viewModel.courtMentionResults.last?.id {
                                    Divider().background(NETRTheme.border).padding(.leading, 56)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: 220)
                    .background(NETRTheme.surface)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeOut(duration: 0.18), value: viewModel.courtMentionResults.count)
        }
    }

    // MARK: - Input

    private var chatInput: some View {
        VStack(spacing: 0) {
            Color(NETRTheme.border).frame(height: 0.5)

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

            HStack(alignment: .bottom, spacing: 10) {
                Button { showCourtPicker = true } label: {
                    LucideIcon("map-pin", size: 18)
                        .foregroundStyle(viewModel.courtTag != nil ? NETRTheme.neonGreen : NETRTheme.subtext)
                        .frame(width: 36, height: 36)
                }

                ZStack(alignment: .bottomTrailing) {
                    TextField("Message…", text: $viewModel.messageText, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(NETRTheme.text)
                        .focused($inputFocused)
                        .lineLimit(1...5)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .padding(.trailing, viewModel.charsRemaining < 300 ? 36 : 0)
                        .background(NETRTheme.card, in: .rect(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(NETRTheme.border, lineWidth: 1)
                        )
                        .onSubmit {
                            if viewModel.canSend { Task { await viewModel.sendMessage() } }
                        }

                    if viewModel.charsRemaining < 300 {
                        Text("\(viewModel.charsRemaining)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(
                                viewModel.charsRemaining < 0 ? NETRTheme.red :
                                viewModel.charsRemaining < 100 ? NETRTheme.red : NETRTheme.gold
                            )
                            .padding(.trailing, 10)
                            .padding(.bottom, 11)
                    }
                }

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Group {
                        if viewModel.isSending {
                            ProgressView().tint(Color.black)
                        } else {
                            LucideIcon("arrow-up", size: 16)
                                .foregroundStyle(Color.black)
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
            .padding(.horizontal, 14)
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
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DirectMessage
    let isCurrentUser: Bool
    var isFirstInGroup: Bool = true
    var isLastInGroup: Bool = true
    var onMentionTap: ((String) -> Void)? = nil
    var onCourtTap: ((String?, String?) -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isCurrentUser { Spacer(minLength: 64) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !message.content.isEmpty {
                    MentionTextView(
                        text: message.content,
                        textColor: isCurrentUser ? .white : NETRTheme.text,
                        mentionColor: NETRTheme.neonGreen,
                        onMentionTap: onMentionTap
                    )
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
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
                        color: isCurrentUser
                            ? NETRTheme.neonGreen.opacity(0.1)
                            : Color.black.opacity(0.2),
                        radius: 4, x: 0, y: 2
                    )
                }

                if let courtName = message.courtTagName {
                    Button {
                        onCourtTap?(message.courtTagId, courtName)
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(NETRTheme.neonGreen.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                LucideIcon("map-pin", size: 13)
                                    .foregroundStyle(NETRTheme.neonGreen)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(courtName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(NETRTheme.text)
                                Text("Tap to view court")
                                    .font(.system(size: 10))
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                            Spacer(minLength: 0)
                            LucideIcon("chevron-right", size: 12)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressButtonStyle())
                }

                if isLastInGroup {
                    Text(message.createdAt.relativeTimeFromISO)
                        .font(.system(size: 10))
                        .foregroundStyle(NETRTheme.muted)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                }
            }

            if !isCurrentUser { Spacer(minLength: 64) }
        }
        .padding(.vertical, isLastInGroup ? 1 : 0.5)
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let bigR: CGFloat = 18
        let smallR: CGFloat = 5
        let tl: CGFloat = bigR
        let tr: CGFloat = bigR
        let bl: CGFloat = isCurrentUser ? bigR : smallR
        let br: CGFloat = isCurrentUser ? smallR : bigR

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
