import SwiftUI

struct ContentView: View {
    @Environment(MockDataStore.self) private var store
    @Environment(AppearanceManager.self) private var appearance
    @State private var selectedTab: Tab = .courts
    @State private var courtsViewModel = CourtsViewModel()

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
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .courts:
                    CourtsView(viewModel: courtsViewModel)
                case .rate:
                    RateView()
                case .feed:
                    FeedView()
                case .profile:
                    ProfileView(courtsViewModel: courtsViewModel)
                case .settings:
                    SettingsView(store: store, appearance: appearance, courtsViewModel: courtsViewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            customTabBar
        }
        .ignoresSafeArea(.keyboard)
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
                        LucideIcon(tab.icon, size: 18)
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
