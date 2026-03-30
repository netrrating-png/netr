import SwiftUI
import Supabase
import Auth
import GoogleSignIn

@main
struct NETRApp: App {
    @State private var supabase = SupabaseManager.shared
    @State private var biometrics = BiometricAuthManager()
    @State private var appearance = AppearanceManager()
    @State private var store = MockDataStore()
    @UIApplicationDelegateAdaptor(NETRAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(supabase)
                .environment(biometrics)
                .environment(appearance)
                .environment(store)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Let Google Sign-In SDK handle its own callback URLs first.
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    // Fall through to Supabase for any other deep links (e.g. magic links).
                    Task {
                        do {
                            try await SupabaseManager.shared.client.auth.session(from: url)
                            print("[NETR Auth] OAuth callback handled for URL: \(url)")
                        } catch {
                            print("[NETR Auth] OAuth callback error: \(error)")
                        }
                    }
                }
                .onAppear {
                    // Request push permission after first login
                    if supabase.isSignedIn {
                        PushNotificationManager.shared.refreshTokenIfNeeded()
                        NETRLocationManager.shared.requestWhenInUsePermission()
                        NETRLocationManager.shared.startPeriodicUpdates()
                    }
                }
                .onChange(of: supabase.isSignedIn) { _, signedIn in
                    if signedIn {
                        PushNotificationManager.shared.requestPermission()
                        NETRLocationManager.shared.requestWhenInUsePermission()
                        NETRLocationManager.shared.startPeriodicUpdates()
                    } else {
                        NETRLocationManager.shared.stopUpdates()
                    }
                }
        }
    }
}

// MARK: - App Delegate for APNs

class NETRAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = PushNotificationManager.shared.handleNotificationResponse(response)
        completionHandler()
    }
}
