import LocalAuthentication
import SwiftUI

@Observable
class BiometricAuthManager {

    var isUnlocked: Bool = false
    var biometricType: BiometricType = .none
    var authError: BiometricError?

    nonisolated enum BiometricType: Sendable {
        case faceID
        case touchID
        case none

        var displayName: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .none: return "Passcode"
            }
        }

        var iconName: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .none: return "lock.fill"
            }
        }
    }

    nonisolated enum BiometricError: LocalizedError, Sendable {
        case notAvailable
        case notEnrolled
        case failed
        case cancelled
        case lockout

        var errorDescription: String? {
            switch self {
            case .notAvailable: return "Biometrics not available on this device"
            case .notEnrolled: return "No biometrics enrolled. Set up Face ID in Settings."
            case .failed: return "Authentication failed. Try again."
            case .cancelled: return nil
            case .lockout: return "Too many attempts. Use your passcode."
            }
        }
    }

    init() {
        detectBiometricType()
    }

    func detectBiometricType() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }
        switch context.biometryType {
        case .faceID: biometricType = .faceID
        case .touchID: biometricType = .touchID
        default: biometricType = .none
        }
    }

    var isBiometricsAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func authenticate(reason: String = "Unlock NETR") async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let err = error {
                switch err.code {
                case LAError.biometryNotEnrolled.rawValue:
                    authError = .notEnrolled
                default:
                    authError = .notAvailable
                }
            }
            isUnlocked = false
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            isUnlocked = success
            if success { authError = nil }
            return success
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                authError = .cancelled
            case .biometryLockout:
                authError = .lockout
            default:
                authError = .failed
            }
            isUnlocked = false
            return false
        } catch {
            authError = .failed
            isUnlocked = false
            return false
        }
    }

    func authenticateWithPasscode(reason: String = "Unlock NETR") async -> Bool {
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            isUnlocked = success
            return success
        } catch {
            isUnlocked = false
            return false
        }
    }

    func lock() {
        isUnlocked = false
    }
}
