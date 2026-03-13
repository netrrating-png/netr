import Foundation

enum Config {
    static let SUPABASE_URL: String = {
        if let value = ProcessInfo.processInfo.environment["SUPABASE_URL"], !value.isEmpty {
            return value
        }
        if let value = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !value.isEmpty {
            return value
        }
        return ""
    }()

    static let SUPABASE_ANON_KEY: String = {
        if let value = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !value.isEmpty {
            return value
        }
        if let value = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !value.isEmpty {
            return value
        }
        return ""
    }()
}
