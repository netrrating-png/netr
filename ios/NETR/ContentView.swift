import SwiftUI

struct ContentView: View {
    @Environment(MockDataStore.self) private var store
    @Environment(AppearanceManager.self) private var appearance
    @Environment(SupabaseManager.self) private var supabase
    @State private var selectedTab: Tab = .courts
    @State private var courtsViewModel = CourtsViewModel()
    @State private var showSelfAssessment: Bool = false
    @State private var dismissedAssessmentBanner: Bool = false

    private var isUnrated: Bool {
        guard let profile = supabase.currentProfile else { return false }
        return profile.netrScore == nil && SelfAssessmentStore.savedScore == nil
    }

    enum Tab: String, CaseIterable {
        case courts = "Courts"
        case rate = "Rate"
        case feed = "Feed"
        case profile = "Profile"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .courts: return "map"
            case .rate: return "star"
            case .feed: return "messages-square"
            case .profile: return "user"
            case .settings: return "settings"
            }
        }

        var index: Int {
            Self.allCases.firstIndex(of: self) ?? 0
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if isUnrated && !dismissedAssessmentBanner {
                    assessmentBanner
                }

                Group {
                    switch selectedTab {
                    case .courts:
                        CourtsView(viewModel: courtsViewModel)
                    case .rate:
                        RateView()
                    case .feed:
                        FeedView()
                    case .profile:
                        ProfileView(showSelfAssessment: $showSelfAssessment)
                    case .settings:
                        SettingsView(store: store, appearance: appearance)
                    }
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
    }

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
        let tabCount = Tab.allCases.count

        GeometryReader { geo in
            let barWidth = geo.size.width * 0.85
            let tabWidth = barWidth / CGFloat(tabCount)

            ZStack {
                // Neon glow behind the pill
                Capsule()
                    .fill(NETRTheme.neonGreen.opacity(0.08))
                    .blur(radius: 20)
                    .frame(width: barWidth, height: 70)

                // Glass pill container
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.rawValue) { tab in
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                selectedTab = tab
                            }
                        } label: {
                            ZStack {
                                LucideIcon(tab.icon, size: 18)
                                    .foregroundStyle(
                                        selectedTab == tab
                                            ? NETRTheme.neonGreen
                                            : Color(red: 0.42, green: 0.42, blue: 0.51)
                                    )
                                    .shadow(
                                        color: selectedTab == tab ? NETRTheme.neonGreen.opacity(0.6) : .clear,
                                        radius: 8
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: barWidth)
                .background(
                    ZStack {
                        // Active indicator capsule — slides behind active tab
                        Capsule()
                            .fill(NETRTheme.neonGreen.opacity(0.12))
                            .frame(width: 44, height: 36)
                            .shadow(color: NETRTheme.neonGreen.opacity(0.25), radius: 10)
                            .offset(x: tabWidth * CGFloat(selectedTab.index) - barWidth / 2 + tabWidth / 2)
                            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: selectedTab)
                    }
                )
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(NETRTheme.neonGreen.opacity(0.15), lineWidth: 1)
                )
            }
            .frame(width: geo.size.width)
        }
        .frame(height: 56)
        .padding(.bottom, 16)
    }
}
