//
//  FABMenuView.swift
//  Budget Expense
//

import SwiftUI

/// FAB Menu with expandable options for Add Expense, OCR (future), and Split Bill
struct FABMenuView: View {
    @Binding var showUniversalAdd: Bool
    @Binding var showSplitBill: Bool
    @Binding var showOCRScanner: Bool
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 16) {
            // Expanded menu options
            if isExpanded {
                VStack(alignment: .trailing, spacing: 12) {
                    // Split Bill
                    FABMenuItem(
                        icon: "person.2.fill",
                        label: "Split Bill",
                        color: Color(red: 0.3, green: 0.6, blue: 1.0)
                    ) {
                        isExpanded = false
                        // Small delay to let menu close before opening sheet
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showSplitBill = true
                        }
                    }
                    
                    // OCR Expense (Future - disabled)
                    FABMenuItem(
                        icon: "doc.text.viewfinder",
                        label: "OCR Expense",
                        color: Color(red: 0.92, green: 0.66, blue: 0.10),
                        isDisabled: true
                    ) {
                        // Future implementation
                    }
                    
                    // Add Expense
                    FABMenuItem(
                        icon: "plus.circle.fill",
                        label: "Add Expense",
                        color: .neonGreen
                    ) {
                        isExpanded = false
                        // Small delay to let menu close before opening sheet
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showUniversalAdd = true
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Main FAB Button
            Button {
                withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                    isExpanded.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.95, green: 0.4, blue: 0.2))
                        .frame(width: 64, height: 64)
                        .shadow(color: Color(red: 0.95, green: 0.4, blue: 0.2).opacity(0.5), radius: 12, x: 0, y: 4)
                    
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showSplitBill) {
            SplitBillView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

/// Individual FAB Menu Item
struct FABMenuItem: View {
    let icon: String
    let label: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Spacer()
                
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(color)
                    .clipShape(Circle())
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(.leading, 20)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(white: 0.12))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

#Preview {
    ZStack {
        Color.appBg.ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                FABMenuView(
                    showUniversalAdd: .constant(false),
                    showSplitBill: .constant(false),
                    showOCRScanner: .constant(false)
                )
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
}
