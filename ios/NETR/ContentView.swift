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
        supabase.currentProfile?.netrScore == nil && SelfAssessmentStore.savedScore == nil
    }

    enum Tab: String, CaseIterable {
        case courts = "Courts"
        case rate = "Rate"
        case feed = "Feed"
        case profile = "Profile"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .courts: return "map.fill"
            case .rate: return "star.fill"
            case .feed: return "bubble.left.and.text.bubble.right.fill"
            case .profile: return "person.fill"
            case .settings: return "gearshape.fill"
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
                        ProfileView(courtsViewModel: courtsViewModel, showSelfAssessment: $showSelfAssessment)
                    case .settings:
                        SettingsView(store: store, appearance: appearance, courtsViewModel: courtsViewModel)
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
    }

    private var assessmentBanner: some View {
        Button {
            showSelfAssessment = true
        } label: {
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
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(selectedTab == tab ? NETRTheme.neonGreen : NETRTheme.subtext)

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(selectedTab == tab ? NETRTheme.neonGreen : NETRTheme.subtext)

                        Circle()
                            .fill(selectedTab == tab ? NETRTheme.neonGreen : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                }
            }
        }
        .padding(.bottom, 16)
        .background(
            NETRTheme.surface
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
