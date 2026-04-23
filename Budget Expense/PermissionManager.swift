//
//  PermissionManager.swift
//  Budget Expense
//

import SwiftUI
import Photos
import LocalAuthentication
import AVFoundation

@MainActor
@Observable
class PermissionManager {
    var photoLibraryStatus: PermissionStatus = .notDetermined
    var cameraStatus: PermissionStatus = .notDetermined
    var faceIDStatus: PermissionStatus = .notDetermined
    
    var allPermissionsGranted: Bool {
        photoLibraryStatus == .authorized &&
        cameraStatus == .authorized &&
        faceIDStatus == .authorized
    }
    
    init() {
        checkAllPermissions()
    }
    
    func checkAllPermissions() {
        checkPhotoLibrary()
        checkCamera()
        checkFaceID()
    }
    
    // MARK: - Photo Library
    
    func checkPhotoLibrary() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photoLibraryStatus = PermissionStatus(from: status)
    }
    
    func requestPhotoLibrary() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoLibraryStatus = PermissionStatus(from: status)
    }
    
    // MARK: - Camera
    
    func checkCamera() {
        #if targetEnvironment(simulator)
        // Simulator doesn't have camera
        cameraStatus = .notAvailable
        #else
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraStatus = PermissionStatus(from: status)
        #endif
    }
    
    func requestCamera() async {
        #if targetEnvironment(simulator)
        cameraStatus = .notAvailable
        #else
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraStatus = granted ? .authorized : .denied
        #endif
    }
    
    // MARK: - Face ID / Touch ID
    
    func checkFaceID() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // Biometrics available
            faceIDStatus = .notDetermined
        } else {
            // No biometrics available
            faceIDStatus = .notAvailable
        }
    }
    
    func requestFaceID() async {
        let context = LAContext()
        context.localizedCancelTitle = "Skip"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to secure your financial data"
            )
            faceIDStatus = success ? .authorized : .denied
        } catch {
            print("❌ Biometric authentication error: \(error)")
            faceIDStatus = .denied
        }
    }
    
    // MARK: - Request All Permissions
    
    func requestAllPermissions() async {
        print("🔐 Requesting all permissions...")
        
        // Request in sequence
        await requestPhotoLibrary()
        await requestCamera()
        await requestFaceID()
        
        print("✅ All permissions requested")
        checkAllPermissions()
    }
}

// MARK: - Permission Status Enum

enum PermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
    case notAvailable
    
    var icon: String {
        switch self {
        case .notDetermined: return "questionmark.circle"
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .restricted: return "exclamationmark.triangle.fill"
        case .notAvailable: return "slash.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .notDetermined: return .gray
        case .authorized: return .neonGreen
        case .denied: return .neonRed
        case .restricted: return .orange
        case .notAvailable: return .gray
        }
    }
    
    var title: String {
        switch self {
        case .notDetermined: return "Not Requested"
        case .authorized: return "Granted"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notAvailable: return "Not Available"
        }
    }
    
    // MARK: - Conversion from System Status
    
    init(from photoStatus: PHAuthorizationStatus) {
        switch photoStatus {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized, .limited: self = .authorized
        @unknown default: self = .notDetermined
        }
    }
    
    init(from avStatus: AVAuthorizationStatus) {
        switch avStatus {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .authorized
        @unknown default: self = .notDetermined
        }
    }
    
//    init(from contactStatus: CNAuthorizationStatus) {
//        switch contactStatus {
//        case .notDetermined: self = .notDetermined
//        case .restricted: self = .restricted
//        case .denied: self = .denied
//        case .authorized: self = .authorized
//        @unknown default: self = .notDetermined
//        }
//    }
}
