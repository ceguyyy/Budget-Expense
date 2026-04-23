//
//  ResetPINView.swift
//  Budget Expense
//

import SwiftUI

struct ResetPINView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authenticationManager) private var authManager
    
    @State private var currentPIN = ""
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var step: ResetStep = .verifyOld
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var shakeOffset: CGFloat = 0
    
    private let pinLength = 6
    
    enum ResetStep {
        case verifyOld
        case enterNew
        case confirmNew
        
        var title: String {
            switch self {
            case .verifyOld: return "Enter Current PIN"
            case .enterNew: return "Enter New PIN"
            case .confirmNew: return "Confirm New PIN"
            }
        }
        
        var subtitle: String {
            switch self {
            case .verifyOld: return "Verify your current PIN"
            case .enterNew: return "Create a new 6-digit PIN"
            case .confirmNew: return "Enter your new PIN again"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Title and Instructions
                    VStack(spacing: 12) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundStyle(.neonGreen)
                        
                        Text(step.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text(step.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // PIN Dots Display
                    HStack(spacing: 20) {
                        ForEach(0..<pinLength, id: \.self) { index in
                            Circle()
                                .fill(currentDisplayPIN.count > index ? Color.neonGreen : Color(white: 0.2))
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
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Reset PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(Color(white: 0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                if step == .verifyOld {
                    currentPIN = ""
                } else {
                    resetToCurrentStep()
                }
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var currentDisplayPIN: String {
        switch step {
        case .verifyOld: return currentPIN
        case .enterNew: return newPIN
        case .confirmNew: return confirmPIN
        }
    }
    
    private func addDigit(_ digit: String) {
        switch step {
        case .verifyOld:
            if currentPIN.count < pinLength {
                currentPIN += digit
                if currentPIN.count == pinLength {
                    verifyCurrentPIN()
                }
            }
        case .enterNew:
            if newPIN.count < pinLength {
                newPIN += digit
                if newPIN.count == pinLength {
                    withAnimation {
                        step = .confirmNew
                    }
                }
            }
        case .confirmNew:
            if confirmPIN.count < pinLength {
                confirmPIN += digit
                if confirmPIN.count == pinLength {
                    validateNewPIN()
                }
            }
        }
    }
    
    private func removeDigit() {
        switch step {
        case .verifyOld:
            if !currentPIN.isEmpty {
                currentPIN.removeLast()
            }
        case .enterNew:
            if !newPIN.isEmpty {
                newPIN.removeLast()
            }
        case .confirmNew:
            if !confirmPIN.isEmpty {
                confirmPIN.removeLast()
            } else {
                // Go back to enter new PIN
                withAnimation {
                    step = .enterNew
                    newPIN = ""
                }
            }
        }
    }
    
    private func verifyCurrentPIN() {
        if authManager.verifyPIN(currentPIN) {
            withAnimation {
                step = .enterNew
            }
        } else {
            errorMessage = "Incorrect PIN. Please try again."
            showError = true
            shakeAnimation()
            currentPIN = ""
        }
    }
    
    private func validateNewPIN() {
        if newPIN == confirmPIN {
            // Success!
            authManager.setPIN(newPIN)
            dismiss()
        } else {
            errorMessage = "PINs don't match. Please try again."
            showError = true
            shakeAnimation()
        }
    }
    
    private func resetToCurrentStep() {
        switch step {
        case .verifyOld:
            currentPIN = ""
        case .enterNew:
            newPIN = ""
        case .confirmNew:
            confirmPIN = ""
            newPIN = ""
            withAnimation {
                step = .enterNew
            }
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
    ResetPINView()
        .environment(\.authenticationManager, AuthenticationManager())
}
