//
//  SplitBillView.swift
//  Budget Expense
//

import SwiftUI
#if os(iOS)
import ContactsUI
#endif

struct SplitBillView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.categoryManager) private var categoryManager
    @Environment(\.dismiss) private var dismiss
    
    // Header Data
    @State private var billDescription = ""
    @State private var category = ""
    @State private var date = Date()
    
    // Who Paid (Manual or Contact)
    @State private var payerName: String = ""
    
    // Split Configuration
    @State private var splitMethod: SplitMethod = .itemized
    @State private var participants: [SplitParticipant] = []
    
    // Currency for Debts
    @State private var currency: Currency = .idr
    
    // Basic Mode
    @State private var totalAmountText = ""
    
    // Itemized Mode
    @State private var items: [SplitItem] = []
    @State private var taxText = ""
    @State private var serviceChargeText = ""
    
    // Presentation States
    @State private var showAddParticipant = false
    @State private var showParticipantContactPicker = false
    @State private var showPayerContactPicker = false
    @State private var showAddItem = false
    
    private var categories: [String] {
        categoryManager.categoryNames(for: .outflow)
    }
    
    private var taxAmount: Double { Double(taxText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var serviceCharge: Double { Double(serviceChargeText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    
    private var totalAmount: Double {
        if splitMethod == .itemized {
            let subtotal = items.reduce(0) { $0 + ($1.price * Double($1.qty)) }
            return subtotal + taxAmount + serviceCharge
        } else {
            return Double(totalAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
    }
    
    private var currencySymbol: String {
        currency.symbol
    }
    
    private var canSave: Bool {
        totalAmount > 0 &&
        !payerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !participants.isEmpty &&
        !billDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var totalAllocated: Double {
        participants.reduce(0) { $0 + $1.amount }
    }
    
    private var allocationValid: Bool {
        if splitMethod == .itemized {
            let allItemsAssigned = items.allSatisfy { !$0.assigned.isEmpty }
            return allItemsAssigned && abs(totalAllocated - totalAmount) < 0.05
        } else if splitMethod == .percentage {
            let totalPercentage = participants.reduce(0) { $0 + $1.percentage }
            return abs(totalPercentage - 100.0) < 0.05 && abs(totalAllocated - totalAmount) < 0.05
        } else {
            return abs(totalAllocated - totalAmount) < 0.05
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        participantsSection
                        Divider()
                        descriptionField
                        categoryField
                        payerField
                        datePicker
                        splitMethodPicker
                        
                        if splitMethod == .itemized {
                            itemsSection
                        } else {
                            totalAmountField
                        }
                        
                        
                        
                        if !participants.isEmpty {
                            allocationSummary
                        }
                        
                        saveBtn
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Split Bill")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.glassText)
                }
            }
            .sheet(isPresented: $showAddParticipant) {
                AddParticipantView(
                    participants: $participants,
                    totalAmount: totalAmount,
                    splitMethod: splitMethod
                )
            }
            .sheet(isPresented: $showAddItem) {
                AddReceiptItemView(
                    items: $items,
                    participants: participants
                )
            }
            #if os(iOS)
            .sheet(isPresented: $showParticipantContactPicker) {
                ContactPickerView(participants: $participants)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showPayerContactPicker) {
                SingleContactPickerView(name: $payerName)
                    .ignoresSafeArea()
            }
            #endif
            .onChange(of: totalAmountText) { _, _ in redistributeAmounts() }
            .onChange(of: taxText) { _, _ in redistributeAmounts() }
            .onChange(of: serviceChargeText) { _, _ in redistributeAmounts() }
            .onChange(of: splitMethod) { _, _ in redistributeAmounts() }
            .onChange(of: items) { _, _ in redistributeAmounts() }
            .onChange(of: participants) { _, _ in redistributeAmounts() }
            .onAppear {
                if let firstWallet = store.wallets.first {
                    currency = firstWallet.currency
                }
            }
        }
    }
    
    // MARK: - Header Fields
    
    private var descriptionField: some View {
        field("RESTAURANT / BILL NAME", "text.alignleft") {
            TextField("e.g. Dinner at McDonald's", text: $billDescription)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(.white)
                .padding(14)
                .glassEffect(in: .rect(cornerRadius: 14))
        }
    }
    
    private var categoryField: some View {
        field("CATEGORY", "tag") {
            Menu {
                ForEach(categories, id: \.self) { cat in
                    Button(cat) { category = cat }
                }
            } label: {
                HStack {
                    Text(category.isEmpty ? "Select category…" : category)
                        .foregroundStyle(category.isEmpty ? Color(white: 0.35) : .white)
                        .font(.body)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.dimText)
                }
                .padding(14)
                .glassEffect(in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var payerField: some View {
        field("WHO PAID?", "person.fill") {
            HStack(spacing: 12) {
                TextField("Enter name or pick from contacts", text: $payerName)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.white)
                
                #if os(iOS)
                Button {
                    showPayerContactPicker = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.neonGreen)
                }
                #endif
            }
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
    }
    
    private var datePicker: some View {
        field("DATE", "calendar") {
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(14)
                .glassEffect(in: .rect(cornerRadius: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Split Method
    
    private var splitMethodPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("SPLIT MODE", systemImage: "square.split.2x1")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.glassText)
                .kerning(0.8)
            
            HStack(spacing: 8) {
                splitMethodButton(.itemized, "Items", "list.bullet.rectangle")
                splitMethodButton(.equal, "Equal", "equal.square")
                splitMethodButton(.percentage, "Percent", "percent")
                splitMethodButton(.custom, "Custom", "slider.horizontal.3")
            }
        }
    }
    
    @ViewBuilder
    private func splitMethodButton(_ method: SplitMethod, _ label: String, _ icon: String) -> some View {
        Button {
            withAnimation(.spring(duration: 0.2)) {
                splitMethod = method
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(splitMethod == method ? .neonGreen : Color(white: 0.3))
                
                Text(label)
                    .font(.caption.weight(splitMethod == method ? .semibold : .regular))
                    .foregroundStyle(splitMethod == method ? .white : Color(white: 0.38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect(
                splitMethod == method ? .regular.tint(.neonGreen) : .regular,
                in: .rect(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Items Section
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("RECEIPT ITEMS", systemImage: "cart")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.glassText)
                    .kerning(0.8)
                Spacer()
                Button {
                    showAddItem = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Item")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.neonGreen)
                }
            }
            
            if items.isEmpty {
                Text("No items added yet")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .glassEffect(in: .rect(cornerRadius: 14))
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        ItemRow(item: item, currencySymbol: currencySymbol, participants: participants) {
                            withAnimation { items.removeAll { $0.id == item.id } }
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                field("TAX", "percent") {
                    HStack {
                        Text(currencySymbol).font(.subheadline).foregroundStyle(.glassText)
                        TextField("0", text: $taxText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .glassEffect(in: .rect(cornerRadius: 12))
                }
                
                field("SERVICE CHG", "tray") {
                    HStack {
                        Text(currencySymbol).font(.subheadline).foregroundStyle(.glassText)
                        TextField("0", text: $serviceChargeText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .glassEffect(in: .rect(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Basic Total Amount Field
    
    private var totalAmountField: some View {
        field("TOTAL AMOUNT", "banknote") {
            HStack(spacing: 10) {
                Text(currencySymbol)
                    .font(.headline)
                    .foregroundStyle(.glassText)
                    .frame(minWidth: 24)
                
                TextField("0", text: $totalAmountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .textFieldStyle(.plain)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
    }
    
    // MARK: - Participants Section
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("PARTICIPANTS", systemImage: "person.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.glassText)
                    .kerning(0.8)
                
                Spacer()
                
                HStack(spacing: 16) {
                    #if os(iOS)
                    Button { showParticipantContactPicker = true } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Contact")
                    }
                    #endif
                    
                    Button { showAddParticipant = true } label: {
                        Image(systemName: "plus.circle.fill")
                        Text("Manual")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.neonGreen)
            }
            
            if participants.isEmpty {
                Text("No participants added yet")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .glassEffect(in: .rect(cornerRadius: 14))
            } else {
                VStack(spacing: 8) {
                    // Passed down as bindings so inline editing works
                    ForEach($participants) { $participant in
                        ParticipantRow(
                            participant: $participant,
                            currencySymbol: currencySymbol,
                            splitMethod: splitMethod,
                            onDelete: {
                                withAnimation {
                                    participants.removeAll { $0.id == participant.id }
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Allocation Summary
    
    private var allocationSummary: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Grand Total:")
                    .font(.subheadline)
                    .foregroundStyle(.glassText)
                Spacer()
                Text("\(currencySymbol) \(formatNumber(totalAmount))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("Allocated:")
                    .font(.subheadline)
                    .foregroundStyle(.glassText)
                Spacer()
                Text("\(currencySymbol) \(formatNumber(totalAllocated))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(allocationValid ? .neonGreen : .neonRed)
            }
            
            if !allocationValid {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    
                    if splitMethod == .itemized {
                        Text("Ensure all items are assigned and totals match")
                    } else if splitMethod == .percentage {
                        let currentPercent = participants.reduce(0) { $0 + $1.percentage }
                        Text("Percentage adds up to \(formatNumber(currentPercent))% (needs 100%)")
                    } else {
                        Text("Allocation must equal total amount")
                    }
                }
                .font(.caption)
                .foregroundStyle(.neonRed)
            }
        }
        .padding(14)
        .glassEffect(in: .rect(cornerRadius: 14))
    }
    
    // MARK: - Save Button
    
    private var saveBtn: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Split & Save")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canSave || !allocationValid)
        .opacity(canSave && allocationValid ? 1 : 0.38)
    }
    
    // MARK: - Helper Functions
    
    @ViewBuilder
    private func field<C: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.glassText)
                .kerning(0.8)
            content()
        }
    }
    
    private func redistributeAmounts() {
        guard !participants.isEmpty else { return }
        
        switch splitMethod {
        case .equal:
            guard totalAmount > 0 else { return }
            let perPerson = totalAmount / Double(participants.count)
            for i in participants.indices {
                participants[i].amount = perPerson
            }
            
        case .percentage:
            guard totalAmount > 0 else { return }
            for i in participants.indices {
                // Calculates amount directly from user's custom percentage input
                participants[i].amount = (participants[i].percentage / 100.0) * totalAmount
            }
            
        case .custom:
            // Custom requires manual editing from inside the ParticipantRow, don't auto-overwrite.
            break
            
        case .itemized:
            let subtotal = items.reduce(0) { $0 + ($1.price * Double($1.qty)) }
            let totalExtra = taxAmount + serviceCharge
            
            // 1. Reset all amounts
            for i in participants.indices {
                participants[i].amount = 0
            }
            
            guard subtotal > 0 else { return }
            
            // 2. Add item shares
            for item in items {
                let itemTotal = item.price * Double(item.qty)
                let assignedCount = Double(item.assigned.count)
                guard assignedCount > 0 else { continue } // Invalid unassigned item
                
                let shareAmount = itemTotal / assignedCount
                
                for participantId in item.assigned {
                    if let idx = participants.firstIndex(where: { $0.id == participantId }) {
                        participants[idx].amount += shareAmount
                    }
                }
            }
            
            // 3. Pro-rate Extra Charges based on share of subtotal
            if totalExtra > 0 {
                for i in participants.indices {
                    let userSubtotal = participants[i].amount
                    if userSubtotal > 0 {
                        let proportion = userSubtotal / subtotal
                        participants[i].amount += (proportion * totalExtra)
                    }
                }
            }
        }
    }
    
    private func save() {
        guard canSave, allocationValid else { return }
        
        let desc = billDescription.trimmingCharacters(in: .whitespaces)
        let formattedPayer = payerName.trimmingCharacters(in: .whitespaces)
        
        let subtotal = items.reduce(0) { $0 + ($1.price * Double($1.qty)) }
        let totalExtra = taxAmount + serviceCharge
        
        for participant in participants {
            // Optional: Skip creating a debt if the participant's name matches the payer's name
            if participant.name.caseInsensitiveCompare(formattedPayer) == .orderedSame { continue }
            
            var debtItems: [DebtItem] = []
            
            if splitMethod == .itemized {
                for item in items where item.assigned.contains(participant.id) {
                    let shareAmount = (item.price * Double(item.qty)) / Double(item.assigned.count)
                    debtItems.append(DebtItem(name: item.name, amount: shareAmount))
                }
                
                if totalExtra > 0 {
                    let userSubtotal = debtItems.reduce(0) { $0 + $1.amount }
                    if subtotal > 0 && userSubtotal > 0 {
                        let proportion = userSubtotal / subtotal
                        debtItems.append(DebtItem(name: "Tax & Service", amount: proportion * totalExtra))
                    }
                }
            } else if splitMethod == .percentage {
                debtItems.append(DebtItem(name: "Share (\(formatNumber(participant.percentage))%)", amount: participant.amount))
            } else {
                debtItems.append(DebtItem(name: "Share of Bill", amount: participant.amount))
            }
            
            let debt = Debt(
                personName: participant.name,
                amount: participant.amount,
                currency: currency,
                note: "Split from: \(desc) (Paid by \(formattedPayer))",
                date: date,
                dueDate: nil,
                isSettled: false,
                items: debtItems.isEmpty ? nil : debtItems
            )
            store.addDebt(debt)
        }
        
        dismiss()
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Enums & Models

enum SplitMethod: String, CaseIterable {
    case itemized = "Items"
    case equal = "Equal"
    case percentage = "Percentage"
    case custom = "Custom"
}

struct SplitParticipant: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var amount: Double
    var percentage: Double = 0
}

struct SplitItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var price: Double
    var qty: Int
    var assigned: Set<UUID>
}

// MARK: - Subviews

struct ItemRow: View {
    let item: SplitItem
    let currencySymbol: String
    let participants: [SplitParticipant]
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text("\(item.qty)x @ \(currencySymbol) \(formatNumber(item.price))")
                        .font(.caption)
                        .foregroundStyle(.dimText)
                }
                Spacer()
                Text("\(currencySymbol) \(formatNumber(item.price * Double(item.qty)))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .foregroundStyle(.neonRed)
                        .padding(8)
                        .background(Color.neonRed.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // People tags
            let assignedNames = participants.filter { item.assigned.contains($0.id) }.map { $0.name }
            if assignedNames.isEmpty {
                Text("⚠️ Unassigned")
                    .font(.caption2.bold())
                    .foregroundStyle(.neonRed)
            } else {
                Text("For: " + assignedNames.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.glassText)
                    .lineLimit(2)
            }
            
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Updated Participant Row (Inline Editing)

import SwiftUI

struct ParticipantRow: View {
    @Binding var participant: SplitParticipant
    let currencySymbol: String
    let splitMethod: SplitMethod
    let onDelete: () -> Void
    
    @State private var percentageText: String = ""
    @State private var amountText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            inputSection
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        
        // MARK: - Sync
        .onAppear {
            percentageText = formatNumber(participant.percentage)
            amountText = formatNumber(participant.amount)
        }
        .onChange(of: participant.percentage) { _, newVal in
            percentageText = formatNumber(newVal)
        }
        .onChange(of: participant.amount) { _, newVal in
            amountText = formatNumber(newVal)
        }
    }
    
    // MARK: - Header (Avatar + Name + Delete)
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.neonGreen.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .glassEffect(.clear)
                
                Text(participant.name.prefix(1).uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.neonGreen)
                    .glassEffect()
                Text(participant.name.prefix(2).uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .glassEffect()
            }
            
            // Name
            Text(participant.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
            
            Spacer()
            
            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Input/Amount Section
    private var inputSection: some View {
        HStack {
            Text("Share")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5)) // Adjust to your .glassText if preferred
            
            Spacer()
            
            if splitMethod == .percentage {
                percentageInputView
            } else if splitMethod == .custom {
                customInputView
            } else {
                staticAmountView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.15)) // Subtle inset feel for the input area
    }
    
    // MARK: - Specific Input Views
    
    private var percentageInputView: some View {
        HStack(spacing: 12) {
            // Editable Percentage Box
            HStack(spacing: 2) {
                TextField("0", text: $percentageText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 45)
                    .onChange(of: percentageText) { _, newVal in
                        let clean = newVal.replacingOccurrences(of: ",", with: ".")
                        participant.percentage = Double(clean) ?? 0
                    }
                
                Text("%")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08)) // Clearly indicates it's editable
            .cornerRadius(8)
            
            Text("=")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.3))
            
            // Calculated Amount (Read-only)
            Text("\(currencySymbol) \(formatNumber(participant.amount))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.neonGreen)
        }
    }
    
    private var customInputView: some View {
        HStack(spacing: 4) {
            Text(currencySymbol)
                .foregroundStyle(.white.opacity(0.5))
            
            TextField("0", text: $amountText)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
                .font(.subheadline.bold())
                .foregroundStyle(.neonGreen)
                .frame(width: 80)
                .onChange(of: amountText) { _, newVal in
                    let clean = newVal.replacingOccurrences(of: ",", with: ".")
                    participant.amount = Double(clean) ?? 0
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08)) // Clearly indicates it's editable
        .cornerRadius(8)
    }
    
    private var staticAmountView: some View {
        Text("\(currencySymbol) \(formatNumber(participant.amount))")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.neonGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.neonGreen.opacity(0.1)) // Highlights the final cut beautifully
            .cornerRadius(8)
    }
    
    // MARK: - Helpers
    private func formatNumber(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? "0"
    }
}

// MARK: - Add Participant & Add Item Views

struct AddParticipantView: View {
    @Binding var participants: [SplitParticipant]
    let totalAmount: Double
    let splitMethod: SplitMethod
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var customAmount = ""
    @State private var percentage = 50.0
    
    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                VStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("NAME", systemImage: "person")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.glassText)
                            .kerning(0.8)
                        
                        TextField("Enter participant name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(.white)
                            .padding(14)
                            .glassEffect(in: .rect(cornerRadius: 14))
                    }
                    
                    if splitMethod == .percentage {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("PERCENTAGE", systemImage: "percent")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.glassText)
                                .kerning(0.8)
                            
                            VStack(spacing: 8) {
                                Slider(value: $percentage, in: 0...100, step: 1)
                                    .tint(.neonGreen)
                                
                                Text("\(Int(percentage))% = Rp \(formatNumber((percentage / 100.0) * totalAmount))")
                                    .font(.subheadline)
                                    .foregroundStyle(.glassText)
                            }
                            .padding(14)
                            .glassEffect(in: .rect(cornerRadius: 14))
                        }
                    } else if splitMethod == .custom {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("AMOUNT", systemImage: "banknote")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.glassText)
                                .kerning(0.8)
                            
                            HStack(spacing: 10) {
                                Text("Rp")
                                    .font(.headline)
                                    .foregroundStyle(.glassText)
                                    .frame(minWidth: 24)
                                
                                TextField("0", text: $customAmount)
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                                    .textFieldStyle(.plain)
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                            }
                            .padding(14)
                            .glassEffect(in: .rect(cornerRadius: 14))
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: addParticipant) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Participant")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!canAdd)
                    .opacity(canAdd ? 1 : 0.38)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .navigationTitle("Add Participant")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.glassText)
                }
            }
        }
    }
    
    private func addParticipant() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        var amount: Double = 0
        switch splitMethod {
        case .equal, .itemized:
            amount = 0 // Calculated dynamically in redistributeAmounts
        case .percentage:
            amount = (percentage / 100.0) * totalAmount
        case .custom:
            amount = Double(customAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
        
        let participant = SplitParticipant(
            name: trimmedName,
            amount: amount,
            percentage: splitMethod == .percentage ? percentage : 0
        )
        
        participants.append(participant)
        dismiss()
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct AddReceiptItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var items: [SplitItem]
    let participants: [SplitParticipant]
    
    @State private var name = ""
    @State private var priceText = ""
    @State private var qtyText = "1"
    @State private var assigned: Set<UUID> = []
    
    private var canSave: Bool {
        !name.isEmpty && (Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 && !assigned.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 22) {
                        if participants.isEmpty {
                            Label("Please add participants to the bill first before adding items.", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.neonRed)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(in: .rect(cornerRadius: 14))
                        }
                        
                        // Item Details
                        VStack(alignment: .leading, spacing: 9) {
                            Label("ITEM DETAILS", systemImage: "cube.box")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.glassText)
                                .kerning(0.8)
                            
                            VStack(spacing: 0) {
                                TextField("Item Name (e.g. Burger)", text: $name)
                                    .padding(14)
                                    .foregroundStyle(.white)
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                HStack {
                                    TextField("Price", text: $priceText)
                                        #if os(iOS)
                                        .keyboardType(.decimalPad)
                                        #endif
                                        .foregroundStyle(.white)
                                    
                                    Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                                    
                                    TextField("Qty", text: $qtyText)
                                        #if os(iOS)
                                        .keyboardType(.numberPad)
                                        #endif
                                        .foregroundStyle(.white)
                                        .frame(width: 50)
                                }
                                .padding(14)
                            }
                            .glassEffect(in: .rect(cornerRadius: 14))
                        }
                        
                        // Assignees
                        VStack(alignment: .leading, spacing: 9) {
                            Label("WHO SHARES THIS ITEM?", systemImage: "person.2")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.glassText)
                                .kerning(0.8)
                            
                            VStack(spacing: 8) {
                                ForEach(participants) { p in
                                    Button {
                                        if assigned.contains(p.id) {
                                            assigned.remove(p.id)
                                        } else {
                                            assigned.insert(p.id)
                                        }
                                    } label: {
                                        HStack {
                                            Text(p.name)
                                                .foregroundStyle(.white)
                                            Spacer()
                                            if assigned.contains(p.id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.neonGreen)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundStyle(.glassText)
                                            }
                                        }
                                        .padding(14)
                                        .glassEffect(in: .rect(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                HStack {
                                    Button("Select All") {
                                        assigned = Set(participants.map { $0.id })
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.neonGreen)
                                    
                                    Spacer()
                                    
                                    Button("Deselect All") {
                                        assigned.removeAll()
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.neonRed)
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 4)
                            }
                        }
                        .disabled(participants.isEmpty)
                        .opacity(participants.isEmpty ? 0.5 : 1)
                        
                        Button {
                            let item = SplitItem(
                                name: name,
                                price: Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0,
                                qty: Int(qtyText) ?? 1,
                                assigned: assigned
                            )
                            items.append(item)
                            dismiss()
                        } label: {
                            Text("Save Item")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.38)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Add Receipt Item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.glassText)
                }
            }
        }
    }
}

// MARK: - iOS Contact Pickers
#if os(iOS)
// 1. Multiple Participant Picker
struct ContactPickerView: UIViewControllerRepresentable {
    @Binding var participants: [SplitParticipant]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            DispatchQueue.main.async {
                for contact in contacts {
                    let given = contact.givenName
                    let family = contact.familyName
                    let org = contact.organizationName
                    
                    let name = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
                    let finalName = name.isEmpty ? (org.isEmpty ? "Unknown" : org) : name
                    
                    if !self.parent.participants.contains(where: { $0.name == finalName }) {
                        let newParticipant = SplitParticipant(name: finalName, amount: 0)
                        self.parent.participants.append(newParticipant)
                    }
                }
            }
        }
    }
}

// 2. Single Contact Picker for "Who Paid"
struct SingleContactPickerView: UIViewControllerRepresentable {
    @Binding var name: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: SingleContactPickerView
        
        init(_ parent: SingleContactPickerView) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            DispatchQueue.main.async {
                let given = contact.givenName
                let family = contact.familyName
                let org = contact.organizationName
                
                let fullName = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
                self.parent.name = fullName.isEmpty ? (org.isEmpty ? "Unknown" : org) : fullName
            }
        }
    }
}
#endif

#Preview {
    SplitBillView()
        .environment(AppStore())
        .environment(\.categoryManager, CategoryManager())
}
