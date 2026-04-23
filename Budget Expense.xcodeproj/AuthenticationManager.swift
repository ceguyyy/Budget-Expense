//
//  AuthenticationManager.swift
//  Budget Expense
//

import SwiftUI
import LocalAuthentication
import Combine

@MainActor
@Observable
class AuthenticationManager {
    var isAuthenticated = false
    var isAppLocked = true
    var hasPIN: Bool {
        UserDefaults.standard.string(forKey: pinKey) != nil
    }
    
    private let pinKey = "budget_expense_pin"
    private let faceIDEnabledKey = "budget_expense_faceid_enabled"
    
    var isFaceIDEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: faceIDEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: faceIDEnabledKey) }
    }
    
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
    
    // MARK: - PIN Management
    
    func setPIN(_ pin: String) {
        UserDefaults.standard.set(pin, forKey: pinKey)
        print("✅ PIN set successfully")
    }
    
    func verifyPIN(_ pin: String) -> Bool {
        guard let savedPIN = UserDefaults.standard.string(forKey: pinKey) else {
            return false
        }
        return pin == savedPIN
    }
    
    func resetPIN(oldPIN: String, newPIN: String) -> Bool {
        guard verifyPIN(oldPIN) else {
            return false
        }
        setPIN(newPIN)
        return true
    }
    
    func authenticate(with pin: String) -> Bool {
        if verifyPIN(pin) {
            isAuthenticated = true
            isAppLocked = false
            return true
        }
        return false
    }
    
    // MARK: - Biometric Authentication
    
    func authenticateWithBiometrics() async -> Bool {
        guard isFaceIDEnabled else {
            return false
        }
        
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            return false
        }
        
        do {
            let reason = "Unlock Budget Expense"
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            
            if success {
                isAuthenticated = true
                isAppLocked = false
            }
            
            return success
        } catch {
            print("❌ Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Lock/Unlock
    
    func lockApp() {
        isAuthenticated = false
        isAppLocked = true
    }
    
    func unlockApp() {
        isAuthenticated = true
        isAppLocked = false
    }
}

// MARK: - Biometric Type

enum BiometricType {
    case none
    case touchID
    case faceID
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "lock.fill"
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        }
    }
}
// MARK: - Environment Key

struct AuthenticationManagerKey: EnvironmentKey {
    static let defaultValue = AuthenticationManager()
}

extension EnvironmentValues {
    var authenticationManager: AuthenticationManager {
        get { self[AuthenticationManagerKey.self] }
        set { self[AuthenticationManagerKey.self] = newValue }
    }
}

