import SwiftUI

struct RootView: View {

    @Environment(SupabaseManager.self) private var supabase
    @Environment(BiometricAuthManager.self) private var biometrics
    @AppStorage("biometricsEnabled") private var biometricsEnabled: Bool = true
    @AppStorage("hasCompletedPhotoPrompt") private var hasCompletedPhotoPrompt: Bool = false
    @AppStorage("photoPromptSkipCount") private var photoPromptSkipCount: Int = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if !supabase.hasBootstrappedAuth {
                LaunchSplashView(probablySignedIn: supabase.lastKnownSignedIn)
                    .preferredColorScheme(.dark)
                    .transition(.opacity)
            } else if !supabase.isSignedIn || !hasCompletedOnboarding {
                OnboardingView()
                    .preferredColorScheme(.dark)
            } else if biometrics.isBiometricsAvailable && biometricsEnabled && !biometrics.isUnlocked {
                LockScreenView()
                    .preferredColorScheme(.dark)
                    .transition(.opacity)
            } else if !hasCompletedPhotoPrompt && supabase.currentUserAvatarUrl == nil {
                ProfilePhotoPromptView {
                    hasCompletedPhotoPrompt = true
                    if supabase.currentUserAvatarUrl == nil {
                        // User skipped — track for reminder badge
                        photoPromptSkipCount = 1
                    }
                }
                .preferredColorScheme(.dark)
                .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: supabase.hasBootstrappedAuth)
        .animation(.easeInOut(duration: 0.3), value: supabase.isSignedIn)
        .animation(.easeInOut(duration: 0.3), value: biometrics.isUnlocked)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedPhotoPrompt)
        .overlay {
            if supabase.isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .tint(NETRTheme.neonGreen)
                        .scaleEffect(1.5)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

/// Neutral launch splash shown while Supabase restores the cached session.
/// Without it, signed-in users briefly see the sign-in screen during the
/// 5–10s the auth client takes to emit `.initialSession`.
struct LaunchSplashView: View {
    let probablySignedIn: Bool

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("NETR")
                    .font(NETRTheme.headingFont(size: .largeTitle))
                    .foregroundStyle(NETRTheme.text)
                    .neonGlow(NETRTheme.neonGreen, radius: 8)
                ProgressView()
                    .tint(NETRTheme.neonGreen)
                    .scaleEffect(1.2)
            }
        }
    }
}
