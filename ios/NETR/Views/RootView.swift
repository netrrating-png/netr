import SwiftUI

struct RootView: View {

    @Environment(SupabaseManager.self) private var supabase
    @Environment(BiometricAuthManager.self) private var biometrics
    @AppStorage("biometricsEnabled") private var biometricsEnabled: Bool = true

    var body: some View {
        Group {
            if !supabase.isSignedIn {
                OnboardingView()
                    .preferredColorScheme(.dark)
            } else if biometrics.isBiometricsAvailable && biometricsEnabled && !biometrics.isUnlocked {
                LockScreenView()
                    .preferredColorScheme(.dark)
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: supabase.isSignedIn)
        .animation(.easeInOut(duration: 0.3), value: biometrics.isUnlocked)
        .overlay {
            if supabase.isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .tint(NETRTheme.neonGreen)
                        .scaleEffect(1.5)
                }
            }
        }
    }
}
