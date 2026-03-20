import SwiftUI

struct DMInboxView: View {
    @Bindable var viewModel: DMViewModel
    @State private var selectedConversation: DMConversation?
    @State private var showChat: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(NETRTheme.border)

            if viewModel.isLoading && viewModel.conversations.isEmpty {
                loadingState
            } else if viewModel.conversations.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .background(NETRTheme.background)
        .sheet(isPresented: $viewModel.showNewMessage) {
            NewDMSheet(viewModel: viewModel) { convo in
                viewModel.showNewMessage = false
                selectedConversation = convo
                showChat = true
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NETRTheme.background)
        }
        .onChange(of: selectedConversation) { _, newConvo in
            if newConvo != nil { showChat = true }
        }
        .fullScreenCover(isPresented: $showChat, onDismiss: {
            selectedConversation = nil
            Task { await viewModel.loadConversations() }
        }) {
            if let convo = selectedConversation {
                ChatThreadView(conversation: convo)
            }
        }
        .task {
            await viewModel.loadConversations()
            await viewModel.subscribeToConversations()
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
                ForEach(viewModel.conversations) { convo in
                    Button {
                        selectedConversation = convo
                    } label: {
                        ConversationRow(conversation: convo)
                    }
                    .buttonStyle(.plain)
                    Divider().background(NETRTheme.border).padding(.leading, 72)
                }
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await viewModel.loadConversations()
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
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                dmAvatar(name: user?.displayName ?? "?", url: user?.avatarUrl, size: 48)

                if let score = user?.netrScore {
                    Text(String(format: "%.0f", score))
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(NETRRating.color(for: score))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(NETRTheme.background, in: .rect(cornerRadius: 4))
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
                        .foregroundStyle(conversation.unreadCount > 0 ? NETRTheme.text : NETRTheme.text)
                        .lineLimit(1)

                    Spacer()

                    if let ts = conversation.lastMessageAt {
                        Text(ts.relativeTimeFromISO)
                            .font(.caption2)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }

                HStack {
                    Text(conversation.lastMessageText ?? "No messages yet")
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
    }

    private func dmAvatar(name: String, url: String?, size: CGFloat) -> some View {
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

// MARK: - New DM Sheet

struct NewDMSheet: View {
    @Bindable var viewModel: DMViewModel
    var onConversationReady: (DMConversation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery: String = ""
    @State private var isCreating: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
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
                    } else if isCreating {
                        VStack(spacing: 12) {
                            ProgressView().tint(NETRTheme.neonGreen)
                            Text("Starting conversation...")
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
                                    .disabled(isCreating)
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
            if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                NETRTheme.card
                    .frame(width: 40, height: 40)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                            }
                        }
                    }
                    .clipShape(Circle())
            } else {
                let initials = {
                    guard let name = user.fullName else { return "?" }
                    let parts = name.split(separator: " ")
                    return parts.count >= 2
                        ? "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
                        : String(name.prefix(2)).uppercased()
                }()
                Text(initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .frame(width: 40, height: 40)
                    .background(NETRTheme.card, in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName ?? "Player")
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
        isCreating = true
        Task {
            if let convo = await viewModel.findOrCreateConversation(with: user.id) {
                isCreating = false
                onConversationReady(convo)
            } else {
                isCreating = false
            }
        }
    }
}
