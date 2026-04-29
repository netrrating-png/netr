import SwiftUI
import Supabase
import Auth
import PostgREST

struct ContentView: View {
    @Environment(MockDataStore.self) private var store
    @Environment(AppearanceManager.self) private var appearance
    @Environment(SupabaseManager.self) private var supabase
    @State private var selectedTab: Tab = .courts
    @State private var feedScrollToTop: Bool = false
    @State private var courtsViewModel = CourtsViewModel()
    @State private var dmViewModel = DMViewModel()
    @State private var showSelfAssessment: Bool = false
    @State private var dismissedAssessmentBanner: Bool = false
    @State private var showSettings: Bool = false
    @State private var showPhotoBanner: Bool = false
    @AppStorage("photoPromptSkipCount") private var photoPromptSkipCount: Int = 0
    @Namespace private var tabBarNamespace

    // Active game banner
    @State private var hostActiveGame: SupabaseGame? = nil
    @State private var activeGameLobbyVM = GameViewModel()
    @State private var showActiveGameSheet: Bool = false

    // DM notification banner tap -> open conversation
    @State private var dmBannerTargetUserId: String?
    @State private var dmBannerShowChat: Bool = false

    private var isUnrated: Bool {
        guard let profile = supabase.currentProfile else { return false }
        return profile.netrScore == nil && SelfAssessmentStore.savedScore == nil
    }

