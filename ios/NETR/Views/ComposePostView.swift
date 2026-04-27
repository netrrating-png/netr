import SwiftUI
import Supabase

struct ComposePostView: View {
    @Bindable var viewModel: FeedViewModel
    var quotePost: SupabaseFeedPost? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var postText: String = ""
    @State private var selectedCourt: FeedCourtSearchResult? = nil
    @State private var showCourtPicker: Bool = false

    private let maxChars = 1000

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
                            courtChip(court)
                                .padding(.horizontal, 16)
                        }

                        if let quote = quotePost {
                            quotePostEmbed(quote)
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
                                courtId: selectedCourt?.id,
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
            .sheet(isPresented: $showCourtPicker) {
                CourtTagPickerView(selectedCourt: $selectedCourt)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.black)
            }
        }
    }

    private var authorAvatar: some View {
        AvatarView.currentUser(size: 40)
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

    // MARK: - Quote Post Embed

    private func quotePostEmbed(_ post: SupabaseFeedPost) -> some View {
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

    // MARK: - Mention Suggestions

    private var mentionSuggestions: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.mentionResults) { user in
                Button {
                    insertMention(user: user)
                } label: {
                    HStack(spacing: 10) {
                        AvatarView(url: user.avatarUrl, name: user.displayName, size: 28)

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

    private func insertMention(user: UserSearchResult) {
        guard let username = user.username else { return }
        let query = viewModel.activeMentionQuery
        if let range = postText.range(of: "@\(query)", options: .backwards) {
            postText.replaceSubrange(range, with: "@\(username) ")
        }
        viewModel.dismissMentionSearch()
    }

    // MARK: - Court Chip

    private func courtChip(_ court: FeedCourtSearchResult) -> some View {
        HStack(spacing: 6) {
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
            Button {
                selectedCourt = nil
            } label: {
                LucideIcon("x-circle", size: 12)
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .padding(10)
        .background(NETRTheme.neonGreen.opacity(0.06), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button {
                showCourtPicker = true
            } label: {
                HStack(spacing: 4) {
                    LucideIcon("map-pin", size: 14)
                    Text("Court")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(selectedCourt != nil ? NETRTheme.neonGreen : NETRTheme.subtext)
            }

            Spacer()

            Text("\(charsRemaining)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(
                    charsRemaining < 0   ? NETRTheme.red  :
                    charsRemaining < 50  ? NETRTheme.red  :
                    charsRemaining < 150 ? NETRTheme.gold :
                    NETRTheme.muted
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
