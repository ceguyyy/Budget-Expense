//
//  PermissionOnboardingView.swift
//  Budget Expense
//

import SwiftUI

struct PermissionOnboardingView: View {
    @Environment(PermissionManager.self) private var permissionManager
    @Binding var isPresented: Bool
    
    @State private var currentPage = 0
    @State private var isRequesting = false
    
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button("Skip") {
                        isPresented = false
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.glassText)
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                
                Spacer()
                
                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    permissionsPage.tag(1)
                    readyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                
                Spacer()
                
                // Bottom Button
                bottomButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Pages
    
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Image("image_logo")
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(radius: 10)
           
            
            VStack(spacing: 12) {
                Text("Welcome to")
                    .font(.title2)
                    .foregroundStyle(.glassText)
                
                Text("Duit Gw Woi")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Your personal finance companion")
                    .font(.subheadline)
                    .foregroundStyle(.glassText)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Track your expenses & income")
                FeatureRow(icon: "creditcard.fill", text: "Manage credit cards & debts")
                FeatureRow(icon: "doc.text.viewfinder", text: "Scan receipts with OCR")
                FeatureRow(icon: "person.2.fill", text: "Split bills with friends")
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
    
    private var permissionsPage: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.neonGreen)
                
                Text("We Need Your Permission")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("To provide the best experience, we need access to:")
                    .font(.subheadline)
                    .foregroundStyle(.glassText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "photo.fill",
                    title: "Photo Library",
                    description: "Scan receipts from your photos",
                    status: permissionManager.photoLibraryStatus
                )
                
                PermissionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    description: "Take photos of receipts",
                    status: permissionManager.cameraStatus
                )
                
                PermissionRow(
                    icon: "faceid",
                    title: "Face ID / Touch ID",
                    description: "Secure your financial data",
                    status: permissionManager.faceIDStatus
                )
            }
            .padding(.horizontal, 20)
        }
        .padding()
    }
    
    private var readyPage: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.neonGreen)
            
            VStack(spacing: 12) {
                Text("All Set!")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("You're ready to start managing your finances")
                    .font(.subheadline)
                    .foregroundStyle(.glassText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                StatusCard(
                    icon: "photo.fill",
                    title: "Photo Library",
                    status: permissionManager.photoLibraryStatus
                )
                StatusCard(
                    icon: "camera.fill",
                    title: "Camera",
                    status: permissionManager.cameraStatus
                )
                StatusCard(
                    icon: "faceid",
                    title: "Face ID",
                    status: permissionManager.faceIDStatus
                )
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
    
    // MARK: - Bottom Button
    
    private var bottomButton: some View {
        Group {
            if currentPage == 0 {
                Button(action: {
                    withAnimation {
                        currentPage = 1
                    }
                }) {
                    Text("Get Started")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                }
                .padding(.horizontal)
            } else if currentPage == 1 {
                Button {
                    requestPermissions()
                } label: {
                    HStack(spacing: 10) {
                        if isRequesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        
                        Text(isRequesting ? "Requesting..." : "Grant Permissions")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(isRequesting ? 0 : 0.2), radius: 10, y: 5)
                }
                .disabled(isRequesting)
                .padding(.horizontal)
            } else {
                Button(action: {
                    // Mark onboarding as complete
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    isPresented = false
                }) {
                    Text("Start Using App")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
        
                        .foregroundColor(.white) // 👈 putih
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                }
                .padding(.horizontal)
            }
        }
        .buttonStyle(.glassProminent)
    }
    
    // MARK: - Actions
    
    private func requestPermissions() {
        isRequesting = true
        
        Task {
            await permissionManager.requestAllPermissions()
            
            // Small delay to show the updated statuses
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            
            await MainActor.run {
                isRequesting = false
                withAnimation {
                    currentPage = 2
                }
            }
        }
    }
}

// MARK: - Subviews

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.neonGreen)
                .frame(width: 30)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
            
            Spacer()
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.neonGreen)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.glassText)
            }
            
            Spacer()
            
            if status != .notDetermined {
                Image(systemName: status.icon)
                    .font(.title3)
                    .foregroundStyle(status.color)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}

struct StatusCard: View {
    let icon: String
    let title: String
    let status: PermissionStatus
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(status.color)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .font(.caption)
                Text(status.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(status.color)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
}

#Preview {
    PermissionOnboardingView(isPresented: .constant(true))
        .environment(PermissionManager())
}
