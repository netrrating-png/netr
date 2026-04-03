import SwiftUI
import CoreLocation

struct NotificationPreferencesView: View {
    @State private var viewModel = NotificationViewModel()
    @State private var prefs: NotificationPreferences?
    @State private var isLoading: Bool = true
    @State private var locationManager = CLLocationManager()
    @State private var locationDenied: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let limeGreen = NETRTheme.neonGreen
    private let radiusOptions = [1, 2, 5, 10, 25]

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(limeGreen)
            } else if let prefs = Binding($prefs) {
                preferencesContent(prefs: prefs)
            }
        }
        .navigationTitle("Notification Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(NETRTheme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            let loaded = await viewModel.loadPreferences()
            prefs = loaded
            isLoading = false
            checkLocationPermission()
        }
    }

    // MARK: - Content

    private func preferencesContent(prefs: Binding<NotificationPreferences>) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                masterToggle(prefs: prefs)

                if prefs.pushEnabled.wrappedValue {
                    socialSection(prefs: prefs)
                    gameRatingSection(prefs: prefs)
                    courtsNearbySection(prefs: prefs)
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Master Toggle

    private func masterToggle(prefs: Binding<NotificationPreferences>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                LucideIcon("bell")
                    .foregroundStyle(limeGreen)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Push Notifications")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                    Text(prefs.pushEnabled.wrappedValue ? "All notifications enabled" : "All notifications disabled")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }

                Spacer()

                Toggle("", isOn: prefs.pushEnabled)
                    .labelsHidden()
                    .tint(limeGreen)
                    .onChange(of: prefs.pushEnabled.wrappedValue) { _, _ in
                        savePrefs()
                    }
            }
            .padding(14)
        }
        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Social Section

    private func socialSection(prefs: Binding<NotificationPreferences>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SOCIAL")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(1)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                prefToggle(icon: "user-plus", title: "New followers", binding: prefs.follows)
                divider
                prefToggle(icon: "heart", title: "Likes on your posts", binding: prefs.likes)
                divider
                prefToggle(icon: "message-circle", title: "Comments on your posts", binding: prefs.comments)
                divider
                prefToggle(icon: "repeat", title: "Reposts of your posts", binding: prefs.reposts)
                divider
                prefToggle(icon: "at-sign", title: "Mentions in posts", binding: prefs.mentions)
                divider
                prefToggle(icon: "messages-square", title: "Direct messages", binding: prefs.directMessages)
            }
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Game & Rating Section

    private func gameRatingSection(prefs: Binding<NotificationPreferences>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GAME & RATING ACTIVITY")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(1)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                prefToggle(icon: "star", title: "Someone rated your game", binding: prefs.ratingReceived)
                divider
                prefToggle(icon: "trending-up", title: "Your NETR score updates", binding: prefs.scoreUpdated)
                divider
                prefToggle(icon: "trophy", title: "Rating milestones", binding: prefs.ratingMilestones)
                divider
                prefToggle(icon: "user-plus", title: "Game invites", binding: prefs.gameInvites)
                divider
                prefToggle(icon: "clock", title: "Game reminders", binding: prefs.gameReminders)
            }
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Courts & Nearby Section

    private func courtsNearbySection(prefs: Binding<NotificationPreferences>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COURTS & NEARBY GAMES")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(1)
                .foregroundStyle(NETRTheme.subtext)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                prefToggle(icon: "home", title: "Games starting at my home court", binding: prefs.gameAtHomeCourt)
                divider
                prefToggle(icon: "heart", title: "Games starting at my favorite courts", binding: prefs.gameAtFavoriteCourt)
                divider
                prefToggle(icon: "map-pin", title: "Games starting nearby", binding: prefs.gameNearby)

                // Radius selector
                if prefs.gameNearby.wrappedValue {
                    divider

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nearby radius")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(NETRTheme.text)

                        HStack(spacing: 0) {
                            ForEach(radiusOptions, id: \.self) { miles in
                                let isSelected = prefs.nearbyRadiusMiles.wrappedValue == miles
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        prefs.nearbyRadiusMiles.wrappedValue = miles
                                    }
                                    savePrefs()
                                } label: {
                                    Text("\(miles) mi")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isSelected ? Color.black : NETRTheme.subtext)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            isSelected
                                                ? limeGreen
                                                : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 8)
                                        )
                                }
                            }
                        }
                        .background(NETRTheme.muted, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 2)

                        if locationDenied {
                            HStack(spacing: 8) {
                                Image(systemName: "location.slash.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(NETRTheme.gold)

                                Text("Enable location to get nearby game alerts")
                                    .font(.system(size: 12))
                                    .foregroundStyle(NETRTheme.gold)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(NETRTheme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(14)
                }

                divider
                prefToggle(icon: "play", title: "Games starting soon", binding: prefs.gameStarting)
            }
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Reusable Toggle Row

    private func prefToggle(icon: String, title: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            LucideIcon(icon, size: 16)
                .foregroundStyle(NETRTheme.subtext)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(NETRTheme.text)

            Spacer()

            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(limeGreen)
                .onChange(of: binding.wrappedValue) { _, _ in
                    savePrefs()
                }
        }
        .padding(14)
    }

    private var divider: some View {
        Divider().background(NETRTheme.border).padding(.leading, 50)
    }

    // MARK: - Helpers

    private func savePrefs() {
        guard let prefs else { return }
        Task { await viewModel.savePreferences(prefs) }
    }

    private func checkLocationPermission() {
        let status = locationManager.authorizationStatus
        locationDenied = (status == .denied || status == .restricted)
    }
}
