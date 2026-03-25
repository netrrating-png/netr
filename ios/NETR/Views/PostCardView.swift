import SwiftUI

struct PostCardView: View {
    let post: SupabaseFeedPost
    var isOwnPost: Bool = false
    let onLike: () -> Void
    let onComment: () -> Void
    let onDelete: () -> Void
    let onBlock: () -> Void
    var onProfileTap: ((String) -> Void)? = nil
    var onCourtTap: ((String, String) -> Void)? = nil

    @State private var likeScale: CGFloat = 1.0

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
    }

    // MARK: - Post Content (original post)

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
        Group {
            if let avatarUrl = author?.avatarUrl, let url = URL(string: avatarUrl) {
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
                    .overlay(Circle().stroke(NETRRating.color(for: author?.netrScore), lineWidth: 2))
            } else {
                Text(initialsFor(author?.name))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 40, height: 40)
                    .background(NETRTheme.card, in: Circle())
                    .overlay(Circle().stroke(NETRRating.color(for: author?.netrScore), lineWidth: 2))
            }
        }
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

    // MARK: - Content Text (with @mention styling)

    private func contentText(_ text: String) -> some View {
        Text(styledContent(text))
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    private func styledContent(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = UIColor(NETRTheme.text)

        let mentionPattern = #"@\w+"#
        if let regex = try? NSRegularExpression(pattern: mentionPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                if let swiftRange = Range(match.range, in: text),
                   let attrRange = Range(swiftRange, in: result) {
                    result[attrRange].foregroundColor = UIColor(NETRTheme.blue)
                }
            }
        }

        return result
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
                    LucideIcon("heart", size: 12)
                    if post.likeCount > 0 {
                        Text("\(post.likeCount)")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(post.isLiked ? NETRTheme.neonGreen : NETRTheme.subtext)
                .scaleEffect(likeScale)
                .frame(minWidth: 60, alignment: .leading)
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

            Spacer()
        }
        .padding(.leading, 50)
    }

    // MARK: - Helpers

    private func initialsFor(_ name: String?) -> String {
        let name = name ?? "?"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
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
            .frame(minWidth: 60, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
