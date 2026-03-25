import SwiftUI
import Supabase

struct CommentsView: View {
    let post: SupabaseFeedPost
    var onCommentAdded: (() -> Void)? = nil
    @State private var comments: [PostComment] = []
    @State private var isLoading: Bool = true
    @State private var commentText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var replyingTo: PostComment? = nil
    @State private var likedCommentIds: Set<String> = []
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var realtimeTask: Task<Void, Never>?

    @Environment(\.dismiss) private var dismiss

    private let client = SupabaseManager.shared.client

    private let commentSelectQuery = "id, post_id, author_id, content, like_count, parent_comment_id, created_at, profiles(id, full_name, username, avatar_url, netr_score)"

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
                            emptyState
                        } else {
                            commentsList
                        }
                    }
                    .padding(.bottom, 80)
                }
                .scrollIndicators(.hidden)
                .dismissKeyboardOnScroll()

                commentInput
            }
            .background(Color.black)
            .hideKeyboardOnTap()
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
                await loadLikedCommentIds()
                await subscribeToComments()
            }
            .onDisappear {
                realtimeTask?.cancel()
                Task {
                    if let channel = realtimeChannel {
                        await client.realtimeV2.removeChannel(channel)
                    }
                }
            }
        }
    }

    // MARK: - Original Post

    private var originalPost: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                feedAvatar(name: post.author?.name ?? "?", url: post.author?.avatarUrl, size: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.author?.name ?? "Player")
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🏀")
                .font(.system(size: 40))
            Text("No comments yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NETRTheme.text)
            Text("Be the first to reply.")
                .font(.caption)
                .foregroundStyle(NETRTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Comments List (threaded)

    private var commentsList: some View {
        LazyVStack(spacing: 0) {
            let topLevel = comments.filter { $0.parentCommentId == nil }
            ForEach(topLevel) { comment in
                CommentRow(
                    comment: comment,
                    isLiked: likedCommentIds.contains(comment.id),
                    onLike: { Task { await toggleCommentLike(comment) } },
                    onReply: { startReply(to: comment) }
                )
                Divider().background(NETRTheme.border)

                // Replies (1 level deep)
                let replies = comments.filter { $0.parentCommentId == comment.id }
                ForEach(replies) { reply in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(NETRTheme.border)
                            .frame(width: 2)
                            .padding(.leading, 36)
                        CommentRow(
                            comment: reply,
                            isLiked: likedCommentIds.contains(reply.id),
                            onLike: { Task { await toggleCommentLike(reply) } },
                            onReply: { startReply(to: reply) },
                            isReply: true
                        )
                    }
                    Divider().background(NETRTheme.border)
                }
            }
        }
    }

    // MARK: - Comment Input

    private var commentInput: some View {
        VStack(spacing: 0) {
            if let replyTo = replyingTo {
                HStack(spacing: 6) {
                    Text("Replying to \(replyTo.author?.handle ?? "comment")")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.blue)
                    Spacer()
                    Button {
                        replyingTo = nil
                        commentText = ""
                    } label: {
                        LucideIcon("x", size: 10)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(NETRTheme.surface)
            }

            Divider().background(NETRTheme.border)

            HStack(spacing: 8) {
                TextField("Reply...", text: $commentText)
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.text)
                    .submitLabel(.send)
                    .onSubmit { Task { await submitComment() } }
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
                        canSubmit ? NETRTheme.neonGreen : NETRTheme.muted,
                        in: Circle()
                    )
                }
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(NETRTheme.surface)
        }
    }

    private var canSubmit: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Helpers

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

    // MARK: - Data

    private func loadComments() async {
        do {
            let result: [PostComment] = try await client
                .from("comments")
                .select(commentSelectQuery)
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

    private func loadLikedCommentIds() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        let rows: [CommentLikeRow]? = try? await client
            .from("comment_likes")
            .select("comment_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        likedCommentIds = Set(rows?.map { $0.commentId } ?? [])
    }

    private func submitComment() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSubmitting = true

        do {
            let payload = CreateCommentPayload(
                postId: post.id,
                authorId: userId,
                content: text,
                parentCommentId: replyingTo?.id
            )
            let created: PostComment = try await client
                .from("comments")
                .insert(payload)
                .select(commentSelectQuery)
                .single()
                .execute()
                .value

            comments.append(created)
            commentText = ""
            replyingTo = nil
            isSubmitting = false
            onCommentAdded?()
        } catch {
            isSubmitting = false
            print("Submit comment error: \(error)")
        }
    }

    private func toggleCommentLike(_ comment: PostComment) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        guard let i = comments.firstIndex(where: { $0.id == comment.id }) else { return }

        let wasLiked = likedCommentIds.contains(comment.id)
        comments[i].likeCount += wasLiked ? -1 : 1

        if wasLiked {
            likedCommentIds.remove(comment.id)
        } else {
            likedCommentIds.insert(comment.id)
        }

        do {
            if wasLiked {
                try await client
                    .from("comment_likes")
                    .delete()
                    .eq("comment_id", value: comment.id)
                    .eq("user_id", value: userId)
                    .execute()
            } else {
                try await client
                    .from("comment_likes")
                    .insert(CommentLikePayload(commentId: comment.id, userId: userId))
                    .execute()
            }
        } catch {
            // Revert
            if let j = comments.firstIndex(where: { $0.id == comment.id }) {
                comments[j].likeCount = comment.likeCount
            }
            if wasLiked { likedCommentIds.insert(comment.id) } else { likedCommentIds.remove(comment.id) }
            print("Comment like error: \(error)")
        }
    }

    private func startReply(to comment: PostComment) {
        replyingTo = comment
        if let username = comment.author?.username {
            commentText = "@\(username) "
        }
    }

    // MARK: - Realtime

    private func subscribeToComments() async {
        let channel = client.realtimeV2.channel("comments-\(post.id)")
        realtimeChannel = channel

        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "comments",
            filter: "post_id=eq.\(post.id)"
        )

        await channel.subscribe()

        realtimeTask = Task {
            for await change in changes {
                // Only add if we don't already have it (from our own submit)
                if let newId = change.record["id"]?.stringValue,
                   !comments.contains(where: { $0.id == newId }) {
                    await loadComments()
                }
            }
        }
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: PostComment
    var isLiked: Bool = false
    let onLike: () -> Void
    let onReply: () -> Void
    var isReply: Bool = false

    @State private var likeScale: CGFloat = 1.0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            commentAvatar

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(comment.author?.name ?? "Player")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NETRTheme.text)

                    if let netr = comment.author?.netrScore {
                        Text(String(format: "%.1f", netr))
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(NETRRating.color(for: netr))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(NETRRating.color(for: netr).opacity(0.12), in: .rect(cornerRadius: 3))
                    }

                    Text(comment.author?.handle ?? "")
                        .font(.caption2)
                        .foregroundStyle(NETRTheme.subtext)
                    Text("·")
                        .foregroundStyle(NETRTheme.muted)
                    Text(comment.createdAt.relativeTimeFromISO)
                        .font(.caption2)
                        .foregroundStyle(NETRTheme.subtext)
                }

                if !comment.content.isEmpty {
                    Text(comment.content)
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 16) {
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
                        HStack(spacing: 3) {
                            LucideIcon("heart", size: 11)
                            if comment.likeCount > 0 {
                                Text("\(comment.likeCount)")
                                    .font(.system(size: 10))
                            }
                        }
                        .foregroundStyle(isLiked ? NETRTheme.neonGreen : NETRTheme.subtext)
                        .scaleEffect(likeScale)
                    }
                    .buttonStyle(.plain)

                    Button(action: onReply) {
                        HStack(spacing: 3) {
                            LucideIcon("reply", size: 11)
                            Text("Reply")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(NETRTheme.subtext)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var commentAvatar: some View {
        Group {
            let size: CGFloat = isReply ? 24 : 28
            if let url = comment.author?.avatarUrl, let imageUrl = URL(string: url) {
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
                let name = comment.author?.name ?? "?"
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
