import SwiftUI

// MARK: - Crew Inbox Preview

struct CrewInboxPreview {
    var lastMessage: String?
    var lastMessageAt: String?
    var unreadCount: Int = 0
}

// MARK: - DMInboxView

struct DMInboxView: View {
    @Bindable var viewModel: DMViewModel
    @State private var selectedConversation: DMConversation?
    @State private var showChat: Bool = false
    @State private var crewViewModel = CrewViewModel()
    @State private var selectedCrew: MyCrew? = nil
    @State private var searchText: String = ""
    @State private var crewPreviews: [String: CrewInboxPreview] = [:]
    @State private var locallyReadCrews: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    var filteredConversations: [DMConversation] {
        guard !searchText.isEmpty else { return viewModel.conversations }
        let q = searchText.lowercased()
        return viewModel.conversations.filter {
            ($0.otherUser?.displayName?.lowercased().contains(q) == true) ||
            ($0.otherUser?.username?.lowercased().contains(q) == true) ||
            ($0.lastMessage?.lowercased().contains(q) == true)
        }
    }

    var filteredCrews: [MyCrew] {
        guard !searchText.isEmpty else { return crewViewModel.myCrews }
        let q = searchText.lowercased()
        return crewViewModel.myCrews.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                inboxHeader
                searchBar
                    .padding(.bottom, 4)

                if viewModel.isLoading && viewModel.conversations.isEmpty && crewViewModel.myCrews.isEmpty {
                    loadingState
                } else if viewModel.conversations.isEmpty && crewViewModel.myCrews.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }

