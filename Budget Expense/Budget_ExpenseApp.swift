//
//  Budget_ExpenseApp.swift
//  Budget Expense
//
//  Created by Christian Gunawan on 23/04/26.
//

import SwiftUI

@main
struct Budget_ExpenseApp: App {
    @State private var authManager = AuthenticationManager()
    @State private var categoryManager = CategoryManager()
    @State private var appleSignInManager = AppleSignInManager()
    @State private var cloudKitManager = CloudKitManager()
    @State private var permissionManager = PermissionManager()
    @State private var ocrDataManager = OCRDataManager()
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showPermissionOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            AuthenticationWrapper()
                .environment(\.authenticationManager, authManager)
                .environment(\.categoryManager, categoryManager)
                .environment(\.appleSignInManager, appleSignInManager)
                .environment(\.cloudKitManager, cloudKitManager)
                .environment(permissionManager)
                .environment(\.ocrDataManager, ocrDataManager)
                .ignoresSafeArea()
                .fullScreenCover(isPresented: $showPermissionOnboarding) {
                    PermissionOnboardingView(isPresented: $showPermissionOnboarding)
                        .environment(permissionManager)
                }
                .onAppear {
                    // Show onboarding on first launch
                    if !hasCompletedOnboarding {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showPermissionOnboarding = true
                        }
                    }
                }
        }
    }
}
