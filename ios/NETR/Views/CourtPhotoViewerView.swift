import SwiftUI
import Supabase
import Auth
import PostgREST

/// Full-screen court photo viewer with swipe navigation and delete capability.
struct CourtPhotoViewerView: View {
    let photos: [CourtPhoto]
    let initialIndex: Int
    var onDelete: ((String) -> Void)? = nil

    @State private var currentIndex: Int
    @State private var showDeleteConfirm: Bool = false
    @Environment(\.dismiss) private var dismiss

    private var currentUserId: String? {
        SupabaseManager.shared.session?.user.id.uuidString
    }

    init(photos: [CourtPhoto], initialIndex: Int, onDelete: ((String) -> Void)? = nil) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.onDelete = onDelete
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    VStack(spacing: 0) {
                        Spacer()

                        AsyncImage(url: URL(string: photo.photoUrl)) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(.rect(cornerRadius: 4))
                            } else {
                                ProgressView().tint(NETRTheme.neonGreen)
                                    .frame(maxWidth: .infinity, minHeight: 300)
                            }
                        }

                        Spacer()

                        // Info bar
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                AvatarView(url: photo.uploader?.avatarUrl, name: photo.uploader?.name, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(photo.uploader?.name ?? "Player")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(NETRTheme.text)
                                    Text(photo.createdAt.relativeTimeFromISO)
                                        .font(.caption)
                                        .foregroundStyle(NETRTheme.subtext)
                                }
                                Spacer()
                            }

                            if let caption = photo.caption, !caption.isEmpty {
                                Text(caption)
                                    .font(.subheadline)
                                    .foregroundStyle(NETRTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(16)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            // Top bar
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        LucideIcon("x", size: 16)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Spacer()

                    if let photo = currentPhoto, photo.userId == currentUserId {
                        Button { showDeleteConfirm = true } label: {
                            LucideIcon("trash-2", size: 16)
                                .foregroundStyle(NETRTheme.red)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .alert("Delete Photo?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let photo = currentPhoto else { return }
                Task { await deletePhoto(photo) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This photo will be permanently removed.")
        }
    }

    private var currentPhoto: CourtPhoto? {
        guard currentIndex >= 0, currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }

    private func deletePhoto(_ photo: CourtPhoto) async {
        do {
            try await SupabaseManager.shared.client
                .from("court_photos")
                .delete()
                .eq("id", value: photo.id)
                .execute()

            onDelete?(photo.id)
            dismiss()
            print("[NETR Courts] Photo deleted: \(photo.id)")
        } catch {
            print("[NETR Courts] Delete photo error: \(error)")
        }
    }
}

// Make Int identifiable for fullScreenCover
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
