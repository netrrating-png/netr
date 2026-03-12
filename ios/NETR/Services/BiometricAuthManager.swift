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
        // Check biometryType first (does not trigger TCC), then validate policy
        switch context.biometryType {
        case .faceID:
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                biometricType = .none
                return
            }
            biometricType = .faceID
        case .touchID:
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                biometricType = .none
                return
            }
            biometricType = .touchID
        default:
            biometricType = .none
        }
    }

    var isBiometricsAvailable: Bool {
        let context = LAContext()
        // biometryType is safe to read without TCC; canEvaluatePolicy may crash
        // if NSFaceIDUsageDescription is missing, so check type first
        guard context.biometryType != .none else { return false }
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func authenticate(reason: String = "Unlock NETR") async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics not available or not enrolled — skip and unlock
            if let err = error {
                switch err.code {
                case LAError.biometryNotEnrolled.rawValue:
                    authError = .notEnrolled
                case LAError.biometryNotAvailable.rawValue:
                    authError = .notAvailable
                default:
                    authError = .notAvailable
                }
            }
            isUnlocked = true
            return true
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
                isUnlocked = false
                return false
            case .biometryLockout:
                authError = .lockout
                // Fall through to passcode
                return await authenticateWithPasscode(reason: reason)
            case .biometryNotAvailable, .biometryNotEnrolled:
                // Hardware/enrollment issue at eval time — skip biometrics
                isUnlocked = true
                return true
            default:
                authError = .failed
                isUnlocked = false
                return false
            }
        } catch {
            // Unknown error — don't block the user
            authError = .failed
            isUnlocked = true
            return true
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
            // Passcode also failed — don't block the user
            isUnlocked = true
            return true
        }
    }

    func lock() {
        isUnlocked = false
    }
}
