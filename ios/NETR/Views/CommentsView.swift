import SwiftUI
import Supabase
import Auth
import PostgREST

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

    // Mention autocomplete
    @State private var mentionResults: [UserSearchResult] = []
    @State private var showMentionResults: Bool = false
    @State private var activeMentionQuery: String = ""
    @State private var mentionSearchTask: Task<Void, Never>?

    // Profile navigation
    @State private var selectedProfileUserId: String?
    @State private var mentionLookupTask: Task<Void, Never>?

    // Delete + error
    @State private var commentToDelete: PostComment?
    @State private var showDeleteConfirm: Bool = false
    @State private var commentError: String?

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

                if showMentionResults && !mentionResults.isEmpty {
                    mentionSuggestionsView
                }

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
                mentionSearchTask?.cancel()
                mentionLookupTask?.cancel()
                Task {
                    if let channel = realtimeChannel {
                        await client.realtimeV2.removeChannel(channel)
                    }
                }
            }
            .fullScreenCover(item: $selectedProfileUserId) { userId in
                PublicPlayerProfileView(userId: userId)
            }
            .alert("Delete comment?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let comment = commentToDelete {
                        Task { await deleteComment(comment) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
            .overlay(alignment: .top) {
                if let error = commentError {
                    Text(error)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NETRTheme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(NETRTheme.red.opacity(0.9), in: .capsule)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .seconds(3))
                                withAnimation { commentError = nil }
                            }
                        }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: commentError)
        }
    }

    // MARK: - Mention → Profile Lookup

    private func lookupAndNavigate(username: String) {
        mentionLookupTask?.cancel()
        mentionLookupTask = Task {
            do {
                nonisolated struct IdRow: Decodable, Sendable { let id: String }
                let rows: [IdRow] = try await client
                    .from("profiles")
                    .select("id")
                    .eq("username", value: username)
                    .limit(1)
                    .execute()
                    .value
                if let user = rows.first {
                    selectedProfileUserId = user.id
                }
            } catch {
                print("[NETR] Mention lookup error for @\(username): \(error)")
            }
        }
    }

    // MARK: - Original Post

    private var originalPost: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AvatarView(url: post.author?.avatarUrl, name: post.author?.name, size: 36)

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
            }
            .font(.caption)
            .foregroundStyle(NETRTheme.subtext)
        }
        .padding(16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            LucideIcon("message-circle", size: 40)
                .foregroundStyle(NETRTheme.muted)
            Text("No comments yet. Be the first.")
                .font(.subheadline.weight(.semibold))
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
                    onReply: { startReply(to: comment) },
                    isOwnComment: comment.authorId == SupabaseManager.shared.session?.user.id.uuidString,
                    onProfileTap: { userId in selectedProfileUserId = userId },
                    onMentionTap: { username in lookupAndNavigate(username: username) },
                    onDelete: {
                        commentToDelete = comment
                        showDeleteConfirm = true
                    }
                )
                Divider().background(NETRTheme.border)

                // Replies shown chronologically (oldest first) for natural conversation flow
                let replies = Array(comments.filter { $0.parentCommentId == comment.id }.reversed())
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
                            isReply: true,
                            isOwnComment: reply.authorId == SupabaseManager.shared.session?.user.id.uuidString,
                            onProfileTap: { userId in selectedProfileUserId = userId },
                            onMentionTap: { username in lookupAndNavigate(username: username) },
                            onDelete: {
                                commentToDelete = reply
                                showDeleteConfirm = true
                            }
                        )
                    }
                    Divider().background(NETRTheme.border)
                }
            }
        }
    }

    // MARK: - Mention Suggestions

    private var mentionSuggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(mentionResults) { user in
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

                if user.id != mentionResults.last?.id {
                    Divider().background(NETRTheme.border)
                }
            }
        }
        .background(NETRTheme.surface)
    }

    // MARK: - Comment Input

    private var commentInput: some View {
        VStack(spacing: 0) {
            if let replyTo = replyingTo {
                HStack(spacing: 6) {
                    Text("Replying to \(replyTo.author?.handle ?? "comment")")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.neonGreen)
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
                    .onChange(of: commentText) { _, newValue in
                        searchMentions(text: newValue)
                    }
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

    // MARK: - Mention Search

    private func searchMentions(text: String) {
        mentionSearchTask?.cancel()

        let cursorPosition = text.count
        let prefixText = String(text.prefix(cursorPosition))
        guard let atIndex = prefixText.lastIndex(of: "@") else {
            mentionResults = []
            showMentionResults = false
            activeMentionQuery = ""
            return
        }

        let queryStart = prefixText.index(after: atIndex)
        let query = String(prefixText[queryStart...])

        if query.contains(" ") || query.isEmpty {
            mentionResults = []
            showMentionResults = false
            activeMentionQuery = ""
            return
        }

        activeMentionQuery = query
        showMentionResults = true

        mentionSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }

            do {
                let results: [UserSearchResult] = try await client
                    .from("profiles")
                    .select("id, username, full_name, avatar_url, netr_score")
                    .ilike("username", pattern: "\(query)%")
                    .limit(5)
                    .execute()
                    .value

                guard !Task.isCancelled else { return }
                mentionResults = results
            } catch {
                guard !Task.isCancelled else { return }
                mentionResults = []
            }
        }
    }

    private func insertMention(user: UserSearchResult) {
        guard let username = user.username else { return }
        let query = activeMentionQuery
        if let range = commentText.range(of: "@\(query)", options: .backwards) {
            commentText.replaceSubrange(range, with: "@\(username) ")
        }
        mentionResults = []
        showMentionResults = false
        activeMentionQuery = ""
        mentionSearchTask?.cancel()
    }

    // MARK: - Data

    private func loadComments() async {
        do {
            let result: [PostComment] = try await client
                .from("comments")
                .select(commentSelectQuery)
                .eq("post_id", value: post.id)
                .order("created_at", ascending: false)
                .execute()
                .value

            comments = result
            isLoading = false
        } catch {
            isLoading = false
            print("[NETR] Load comments error: \(error)")
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

            // Parse @mentions and insert into mentions table
            await insertMentions(commentId: created.id, text: text, userId: userId)

            commentText = ""
            replyingTo = nil
            isSubmitting = false
            onCommentAdded?()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } catch {
            isSubmitting = false
            commentError = "Failed to post comment"
            print("[NETR] Submit comment error: \(error)")
        }
    }

    private func deleteComment(_ comment: PostComment) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString,
              comment.authorId == userId else { return }

        guard let idx = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        let removed = comments.remove(at: idx)
        // Also remove any replies to this comment
        let removedReplies = comments.filter { $0.parentCommentId == comment.id }
        comments.removeAll { $0.parentCommentId == comment.id }

        do {
            try await client
                .from("comments")
                .delete()
                .eq("id", value: comment.id)
                .execute()
        } catch {
            // Revert on failure
            comments.insert(removed, at: min(idx, comments.count))
            comments.append(contentsOf: removedReplies)
            commentError = "Failed to delete comment"
            print("[NETR] Delete comment error: \(error)")
        }
    }

    private func insertMentions(commentId: String, text: String, userId: String) async {
        let mentionedUsernames = extractMentions(from: text)
        guard !mentionedUsernames.isEmpty else { return }

        for username in mentionedUsernames {
            do {
                nonisolated struct UsernameRow: Decodable, Sendable {
                    let id: String
                }
                let rows: [UsernameRow] = try await client
                    .from("profiles")
                    .select("id")
                    .eq("username", value: username)
                    .limit(1)
                    .execute()
                    .value

                guard let mentionedUser = rows.first else { continue }

                let payload = MentionPayload(
                    commentId: commentId,
                    postId: post.id,
                    mentionedUserId: mentionedUser.id,
                    mentioningUserId: userId
                )
                try await client
                    .from("mentions")
                    .insert(payload)
                    .execute()
            } catch {
                print("[NETR] Insert mention error for @\(username): \(error)")
            }
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
            if let j = comments.firstIndex(where: { $0.id == comment.id }) {
                comments[j].likeCount = comment.likeCount
            }
            if wasLiked { likedCommentIds.insert(comment.id) } else { likedCommentIds.remove(comment.id) }
            print("[NETR] Comment like error: \(error)")
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
    var isOwnComment: Bool = false
    var onProfileTap: ((String) -> Void)? = nil
    var onMentionTap: ((String) -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var likeScale: CGFloat = 1.0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Tappable avatar
            Button {
                if let authorId = comment.author?.id { onProfileTap?(authorId) }
            } label: {
                commentAvatar
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    // Tappable username
                    Button {
                        if let authorId = comment.author?.id { onProfileTap?(authorId) }
                    } label: {
                        Text(comment.author?.name ?? "Player")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NETRTheme.text)
                    }
                    .buttonStyle(.plain)

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
                    MentionTextView(
                        text: comment.content,
                        font: .preferredFont(forTextStyle: .subheadline),
                        onMentionTap: onMentionTap
                    )
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

                    if isOwnComment, let onDelete {
                        Spacer()
                        Button(action: onDelete) {
                            LucideIcon("trash-2", size: 11)
                                .foregroundStyle(NETRTheme.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var commentAvatar: some View {
        AvatarView(url: comment.author?.avatarUrl, name: comment.author?.name, size: isReply ? 24 : 28)
    }
}
