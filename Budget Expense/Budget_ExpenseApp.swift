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
    @State private var calendarManager = CalendarManager()
    @State private var permissionManager = PermissionManager()
    @State private var ocrDataManager = OCRDataManager()

    @State private var showSplashScreen = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showPermissionOnboarding = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplashScreen {
                    splashView
                        .transition(.opacity)
                } else {
                    AuthenticationWrapper()
                        .environment(\.authenticationManager, authManager)
                        .environment(\.categoryManager, categoryManager)
                        .environment(\.appleSignInManager, appleSignInManager)
                        .environment(\.cloudKitManager, cloudKitManager)
                        .environment(\.calendarManager, calendarManager)
                        .environment(permissionManager)
                        .environment(\.ocrDataManager, ocrDataManager)
                }
            }
            .ignoresSafeArea()
            .fullScreenCover(isPresented: $showPermissionOnboarding) {
                PermissionOnboardingView(isPresented: $showPermissionOnboarding)
                    .environment(permissionManager)
            }
            .onAppear {
                // Splash screen timer
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplashScreen = false
                    }

                    // Show onboarding on first launch after splash
                    if !hasCompletedOnboarding {
                        showPermissionOnboarding = true
                    }
                }
            }
        }
    }

    private var splashView: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("image_logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                Text("DuitGwWoi")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .kerning(1.5)
            }
        }
    }
}
