//
//  AuthenticationWrapper.swift
//  Budget Expense
//

import SwiftUI

struct AuthenticationWrapper: View {
    @Environment(\.authenticationManager) private var authManager: AuthenticationManager
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            // Main App Content
            ContentView()
                .blur(radius: authManager.isAppLocked ? 10 : 0)
            
            // Authentication Overlay
            if !authManager.hasPIN {
                // First launch - setup PIN
                PINSetupView {
                    // PIN setup completed
                }
                .transition(.opacity)
            } else if authManager.isAppLocked {
                // App is locked - show PIN entry
                PINEntryView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAppLocked)
        .animation(.easeInOut(duration: 0.3), value: authManager.hasPIN)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }
    
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        switch newPhase {
        case .background, .inactive:
            // App going to background - lock it if PIN is set
            if authManager.hasPIN {
                authManager.lockApp()
            }
        case .active:
            // App becoming active - if locked, user needs to authenticate
            break
        @unknown default:
            break
        }
    }
}

#Preview {
    let authManager = AuthenticationManager()
    AuthenticationWrapper()
        .environment(\.authenticationManager, authManager)
}
