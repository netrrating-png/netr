import SwiftUI
import PhotosUI
import Auth

struct SettingsView: View {
    let store: MockDataStore
    @Bindable var appearance: AppearanceManager
    @Bindable var courtsViewModel: CourtsViewModel
    @Environment(SupabaseManager.self) private var supabase
    @Environment(BiometricAuthManager.self) private var biometrics
    @AppStorage("biometricsEnabled") private var biometricsEnabled: Bool = true
    @State private var showMyGames: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showSignOutConfirm: Bool = false
    @State private var profileViewModel = ProfileViewModel()

    private var user: Player { store.currentUser }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    profileCard
                    myGamesButton
                    appearanceSection
                    securitySection
                    accountSection
                    aboutSection
                    signOutSection
                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showMyGames) {
            NavigationStack {
                MyGamesView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NETRTheme.background)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: profileViewModel, player: user)
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.background)
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await profileViewModel.uploadAvatar(image)
                    store.currentUser.profileImageData = data
                }
            }
        }
    }

    @ViewBuilder
    private var ratingInlineBadge: some View {
        let ratingColor = NETRRating.color(for: user.rating)
        let ratingText = user.rating.map { String(format: "%.1f", $0) } ?? "--"
        HStack(spacing: 3) {
            Text(ratingText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(user.isProvisional ? NETRTheme.subtext : ratingColor)
            if user.isProvisional && !user.isProspect {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            (user.isProvisional ? NETRTheme.subtext : ratingColor).opacity(0.12),
            in: Capsule()
        )
    }

    private var profileCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                Text("SETTINGS")
                    .font(NETRTheme.headingFont(size: .title2))
                    .foregroundStyle(NETRTheme.text)
                Spacer()
            }

            HStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .stroke(
                                NETRRating.color(for: user.rating),
                                style: StrokeStyle(
                                    lineWidth: 3,
                                    dash: user.isProvisional && !user.isProspect ? [6, 4] : []
                                )
                            )
                            .frame(width: 72, height: 72)
                            .neonGlow(NETRRating.color(for: user.rating), radius: 6)

                        if let urlStr = user.avatarUrl, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
                                } else {
                                    Text(user.avatar)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(NETRTheme.text)
                                        .frame(width: 64, height: 64)
                                        .background(NETRTheme.card, in: Circle())
                                }
                            }
                        } else if let imageData = user.profileImageData,
                                  let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                        } else {
                            Text(user.avatar)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(NETRTheme.text)
                                .frame(width: 64, height: 64)
                                .background(NETRTheme.card, in: Circle())
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        LucideIcon("camera", size: 10)
                            .foregroundStyle(NETRTheme.background)
                            .frame(width: 24, height: 24)
                            .background(NETRTheme.neonGreen, in: Circle())
                            .overlay(Circle().stroke(NETRTheme.background, lineWidth: 2))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(user.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(NETRTheme.text)
                        if user.isVerified {
                            LucideIcon("badge-check", size: 12)
                                .foregroundStyle(NETRTheme.neonGreen)
                        }
                        ratingInlineBadge
                    }
                    Text(user.username)
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                    HStack(spacing: 6) {
                        Text(user.position.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(NETRTheme.neonGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(NETRTheme.neonGreen.opacity(0.1), in: Capsule())
                        Text(user.city)
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(NETRTheme.card, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(NETRTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var myGamesButton: some View {
        Button {
            showMyGames = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(NETRTheme.gold.opacity(0.1))
                        .frame(width: 40, height: 40)
                    LucideIcon("trophy")
                        .foregroundStyle(NETRTheme.gold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("My Games")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                    Text("Active and upcoming games")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }

                Spacer()

                LucideIcon("chevron-right", size: 12)
                    .foregroundStyle(NETRTheme.muted)
            }
            .padding(14)
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(NETRTheme.gold.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        .padding(.horizontal, 16)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPEARANCE")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(1)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    LucideIcon(appearance.isDarkMode ? "moon" : "sun")
                        .foregroundStyle(appearance.isDarkMode ? NETRTheme.purple : NETRTheme.gold)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dark Mode")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NETRTheme.text)
                        Text(appearance.isDarkMode ? "Midnight court vibes" : "Daylight game mode")
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    Spacer()

                    Toggle("", isOn: $appearance.isDarkMode)
                        .labelsHidden()
                        .tint(NETRTheme.neonGreen)
                }
                .padding(14)
            }
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SECURITY")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(1)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 16)

            if biometrics.isBiometricsAvailable {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: biometrics.biometricType.iconName)
                            .font(.body)
                            .foregroundStyle(NETRTheme.neonGreen)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(biometrics.biometricType.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NETRTheme.text)
                            Text("Require \(biometrics.biometricType.displayName) to unlock")
                                .font(.caption)
                                .foregroundStyle(NETRTheme.subtext)
                        }

                        Spacer()

                        Toggle("", isOn: $biometricsEnabled)
                            .labelsHidden()
                            .tint(NETRTheme.neonGreen)
                            .onChange(of: biometricsEnabled) { _, enabled in
                                if !enabled { biometrics.isUnlocked = true }
                            }
                    }
                    .padding(14)
                }
                .background(NETRTheme.card, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
                .padding(.horizontal, 16)
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCOUNT")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(1)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                SettingsRow(icon: "user", iconColor: NETRTheme.blue, title: "Edit Profile", subtitle: "Name, position, city", action: { showEditProfile = true })
                Divider().padding(.leading, 50)
                SettingsRow(icon: "bell", iconColor: NETRTheme.gold, title: "Notifications", subtitle: "Manage alerts & sounds")
                Divider().padding(.leading, 50)
                SettingsRow(icon: "lock", iconColor: NETRTheme.red, title: "Privacy", subtitle: "Profile visibility & data")
            }
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ABOUT")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(1)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                SettingsRow(icon: "info", iconColor: NETRTheme.subtext, title: "About NETR", subtitle: "Version 1.0")
                Divider().padding(.leading, 50)
                SettingsRow(icon: "file-text", iconColor: NETRTheme.subtext, title: "Terms of Service", subtitle: nil)
                Divider().padding(.leading, 50)
                SettingsRow(icon: "hand", iconColor: NETRTheme.subtext, title: "Privacy Policy", subtitle: nil)
            }
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    private var signOutSection: some View {
        Button {
            showSignOutConfirm = true
        } label: {
            HStack(spacing: 12) {
                LucideIcon("log-out")
                    .foregroundStyle(NETRTheme.red)
                    .frame(width: 24)
                Text("Sign Out")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NETRTheme.red)
                Spacer()
            }
            .padding(14)
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle())
        .padding(.horizontal, 16)
        .alert("Sign Out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task { try? await supabase.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your account.")
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    var action: (() -> Void)? = nil

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 12) {
                LucideIcon(icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }

                Spacer()

                LucideIcon("chevron-right", size: 12)
                    .foregroundStyle(NETRTheme.muted)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }
}