    enum Tab: String, CaseIterable {
        case courts = "Courts"
        case rate = "Rate"
        case feed = "Feed"
        case dailyGame = "Daily Game"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .feed: return "house"
            case .courts: return "target"
            case .rate: return "star"
            case .dailyGame: return "gamepad-2"
            case .profile: return "user"
            }
        }

    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                if isUnrated && !dismissedAssessmentBanner {
                    assessmentBanner
                }

                if let game = hostActiveGame, !showActiveGameSheet {
                    activeGameBanner(game: game)
                }

                ZStack {
                    tabContent(for: .feed)
                        .zIndex(selectedTab == .feed ? 1 : 0)

                    tabContent(for: .courts)
                        .zIndex(selectedTab == .courts ? 1 : 0)

                    tabContent(for: .rate)
                        .zIndex(selectedTab == .rate ? 1 : 0)

                    tabContent(for: .dailyGame)
                        .zIndex(selectedTab == .dailyGame ? 1 : 0)

                    tabContent(for: .profile)
                        .zIndex(selectedTab == .profile ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 50, coordinateSpace: .local)
                        .onEnded { value in
                            let h = value.translation.width
                            let v = value.translation.height
                            // Only fire when clearly horizontal (2.5× more horizontal than vertical)
                            guard abs(h) > abs(v) * 2.5, abs(h) > 60 else { return }
                            let tabs = Tab.allCases
                            guard let idx = tabs.firstIndex(of: selectedTab) else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if h < 0, idx < tabs.count - 1 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedTab = tabs[idx + 1]
                                }
                            } else if h > 0, idx > 0 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedTab = tabs[idx - 1]
                                }
                            }
                        }
                )
            }

            customTabBar
        }
        .modifier(DMNotificationOverlay(
            manager: dmViewModel.notificationManager,
            onOpenConversation: { userId in
                dmBannerTargetUserId = userId
                // DM tab no longer exists - open chat directly as full-screen cover
                dmBannerShowChat = true
            }
        ))
        .fullScreenCover(isPresented: $dmBannerShowChat, onDismiss: {
            dmBannerTargetUserId = nil
            Task { await dmViewModel.loadConversations() }
        }) {
            if let targetId = dmBannerTargetUserId {
                let profile = dmViewModel.conversations.first(where: { $0.otherUserId == targetId })?.otherUser
                ChatThreadView(
                    otherUserId: targetId,
                    otherUser: profile,
                    dmViewModel: dmViewModel
                )
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showSelfAssessment) {
            SelfAssessmentSheetView(onComplete: {
                dismissedAssessmentBanner = true
            })
        }
        .onChange(of: selectedTab) { _, _ in
            // DM unread count stays fresh via the header button's own .task
        }
        .onChange(of: supabase.currentProfile?.fullName) { _, _ in
            if let profile = supabase.currentProfile {
                store.syncFromProfile(profile)
            }
        }
        .onChange(of: supabase.currentProfile?.avatarUrl) { _, _ in
            if let profile = supabase.currentProfile {
                store.syncFromProfile(profile)
            }
        }
        .onChange(of: supabase.currentUserAvatarUrl) { _, newUrl in
            // When avatar URL changes via upload, sync the store immediately
            if let newUrl, var profile = supabase.currentProfile {
                profile.avatarUrl = newUrl
                store.syncFromProfile(profile)
            }
        }
        .onAppear {
            if let profile = supabase.currentProfile {
                store.syncFromProfile(profile)
            }
        }
        .task {
            await checkForHostActiveGame()
            // Increment photo skip session counter (caps at 4 to stop showing badge after 3)
            if photoPromptSkipCount > 0 && photoPromptSkipCount <= 3 && supabase.currentUserAvatarUrl == nil {
                photoPromptSkipCount += 1
            }
        }
        .sheet(isPresented: $showActiveGameSheet, onDismiss: {
            Task { await checkForHostActiveGame() }
        }) {
            GameLobbyView(viewModel: activeGameLobbyVM, onDismiss: {
                showActiveGameSheet = false
                hostActiveGame = nil
                Task { await checkForHostActiveGame() }
            })
        }
    }

    // MARK: - Tab Content with Transition

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        let isActive = selectedTab == tab

        Group {
            switch tab {
            case .feed:
                FeedView(scrollToTopTrigger: $feedScrollToTop, dmViewModel: dmViewModel)
            case .courts:
                CourtsView(viewModel: courtsViewModel, dmViewModel: dmViewModel)
            case .rate:
                RateView(dmViewModel: dmViewModel)
            case .dailyGame:
                DailyGameHubView(dmViewModel: dmViewModel)
            case .profile:
                ZStack(alignment: .topTrailing) {
                    ProfileView(courtsViewModel: courtsViewModel, showSelfAssessment: $showSelfAssessment, showPhotoBanner: $showPhotoBanner)
                    HStack(spacing: 10) {
                        DMHeaderButton(dmViewModel: dmViewModel)
                        Button {
                            showSettings = true
                        } label: {
                            LucideIcon("settings", size: 18)
                                .foregroundStyle(NETRTheme.text)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
                        }
                    }
                    .padding(.top, 52)
                    .padding(.trailing, 16)
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView(store: store, appearance: appearance, courtsViewModel: courtsViewModel)
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.black)
                }
            }
        }
        .opacity(isActive ? 1.0 : 0.0)
        .scaleEffect(isActive ? 1.0 : 0.96)
        .blur(radius: isActive ? 0 : 2)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .allowsHitTesting(isActive)
    }

    // MARK: - Active Game Banner

    private func checkForHostActiveGame() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        let games: [SupabaseGame] = (try? await SupabaseManager.shared.client
            .from("games")
            .select()
            .eq("host_id", value: userId)
            .in("status", values: ["active", "waiting"])
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value) ?? []
        hostActiveGame = games.first
    }

    @ViewBuilder
    private func activeGameBanner(game: SupabaseGame) -> some View {
        let isActive = game.status == "active"
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isActive ? NETRTheme.neonGreen : NETRTheme.gold)
                    .frame(width: 8, height: 8)
                if isActive {
                    Circle()
                        .fill(NETRTheme.neonGreen.opacity(0.3))
                        .frame(width: 14, height: 14)
                }
            }

            Text(isActive ? "GAME IN PROGRESS" : "LOBBY OPEN")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isActive ? NETRTheme.neonGreen : NETRTheme.gold)
                .tracking(0.8)

            if let fmt = GameFormat(rawValue: game.format) {
                Text("·")
                    .foregroundStyle(NETRTheme.muted)
                Text(fmt.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)
            }

            Spacer(minLength: 4)

            Text(isActive ? "Manage" : "Open")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isActive ? NETRTheme.neonGreen : NETRTheme.gold)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isActive ? NETRTheme.neonGreen : NETRTheme.gold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background((isActive ? NETRTheme.neonGreen : NETRTheme.gold).opacity(0.07))
        .overlay(
            Rectangle()
                .fill((isActive ? NETRTheme.neonGreen : NETRTheme.gold).opacity(0.25))
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                activeGameLobbyVM.game = game
                await activeGameLobbyVM.loadPlayers(gameId: game.id)
                await activeGameLobbyVM.subscribeToLobby(gameId: game.id)
                showActiveGameSheet = true
            }
        }
    }

    // MARK: - Assessment Banner

    private var assessmentBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(NETRTheme.neonGreen)

            Text("Complete your self-assessment to get your NETR score")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NETRTheme.text)
                .lineLimit(1)

            Spacer(minLength: 4)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NETRTheme.neonGreen)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    dismissedAssessmentBanner = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .frame(width: 22, height: 22)
                    .background(NETRTheme.muted, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(NETRTheme.neonGreen.opacity(0.08))
        .overlay(
            Rectangle()
                .fill(NETRTheme.neonGreen.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showSelfAssessment = true
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                let isSelected = selectedTab == tab
                Button {
                    if !isSelected {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    } else if tab == .feed {
                        feedScrollToTop.toggle()
                    } else if tab == .profile && photoPromptSkipCount > 0 && photoPromptSkipCount <= 3 && supabase.currentUserAvatarUrl == nil {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPhotoBanner = true
                        }
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            if tab == .profile {
                                // Profile tab: avatar photo (Instagram-style)
                                ZStack {
                                    AvatarView.currentUser(size: 24)
                                        .opacity(isSelected ? 1.0 : 0.5)

                                    // Neon ring when selected
                                    if isSelected {
                                        Circle()
                                            .stroke(NETRTheme.neonGreen, lineWidth: 1.5)
                                            .frame(width: 30, height: 30)
                                    }

                                    // Photo reminder badge
                                    if photoPromptSkipCount > 0 && photoPromptSkipCount <= 3 && supabase.currentUserAvatarUrl == nil {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 12, y: -10)
                                    }
                                }
                            } else {
                                // Regular icon tabs
                                LucideIcon(tab.icon, size: 22)
                                    .foregroundStyle(
                                        isSelected
                                            ? NETRTheme.neonGreen
                                            : Color.white.opacity(0.35)
                                    )
                                    .scaleEffect(isSelected ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
                            }
                        }
                        .frame(height: 28)

                        // Active indicator bar
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(NETRTheme.neonGreen)
                                    .frame(width: 20, height: 3)
                                    .shadow(color: NETRTheme.neonGreen.opacity(0.6), radius: 6)
                                    .shadow(color: NETRTheme.neonGreen.opacity(0.3), radius: 12)
                                    .matchedGeometryEffect(id: "activeTabIndicator", in: tabBarNamespace)
                            }
                        }
                        .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                }
            }
        }
        .padding(.horizontal, 8)
        .background(
            ZStack {
                // Dark frosted glass
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                // Darker tint for depth
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.45))

                // Subtle top highlight edge
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.4), radius: 16, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}
