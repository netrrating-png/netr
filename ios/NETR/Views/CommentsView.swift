import SwiftUI
import Supabase
import Auth
import PhotosUI

struct CommentsView: View {
    let post: SupabaseFeedPost
    var onCommentAdded: (() -> Void)? = nil
    @State private var comments: [PostComment] = []
    @State private var isLoading: Bool = true
    @State private var commentText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var submitError: String?
    @State private var showSubmitError: Bool = false

    // Photo attachment
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploadingPhoto: Bool = false

    // Court attachment
    @State private var selectedCourt: FeedCourtSearchResult?
    @State private var showCourtSearch: Bool = false
    @State private var feedViewModel = FeedViewModel()

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
                .dismissKeyboardOnScroll()

                commentInput
            }
            .background(NETRTheme.background)
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
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                    selectedPhotoItem = nil
                }
            }
            .sheet(isPresented: $showCourtSearch) {
                CourtSearchSheet(viewModel: feedViewModel, selectedCourt: $selectedCourt)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NETRTheme.background)
            }
            .alert("Error", isPresented: $showSubmitError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(submitError ?? "Something went wrong.")
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

            // Attachment previews
            if selectedImage != nil || selectedCourt != nil {
                VStack(spacing: 8) {
                    if let image = selectedImage {
                        HStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 45)
                                .clipShape(.rect(cornerRadius: 8))
                            Text("Photo attached")
                                .font(.caption)
                                .foregroundStyle(NETRTheme.subtext)
                            Spacer()
                            Button {
                                selectedImage = nil
                            } label: {
                                LucideIcon("x-circle", size: 14)
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                        }
                    }

                    if let court = selectedCourt {
                        HStack(spacing: 6) {
                            LucideIcon("map-pin", size: 12)
                                .foregroundStyle(NETRTheme.blue)
                            Text(court.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(NETRTheme.text)
                            if let hood = court.neighborhood {
                                Text("· \(hood)")
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
                        .padding(8)
                        .background(NETRTheme.blue.opacity(0.06), in: .rect(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            HStack(spacing: 8) {
                // Court button
                Button {
                    showCourtSearch = true
                } label: {
                    LucideIcon("map-pin", size: 16)
                        .foregroundStyle(selectedCourt != nil ? NETRTheme.blue : NETRTheme.subtext)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Photo button
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    LucideIcon("camera", size: 16)
                        .foregroundStyle(selectedImage != nil ? NETRTheme.neonGreen : NETRTheme.subtext)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .disabled(selectedImage != nil)

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
                        if isSubmitting || isUploadingPhoto {
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
                .disabled(!canSubmit || isSubmitting || isUploadingPhoto)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(NETRTheme.surface)
        }
    }

    private var canSubmit: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedImage != nil
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
                .select("id, post_id, user_id, content, like_count, photo_url, court_id, created_at, profiles(id, full_name, username, avatar_url, netr_score, vibe_score), courts(id, name, neighborhood, verified)")
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
        guard !text.isEmpty || selectedImage != nil else { return }

        isSubmitting = true

        // Upload photo if present
        var photoUrl: String?
        if let image = selectedImage, let data = image.jpegData(compressionQuality: 0.8) {
            isUploadingPhoto = true
            let timestamp = Int(Date().timeIntervalSince1970)
            let path = "comments/\(userId)/\(timestamp).jpg"
            do {
                try await client.storage
                    .from("feed-photos")
                    .upload(path, data: data, options: FileOptions(
                        cacheControl: "3600", contentType: "image/jpeg", upsert: true
                    ))
                let url = try client.storage
                    .from("feed-photos")
                    .getPublicURL(path: path)
                photoUrl = url.absoluteString
            } catch {
                print("Comment photo upload error: \(error)")
            }
            isUploadingPhoto = false
        }

        do {
            let courtIdStr = selectedCourt.map { String($0.id) }
            let payload = CreateCommentPayload(
                postId: post.id,
                userId: userId,
                content: text.isEmpty ? "" : text,
                photoUrl: photoUrl,
                courtId: courtIdStr
            )
            let created: PostComment = try await client
                .from("post_comments")
                .insert(payload)
                .select("id, post_id, user_id, content, like_count, photo_url, court_id, created_at, profiles(id, full_name, username, avatar_url, netr_score, vibe_score), courts(id, name, neighborhood, verified)")
                .single()
                .execute()
                .value

            comments.append(created)
            commentText = ""
            selectedImage = nil
            selectedCourt = nil
            isSubmitting = false
            onCommentAdded?()
        } catch {
            isSubmitting = false
            submitError = "Failed to post comment. Please try again."
            showSubmitError = true
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

                if !comment.content.isEmpty {
                    Text(comment.content)
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Attached photo
                if let photoUrl = comment.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: 220, maxHeight: 160)
                                .clipShape(.rect(cornerRadius: 10))
                        } else if phase.error == nil {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(NETRTheme.card)
                                .frame(width: 120, height: 80)
                                .overlay { ProgressView().tint(NETRTheme.neonGreen) }
                        }
                    }
                }

                // Attached court
                if let court = comment.taggedCourt {
                    HStack(spacing: 5) {
                        LucideIcon("map-pin", size: 10)
                            .foregroundStyle(NETRTheme.blue)
                        Text(court.name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(NETRTheme.text)
                        if let hood = court.neighborhood {
                            Text("· \(hood)")
                                .font(.caption2)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(NETRTheme.blue.opacity(0.06), in: .rect(cornerRadius: 6))
                }

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
