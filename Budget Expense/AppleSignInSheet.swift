//
//  AppleSignInSheet.swift
//  Budget Expense
//

import SwiftUI

struct AppleSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appleSignInManager) private var signInManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.45, green: 0.2, blue: 0.9).opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white)
                    }
                    
                    // Title & Description
                    VStack(spacing: 12) {
                        Text("Sign in with Apple")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        
                        Text("Sign in to enable iCloud backup and sync your budget data across all your devices securely.")
                            .font(.body)
                            .foregroundStyle(.glassText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Benefits
                    VStack(alignment: .leading, spacing: 16) {
                        BenefitRow(
                            icon: "icloud.fill",
                            title: "iCloud Backup",
                            description: "Automatically backup your data"
                        )
                        
                        BenefitRow(
                            icon: "lock.shield.fill",
                            title: "Privacy First",
                            description: "Your data stays private and secure"
                        )
                        
                        BenefitRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Cross-Device Sync",
                            description: "Access your budget from any device"
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Sign In Button
                    SignInWithAppleButton {
                        dismiss()
                    }
                    .frame(height: 50)
                    .padding(.horizontal, 24)
                    
                    // Skip Button
                    Button {
                        dismiss()
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundStyle(.glassText)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.glassText)
                    }
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.neonGreen.opacity(0.15))
                    .frame(width: 44, height: 44)
                
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
        }
    }
}

#Preview {
    AppleSignInSheet()
        .environment(\.appleSignInManager, AppleSignInManager())
}
