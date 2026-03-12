import SwiftUI

struct PostCardView: View {
    let post: SupabaseFeedPost
    var isOwnPost: Bool = false
    let onLike: () -> Void
    let onComment: () -> Void
    let onRepost: () -> Void
    let onDelete: () -> Void
    let onBlock: () -> Void

    private var author: FeedAuthor? { post.author }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                avatarView
                VStack(alignment: .leading, spacing: 2) {
                    authorLine
                    contentView
                }
            }

            if !post.hashtags.isEmpty {
                hashtagRow
            }

            if let court = post.taggedCourt {
                courtEmbed(court)
            }

            actionBar
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            if isOwnPost {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Post", systemImage: "trash")
                }
            }

            if !isOwnPost {
                Button(role: .destructive) {
                    onBlock()
                } label: {
                    Label("Block \(author?.handle ?? "user")", systemImage: "person.slash")
                }
            }
        }
    }

    private var avatarView: some View {
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
                    .overlay(Circle().stroke(NETRTheme.ratingColor(for: author?.netrScore), lineWidth: 2))
            } else {
                Text(initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 40, height: 40)
                    .background(NETRTheme.card, in: Circle())
                    .overlay(Circle().stroke(NETRTheme.ratingColor(for: author?.netrScore), lineWidth: 2))
            }
        }
    }

    private var initials: String {
        let name = author?.displayName ?? "?"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var authorLine: some View {
        HStack(spacing: 4) {
            Text(author?.displayName ?? "Player")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NETRTheme.text)
                .lineLimit(1)

            if let netr = author?.netrScore {
                Text(String(format: "%.1f", netr))
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(NETRTheme.ratingColor(for: netr))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(NETRTheme.ratingColor(for: netr).opacity(0.12), in: .rect(cornerRadius: 4))
            }

            if let vibe = author?.vibeScore {
                VibeDecalView(vibe: vibe, size: .small)
            }

            Text(author?.handle ?? "")
                .font(.caption)
                .foregroundStyle(NETRTheme.subtext)
                .lineLimit(1)

            Text("·")
                .foregroundStyle(NETRTheme.muted)

            Text(post.createdAt.relativeTimeFromISO)
                .font(.caption)
                .foregroundStyle(NETRTheme.subtext)
        }
    }

    private var contentView: some View {
        Text(attributedContent)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    private var attributedContent: AttributedString {
        var result = AttributedString(post.content)
        result.foregroundColor = UIColor(NETRTheme.text)

        let text = post.content
        let hashtagPattern = #"#\w+"#
        let mentionPattern = #"@\w+"#

        if let regex = try? NSRegularExpression(pattern: hashtagPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                if let swiftRange = Range(match.range, in: text),
                   let attrRange = Range(swiftRange, in: result) {
                    result[attrRange].foregroundColor = UIColor(NETRTheme.neonGreen)
                }
            }
        }

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

    private var hashtagRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(post.hashtags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NETRTheme.neonGreen)
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.leading, 50)
    }

    private func courtEmbed(_ court: FeedCourt) -> some View {
        HStack(spacing: 8) {
            LucideIcon("map-pin", size: 14)
                .foregroundStyle(NETRTheme.blue)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(court.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NETRTheme.text)
                    if court.verified == true {
                        LucideIcon("badge-check", size: 9)
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                }
                if let hood = court.neighborhood {
                    Text(hood)
                        .font(.system(size: 10))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(NETRTheme.blue.opacity(0.06), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.blue.opacity(0.15), lineWidth: 1))
        .padding(.leading, 50)
    }

    private var actionBar: some View {
        HStack(spacing: 0) {
            FeedActionButton(
                icon: "heart",
                count: post.likeCount,
                color: post.isLiked ? NETRTheme.neonGreen : NETRTheme.subtext,
                action: onLike
            )
            FeedActionButton(
                icon: "message-circle",
                count: post.commentCount,
                color: NETRTheme.subtext,
                action: onComment
            )
            FeedActionButton(
                icon: "repeat",
                count: post.repostCount,
                color: post.isReposted ? NETRTheme.neonGreen : NETRTheme.subtext,
                action: onRepost
            )
            Button {
                sharePost()
            } label: {
                LucideIcon("share", size: 12)
                    .foregroundStyle(NETRTheme.subtext)
                    .frame(minWidth: 40, alignment: .leading)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.leading, 50)
    }

    private func sharePost() {
        let text = "\(author?.displayName ?? "Someone") on NETR: \(post.content)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
}

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
