import SwiftUI

struct ContentView: View {
    @Environment(MockDataStore.self) private var store
    @Environment(AppearanceManager.self) private var appearance
    @Environment(SupabaseManager.self) private var supabase
    @State private var selectedTab: Tab = .feed
    @State private var courtsViewModel = CourtsViewModel()
    @State private var notificationViewModel = NotificationViewModel()
    @State private var showSelfAssessment: Bool = false
    @State private var dismissedAssessmentBanner: Bool = false
    @State private var showSettings: Bool = false
    @Namespace private var tabBarNamespace

    private var isUnrated: Bool {
        guard let profile = supabase.currentProfile else { return false }
        return profile.netrScore == nil && SelfAssessmentStore.savedScore == nil
    }

    enum Tab: String, CaseIterable {
        case courts = "Courts"
        case rate = "Rate"
        case feed = "Feed"
        case profile = "Profile"
        case notifications = "Alerts"

        var icon: String {
            switch self {
            case .feed: return "messages-square"
            case .courts: return "map"
            case .rate: return "star"
            case .notifications: return "bell"
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

                ZStack {
                    tabContent(for: .feed)
                        .zIndex(selectedTab == .feed ? 1 : 0)

                    tabContent(for: .courts)
                        .zIndex(selectedTab == .courts ? 1 : 0)

                    tabContent(for: .rate)
                        .zIndex(selectedTab == .rate ? 1 : 0)

                    tabContent(for: .notifications)
                        .zIndex(selectedTab == .notifications ? 1 : 0)

                    tabContent(for: .profile)
                        .zIndex(selectedTab == .profile ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showSelfAssessment) {
            SelfAssessmentSheetView(onComplete: {
                dismissedAssessmentBanner = true
            })
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
        .onAppear {
            if let profile = supabase.currentProfile {
                store.syncFromProfile(profile)
            }
        }
        .task {
            await notificationViewModel.fetchNotifications()
            await notificationViewModel.subscribeToNotifications()
        }
    }

    // MARK: - Tab Content with Transition

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        let isActive = selectedTab == tab

        Group {
            switch tab {
            case .feed:
                FeedView()
            case .courts:
                CourtsView(viewModel: courtsViewModel)
            case .rate:
                RateView()
            case .notifications:
                NotificationsView()
            case .profile:
                ZStack(alignment: .topTrailing) {
                    ProfileView(courtsViewModel: courtsViewModel, showSelfAssessment: $showSelfAssessment)
                    Button {
                        showSettings = true
                    } label: {
                        LucideIcon("settings", size: 18)
                            .foregroundStyle(NETRTheme.text)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            // Active pill background with matchedGeometryEffect
                            if isSelected {
                                ZStack {
                                    // Pure black base
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.black)

                                    // Ultra thin material overlay
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.ultraThinMaterial)
                                        .environment(\.colorScheme, .dark)

                                    // White border at 8% opacity
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                }
                                .frame(width: 48, height: 36)
                                .matchedGeometryEffect(id: "activeTabPill", in: tabBarNamespace)

                                // Lime green soft glow underneath
                                Circle()
                                    .fill(NETRTheme.neonGreen.opacity(0.30))
                                    .frame(width: 40, height: 40)
                                    .blur(radius: 20)
                                    .offset(y: 4)
                            }

                            // Icon with optional badge
                            ZStack(alignment: .topTrailing) {
                                LucideIcon(tab.icon, size: 18)
                                    .foregroundStyle(
                                        isSelected
                                            ? NETRTheme.neonGreen
                                            : Color.white.opacity(0.40)
                                    )
                                    .scaleEffect(isSelected ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                                // Unread badge for notifications tab
                                if tab == .notifications && notificationViewModel.unreadCount > 0 {
                                    Text("\(min(notificationViewModel.unreadCount, 99))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.black)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(NETRTheme.neonGreen, in: Capsule())
                                        .offset(x: 10, y: -8)
                                }
                            }
                        }
                        .frame(height: 36)

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                isSelected
                                    ? NETRTheme.neonGreen
                                    : Color.white.opacity(0.40)
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(.horizontal, 12)
        .background(
            ZStack {
                // Pure black base
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.black)

                // Ultra thin material dark blur
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                // Dark tint over blur
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.black.opacity(0.55))
            }
        )
        .shadow(color: Color.black.opacity(0.50), radius: 16, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }
}
