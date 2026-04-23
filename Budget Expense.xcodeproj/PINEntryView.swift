//
//  PINEntryView.swift
//  Budget Expense
//

import SwiftUI

struct PINEntryView: View {
    @Environment(\.authenticationManager) private var authManager
    
    @State private var pin = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var attemptCount = 0
    @State private var showBiometric = false
    
    private let pinLength = 6
    private let maxAttempts = 5
    
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo/Title
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.neonGreen)
                    
                    Text("Duit Gw Woi App")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("Enter your PIN to unlock")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                // PIN Dots Display
                HStack(spacing: 20) {
                    ForEach(0..<pinLength, id: \.self) { index in
                        Circle()
                            .fill(pin.count > index ? Color.neonGreen : Color(white: 0.2))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.neonGreen.opacity(0.3), lineWidth: 2)
                            )
                    }
                }
                .offset(x: shakeOffset)
                .animation(.default, value: shakeOffset)
                
                Spacer()
               
            
                
                // Biometric Button (if enabled)
//                    Button {
//                        authenticateWithBiometric()
//                    } label: {
//                        HStack(spacing: 8) {
//                            Image(systemName: authManager.biometricType.icon)
//                                .font(.title3)
//                            Text("Forgot Pin")
//                        }
//                        .foregroundStyle(.neonRed)
//                        .padding()
//                        .background(Color.neonRed.opacity(0.15))
//                        .cornerRadius(12)
//                    }
                
                // Number Pad
                VStack(spacing: 16) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 16) {
                            ForEach(1..<4) { col in
                                let number = row * 3 + col
                                NumberButton(number: "\(number)") {
                                    addDigit("\(number)")
                                }
                            }
                        }
                    }
                  
                    
                    // Bottom Row: Empty, 0, Delete
                    HStack(spacing: 16) {
                        if authManager.isFaceIDEnabled {
                            Button {
                                authenticateWithBiometric()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(white: 0.12))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "faceid")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .frame(width: 80, height: 80)
                            .glassEffect(.clear)
                        } else {
                            Button {
                               print("No Face ID")
                            } label: {
                            }
                            .frame(width: 80, height: 80)
                            
                        }
                        
                        NumberButton(number: "0") {
                            addDigit("0")
                        }
                        
                        Button {
                            removeDigit()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.12))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "delete.left.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .frame(width: 80, height: 80)
                        .glassEffect(.clear)
                        
                        
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Auto-trigger biometric on appear if enabled
            if authManager.isFaceIDEnabled && !showBiometric {
                showBiometric = true
                Task {
                    await tryBiometricAuthentication()
                }
            }
        }
    }
    
    private func addDigit(_ digit: String) {
        if pin.count < pinLength {
            pin += digit
            if pin.count == pinLength {
                validatePIN()
            }
        }
    }
    
    private func removeDigit() {
        if !pin.isEmpty {
            pin.removeLast()
        }
    }
    
    private func validatePIN() {
        if authManager.authenticate(with: pin) {
            // Success - app will unlock automatically
            print("✅ PIN authenticated successfully")
        } else {
            // Failed
            attemptCount += 1
            
            if attemptCount >= maxAttempts {
                errorMessage = "Too many failed attempts. Please try again later."
                // In a production app, you might want to implement a lockout period
            } else {
                errorMessage = "Incorrect PIN"
            }
            
            shakeAnimation()
            pin = ""
        }
    }
    
    private func authenticateWithBiometric() {
        Task {
            await tryBiometricAuthentication()
        }
    }
    
    private func tryBiometricAuthentication() async {
        let success = await authManager.authenticateWithBiometrics()
        if success {
            print("✅ Biometric authentication successful")
        } else {
            print("❌ Biometric authentication failed")
        }
    }
    
    private func shakeAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
            shakeOffset = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                shakeOffset = 0
            }
        }
    }
}

#Preview {
    PINEntryView()
        .environment(\.authenticationManager, AuthenticationManager())
}
