import SwiftUI

struct DMInboxView: View {
    @Bindable var viewModel: DMViewModel
    @State private var selectedConversation: DMConversation?
    @State private var showChat: Bool = false
    @State private var crewViewModel = CrewViewModel()
    @State private var selectedCrew: MyCrew? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(NETRTheme.border)

            if viewModel.isLoading && viewModel.conversations.isEmpty && crewViewModel.myCrews.isEmpty {
                loadingState
            } else if viewModel.conversations.isEmpty && crewViewModel.myCrews.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .background(Color.black)
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
        }
        .task {
            await viewModel.loadConversations()
            await viewModel.subscribeToConversations()
            await crewViewModel.loadMyCrews()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("MESSAGES")
                .font(NETRTheme.headingFont(size: .title2))
                .foregroundStyle(NETRTheme.text)
            Spacer()
            Button {
                viewModel.showNewMessage = true
            } label: {
                LucideIcon("pencil", size: 16)
                    .foregroundStyle(NETRTheme.neonGreen)
                    .frame(width: 34, height: 34)
                    .background(NETRTheme.card, in: Circle())
                    .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Crew group chats section
                if !crewViewModel.myCrews.isEmpty {
                    HStack {
                        LucideIcon("users", size: 11)
                            .foregroundStyle(NETRTheme.neonGreen)
                        Text("CREWS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(NETRTheme.subtext)
                            .tracking(1.3)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 6)

                    ForEach(crewViewModel.myCrews) { myCrew in
                        Button {
                            crewViewModel.messages = []
                            selectedCrew = myCrew
                        } label: {
                            CrewConversationRow(crew: myCrew)
                        }
                        .buttonStyle(.plain)
                        if myCrew.id != crewViewModel.myCrews.last?.id {
                            Divider().background(NETRTheme.border).padding(.leading, 72)
                        }
                    }

                    Divider().background(NETRTheme.border).padding(.top, 8)

                    HStack {
                        Text("DIRECT MESSAGES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(NETRTheme.subtext)
                            .tracking(1.3)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                }

                // 1:1 DMs
                ForEach(viewModel.conversations) { convo in
                    Button {
                        selectedConversation = convo
                    } label: {
                        ConversationRow(conversation: convo)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    Divider().background(NETRTheme.border).padding(.leading, 72)
                }
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await viewModel.loadConversations()
            await crewViewModel.loadMyCrews()
        }
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
        VStack(spacing: 16) {
            Spacer()
            LucideIcon("message-circle", size: 48)
                .foregroundStyle(NETRTheme.muted)
            Text("No messages yet")
                .font(.headline)
                .foregroundStyle(NETRTheme.text)
            Text("Find a baller and send a DM.")
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)
            Button {
                viewModel.showNewMessage = true
            } label: {
                HStack(spacing: 8) {
                    LucideIcon("pencil", size: 14)
                    Text("NEW MESSAGE")
                        .font(.system(.subheadline, design: .default, weight: .bold).width(.compressed))
                        .tracking(1)
                }
                .foregroundStyle(NETRTheme.background)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(PressButtonStyle())
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: DMConversation

    private var user: FeedAuthor? { conversation.otherUser }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                dmAvatar(name: user?.displayName ?? "?", url: user?.avatarUrl, size: 48)

                if let score = user?.netrScore {
                    Text(String(format: "%.0f", score))
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(NETRRating.color(for: score))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.black, in: .rect(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(NETRRating.color(for: score).opacity(0.4), lineWidth: 1)
                        )
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user?.displayName ?? "Player")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NETRTheme.text)
                        .lineLimit(1)

                    Spacer()

                    if let ts = conversation.lastMessageAt {
                        Text(ts.relativeTimeFromISO)
                            .font(.caption2)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }

                HStack {
                    Text(conversation.lastMessage ?? "No messages yet")
                        .font(.caption)
                        .foregroundStyle(conversation.unreadCount > 0 ? NETRTheme.text : NETRTheme.subtext)
                        .fontWeight(conversation.unreadCount > 0 ? .medium : .regular)
                        .lineLimit(1)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(NETRTheme.background)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(NETRTheme.neonGreen, in: Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func dmAvatar(name: String, url: String?, size: CGFloat) -> some View {
        AvatarView(url: url, name: name, size: size)
    }
}

// MARK: - Crew Conversation Row

struct CrewConversationRow: View {
    let crew: MyCrew

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(NETRTheme.neonGreen.opacity(0.12))
                    .frame(width: 48, height: 48)
                LucideIcon(crew.icon, size: 22)
                    .foregroundStyle(NETRTheme.neonGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(crew.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NETRTheme.text)
                        .lineLimit(1)
                    Spacer()
                    Text("Group")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NETRTheme.neonGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NETRTheme.neonGreen.opacity(0.1), in: Capsule())
                }
                Text("Tap to open crew chat")
                    .font(.caption)
                    .foregroundStyle(NETRTheme.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
                    HStack(spacing: 8) {
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
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.border, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if viewModel.isSearching {
                        VStack {
                            ProgressView().tint(NETRTheme.neonGreen)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if viewModel.searchResults.isEmpty && !searchQuery.isEmpty {
                        Text("No players found")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.searchResults) { user in
                                    Button {
                                        startConversation(with: user)
                                    } label: {
                                        userRow(user: user)
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

    private func userRow(user: UserSearchResult) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarUrl, name: user.displayName ?? "?", size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? "Player")
                    .font(.subheadline.weight(.semibold))
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
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(NETRRating.color(for: score).opacity(0.12), in: .rect(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
