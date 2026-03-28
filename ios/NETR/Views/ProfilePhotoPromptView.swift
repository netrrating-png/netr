import SwiftUI
import PhotosUI
import Supabase
import Auth
import PostgREST

struct ProfilePhotoPromptView: View {
    var onComplete: () -> Void

    @State private var selectedImage: UIImage?
    @State private var isUploading: Bool = false
    @State private var uploadError: String?
    @StateObject private var photoPicker = PhotoPickerManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                avatarCircle
                    .padding(.bottom, 28)

                headline
                    .padding(.bottom, 10)

                subheadline
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)

                bulletPoints
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)

                if let error = uploadError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(NETRTheme.red)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }

                Spacer()

                buttons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .photoPickerSheet(manager: photoPicker)
        .onChange(of: photoPicker.selectedImage) { _, newImage in
            if let newImage {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedImage = newImage
                }
            }
        }
    }

    // MARK: - Avatar Circle

    private var avatarCircle: some View {
        ZStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(NETRTheme.neonGreen, lineWidth: 3)
                    )
                    .shadow(color: NETRTheme.neonGreen.opacity(0.3), radius: 16)
            } else {
                Circle()
                    .fill(NETRTheme.card)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(
                                NETRTheme.neonGreen.opacity(0.4),
                                style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                            )
                    )
                    .overlay(
                        LucideIcon("camera", size: 32)
                            .foregroundStyle(NETRTheme.neonGreen.opacity(0.5))
                    )
            }
        }
    }

    // MARK: - Text

    private var headline: some View {
        Text("Put a face to your game.")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
    }

    private var subheadline: some View {
        Text("Players who add a photo get recognized on the court and trusted on the app. Your profile photo is the first thing other ballers see when they rate you or check your NETR score.")
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.6))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }

    private var bulletPoints: some View {
        VStack(alignment: .leading, spacing: 12) {
            bulletRow("Get recognized by players you've run with")
            bulletRow("Build credibility with a real profile")
            bulletRow("Show up in search results with your face")
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("✓")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(NETRTheme.neonGreen)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Buttons

    private var buttons: some View {
        VStack(spacing: 14) {
            if selectedImage != nil {
                // Photo selected — show confirm button
                Button {
                    uploadAndContinue()
                } label: {
                    HStack(spacing: 8) {
                        if isUploading {
                            ProgressView()
                                .tint(Color.black)
                        }
                        Text(isUploading ? "UPLOADING..." : "Looks good, let's go →")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                    .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 16)
                }
                .buttonStyle(PressButtonStyle())
                .disabled(isUploading)

                // Allow re-pick
                Button {
                    photoPicker.showActionSheet = true
                } label: {
                    Text("Choose a different photo")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                // No photo yet — show upload button
                Button {
                    photoPicker.showActionSheet = true
                } label: {
                    Text("Upload My Photo")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                        .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 16)
                }
                .buttonStyle(PressButtonStyle())
            }

            // Skip
            Button {
                onComplete()
            } label: {
                Text("Skip for now")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .disabled(isUploading)
        }
    }

    // MARK: - Upload

    private func uploadAndContinue() {
        guard let image = selectedImage else { return }

        isUploading = true
        uploadError = nil

        Task {
            do {
                try await SupabaseManager.shared.uploadAvatar(image)
                print("[NETR Avatar] Onboarding photo upload succeeded")
                onComplete()
            } catch {
                isUploading = false
                uploadError = "Upload failed. Try again or skip for now."
                print("[NETR Avatar] Onboarding upload error: \(error)")
            }
        }
    }
}
