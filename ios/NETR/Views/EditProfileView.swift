import SwiftUI
import PhotosUI
import Supabase

struct EditProfileView: View {
    @Bindable var viewModel: ProfileViewModel
    var player: Player
    @Environment(\.dismiss) private var dismiss

    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var city: String = ""
    @State private var selectedPosition: Position = .unknown

    @State private var showCourtPicker: Bool = false
    @State private var allCourts: [Court] = []
    @State private var courtSearch: String = ""

    @State private var bannerPhotoItem: PhotosPickerItem?
    @State private var bannerImage: UIImage?
    @State private var avatarPhotoItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?

    @State private var isUploadingBanner: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var showSaveError: Bool = false
    @State private var showSaveSuccess: Bool = false

    private let maxBioChars = 150

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        bannerSection
                        avatarSection
                        formFields
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NETRTheme.neonGreen)
                        .disabled(isSaving)
                }
            }
            .onAppear { populateFields() }
            .task {
                if let userId = SupabaseManager.shared.session?.user.id.uuidString {
                    await viewModel.loadHomeCourt(userId: userId)
                }
            }
            .sheet(isPresented: $showCourtPicker) {
                courtPickerSheet
            }
            .onChange(of: bannerPhotoItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        bannerImage = image
                    }
                }
            }
            .onChange(of: avatarPhotoItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        avatarImage = image
                    }
                }
            }
            .alert("Profile Saved", isPresented: $showSaveSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your profile has been updated.")
            }
            .alert("Save Failed", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Something went wrong. Please try again.")
            }
        }
    }

    // MARK: - Banner

    private var bannerSection: some View {
        ZStack(alignment: .bottomTrailing) {
            if let bannerImage {
                Image(uiImage: bannerImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
            } else if let bannerUrlStr = player.bannerUrl, let url = URL(string: bannerUrlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipped()
                    } else {
                        defaultBannerGradient
                    }
                }
            } else {
                defaultBannerGradient
            }

            PhotosPicker(selection: $bannerPhotoItem, matching: .images) {
                HStack(spacing: 6) {
                    LucideIcon("camera", size: 12)
                    Text("Edit")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.6), in: Capsule())
            }
            .padding(12)
        }
        .frame(height: 160)
    }

    private var defaultBannerGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                NETRRating.color(for: player.rating).opacity(0.3),
                NETRTheme.surface,
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 160)
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        HStack {
            ZStack(alignment: .bottomTrailing) {
                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(NETRTheme.background, lineWidth: 4))
                } else if let urlStr = player.avatarUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(NETRTheme.background, lineWidth: 4))
                        } else {
                            avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }

                PhotosPicker(selection: $avatarPhotoItem, matching: .images) {
                    LucideIcon("camera", size: 10)
                        .foregroundStyle(NETRTheme.background)
                        .frame(width: 24, height: 24)
                        .background(NETRTheme.neonGreen, in: Circle())
                        .overlay(Circle().stroke(NETRTheme.background, lineWidth: 2))
                }
            }
            .offset(y: -30)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, -20)
    }

    private var avatarPlaceholder: some View {
        Text(player.avatar)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(NETRTheme.text)
            .frame(width: 80, height: 80)
            .background(NETRTheme.card, in: Circle())
            .overlay(Circle().stroke(NETRTheme.background, lineWidth: 4))
    }

    // MARK: - Form Fields

    private var formFields: some View {
        VStack(spacing: 16) {
            editField(label: "Full Name", text: $fullName)
            editField(label: "Username", text: $username)

            VStack(alignment: .leading, spacing: 6) {
                Text("Bio")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)

                TextEditor(text: $bio)
                    .font(.system(size: 14))
                    .foregroundStyle(NETRTheme.text)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(12)
                    .background(NETRTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                    .clipShape(.rect(cornerRadius: 12))
                    .onChange(of: bio) { _, val in
                        if val.count > maxBioChars { bio = String(val.prefix(maxBioChars)) }
                    }

                HStack {
                    Spacer()
                    Text("\(bio.count)/\(maxBioChars)")
                        .font(.system(size: 11))
                        .foregroundStyle(bio.count > maxBioChars - 20 ? NETRTheme.gold : NETRTheme.subtext)
                }
            }

            editField(label: "City", text: $city)

            // Home Court picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Home Court")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)

                Button { showCourtPicker = true } label: {
                    HStack(spacing: 10) {
                        LucideIcon("home", size: 14)
                            .foregroundStyle(viewModel.homeCourt != nil ? NETRTheme.neonGreen : NETRTheme.subtext)
                        Text(viewModel.homeCourt?.name ?? "Select Home Court")
                            .font(.system(size: 14))
                            .foregroundStyle(viewModel.homeCourt != nil ? NETRTheme.text : NETRTheme.subtext)
                        Spacer()
                        LucideIcon("chevron-right", size: 12)
                            .foregroundStyle(NETRTheme.muted)
                    }
                    .padding(12)
                    .background(NETRTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                        viewModel.homeCourt != nil ? NETRTheme.neonGreen.opacity(0.4) : NETRTheme.border,
                        lineWidth: 1
                    ))
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Position")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Position.allCases.filter { $0 != .unknown }, id: \.rawValue) { pos in
                            Button {
                                selectedPosition = pos
                            } label: {
                                VStack(spacing: 4) {
                                    LucideIcon(pos.icon, size: 14)
                                    Text(pos.rawValue)
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundStyle(selectedPosition == pos ? NETRTheme.background : NETRTheme.text)
                                .frame(width: 52, height: 52)
                                .background(
                                    selectedPosition == pos ? NETRTheme.neonGreen : NETRTheme.card,
                                    in: .rect(cornerRadius: 12)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedPosition == pos ? Color.clear : NETRTheme.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var courtPickerSheet: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                let filtered = courtSearch.isEmpty ? allCourts : allCourts.filter {
                    $0.name.localizedCaseInsensitiveContains(courtSearch) ||
                    $0.neighborhood.localizedCaseInsensitiveContains(courtSearch)
                }

                if allCourts.isEmpty {
                    ProgressView().tint(NETRTheme.neonGreen)
                } else {
                    List(filtered) { court in
                        Button {
                            Task {
                                await viewModel.setHomeCourt(courtId: court.id)
                                showCourtPicker = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(court.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(NETRTheme.text)
                                        if court.verified {
                                            LucideIcon("badge-check", size: 11)
                                                .foregroundStyle(NETRTheme.blue)
                                        }
                                    }
                                    Text(court.neighborhood)
                                        .font(.system(size: 11))
                                        .foregroundStyle(NETRTheme.subtext)
                                }
                                Spacer()
                                if viewModel.homeCourt?.id == court.id {
                                    LucideIcon("check", size: 14)
                                        .foregroundStyle(NETRTheme.neonGreen)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(NETRTheme.card)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $courtSearch, prompt: "Search courts")
                }
            }
            .navigationTitle("Choose Home Court")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCourtPicker = false }
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
            .task {
                guard allCourts.isEmpty else { return }
                allCourts = (try? await SupabaseManager.shared.client
                    .from("courts")
                    .select("id, name, address, neighborhood, city, lat, lng, surface, lights, indoor, full_court, verified, tags, court_rating, submitted_by")
                    .order("name", ascending: true)
                    .execute()
                    .value) ?? []
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(NETRTheme.background)
    }

    private func editField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NETRTheme.subtext)

            TextField(label, text: text)
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.text)
                .padding(12)
                .background(NETRTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 12))
                .autocorrectionDisabled()
        }
    }

    // MARK: - Actions

    private func populateFields() {
        fullName = player.name
        username = player.username.hasPrefix("@") ? String(player.username.dropFirst()) : player.username
        bio = viewModel.bio ?? ""
        city = player.city
        selectedPosition = player.position
    }

    private func save() {
        isSaving = true
        Task {
            do {
                // Upload banner if changed
                if let bannerImg = bannerImage {
                    _ = await viewModel.uploadBanner(bannerImg)
                }

                // Upload avatar if changed
                if let avatarImg = avatarImage {
                    await viewModel.uploadAvatar(avatarImg)
                }

                // Update profile fields — send bio even if empty to allow clearing it
                try await viewModel.updateFullProfile(
                    fullName: fullName,
                    username: username,
                    bio: bio,
                    city: city.isEmpty ? nil : city,
                    position: selectedPosition == .unknown ? nil : selectedPosition.rawValue
                )

                isSaving = false
                showSaveSuccess = true
            } catch {
                isSaving = false
                saveError = error.localizedDescription
                showSaveError = true
            }
        }
    }
}
