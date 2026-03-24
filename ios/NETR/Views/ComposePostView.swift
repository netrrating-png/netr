import SwiftUI

struct ComposePostView: View {
    @Bindable var viewModel: FeedViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var postText: String = ""
    @State private var selectedCourt: FeedCourtSearchResult? = nil
    @State private var showCourtSearch: Bool = false

    // Quote post support
    var quotePost: SupabaseFeedPost? = nil

    private let maxChars = 280

    private var charCount: Int { postText.count }
    private var isOverLimit: Bool { charCount > maxChars }
    private var charsRemaining: Int { maxChars - charCount }
    private var canPost: Bool { !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isOverLimit && !viewModel.isPosting }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 10) {
                            authorAvatar
                            VStack(alignment: .leading, spacing: 8) {
                                authorInfo
                                textEditor
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        if let court = selectedCourt {
                            selectedCourtChip(court)
                                .padding(.horizontal, 16)
                        }

                        if let quote = quotePost {
                            quotedPostPreview(quote)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .dismissKeyboardOnScroll()

                if viewModel.showMentionResults && !viewModel.mentionResults.isEmpty {
                    mentionSuggestions
                }

                Divider().background(NETRTheme.border)

                bottomBar
            }
            .background(Color.black)
            .hideKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createPost(
                                content: postText,
                                courtId: selectedCourt.map { $0.id },
                                courtName: selectedCourt?.name
                            )
                        }
                    } label: {
                        Text("POST")
                            .font(.system(.caption, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(canPost ? NETRTheme.background : NETRTheme.muted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(canPost ? NETRTheme.neonGreen : NETRTheme.card, in: Capsule())
                    }
                    .disabled(!canPost)
                }
            }
            .sheet(isPresented: $showCourtSearch) {
                CourtSearchSheet(viewModel: viewModel, selectedCourt: $selectedCourt)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NETRTheme.surface)
            }
        }
    }

    private var authorAvatar: some View {
        Group {
            if let profile = SupabaseManager.shared.currentProfile,
               let avatarUrl = profile.avatarUrl,
               let url = URL(string: avatarUrl) {
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
                let name = SupabaseManager.shared.currentProfile?.fullName ?? "Player"
                let parts = name.split(separator: " ")
                let initials = parts.count >= 2
                    ? "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
                    : String(name.prefix(2)).uppercased()

                Text(initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .frame(width: 40, height: 40)
                    .background(NETRTheme.card, in: Circle())
            }
        }
    }

    private var authorInfo: some View {
        Group {
            if let profile = SupabaseManager.shared.currentProfile {
                HStack(spacing: 4) {
                    Text(profile.fullName ?? profile.username ?? "Player")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NETRTheme.text)
                    if let username = profile.username {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
        }
    }

    private var textEditor: some View {
        ZStack(alignment: .topLeading) {
            if postText.isEmpty {
                Text("What's the run?")
                    .font(.body)
                    .foregroundStyle(NETRTheme.muted)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
            TextEditor(text: $postText)
                .font(.body)
                .foregroundStyle(NETRTheme.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .onChange(of: postText) { _, newValue in
                    viewModel.searchMentions(text: newValue, cursorPosition: newValue.count)
                }
        }
    }

    // MARK: - Mention Suggestions

    private var mentionSuggestions: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.mentionResults) { user in
                Button {
                    insertMention(user: user)
                } label: {
                    HStack(spacing: 10) {
                        if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 28, height: 28)
                                        .clipShape(Circle())
                                } else {
                                    mentionInitials(name: user.displayName)
                                }
                            }
                        } else {
                            mentionInitials(name: user.displayName)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.displayName ?? "Player")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(NETRTheme.text)
                                .lineLimit(1)
                            if let username = user.username {
                                Text("@\(username)")
                                    .font(.caption2)
                                    .foregroundStyle(NETRTheme.subtext)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if let score = user.netrScore {
                            Text(String(format: "%.1f", score))
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(NETRRating.color(for: score))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(NETRRating.color(for: score).opacity(0.12), in: .rect(cornerRadius: 4))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if user.id != viewModel.mentionResults.last?.id {
                    Divider().background(NETRTheme.border)
                }
            }
        }
        .background(NETRTheme.surface)
    }

    private func mentionInitials(name: String?) -> some View {
        let initials: String = {
            guard let name = name else { return "?" }
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }()
        return Text(initials)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(NETRTheme.subtext)
            .frame(width: 28, height: 28)
            .background(NETRTheme.card, in: Circle())
    }

    private func insertMention(user: UserSearchResult) {
        guard let username = user.username else { return }
        let query = viewModel.activeMentionQuery
        if let range = postText.range(of: "@\(query)", options: .backwards) {
            postText.replaceSubrange(range, with: "@\(username) ")
        }
        viewModel.dismissMentionSearch()
    }

    // MARK: - Court Chip

    private func selectedCourtChip(_ court: FeedCourtSearchResult) -> some View {
        HStack(spacing: 6) {
            LucideIcon("map-pin", size: 12)
                .foregroundStyle(NETRTheme.blue)
            Text(court.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NETRTheme.text)
            if let loc = court.location {
                Text("· \(loc)")
                    .font(.caption)
                    .foregroundStyle(NETRTheme.subtext)
            }
            Spacer()
            Button {
                selectedCourt = nil
            } label: {
                LucideIcon("x-circle", size: 12)
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .padding(10)
        .background(NETRTheme.blue.opacity(0.06), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.blue.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Quoted Post Preview

    private func quotedPostPreview(_ post: SupabaseFeedPost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(post.author?.name ?? "Player")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.text)
                Text(post.author?.handle ?? "")
                    .font(.caption2)
                    .foregroundStyle(NETRTheme.subtext)
            }
            Text(post.content)
                .font(.caption)
                .foregroundStyle(NETRTheme.subtext)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NETRTheme.card, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button {
                showCourtSearch = true
            } label: {
                HStack(spacing: 4) {
                    LucideIcon("map-pin", size: 14)
                    Text("Court")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(NETRTheme.blue)
            }

            Spacer()

            Text("\(charCount)/\(maxChars)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(
                    charsRemaining < 0
                    ? NETRTheme.red
                    : (charsRemaining < 20 ? NETRTheme.red : (charsRemaining < 50 ? NETRTheme.gold : NETRTheme.subtext))
                )

            if viewModel.isPosting {
                ProgressView()
                    .tint(NETRTheme.neonGreen)
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(NETRTheme.surface)
    }
}

// MARK: - Court Search Sheet

struct CourtSearchSheet: View {
    @Bindable var viewModel: FeedViewModel
    @Binding var selectedCourt: FeedCourtSearchResult?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    LucideIcon("search")
                        .foregroundStyle(NETRTheme.subtext)
                    TextField("Search courts...", text: $searchText)
                        .foregroundStyle(NETRTheme.text)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                }
                .padding(12)
                .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .onChange(of: searchText) { _, newValue in
                    Task { await viewModel.searchCourts(query: newValue) }
                }

                if viewModel.courtResults.isEmpty && searchText.count >= 1 {
                    VStack(spacing: 8) {
                        LucideIcon("map-pin-off", size: 22)
                            .foregroundStyle(NETRTheme.subtext)
                        Text("No courts found")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.courtResults) { court in
                                Button {
                                    selectedCourt = court
                                    dismiss()
                                } label: {
                                    HStack(spacing: 10) {
                                        LucideIcon("map-pin")
                                            .foregroundStyle(NETRTheme.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(court.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(NETRTheme.text)
                                            if let loc = court.location {
                                                Text(loc)
                                                    .font(.caption)
                                                    .foregroundStyle(NETRTheme.subtext)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .scrollIndicators(.hidden)
                    .dismissKeyboardOnScroll()
                }
            }
            .navigationTitle("Tag a Court")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
    }
}
