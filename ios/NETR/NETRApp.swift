import SwiftUI

@main
struct NETRApp: App {
    @State private var supabase = SupabaseManager.shared
    @State private var biometrics = BiometricAuthManager()
    @State private var appearance = AppearanceManager()
    @State private var store = MockDataStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(supabase)
                .environment(biometrics)
                .environment(appearance)
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
