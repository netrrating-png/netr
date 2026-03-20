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
            Color.black.ignoresSafeArea()

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

    private let limeGreen = Color(hex: "#C8FF00")

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                let isSelected = selectedTab == tab
                Button {
                    if !isSelected {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(limeGreen.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                    .blur(radius: 8)
                            }

                            LucideIcon(tab.icon, size: isSelected ? 20 : 18)
                                .foregroundStyle(
                                    isSelected
                                        ? limeGreen
                                        : Color.white.opacity(0.45)
                                )
                        }
                        .frame(height: 28)

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                isSelected
                                    ? limeGreen
                                    : Color.white.opacity(0.45)
                            )
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
                // Frosted glass base
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                // Dark tint over the blur
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.black.opacity(0.55))

                // Inner glow on top edge
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)

                // Subtle top-edge highlight
                VStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.07), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(height: 24)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}
