import SwiftUI
import Supabase

struct CommentsView: View {
    let post: SupabaseFeedPost
    @State private var comments: [PostComment] = []
    @State private var isLoading: Bool = true
    @State private var commentText: String = ""
    @State private var isSubmitting: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let client = SupabaseManager.shared.client

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        originalPost
                        Divider().background(NETRTheme.border)

                        if isLoading {
                            VStack {
                                ProgressView()
                                    .tint(NETRTheme.neonGreen)
                                    .padding(.top, 40)
                            }
                            .frame(maxWidth: .infinity)
                        } else if comments.isEmpty {
                            VStack(spacing: 12) {
                                LucideIcon("message-circle", size: 32)
                                    .foregroundStyle(NETRTheme.muted)
                                Text("No comments yet")
                                    .font(.subheadline)
                                    .foregroundStyle(NETRTheme.subtext)
                                Text("Be the first to reply")
                                    .font(.caption)
                                    .foregroundStyle(NETRTheme.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(comments) { comment in
                                    CommentRow(comment: comment)
                                    Divider().background(NETRTheme.border)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }
                .scrollIndicators(.hidden)

                commentInput
            }
            .background(NETRTheme.background)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        LucideIcon("x", size: 14)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
            .task {
                await loadComments()
            }
        }
    }

    private var originalPost: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                feedAvatar(name: post.author?.displayName ?? "?", url: post.author?.avatarUrl, size: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.author?.displayName ?? "Player")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NETRTheme.text)
                    Text(post.author?.handle ?? "")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }
                Spacer()
                Text(post.createdAt.relativeTimeFromISO)
                    .font(.caption)
                    .foregroundStyle(NETRTheme.subtext)
            }

            Text(post.content)
                .font(.subheadline)
                .foregroundStyle(NETRTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    LucideIcon("heart", size: 12)
                    Text("\(post.likeCount)")
                }
                HStack(spacing: 4) {
                    LucideIcon("message-circle", size: 12)
                    Text("\(post.commentCount)")
                }
                HStack(spacing: 4) {
                    LucideIcon("repeat", size: 12)
                    Text("\(post.repostCount)")
                }
            }
            .font(.caption)
            .foregroundStyle(NETRTheme.subtext)
        }
        .padding(16)
    }

    private var commentInput: some View {
        VStack(spacing: 0) {
            Divider().background(NETRTheme.border)
            HStack(spacing: 10) {
                TextField("Reply...", text: $commentText)
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.text)
                    .padding(10)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(NETRTheme.border, lineWidth: 1))

                Button {
                    Task { await submitComment() }
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(NETRTheme.background)
                        } else {
                            LucideIcon("arrow-up", size: 14)
                                .foregroundStyle(NETRTheme.background)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .background(
                        commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? NETRTheme.muted
                        : NETRTheme.neonGreen,
                        in: Circle()
                    )
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(NETRTheme.surface)
        }
    }

    private func feedAvatar(name: String, url: String?, size: CGFloat) -> some View {
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

    private func loadComments() async {
        do {
            let result: [PostComment] = try await client
                .from("post_comments")
                .select("id, post_id, user_id, content, like_count, created_at, profiles(id, full_name, username, avatar_url, netr_score, vibe_score)")
                .eq("post_id", value: post.id)
                .order("created_at", ascending: true)
                .execute()
                .value

            comments = result
            isLoading = false
        } catch {
            isLoading = false
            print("Load comments error: \(error)")
        }
    }

    private func submitComment() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSubmitting = true

        do {
            let payload = CreateCommentPayload(postId: post.id, userId: userId, content: text)
            let created: PostComment = try await client
                .from("post_comments")
                .insert(payload)
                .select("id, post_id, user_id, content, like_count, created_at, profiles(id, full_name, username, avatar_url, netr_score, vibe_score)")
                .single()
                .execute()
                .value

            comments.append(created)
            commentText = ""
            isSubmitting = false
        } catch {
            isSubmitting = false
            print("Submit comment error: \(error)")
        }
    }
}

struct CommentRow: View {
    let comment: PostComment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            commentAvatar

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(comment.author?.displayName ?? "Player")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NETRTheme.text)
                    Text(comment.author?.handle ?? "")
                        .font(.caption2)
                        .foregroundStyle(NETRTheme.subtext)
                    Text("·")
                        .foregroundStyle(NETRTheme.muted)
                    Text(comment.createdAt.relativeTimeFromISO)
                        .font(.caption2)
                        .foregroundStyle(NETRTheme.subtext)
                }

                Text(comment.content)
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                if comment.likeCount > 0 {
                    HStack(spacing: 4) {
                        LucideIcon("heart", size: 10)
                        Text("\(comment.likeCount)")
                            .font(.caption2)
                    }
                    .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var commentAvatar: some View {
        Group {
            if let url = comment.author?.avatarUrl, let imageUrl = URL(string: url) {
                NETRTheme.card
                    .frame(width: 28, height: 28)
                    .overlay {
                        AsyncImage(url: imageUrl) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                            }
                        }
                    }
                    .clipShape(Circle())
            } else {
                let name = comment.author?.displayName ?? "?"
                let parts = name.split(separator: " ")
                let initials = parts.count >= 2
                    ? "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
                    : String(name.prefix(2)).uppercased()
                Text(initials)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .frame(width: 28, height: 28)
                    .background(NETRTheme.card, in: Circle())
            }
        }
    }
}
