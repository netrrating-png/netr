import SwiftUI
import PhotosUI
import Auth
import Supabase
import PostgREST
import LocalAuthentication

struct SettingsView: View {
    let store: MockDataStore
    @Bindable var appearance: AppearanceManager
    @Bindable var courtsViewModel: CourtsViewModel
    @Environment(SupabaseManager.self) private var supabase
    @Environment(BiometricAuthManager.self) private var biometrics
    @AppStorage("biometricsEnabled") private var biometricsEnabled: Bool = true
    @AppStorage("profilePrivate") private var profilePrivate: Bool = false
    @State private var showMyGames: Bool = false
    @State private var showNotificationPreferences: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showSignOutConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showDeleteTyping: Bool = false
    @State private var deleteConfirmText: String = ""
    @State private var showPrivacyPolicy: Bool = false
    @State private var showTermsOfService: Bool = false
    @State private var showAbout: Bool = false
    @State private var profileViewModel = ProfileViewModel()
    @State private var isUploadingAvatar: Bool = false
    @State private var avatarUploadError: String?
    @State private var showAvatarError: Bool = false
    @State private var showRatingInsights: Bool = false

    private var user: Player { store.currentUser }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    profileCard
                    NETRPlayerCardSection(
                        user: profileViewModel.player ?? user,
                        milestones: profileViewModel.milestones,
                        homeCourt: profileViewModel.homeCourt
                    )
                    myGamesButton
                    ratingInsightsButton
                    securitySection
                    accountSection
                    notificationsSection
                    privacySection
                    aboutSection
                    signOutSection
                    deleteAccountSection
                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showRatingInsights) {
            if let profile = profileViewModel.userProfile {
                RatingInsightsView(profile: profile, vibeScore: profileViewModel.vibeScore)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NETRTheme.background)
            }
        }
        .task {
            await profileViewModel.loadProfile()
            // Sync private profile state from Supabase
            if let profile = supabase.currentProfile {
                profilePrivate = profile.isPrivate ?? false
            }
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
        .sheet(isPresented: $showAbout) {
            AboutNETRView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                isUploadingAvatar = true
                avatarUploadError = nil
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await profileViewModel.uploadAvatar(image)
                    store.currentUser.profileImageData = data
                    isUploadingAvatar = false
                } else {
                    isUploadingAvatar = false
                    avatarUploadError = "Failed to load the selected photo."
                    showAvatarError = true
                }
                selectedPhotoItem = nil
            }
        }
        .alert("Upload Error", isPresented: $showAvatarError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(avatarUploadError ?? "An error occurred while uploading your photo.")
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

                        if isUploadingAvatar {
                            ProgressView()
                                .tint(NETRTheme.neonGreen)
                                .frame(width: 64, height: 64)
                                .background(NETRTheme.card, in: Circle())
                        } else {
                            AvatarView.currentUser(size: 64)
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

    private var ratingInsightsButton: some View {
        Button {
            showRatingInsights = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(NETRTheme.neonGreen.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NETRTheme.neonGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rating Breakdown")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                    Text("Understand what's behind your score")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)
            }
            .padding(14)
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
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
                                if enabled {
                                    // Trigger biometric auth to verify
                                    let context = LAContext()
                                    var error: NSError?
                                    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                                        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Enable biometric unlock for NETR") { success, _ in
                                            if !success {
                                                DispatchQueue.main.async { biometricsEnabled = false }
                                            }
                                        }
                                    }
                                } else {
                                    biometrics.isUnlocked = true
                                }
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
                SettingsRow(icon: "user", iconColor: NETRTheme.blue, title: "Edit Profile", subtitle: "Name, position, city, bio", action: { showEditProfile = true })
            }
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOTIFICATIONS")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(1)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "bell",
                    iconColor: NETRTheme.gold,
                    title: "Notification Preferences",
                    subtitle: "Push notifications, alerts & sounds",
                    action: { showNotificationPreferences = true }
                )
            }
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showNotificationPreferences) {
            NavigationStack {
                NotificationPreferencesView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NETRTheme.background)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRIVACY")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(1)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    LucideIcon("lock")
                        .foregroundStyle(NETRTheme.red)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Private Profile")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NETRTheme.text)
                        Text(profilePrivate ? "Only followers can see your stats" : "Profile visible to everyone")
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    Spacer()

                    Toggle("", isOn: $profilePrivate)
                        .labelsHidden()
                        .tint(NETRTheme.neonGreen)
                        .onChange(of: profilePrivate) { _, newValue in
                            Task {
                                guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
                                do {
                                    try await SupabaseManager.shared.client
                                        .from("profiles")
                                        .update(["is_private": AnyJSON.bool(newValue)])
                                        .eq("id", value: userId)
                                        .execute()
                                } catch {
                                    print("[NETR] Private profile update error: \(error)")
                                }
                            }
                        }
                }
                .padding(14)
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
                SettingsRow(icon: "info", iconColor: NETRTheme.subtext, title: "About NETR", subtitle: "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")", action: { showAbout = true })
                Divider().padding(.leading, 50)
                SettingsRow(icon: "file-text", iconColor: NETRTheme.subtext, title: "Terms of Service", subtitle: nil, action: { showTermsOfService = true })
                Divider().padding(.leading, 50)
                SettingsRow(icon: "hand", iconColor: NETRTheme.subtext, title: "Privacy Policy", subtitle: nil, action: { showPrivacyPolicy = true })
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
                Task {
                    do {
                        try await supabase.signOut()
                    } catch {
                        print("[NETR] Sign out error: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your account.")
        }
    }

    private var deleteAccountSection: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 12) {
                LucideIcon("trash-2")
                    .foregroundStyle(NETRTheme.red.opacity(0.7))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delete Account")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.red.opacity(0.7))
                    Text("Permanently remove your data")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }
                Spacer()
            }
            .padding(14)
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.red.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle())
        .padding(.horizontal, 16)
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Continue", role: .destructive) {
                showDeleteTyping = true
                deleteConfirmText = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all your data. This cannot be undone.")
        }
        .alert("Type DELETE to confirm", isPresented: $showDeleteTyping) {
            TextField("DELETE", text: $deleteConfirmText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            Button("Delete My Account", role: .destructive) {
                guard deleteConfirmText == "DELETE" else { return }
                Task {
                    await deleteAccountAndSignOut()
                }
            }
            Button("Cancel", role: .cancel) {
                deleteConfirmText = ""
            }
        } message: {
            Text("Type DELETE to permanently delete your account.")
        }
    }

    private func deleteAccountAndSignOut() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        let client = SupabaseManager.shared.client

        // Helper to delete from a table with logging on failure
        func deleteFrom(_ table: String, column: String) async {
            do {
                try await client.from(table).delete().eq(column, value: userId).execute()
            } catch {
                print("[NETR] Delete from \(table) error: \(error)")
            }
        }

        // Delete user data from all tables (continue on individual failures)
        await deleteFrom("feed_posts", column: "author_id")
        await deleteFrom("comments", column: "author_id")
        await deleteFrom("likes", column: "user_id")
        await deleteFrom("comment_likes", column: "user_id")
        await deleteFrom("bookmarks", column: "user_id")
        await deleteFrom("follows", column: "follower_id")
        await deleteFrom("follows", column: "following_id")
        await deleteFrom("mentions", column: "mentioned_user_id")
        await deleteFrom("mentions", column: "mentioning_user_id")
        await deleteFrom("notifications", column: "user_id")
        await deleteFrom("notification_preferences", column: "user_id")
        await deleteFrom("court_favorites", column: "user_id")
        await deleteFrom("profiles", column: "id")

        do {
            try await supabase.signOut()
        } catch {
            print("[NETR] Sign out after delete error: \(error)")
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
