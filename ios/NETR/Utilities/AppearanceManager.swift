import SwiftUI

@Observable
@MainActor
class AppearanceManager {
    var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }

    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }

    init() {
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
    }
}
