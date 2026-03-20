import SwiftUI
import PhotosUI
import Supabase
import Auth

struct ProfileView: View {
    var profileUserId: String? = nil
    var courtsViewModel: CourtsViewModel? = nil
    @Binding var showSelfAssessment: Bool

    @State private var viewModel = ProfileViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showScoreInfo: Bool = false
    @State private var ratingAnimated: Bool = false
    @State private var radarVisible: Bool = false
    @State private var showFollowers: Bool = false
    @State private var showFollowing: Bool = false
    @State private var showBioEdit: Bool = false
    @State private var showRatingScale: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var showCourtLeaderboard: Bool = false
    @State private var localCourtsVM = CourtsViewModel()

    init(profileUserId: String? = nil, courtsViewModel: CourtsViewModel? = nil, showSelfAssessment: Binding<Bool> = .constant(false)) {
        self.profileUserId = profileUserId
        self.courtsViewModel = courtsViewModel
        self._showSelfAssessment = showSelfAssessment
    }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.player == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(NETRTheme.neonGreen)
                        .scaleEffect(1.2)
                    Text("Loading profile...")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                }
            } else if let user = viewModel.player {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        profileHeaderGradient(user: user)

                        VStack(alignment: .leading, spacing: 0) {
                            avatarFollowRow(user: user)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 14)

                            nameBadgeRow(user: user)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 6)

                            bioSection(user: user)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 18)

                            socialCountsRow(user: user)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)

                            Divider().background(NETRTheme.border).padding(.horizontal, 20).padding(.bottom, 24)

                            ratingHeroSection(user: user)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 28)

                            radarSection(user: user)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 28)

                            Divider().background(NETRTheme.border).padding(.horizontal, 20).padding(.bottom, 24)

                            statsStrip(user: user)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)

                            Divider().background(NETRTheme.border).padding(.horizontal, 20).padding(.bottom, 24)

                            if let vibeScore = viewModel.vibeScore {
                                vibeRow(score: vibeScore)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 24)
                                Divider().background(NETRTheme.border).padding(.horizontal, 20).padding(.bottom, 24)
                            }

                            courtRepRow(user: user)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)

                            Divider().background(NETRTheme.border).padding(.horizontal, 20).padding(.bottom, 24)

                            if let court = viewModel.homeCourt {
                                homeCourtRow(court: court, accentColor: ratingColor(for: user))
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 40)
                                    .onTapGesture { showCourtLeaderboard = true }
                            }

                            Spacer(minLength: 100)
                        }
                        .background(NETRTheme.background)
                    }
                }
            } else if viewModel.error != nil {
                VStack(spacing: 16) {
                    LucideIcon("triangle-alert", size: 40)
                        .foregroundStyle(NETRTheme.red)
                    Text("Could not load profile")
                        .font(.headline)
                        .foregroundStyle(NETRTheme.text)
                    Button("Try Again") {
                        Task { await viewModel.loadProfile(userId: profileUserId) }
                    }
                    .foregroundStyle(NETRTheme.neonGreen)
                }
            }
        }
        .task(id: "profile") {
            await viewModel.loadProfile(userId: profileUserId)
        }
        .onAppear {
            Task { await viewModel.loadProfile(userId: profileUserId) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { ratingAnimated = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation { radarVisible = true }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.uploadAvatar(image)
                }
            }
        }
        .onChange(of: showSelfAssessment) { _, isShowing in
            if !isShowing {
                Task { await viewModel.loadProfile(userId: profileUserId) }
            }
        }
        .sheet(isPresented: $showScoreInfo) { ScoreInfoSheet() }
        .sheet(isPresented: $showFollowers) {
            if let uid = profileUserId ?? SupabaseManager.shared.session?.user.id.uuidString {
                ProfileFollowListSheet(
                    title: "Followers",
                    userId: uid,
                    mode: .followers,
                    currentUserId: SupabaseManager.shared.session?.user.id.uuidString
                )
            }
        }
        .sheet(isPresented: $showFollowing) {
            if let uid = profileUserId ?? SupabaseManager.shared.session?.user.id.uuidString {
                ProfileFollowListSheet(
                    title: "Following",
                    userId: uid,
                    mode: .following,
                    currentUserId: SupabaseManager.shared.session?.user.id.uuidString
                )
            }
        }
        .sheet(isPresented: $showBioEdit) {
            ProfileBioEditSheet()
                .onDisappear { Task { await viewModel.loadProfile(userId: profileUserId) } }
        }
        .sheet(isPresented: $showRatingScale) { NETRRatingScaleView() }
        .sheet(isPresented: $showEditProfile) {
            if let user = viewModel.player {
                EditProfileView(viewModel: viewModel, player: user)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NETRTheme.background)
            }
        }
        .sheet(isPresented: $showCourtLeaderboard) {
            if let court = viewModel.homeCourt {
                CourtDetailView(court: court, viewModel: courtsViewModel ?? localCourtsVM, initialTab: 4)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NETRTheme.background)
            }
        }
    }

    // MARK: - Header Gradient

    private func profileHeaderGradient(user: Player) -> some View {
        ZStack(alignment: .bottom) {
            if let bannerUrlStr = user.bannerUrl, let url = URL(string: bannerUrlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, NETRTheme.background]),
                                    startPoint: .center, endPoint: .bottom
                                )
                            )
                    } else {
                        defaultHeaderGradient(user: user)
                    }
                }
            } else {
                defaultHeaderGradient(user: user)
            }
        }
        .frame(height: 160)
    }

    private func defaultHeaderGradient(user: Player) -> some View {
        LinearGradient(
            gradient: Gradient(colors: [
                ratingColor(for: user).opacity(0.18),
                NETRTheme.background,
            ]),
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 160)
    }

    // MARK: - Avatar + Follow Row

    private func avatarFollowRow(user: Player) -> some View {
        let color = ratingColor(for: user)
        let tierColor = user.isProspect ? NETRTheme.purple : (user.isProvisional ? NETRTheme.subtext : NETRRating.color(for: user.rating))

        return HStack(alignment: .bottom) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [color.opacity(0.2), color.opacity(0.05)]),
                        center: .center, startRadius: 0, endRadius: 40
                    ))
                    .frame(width: 84, height: 84)
                Circle()
                    .stroke(
                        tierColor.opacity(user.isVerified ? 0.6 : 0.25),
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: user.isProvisional && !user.isProspect ? [6, 4] : []
                        )
                    )
                    .frame(width: 84, height: 84)

                if let avatarImage = viewModel.avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 76, height: 76)
                        .clipShape(Circle())
                } else if let urlStr = user.avatarUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 76, height: 76)
                                .clipShape(Circle())
                        } else if phase.error != nil {
                            avatarInitials(user: user, color: color)
                        } else {
                            ProgressView()
                                .frame(width: 76, height: 76)
                        }
                    }
                } else {
                    avatarInitials(user: user, color: color)
                }

                let vibeTier = VibeTier.display(score: viewModel.vibeScore)
                let vibeColor = Color(red: vibeTier.color.red, green: vibeTier.color.green, blue: vibeTier.color.blue)
                ZStack {
                    Circle()
                        .fill(vibeColor.opacity(0.35))
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(vibeColor)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(NETRTheme.background, lineWidth: 2))
                        .shadow(color: vibeColor, radius: 6)
                        .shadow(color: vibeColor.opacity(0.5), radius: 10)
                }
                .offset(x: 0, y: 34)

                if viewModel.isCurrentUser {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        ZStack {
                            if viewModel.isUploadingAvatar {
                                ProgressView()
                                    .tint(NETRTheme.background)
                                    .frame(width: 22, height: 22)
                                    .background(NETRTheme.neonGreen, in: Circle())
                                    .overlay(Circle().stroke(NETRTheme.background, lineWidth: 2))
                            } else {
                                LucideIcon("camera", size: 9)
                                    .foregroundStyle(NETRTheme.background)
                                    .frame(width: 22, height: 22)
                                    .background(NETRTheme.neonGreen, in: Circle())
                                    .overlay(Circle().stroke(NETRTheme.background, lineWidth: 2))
                            }
                        }
                    }
                    .disabled(viewModel.isUploadingAvatar)
                    .offset(x: 28, y: -28)
                }
            }
            .shadow(color: color.opacity(user.isVerified ? 0.3 : 0.1), radius: 20)
            .offset(y: -28)

            Spacer()

            HStack(spacing: 10) {
                if viewModel.isCurrentUser {
                    Button { showEditProfile = true } label: {
                        profileActionButton(label: "Edit Profile", icon: "pencil", filled: false)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task { await viewModel.toggleFollow() }
                    } label: {
                        profileActionButton(
                            label: viewModel.isFollowing ? "Following" : "Follow",
                            icon: viewModel.isFollowing ? "check" : "user-plus",
                            filled: !viewModel.isFollowing
                        )
                    }
                    .sensoryFeedback(.selection, trigger: viewModel.isFollowing)

                    Button {} label: {
                        LucideIcon("more-horizontal", size: 15)
                            .foregroundStyle(NETRTheme.subtext)
                            .frame(width: 36, height: 36)
                            .background(NETRTheme.card)
                            .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private func profileActionButton(label: String, icon: String, filled: Bool) -> some View {
        HStack(spacing: 6) {
            LucideIcon(icon, size: 13)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(filled ? NETRTheme.background : NETRTheme.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(filled ? NETRTheme.neonGreen : NETRTheme.card)
        .overlay(Capsule().stroke(filled ? Color.clear : NETRTheme.border, lineWidth: 1))
        .clipShape(Capsule())
    }

    // MARK: - Name + Badges

    private func nameBadgeRow(user: Player) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(user.name)
                    .font(.system(.title2, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)

                if user.isVerified {
                    LucideIcon("badge-check", size: 14)
                        .foregroundStyle(NETRTheme.neonGreen)
                }

                if user.isProspect {
                    Text("PROSPECT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NETRTheme.purple)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(NETRTheme.purple.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(NETRTheme.purple.opacity(0.4), lineWidth: 1))
                        .clipShape(.rect(cornerRadius: 5))
                }
            }

            HStack(spacing: 6) {
                Text(user.username)
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.subtext)
                Text("·")
                    .foregroundStyle(NETRTheme.muted)
                Text(user.position.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ratingColor(for: user))
                Text("·")
                    .foregroundStyle(NETRTheme.muted)
                LucideIcon("map-pin", size: 11)
                    .foregroundStyle(NETRTheme.muted)
                Text(user.city)
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
                if let _ = viewModel.homeCourt {
                    Text("·")
                        .foregroundStyle(NETRTheme.muted)
                    Button { showCourtLeaderboard = true } label: {
                        HStack(spacing: 3) {
                            LucideIcon("home", size: 11)
                                .foregroundStyle(NETRTheme.neonGreen)
                            Text(viewModel.homeCourt!.name)
                                .font(.system(size: 12))
                                .foregroundStyle(NETRTheme.neonGreen)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Bio

    private func bioSection(user: Player) -> some View {
        Group {
            if let bio = viewModel.bio, !bio.isEmpty {
                // Show bio text; current user can tap to edit
                if viewModel.isCurrentUser {
                    Button { showBioEdit = true } label: {
                        Text(bio)
                            .font(.system(size: 14))
                            .foregroundStyle(NETRTheme.text)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(bio)
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                }
            } else if viewModel.isCurrentUser {
                Button { showBioEdit = true } label: {
                    HStack(spacing: 8) {
                        LucideIcon("plus-circle", size: 13)
                            .foregroundStyle(NETRTheme.neonGreen)
                        Text("Add a bio")
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                    .padding(.top, 10)
                }
            }
        }
    }

    // MARK: - Social Counts

    private func socialCountsRow(user: Player) -> some View {
        HStack(spacing: 0) {
            socialCountCell(count: viewModel.followerCount, label: viewModel.followerCount == 1 ? "Follower" : "Followers") {
                showFollowers = true
            }

            Rectangle()
                .fill(NETRTheme.muted)
                .frame(width: 1, height: 28)
                .padding(.horizontal, 24)

            socialCountCell(count: viewModel.followingCount, label: "Following") {
                showFollowing = true
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(user.games)")
                    .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)
                Text("Games")
                    .font(.system(size: 11))
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .padding(.top, 14)
    }

    private func socialCountCell(count: Int, label: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(count >= 1000 ? String(format: "%.1fK", Double(count) / 1000) : "\(count)")
                    .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rating Hero

    private func ratingHeroSection(user: Player) -> some View {
        let color = ratingColor(for: user)
        let isPeerRated = user.isVerified
        let peerProgress = min(1.0, Double(user.reviews) / 5.0)

        return VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NETR RATING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NETRTheme.subtext)
                        .tracking(1.5)
                    NETRTierPill(score: user.rating)
                    if !isPeerRated {
                        HStack(spacing: 5) {
                            Image(systemName: user.rating == nil ? "questionmark.circle.fill" : "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(NETRTheme.subtext)
                            Text(user.rating == nil ? "No self-assessment yet" : "Self-assessed · updates at 5 ratings")
                                .font(.system(size: 11))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    } else {
                        Text("\(user.reviews) peer ratings")
                            .font(.system(size: 11))
                            .foregroundStyle(color.opacity(0.7))
                    }
                }
                Spacer()

                NETRBadge(score: user.rating, size: .xl)
                    .scaleEffect(ratingAnimated ? 1.0 : 0.8)
                    .opacity(ratingAnimated ? 1.0 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.7), value: ratingAnimated)
                    .onTapGesture { showRatingScale = true }
            }

            if !isPeerRated {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(user.reviews) of 5 ratings needed to unlock peer score")
                            .font(.system(size: 11))
                            .foregroundStyle(NETRTheme.subtext)
                        Spacer()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(NETRTheme.muted).frame(height: 4)
                            Capsule()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [color.opacity(0.6), color]),
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: ratingAnimated ? geo.size.width * peerProgress : 0, height: 4)
                                .animation(.easeOut(duration: 0.8).delay(0.2), value: ratingAnimated)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(14)
                .background(NETRTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 12))
            }

            if viewModel.isCurrentUser {
                if user.rating == nil {
                    Button {
                        showSelfAssessment = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 16))
                            Text("TAKE SELF ASSESSMENT")
                                .font(.system(.subheadline, design: .default, weight: .bold).width(.compressed))
                                .tracking(1)
                        }
                        .foregroundStyle(NETRTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }

            if user.trend == .up {
                HStack(spacing: 4) {
                    LucideIcon("arrow-up-right", size: 11)
                        .foregroundStyle(NETRTheme.neonGreen)
                    Text("Trending up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NETRTheme.neonGreen)
                }
            } else if user.trend == .down {
                HStack(spacing: 4) {
                    LucideIcon("arrow-down-right", size: 11)
                        .foregroundStyle(NETRTheme.red)
                    Text("Trending down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NETRTheme.red)
                }
            }
        }
    }

    // MARK: - Radar Section

    private func radarSection(user: Player) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SKILL BREAKDOWN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1.5)
                Spacer()
                if user.isProvisional && !user.isProspect {
                    HStack(spacing: 4) {
                        LucideIcon("lock", size: 9)
                            .foregroundStyle(NETRTheme.subtext)
                        Text("Self-assessed")
                            .font(.system(size: 11))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                Button { showScoreInfo = true } label: {
                    ScoreInfoButton()
                }
            }

            SkillRadarView(skills: buildRadarSkills(from: user.skills), size: 280, animated: true, tierColor: NETRRating.color(for: user.rating))
        }
    }

    // MARK: - Stats Strip

    private func statsStrip(user: Player) -> some View {
        HStack(spacing: 0) {
            profileStatBox(value: "\(user.games)", label: "GAMES")
            Divider().frame(height: 36).background(NETRTheme.muted)
            profileStatBox(value: "\(user.reviews)", label: "REVIEWS")
            Divider().frame(height: 36).background(NETRTheme.muted)
            profileStatBox(
                value: user.isVerified ? "✓" : "—",
                label: "VERIFIED",
                valueColor: user.isVerified ? NETRTheme.neonGreen : NETRTheme.muted
            )
        }
    }

    private func profileStatBox(value: String, label: String, valueColor: Color = NETRTheme.text) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1.3)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Vibe Row

    private func vibeRow(score: Double) -> some View {
        let tier = VibeTier.from(score: score)
        let vibeColor = tier.map { Color(red: $0.color.red, green: $0.color.green, blue: $0.color.blue) } ?? NETRTheme.subtext
        let vibeLabel = tier?.label ?? "Unknown"

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(vibeColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Circle()
                    .fill(vibeColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: vibeColor.opacity(0.8), radius: 5)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("VIBE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1.4)
                Text(vibeLabel)
                    .font(.system(.callout, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(vibeColor)
            }
            Spacer()
            LucideIcon("chevron-right", size: 12)
                .foregroundStyle(NETRTheme.muted)
        }
    }

    // MARK: - Court Rep

    private func courtRepRow(user: Player) -> some View {
        let repLevel = min(max(user.games / 10, 1), 10)
        let repXP = user.games * 5
        let repXPToNext = max(50 - (repXP % 50), 1)
        let repLevelName = repLevel <= 1 ? "Newcomer" : repLevel <= 3 ? "Regular" : repLevel <= 5 ? "Hooper" : "Legend"
        let repColor = ratingColor(for: user)

        return VStack(alignment: .leading, spacing: 12) {
            Text("COURT REP")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1.5)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(repColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Circle()
                        .stroke(repColor, lineWidth: 1.5)
                        .frame(width: 46, height: 46)
                    Text("L\(repLevel)")
                        .font(.system(.callout, design: .default, weight: .black).width(.compressed))
                        .foregroundStyle(repColor)
                }
                .shadow(color: repColor.opacity(0.25), radius: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(repLevelName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(repColor)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(NETRTheme.muted).frame(height: 4)
                            Capsule()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [repColor.opacity(0.6), repColor]),
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * min(1, Double(repXP % 50) / 50.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                    Text("\(repXP) XP · \(repXPToNext) to next level")
                        .font(.system(size: 11))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
    }

    // MARK: - Home Court

    private func homeCourtRow(court: Court, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HOME COURT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1.5)
                Spacer()
                HStack(spacing: 4) {
                    LucideIcon("trophy", size: 11)
                        .foregroundStyle(NETRTheme.gold)
                    Text("TOP 20")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(NETRTheme.gold)
                        .tracking(0.8)
                }
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    LucideIcon("home", size: 15)
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(court.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NETRTheme.text)
                    Text(court.neighborhood)
                        .font(.system(size: 11))
                        .foregroundStyle(NETRTheme.subtext)
                }

                Spacer()

                LucideIcon("chevron-right", size: 11)
                    .foregroundStyle(NETRTheme.muted)
            }
            .padding(12)
            .background(NETRTheme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.25), lineWidth: 1))
        }
    }

    // MARK: - Helpers

    private func avatarInitials(user: Player, color: Color) -> some View {
        Text(user.avatar)
            .font(.system(size: 28, weight: .black, design: .default).width(.compressed))
            .foregroundStyle(color)
            .frame(width: 76, height: 76)
            .background(NETRTheme.card, in: Circle())
    }

    private func ratingColor(for user: Player) -> Color {
        NETRRating.color(for: user.rating)
    }
}

// MARK: - Follow List Sheet

// MARK: - Follow List User Row Model

private struct FollowUser: Identifiable, Sendable {
    let id: String
    let fullName: String?
    let username: String?
    let avatarUrl: String?
    let netrScore: Double?
    let vibeScore: Double?
    var isFollowing: Bool

    var displayName: String { fullName ?? username ?? "Player" }
    var displayHandle: String { username.map { "@\($0)" } ?? "" }
    var initials: String {
        let name = fullName ?? username ?? "?"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Real Follow List Sheet

struct ProfileFollowListSheet: View {
    enum Mode { case followers, following }

    let title: String
    let userId: String          // whose followers/following to show
    let mode: Mode
    let currentUserId: String?  // viewer — nil = not logged in
    @Environment(\.dismiss) private var dismiss

    @State private var users: [FollowUser] = []
    @State private var isLoading = true
    @State private var selectedUserId: String?

    private let client = SupabaseManager.shared.client

    // Convenience init for call sites that used the old (title, count) signature
    init(title: String, userId: String, mode: Mode, currentUserId: String?) {
        self.title = title
        self.userId = userId
        self.mode = mode
        self.currentUserId = currentUserId
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(NETRTheme.background)
                } else if users.isEmpty {
                    VStack(spacing: 8) {
                        Text(mode == .followers ? "No followers yet" : "Not following anyone yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NETRTheme.text)
                        Text(mode == .followers ? "When someone follows this account they'll appear here." : "Follow players to see them here.")
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NETRTheme.background)
                } else {
                    List(users) { user in
                        Button { selectedUserId = user.id } label: {
                            followRow(user)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(NETRTheme.background)
                        .listRowSeparatorTint(NETRTheme.border)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(NETRTheme.background.ignoresSafeArea())
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NETRTheme.neonGreen)
                }
            }
        }
        .task { await load() }
        .fullScreenCover(item: $selectedUserId) { uid in
            PublicPlayerProfileView(userId: uid)
        }
    }

    @ViewBuilder
    private func followRow(_ user: FollowUser) -> some View {
        HStack(spacing: 14) {
            // Avatar
            Circle()
                .fill(NETRTheme.muted)
                .frame(width: 44, height: 44)
                .overlay {
                    if let urlStr = user.avatarUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .clipShape(Circle())
                    } else {
                        Text(user.initials)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }

            // Name + handle + scores
            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NETRTheme.text)
                if !user.displayHandle.isEmpty {
                    Text(user.displayHandle)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                }
                HStack(spacing: 10) {
                    if let rating = user.netrScore {
                        Label(String(format: "%.2f", rating), systemImage: "star.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NETRRating.color(for: rating))
                    }
                    if user.vibeScore != nil {
                        VibeDecalView(vibe: user.vibeScore, size: .small)
                    }
                }
            }
            Spacer()

            // Follow / Following button — only show if viewer is logged in and it's not themselves
            if let currentId = currentUserId, currentId != user.id {
                Button {
                    Task { await toggleFollow(user) }
                } label: {
                    Text(user.isFollowing ? "Following" : "Follow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(user.isFollowing ? NETRTheme.text : NETRTheme.background)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(user.isFollowing ? NETRTheme.muted : NETRTheme.neonGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Data Loading

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        nonisolated struct FollowRow: Decodable, Sendable {
            let followerId: String?
            let followingId: String?
            nonisolated enum CodingKeys: String, CodingKey {
                case followerId = "follower_id"
                case followingId = "following_id"
            }
        }

        // Step 1: get the IDs from the follows table
        let targetIds: [String]
        do {
            if mode == .followers {
                // people who follow `userId`
                let rows: [FollowRow] = try await client
                    .from("follows")
                    .select("follower_id")
                    .eq("following_id", value: userId)
                    .execute()
                    .value
                targetIds = rows.compactMap { $0.followerId }
            } else {
                // people that `userId` follows
                let rows: [FollowRow] = try await client
                    .from("follows")
                    .select("following_id")
                    .eq("follower_id", value: userId)
                    .execute()
                    .value
                targetIds = rows.compactMap { $0.followingId }
            }
        } catch {
            print("FollowList fetch error: \(error)")
            return
        }

        guard !targetIds.isEmpty else { return }

        // Step 2: fetch profiles for those IDs
        nonisolated struct SlimProfile: Decodable, Sendable {
            let id: String
            let fullName: String?
            let username: String?
            let avatarUrl: String?
            let netrScore: Double?
            let vibeScore: Double?
            nonisolated enum CodingKeys: String, CodingKey {
                case id
                case fullName = "full_name"
                case username
                case avatarUrl = "avatar_url"
                case netrScore = "netr_score"
                case vibeScore = "vibe_score"
            }
        }

        let profiles: [SlimProfile]
        do {
            profiles = try await client
                .from("profiles")
                .select("id, full_name, username, avatar_url, netr_score, vibe_score")
                .in("id", values: targetIds)
                .execute()
                .value
        } catch {
            print("FollowList profiles fetch error: \(error)")
            return
        }

        // Step 3: figure out which ones the current viewer already follows
        var viewerFollowingSet: Set<String> = []
        if let currentId = currentUserId, !profiles.isEmpty {
            let profileIds = profiles.map { $0.id }
            nonisolated struct FRow: Decodable, Sendable {
                let followingId: String
                nonisolated enum CodingKeys: String, CodingKey { case followingId = "following_id" }
            }
            if let rows: [FRow] = try? await client
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: currentId)
                .in("following_id", values: profileIds)
                .execute()
                .value {
                viewerFollowingSet = Set(rows.map { $0.followingId })
            }
        }

        // Preserve the order from targetIds
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        users = targetIds.compactMap { id -> FollowUser? in
            guard let p = profileMap[id] else { return nil }
            return FollowUser(
                id: p.id,
                fullName: p.fullName,
                username: p.username,
                avatarUrl: p.avatarUrl,
                netrScore: p.netrScore,
                vibeScore: p.vibeScore,
                isFollowing: viewerFollowingSet.contains(p.id)
            )
        }
    }

    // MARK: - Toggle Follow

    private func toggleFollow(_ user: FollowUser) async {
        guard let currentId = currentUserId, currentId != user.id else { return }

        nonisolated struct FollowPayload: Encodable, Sendable {
            let followerId: String
            let followingId: String
            nonisolated enum CodingKeys: String, CodingKey {
                case followerId = "follower_id"
                case followingId = "following_id"
            }
        }

        guard let idx = users.firstIndex(where: { $0.id == user.id }) else { return }
        let wasFollowing = users[idx].isFollowing
        users[idx].isFollowing = !wasFollowing  // optimistic update

        do {
            if wasFollowing {
                try await client
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: currentId)
                    .eq("following_id", value: user.id)
                    .execute()
            } else {
                try await client
                    .from("follows")
                    .insert(FollowPayload(followerId: currentId, followingId: user.id))
                    .execute()
            }
        } catch {
            users[idx].isFollowing = wasFollowing  // revert on failure
            print("Follow toggle error: \(error)")
        }
    }
}

// MARK: - Bio Edit Sheet

struct ProfileBioEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bio: String = ""
    @State private var isSaving = false
    private let maxChars = 160
    private let client = SupabaseManager.shared.client

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tell the courts who you are.")
                    .font(.system(size: 14))
                    .foregroundStyle(NETRTheme.subtext)

                ZStack(alignment: .topLeading) {
                    if bio.isEmpty {
                        Text("e.g. Hooper since '09. Come find me at Rucker.")
                            .font(.system(size: 14))
                            .foregroundStyle(NETRTheme.muted)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $bio)
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.text)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 100)
                        .onChange(of: bio) { _, val in
                            if val.count > maxChars { bio = String(val.prefix(maxChars)) }
                        }
                }
                .padding(12)
                .background(NETRTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 12))

                HStack {
                    Spacer()
                    Text("\(bio.count)/\(maxChars)")
                        .font(.system(size: 12))
                        .foregroundStyle(bio.count > maxChars - 20 ? NETRTheme.gold : NETRTheme.subtext)
                }

                Spacer()
            }
            .padding(20)
            .background(NETRTheme.background.ignoresSafeArea())
            .navigationTitle("Edit Bio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveBio() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(NETRTheme.neonGreen)
                        } else {
                            Text("Save")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NETRTheme.neonGreen)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .task { await loadCurrentBio() }
        }
    }

    private func loadCurrentBio() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        nonisolated struct BioRow: Decodable, Sendable {
            let bio: String?
        }
        if let row: BioRow = try? await client
            .from("profiles")
            .select("bio")
            .eq("id", value: userId)
            .single()
            .execute()
            .value {
            bio = row.bio ?? ""
        }
    }

    private func saveBio() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        isSaving = true
        nonisolated struct BioUpdate: Encodable, Sendable { let bio: String }
        try? await client
            .from("profiles")
            .update(BioUpdate(bio: bio))
            .eq("id", value: userId)
            .execute()
        isSaving = false
        dismiss()
    }
}