            if !viewModel.conversations.isEmpty || !crewViewModel.myCrews.isEmpty {
                Button { viewModel.showNewMessage = true } label: {
                    ZStack {
                        Circle()
                            .fill(NETRTheme.neonGreen)
                            .frame(width: 54, height: 54)
                            .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 16, y: 4)
                        LucideIcon("pencil", size: 20)
                            .foregroundStyle(Color.black)
                    }
                }
                .buttonStyle(PressButtonStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 34)
            }
        }
        .sheet(isPresented: $viewModel.showNewMessage) {
            NewDMSheet(viewModel: viewModel) { convo in
                viewModel.showNewMessage = false
                selectedConversation = convo
                showChat = true
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.black)
        }
        .onChange(of: selectedConversation) { _, newConvo in
            if newConvo != nil { showChat = true }
        }
        .fullScreenCover(isPresented: $showChat, onDismiss: {
            selectedConversation = nil
            Task { await viewModel.loadConversations() }
        }) {
            if let convo = selectedConversation {
                ChatThreadView(
                    otherUserId: convo.otherUserId,
                    otherUser: convo.otherUser,
                    dmViewModel: viewModel
                )
            }
        }
        .fullScreenCover(item: $selectedCrew) { crew in
            CrewChatView(viewModel: crewViewModel, crew: crew)
                .onDisappear {
                    Task {
                        // Reload myCrews so lastReadAt reflects what was just marked read,
                        // then recompute previews with the fresh timestamps.
                        await crewViewModel.loadMyCrews()
                        await loadCrewPreviews()
                    }
                }
        }
        .task {
            await viewModel.loadConversations()
            await viewModel.subscribeToConversations()
            await crewViewModel.loadMyCrews()
            await loadCrewPreviews()
        }
    }

    // MARK: - Header

    private var inboxHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                LucideIcon("arrow-left", size: 18)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 36, height: 36)
                    .background(NETRTheme.card, in: Circle())
                    .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
            }

            Text("Messages")
                .font(.system(.title2, design: .default, weight: .black).width(.compressed))
                .foregroundStyle(NETRTheme.text)

            Spacer()

            if viewModel.totalUnread > 0 {
                Text("\(min(viewModel.totalUnread, 99))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(NETRTheme.neonGreen, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            LucideIcon("search", size: 14)
                .foregroundStyle(NETRTheme.subtext)
            TextField("Search messages...", text: $searchText)
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    LucideIcon("x", size: 12)
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NETRTheme.card, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !filteredCrews.isEmpty {
                    inboxSectionHeader(icon: "users", label: "CREWS")

                    ForEach(filteredCrews) { myCrew in
                        Button {
                            crewViewModel.messages = []
                            locallyReadCrews.insert(myCrew.id)
                            selectedCrew = myCrew
                        } label: {
                            CrewConversationRow(
                                crew: myCrew,
                                preview: locallyReadCrews.contains(myCrew.id)
                                    ? CrewInboxPreview(
                                        lastMessage: crewPreviews[myCrew.id]?.lastMessage,
                                        lastMessageAt: crewPreviews[myCrew.id]?.lastMessageAt,
                                        unreadCount: 0
                                      )
                                    : crewPreviews[myCrew.id],
                                onSetPrimary: {
                                    Task {
                                        try? await crewViewModel.setPrimary(crewId: myCrew.id)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)

                        if myCrew.id != filteredCrews.last?.id {
                            Divider().background(NETRTheme.border).padding(.leading, 78)
                        }
                    }
                }

                if !filteredConversations.isEmpty {
                    if !filteredCrews.isEmpty {
                        Divider().background(NETRTheme.border).padding(.top, 6)
                    }
                    inboxSectionHeader(icon: "message-circle", label: "DIRECT MESSAGES")

                    ForEach(filteredConversations) { convo in
                        Button { selectedConversation = convo } label: {
                            ConversationRow(conversation: convo)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())

                        if convo.id != filteredConversations.last?.id {
                            Divider().background(NETRTheme.border).padding(.leading, 78)
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            locallyReadCrews.removeAll()
            await viewModel.loadConversations()
            await crewViewModel.loadMyCrews()
            await loadCrewPreviews()
        }
    }

    private func inboxSectionHeader(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            LucideIcon(icon, size: 11)
                .foregroundStyle(NETRTheme.neonGreen)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1.5)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().tint(NETRTheme.neonGreen).scaleEffect(1.2)
            Text("Loading messages...")
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(NETRTheme.neonGreen.opacity(0.08))
                    .frame(width: 88, height: 88)
                LucideIcon("message-circle", size: 38)
                    .foregroundStyle(NETRTheme.neonGreen.opacity(0.5))
            }
            VStack(spacing: 6) {
                Text("No messages yet")
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
                Text("Find a baller and send a DM.")
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
            }
            Button { viewModel.showNewMessage = true } label: {
                HStack(spacing: 8) {
                    LucideIcon("pencil", size: 14)
                    Text("NEW MESSAGE")
                        .font(.system(.subheadline, design: .default, weight: .bold).width(.compressed))
                        .tracking(1)
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
                .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressButtonStyle())
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Load Crew Previews

    private func loadCrewPreviews() async {
        await withTaskGroup(of: (String, CrewInboxPreview).self) { group in
            for myCrew in crewViewModel.myCrews {
                let crewId = myCrew.id
                let dbLastReadAt = myCrew.memberRow.lastReadAt
                // Use whichever timestamp is more recent: DB or local UserDefaults
                let localLastReadAt = CrewViewModel.localLastReadAt(for: crewId)
                let lastReadAt: String?
                switch (dbLastReadAt, localLastReadAt) {
                case let (db?, local?): lastReadAt = db > local ? db : local
                case let (db?, nil):    lastReadAt = db
                case let (nil, local?): lastReadAt = local
                case (nil, nil):        lastReadAt = nil
                }
                group.addTask {
                    let latest = await crewViewModel.latestMessage(for: crewId)
                    let unread = await crewViewModel.unreadCount(
                        for: crewId,
                        lastReadAt: lastReadAt
                    )
                    return (crewId, CrewInboxPreview(
                        lastMessage: latest?.content,
                        lastMessageAt: latest?.createdAt,
                        unreadCount: unread
                    ))
                }
            }
            for await (id, preview) in group {
                crewPreviews[id] = preview
            }
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: DMConversation

    private var user: FeedAuthor? { conversation.otherUser }
    private var hasUnread: Bool { conversation.unreadCount > 0 }

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(url: user?.avatarUrl, name: user?.displayName ?? "?", size: 50)

                if let score = user?.netrScore {
                    Text(String(format: "%.0f", score))
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(NETRRating.color(for: score))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.black, in: .rect(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(NETRRating.color(for: score).opacity(0.5), lineWidth: 1)
                        )
                        .offset(x: 5, y: 5)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(user?.displayName ?? "Player")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NETRTheme.text)
                        .lineLimit(1)
                    Spacer()
                    if let ts = conversation.lastMessageAt {
                        Text(ts.relativeTimeFromISO)
                            .font(.system(size: 11))
                            .foregroundStyle(hasUnread ? NETRTheme.neonGreen : NETRTheme.subtext)
                    }
                }

                HStack(spacing: 6) {
                    Text(conversation.lastMessage ?? "Say something...")
                        .font(.system(size: 13, weight: hasUnread ? .medium : .regular))
                        .foregroundStyle(hasUnread ? NETRTheme.text : NETRTheme.subtext)
                        .lineLimit(1)
                    Spacer()
                    if hasUnread {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(NETRTheme.neonGreen, in: Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(hasUnread ? NETRTheme.neonGreen.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Crew Conversation Row

struct CrewConversationRow: View {
    let crew: MyCrew
    let preview: CrewInboxPreview?
    var onSetPrimary: (() -> Void)? = nil
    private var hasUnread: Bool { (preview?.unreadCount ?? 0) > 0 }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(NETRTheme.neonGreen.opacity(hasUnread ? 0.18 : 0.1))
                    .frame(width: 50, height: 50)
                LucideIcon(crew.icon, size: 22)
                    .foregroundStyle(NETRTheme.neonGreen)

                if hasUnread {
                    Circle()
                        .fill(NETRTheme.neonGreen)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        .offset(x: 17, y: -17)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Text(crew.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NETRTheme.text)
                            .lineLimit(1)
                        Text("Group")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(NETRTheme.neonGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(NETRTheme.neonGreen.opacity(0.12), in: Capsule())
                    }
                    Spacer()
                    if let ts = preview?.lastMessageAt {
                        Text(ts.relativeTimeFromISO)
                            .font(.system(size: 11))
                            .foregroundStyle(hasUnread ? NETRTheme.neonGreen : NETRTheme.subtext)
                    }
                }

                HStack {
                    if let msg = preview?.lastMessage {
                        Text(msg)
                            .font(.system(size: 13, weight: hasUnread ? .medium : .regular))
                            .foregroundStyle(hasUnread ? NETRTheme.text : NETRTheme.subtext)
                            .lineLimit(1)
                    } else {
                        Text("Crew group chat")
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.muted)
                    }
                    Spacer()
                    if let unread = preview?.unreadCount, unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(NETRTheme.neonGreen, in: Circle())
                    }
                }
            }

            // Primary crew star — tap to make this your profile crew
            Button {
                onSetPrimary?()
            } label: {
                Image(systemName: crew.isPrimary ? "star.fill" : "star")
                    .font(.system(size: 16))
                    .foregroundStyle(crew.isPrimary ? NETRTheme.gold : NETRTheme.muted)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(hasUnread ? NETRTheme.neonGreen.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - New DM Sheet

struct NewDMSheet: View {
    @Bindable var viewModel: DMViewModel
    var onConversationReady: (DMConversation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        LucideIcon("search", size: 14)
                            .foregroundStyle(NETRTheme.subtext)
                        TextField("Search players...", text: $searchQuery)
                            .font(.system(size: 14))
                            .foregroundStyle(NETRTheme.text)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: searchQuery) { _, newValue in
                                viewModel.searchUsers(query: newValue)
                            }
                        if !searchQuery.isEmpty {
                            Button { searchQuery = "" } label: {
                                LucideIcon("x", size: 12)
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if viewModel.isSearching {
                        VStack(spacing: 12) {
                            ProgressView().tint(NETRTheme.neonGreen)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if viewModel.searchResults.isEmpty && !searchQuery.isEmpty {
                        VStack(spacing: 8) {
                            LucideIcon("search-x", size: 28)
                                .foregroundStyle(NETRTheme.muted)
                            Text("No players found")
                                .font(.subheadline)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.searchResults) { user in
                                    Button { startConversation(with: user) } label: {
                                        newDMUserRow(user: user)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().background(NETRTheme.border).padding(.leading, 64)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    Spacer()
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
    }

    private func newDMUserRow(user: UserSearchResult) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarUrl, name: user.displayName ?? "?", size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? "Player")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)
                if let username = user.username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer()

            if let score = user.netrScore {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(NETRRating.color(for: score))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(NETRRating.color(for: score).opacity(0.12), in: .rect(cornerRadius: 5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func startConversation(with user: UserSearchResult) {
        let profile = FeedAuthor(
            id: user.id,
            displayName: user.displayName,
            username: user.username,
            avatarUrl: user.avatarUrl,
            netrScore: user.netrScore
        )
        var convo = viewModel.findOrCreateConversation(with: user.id) ?? DMConversation(otherUserId: user.id)
        convo.otherUser = profile
        onConversationReady(convo)
    }
}
