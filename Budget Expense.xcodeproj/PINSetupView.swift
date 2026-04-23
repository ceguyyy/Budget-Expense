//
//  PINSetupView.swift
//  Budget Expense
//

import SwiftUI

struct PINSetupView: View {
    @Environment(\.authenticationManager) private var authManager
    let onComplete: () -> Void
    
    @State private var pin = ""
    @State private var confirmPIN = ""
    @State private var isConfirming = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var shakeOffset: CGFloat = 0
    
    private let pinLength = 6
    
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Title and Instructions
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.neonGreen)
                    
                    Text(isConfirming ? "Confirm Your PIN" : "Create a PIN")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text(isConfirming ? "Enter your PIN again" : "Create a 6-digit PIN to secure your app")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // PIN Dots Display
                HStack(spacing: 20) {
                    ForEach(0..<pinLength, id: \.self) { index in
                        Circle()
                            .fill(currentPIN.count > index ? Color.neonGreen : Color(white: 0.2))
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
                        Color.clear
                            .frame(width: 80, height: 80)
                        
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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                resetPINEntry()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var currentPIN: String {
        isConfirming ? confirmPIN : pin
    }
    
    private func addDigit(_ digit: String) {
        if isConfirming {
            if confirmPIN.count < pinLength {
                confirmPIN += digit
                if confirmPIN.count == pinLength {
                    validatePIN()
                }
            }
        } else {
            if pin.count < pinLength {
                pin += digit
                if pin.count == pinLength {
                    // Move to confirmation
                    withAnimation {
                        isConfirming = true
                    }
                }
            }
        }
    }
    
    private func removeDigit() {
        if isConfirming {
            if !confirmPIN.isEmpty {
                confirmPIN.removeLast()
            } else {
                // Go back to initial PIN entry
                withAnimation {
                    isConfirming = false
                    pin = ""
                }
            }
        } else {
            if !pin.isEmpty {
                pin.removeLast()
            }
        }
    }
    
    private func validatePIN() {
        if pin == confirmPIN {
            // Success!
            authManager.setPIN(pin)
            authManager.unlockApp()
            
            withAnimation {
                onComplete()
            }
        } else {
            // PINs don't match
            errorMessage = "PINs don't match. Please try again."
            showError = true
            shakeAnimation()
        }
    }
    
    private func resetPINEntry() {
        withAnimation {
            pin = ""
            confirmPIN = ""
            isConfirming = false
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

// MARK: - Number Button

struct NumberButton: View {
    let number: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
            hapticFeedback()
        }) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.12))
                    .frame(width: 80, height: 80)
                
                Text(number)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .frame(width: 80, height: 80)
        .glassEffect(.clear)
    }
    
    private func hapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = newValue
                }
            }
    }
}

#Preview {
    PINSetupView {
        print("PIN setup completed")
    }
    .environment(\.authenticationManager, AuthenticationManager())
}
