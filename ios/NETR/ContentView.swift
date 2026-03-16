import SwiftUI

struct ContentView: View {
    @Environment(MockDataStore.self) private var store
    @Environment(AppearanceManager.self) private var appearance
    @Environment(SupabaseManager.self) private var supabase
    @State private var selectedTab: Tab = .courts
    @State private var courtsViewModel = CourtsViewModel()
    @State private var showSelfAssessment: Bool = false
    @State private var dismissedAssessmentBanner: Bool = false
    @State private var showSettings: Bool = false

    private var isUnrated: Bool {
        guard let profile = supabase.currentProfile else { return false }
        return profile.netrScore == nil && SelfAssessmentStore.savedScore == nil
    }

    enum Tab: String, CaseIterable {
        case courts = "Courts"
        case rate = "Rate"
        case feed = "Feed"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .courts: return "map"
            case .rate: return "star"
            case .feed: return "messages-square"
            case .profile: return "user"
            }
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
                            .presentationBackground(NETRTheme.background)
                        }
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
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                Button {
                    if selectedTab != tab {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color(hex: "#39FF14").opacity(0.10))
                                    .frame(width: 40, height: 28)
                            }

                            LucideIcon(tab.icon, size: 18)
                                .foregroundStyle(
                                    selectedTab == tab
                                        ? Color(hex: "#39FF14")
                                        : Color(hex: "#6A6A82")
                                )
                        }

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? Color(hex: "#39FF14")
                                    : Color(hex: "#6A6A82")
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
        .background(
            Rectangle()
                .fill(Color(hex: "#040406"))
                .overlay(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }
}
