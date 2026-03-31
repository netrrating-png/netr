import SwiftUI

struct PostCardView: View {
    let post: SupabaseFeedPost
    var isOwnPost: Bool = false
    let onLike: () -> Void
    let onComment: () -> Void
    var onRepost: (() -> Void)? = nil
    var onUndoRepost: (() -> Void)? = nil
    var onQuotePost: (() -> Void)? = nil
    var onBookmark: (() -> Void)? = nil
    let onDelete: () -> Void
    let onBlock: () -> Void
    var onProfileTap: ((String) -> Void)? = nil
    var onMentionTap: ((String) -> Void)? = nil
    var onCourtTap: ((String, String) -> Void)? = nil

    @State private var likeScale: CGFloat = 1.0
    @State private var bookmarkScale: CGFloat = 1.0
    @State private var showRepostSheet: Bool = false

    private var author: FeedAuthor? { post.author }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            postContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            if isOwnPost {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete Post", systemImage: "trash")
                }
            }
            if !isOwnPost {
                Button(role: .destructive) { onBlock() } label: {
                    Label("Block \(author?.handle ?? "user")", systemImage: "person.slash")
                }
            }
        }
        .confirmationDialog("Repost", isPresented: $showRepostSheet, titleVisibility: .visible) {
            if post.isReposted {
                Button("Undo Repost", role: .destructive) { onUndoRepost?() }
            } else {
                Button("Repost") { onRepost?() }
                Button("Quote Post") { onQuotePost?() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Post Content

    private var postContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button { onProfileTap?(post.authorId) } label: {
                    avatarView(author: author)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    authorLine(author: author, createdAt: post.createdAt)
                    if !post.content.isEmpty {
                        contentText(post.content)
                    }
                }
            }

            if let courtName = post.courtTagName, let courtId = post.courtTagId {
                courtChip(name: courtName, courtId: courtId)
            }

            actionBar
        }
    }

    // MARK: - Avatar

    private func avatarView(author: FeedAuthor?) -> some View {
        AvatarView(
            url: author?.avatarUrl,
            name: author?.name,
            size: 40,
            borderColor: NETRRating.color(for: author?.netrScore),
            borderWidth: 2
        )
    }

    // MARK: - Author Line

    private func authorLine(author: FeedAuthor?, createdAt: String) -> some View {
        HStack(spacing: 4) {
            Button { if let id = author?.id { onProfileTap?(id) } } label: {
                Text(author?.name ?? "Player")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            if let netr = author?.netrScore {
                Text(String(format: "%.1f", netr))
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(NETRRating.color(for: netr))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(NETRRating.color(for: netr).opacity(0.12), in: .rect(cornerRadius: 4))
            }

            Text(author?.handle ?? "")
                .font(.caption)
                .foregroundStyle(NETRTheme.subtext)
                .lineLimit(1)

            Text("·")
                .foregroundStyle(NETRTheme.muted)

            Text(createdAt.relativeTimeFromISO)
                .font(.caption)
                .foregroundStyle(NETRTheme.subtext)
        }
    }

    // MARK: - Content Text (with tappable @mentions in lime green)

    private func contentText(_ text: String) -> some View {
        MentionTextView(text: text, onMentionTap: onMentionTap)
            .padding(.top, 2)
    }

    // MARK: - Court Chip

    private func courtChip(name: String, courtId: String?) -> some View {
        Button {
            if let courtId { onCourtTap?(courtId, name) }
        } label: {
            HStack(spacing: 8) {
                LucideIcon("map-pin", size: 14)
                    .foregroundStyle(NETRTheme.blue)
                Text(name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.text)
                Spacer()
            }
            .padding(10)
            .background(NETRTheme.blue.opacity(0.06), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.blue.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.leading, 50)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            // Like
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    likeScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        likeScale = 1.0
                    }
                }
                onLike()
            } label: {
                HStack(spacing: 4) {
                    LucideIcon(post.isLiked ? "heart" : "heart", size: 12)
                    if post.likeCount > 0 {
                        Text("\(post.likeCount)")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(post.isLiked ? NETRTheme.neonGreen : NETRTheme.subtext)
                .scaleEffect(likeScale)
                .frame(minWidth: 50, alignment: .leading)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: post.isLiked)

            // Comment
            FeedActionButton(
                icon: "message-circle",
                count: post.commentCount,
                color: NETRTheme.subtext,
                action: onComment
            )

            // Repost
            Button {
                showRepostSheet = true
            } label: {
                HStack(spacing: 4) {
                    LucideIcon("repeat-2", size: 12)
                    if post.repostCount > 0 {
                        Text("\(post.repostCount)")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(post.isReposted ? NETRTheme.neonGreen : NETRTheme.subtext)
                .frame(minWidth: 50, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Bookmark
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    bookmarkScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        bookmarkScale = 1.0
                    }
                }
                onBookmark?()
            } label: {
                LucideIcon(post.isBookmarked ? "bookmark" : "bookmark", size: 12)
                    .foregroundStyle(post.isBookmarked ? NETRTheme.neonGreen : NETRTheme.subtext)
                    .scaleEffect(bookmarkScale)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: post.isBookmarked)

            Spacer()
        }
        .padding(.leading, 50)
    }

}

// MARK: - Mention Text View (UITextView-based for tappable @mentions)

struct MentionTextView: UIViewRepresentable {
    let text: String
    var onMentionTap: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onMentionTap: onMentionTap)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.linkTextAttributes = [
            .foregroundColor: UIColor(NETRTheme.neonGreen),
            .underlineStyle: 0
        ]
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.onMentionTap = onMentionTap
        let built = buildAttributedString(text)
        if tv.attributedText != built {
            tv.attributedText = built
            tv.invalidateIntrinsicContentSize()
        }
    }

    private func buildAttributedString(_ text: String) -> NSAttributedString {
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let result = NSMutableAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: UIColor(NETRTheme.text)]
        )
        let pattern = #"@(\w+)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsRange = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: nsRange) {
                let fullRange = match.range
                let usernameRange = match.range(at: 1)
                if let swiftRange = Range(usernameRange, in: text),
                   let url = URL(string: "mention://\(String(text[swiftRange]))") {
                    result.addAttributes([
                        .foregroundColor: UIColor(NETRTheme.neonGreen),
                        .link: url
                    ], range: fullRange)
                }
            }
        }
        return result
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onMentionTap: ((String) -> Void)?

        init(onMentionTap: ((String) -> Void)?) {
            self.onMentionTap = onMentionTap
        }

        func textView(_ textView: UITextView,
                      shouldInteractWith URL: URL,
                      in characterRange: NSRange,
                      interaction: UITextItemInteraction) -> Bool {
            if URL.scheme == "mention", let username = URL.host {
                onMentionTap?(username)
            }
            return false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Prevent text selection highlight
            textView.selectedTextRange = nil
        }
    }
}

// MARK: - Feed Action Button

struct FeedActionButton: View {
    let icon: String
    let count: Int
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                LucideIcon(icon, size: 12)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                }
            }
            .foregroundStyle(color)
            .frame(minWidth: 50, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
