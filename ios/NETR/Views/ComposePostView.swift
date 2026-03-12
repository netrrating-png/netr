import SwiftUI

struct ComposePostView: View {
    @Bindable var viewModel: FeedViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var postText: String = ""
    @State private var selectedCourt: FeedCourtSearchResult? = nil
    @State private var showCourtSearch: Bool = false

    private let maxChars = 280

    private var charCount: Int { postText.count }
    private var isOverLimit: Bool { charCount > maxChars }
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
                            selectedCourtChip(court)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                Divider().background(NETRTheme.border)

                bottomBar
            }
            .background(NETRTheme.background)
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
                                courtId: selectedCourt?.id
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
            .sheet(isPresented: $showCourtSearch) {
                CourtSearchSheet(viewModel: viewModel, selectedCourt: $selectedCourt)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NETRTheme.surface)
            }
        }
    }

    private var authorAvatar: some View {
        Group {
            if let profile = SupabaseManager.shared.currentProfile,
               let avatarUrl = profile.avatarUrl,
               let url = URL(string: avatarUrl) {
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
            } else {
                let name = SupabaseManager.shared.currentProfile?.fullName ?? "You"
                let parts = name.split(separator: " ")
                let initials = parts.count >= 2
                    ? "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
                    : String(name.prefix(2)).uppercased()

                Text(initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .frame(width: 40, height: 40)
                    .background(NETRTheme.card, in: Circle())
            }
        }
    }

    private var authorInfo: some View {
        Group {
            if let profile = SupabaseManager.shared.currentProfile {
                HStack(spacing: 4) {
                    Text(profile.fullName ?? profile.username ?? "You")
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
        }
    }

    private func selectedCourtChip(_ court: FeedCourtSearchResult) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.caption)
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
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .padding(10)
        .background(NETRTheme.blue.opacity(0.06), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.blue.opacity(0.15), lineWidth: 1))
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button {
                showCourtSearch = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 14))
                    Text("Court")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(NETRTheme.blue)
            }

            Spacer()

            Text("\(charCount)/\(maxChars)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(
                    charCount >= 260
                    ? (isOverLimit ? NETRTheme.red : NETRTheme.gold)
                    : NETRTheme.subtext
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

struct CourtSearchSheet: View {
    @Bindable var viewModel: FeedViewModel
    @Binding var selectedCourt: FeedCourtSearchResult?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(NETRTheme.subtext)
                    TextField("Search courts...", text: $searchText)
                        .foregroundStyle(NETRTheme.text)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .onChange(of: searchText) { _, newValue in
                    Task { await viewModel.searchCourts(query: newValue) }
                }

                if viewModel.courtResults.isEmpty && searchText.count >= 2 {
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .font(.title2)
                            .foregroundStyle(NETRTheme.subtext)
                        Text("No courts found")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.courtResults, id: \.id) { court in
                                Button {
                                    selectedCourt = court
                                    dismiss()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(NETRTheme.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(court.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(NETRTheme.text)
                                                if court.verified == true {
                                                    Image(systemName: "checkmark.seal.fill")
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(NETRTheme.neonGreen)
                                                }
                                            }
                                            if let hood = court.neighborhood {
                                                Text(hood)
                                                    .font(.caption)
                                                    .foregroundStyle(NETRTheme.subtext)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Tag a Court")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
    }
}
