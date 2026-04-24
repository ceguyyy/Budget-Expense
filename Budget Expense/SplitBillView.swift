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
    
    let prefilledOCR: OCRResult?
    
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
    
    // Track if loaded from OCR with items (lock to itemized mode)
    @State private var isOCRItemized = false
    
    // ✅ Use onAppear ID to track unique view lifecycle
    @State private var viewLifecycleID = UUID()
    @AppStorage("splitBill_lastLifecycleID") private var lastLifecycleID: String = ""
    
    init(prefilledOCR: OCRResult? = nil) {
        self.prefilledOCR = prefilledOCR
    }
    
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
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 16)
                            
                        currencySelector
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
                    splitMethod: splitMethod,
                    currencySymbol: currencySymbol
                )
            }
            .sheet(isPresented: $showAddItem) {
                AddReceiptItemView(
                    items: $items,
                    participants: participants,
                    currencySymbol: currencySymbol
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
                // ✅ Generate new lifecycle ID and compare with last one
                let currentID = viewLifecycleID.uuidString
                
                guard lastLifecycleID != currentID else {
                    print("⏭️ SplitBill: Skipping OCR load (view already initialized)")
                    return
                }
                
                // Mark this view as initialized
                lastLifecycleID = currentID
                print("🎯 SplitBill: Initializing (Lifecycle: \(currentID.prefix(8))...)...")
                
                if let firstWallet = store.wallets.first {
                    currency = firstWallet.currency
                }
                
                // Load OCR data from parameter or UserDefaults
                var ocrData = prefilledOCR
                
                if ocrData != nil {
                    print("✅ SplitBill: Received OCR data via parameter")
                } else if let data = UserDefaults.standard.data(forKey: "pending_ocr_result") {
                    ocrData = try? JSONDecoder().decode(OCRResult.self, from: data)
                    if ocrData != nil {
                        print("✅ SplitBill: Loaded OCR data from UserDefaults")
                    } else {
                        print("⚠️ SplitBill: Failed to decode OCR data from UserDefaults")
                    }
                    // Clear it after reading
                    UserDefaults.standard.removeObject(forKey: "pending_ocr_result")
                } else {
                    print("ℹ️ SplitBill: No OCR data available - starting fresh")
                }
                
                if let ocr = ocrData {
                    print("📝 SplitBill: Populating fields with OCR data:")
                    print("   - Merchant: \(ocr.merchant ?? "nil")")
                    print("   - Amount: \(ocr.totalAmount ?? 0)")
                    print("   - Items: \(ocr.receiptItems?.count ?? 0)")
                    print("   - Date: \(ocr.date?.description ?? "nil")")
                    
                    // Set merchant/description
                    if let merchant = ocr.merchant {
                        billDescription = merchant
                    }
                    
                    // Set date
                    if let ocrDate = ocr.date {
                        date = ocrDate
                    }
                    
                    // Set currency if available
                    if let currencyCode = ocr.currency {
                        if currencyCode.uppercased() == "USD" {
                            currency = .usd
                        } else {
                            currency = .idr
                        }
                    }
                    
                    // If we have itemized receipt items, FORCE itemized mode and LOCK it
                    if let receiptItems = ocr.receiptItems, !receiptItems.isEmpty {
                        print("   - ✅ FORCING ITEMIZED mode with \(receiptItems.count) items (LOCKED)")
                        splitMethod = .itemized
                        isOCRItemized = true // Lock to itemized mode
                        items = receiptItems.map { item in
                            SplitItem(name: item.name, price: item.price, qty: 1, assigned: [])
                        }
                        print("✅ SplitBill: Items populated successfully")
                    } else if let total = ocr.totalAmount {
                        print("   - Using EQUAL mode with total: \(total)")
                        // Otherwise use basic mode with total
                        splitMethod = .equal
                        totalAmountText = String(format: "%.2f", total)
                    }
                    
                    print("✅ SplitBill: All fields populated from OCR")
                }
            }
            .onDisappear {
                // Clear the lifecycle ID when view completely disappears
                lastLifecycleID = ""
                print("🔄 SplitBill: Lifecycle reset on disappear")
            }
        }
    }
    
    private var currencySelector: some View {
        field("CURRENCY", "dollarsign.circle") {
            Menu {
                ForEach(Currency.allCases, id: \.self) { curr in
                    Button {
                        currency = curr
                    } label: {
                        HStack {
                            Text(curr.flag)
                            Text(curr.name)
                            Spacer()
                            Text(curr.symbol)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(currency.flag)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currency.name)
                            .foregroundStyle(.white)
                            .font(.body)
                        Text(currency.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.glassText)
                    }
                    Spacer()
                    Text(currency.symbol)
                        .foregroundStyle(.glassText)
                        .font(.headline)
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
            HStack {
                Label("SPLIT MODE", systemImage: "square.split.2x1")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.glassText)
                    .kerning(0.8)
                
                if isOCRItemized {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Locked to Items mode (from OCR)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.neonGreen.opacity(0.7))
                }
            }
            
            HStack(spacing: 8) {
                splitMethodButton(.itemized, "Items", "list.bullet.rectangle")
                splitMethodButton(.equal, "Equal", "equal.square")
                splitMethodButton(.percentage, "Percent", "percent")
                splitMethodButton(.custom, "Custom", "slider.horizontal.3")
            }
            .disabled(isOCRItemized)
            .opacity(isOCRItemized ? 0.5 : 1.0)
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
                    ForEach($items) { $item in
                        EditableItemRow(
                            item: $item,
                            currencySymbol: currencySymbol,
                            participants: participants,
                            onDelete: {
                                withAnimation { items.removeAll { $0.id == item.id } }
                            }
                        )
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
                participants[i].amount = (participants[i].percentage / 100.0) * totalAmount
            }
            
        case .custom:
            break
            
        case .itemized:
            let subtotal = items.reduce(0) { $0 + ($1.price * Double($1.qty)) }
            let totalExtra = taxAmount + serviceCharge
            
            for i in participants.indices {
                participants[i].amount = 0
            }
            
            guard subtotal > 0 else { return }
            
            for item in items {
                let itemTotal = item.price * Double(item.qty)
                let assignedCount = Double(item.assigned.count)
                guard assignedCount > 0 else { continue }
                
                let shareAmount = itemTotal / assignedCount
                
                for participantId in item.assigned {
                    if let idx = participants.firstIndex(where: { $0.id == participantId }) {
                        participants[idx].amount += shareAmount
                    }
                }
            }
            
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
        
        // 1. Generate Debt Entries
        for participant in participants {
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
        
        // 2. Generate Split Bill History Record
        let recordItems = items.map { SplitItemRecord(name: $0.name, price: $0.price, qty: $0.qty) }
        let recordParticipants = participants.map { SplitParticipantRecord(name: $0.name, amount: $0.amount, percentage: $0.percentage) }
        
        let historyRecord = SplitBillRecord(
            billName: desc,
            payerName: formattedPayer,
            totalAmount: totalAmount,
            currency: currency,
            date: date,
            items: recordItems,
            participants: recordParticipants
        )
        // ✅ Saving History directly into the global Store exactly here:
        store.addSplitBill(historyRecord)
        
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

// MARK: - Editable Item Row

struct EditableItemRow: View {
    @Binding var item: SplitItem
    let currencySymbol: String
    let participants: [SplitParticipant]
    let onDelete: () -> Void
    
    @State private var isEditing = false
    @State private var showAssignSheet = false
    @State private var editedName: String = ""
    @State private var editedPrice: String = ""
    @State private var editedQty: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                // Editing Mode
                VStack(spacing: 12) {
                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ITEM NAME")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.glassText)
                        TextField("Item name", text: $editedName)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }
                    
                    // Price and Quantity
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PRICE")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.glassText)
                            HStack(spacing: 6) {
                                Text(currencySymbol)
                                    .font(.caption)
                                    .foregroundStyle(.glassText)
                                TextField("0.00", text: $editedPrice)
                                    .textFieldStyle(.plain)
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("QTY")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.glassText)
                            TextField("1", text: $editedQty)
                                .textFieldStyle(.plain)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                        }
                        .frame(width: 80)
                    }
                    
                    // Save/Cancel buttons
                    HStack(spacing: 8) {
                        Button("Cancel") {
                            isEditing = false
                            // Reset to original values
                            editedName = item.name
                            editedPrice = String(format: "%.2f", item.price)
                            editedQty = "\(item.qty)"
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        
                        Button("Save") {
                            // Save changes
                            item.name = editedName
                            if let price = Double(editedPrice.replacingOccurrences(of: ",", with: ".")) {
                                item.price = price
                            }
                            if let qty = Int(editedQty), qty > 0 {
                                item.qty = qty
                            }
                            isEditing = false
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.neonGreen)
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .glassEffect(in: .rect(cornerRadius: 12))
            } else {
                // Display Mode
                VStack(spacing: 0) {
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
                        
                        // Assign button
                        Button {
                            showAssignSheet = true
                        } label: {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(item.assigned.isEmpty ? .neonRed : .blue)
                                .padding(8)
                                .background((item.assigned.isEmpty ? Color.neonRed : Color.blue).opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        // Edit button
                        Button {
                            editedName = item.name
                            editedPrice = String(format: "%.2f", item.price)
                            editedQty = "\(item.qty)"
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.neonGreen)
                                .padding(8)
                                .background(Color.neonGreen.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash.fill")
                                .font(.caption)
                                .foregroundStyle(.neonRed)
                                .padding(8)
                                .background(Color.neonRed.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(12)
                    .glassEffect(in: .rect(cornerRadius: 12))
                    
                    // Assignment display
                    let assignedNames = participants.filter { item.assigned.contains($0.id) }.map { $0.name }
                    if assignedNames.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text(" Tap to assign people")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(.neonRed)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    } else {
                        Text("For: " + assignedNames.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.glassText)
                            .lineLimit(2)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }
                }
                .sheet(isPresented: $showAssignSheet) {
                    AssignParticipantsSheet(
                        item: $item,
                        participants: participants
                    )
                }
            }
        }
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Participant Row (Inline Editing)

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
    
    private var headerSection: some View {
        HStack(spacing: 12) {
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
            
            Text(participant.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
            
            Spacer()
            
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
    
    private var inputSection: some View {
        HStack {
            Text("Share")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            
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
        .background(Color.black.opacity(0.15))
    }
    
    private var percentageInputView: some View {
        HStack(spacing: 12) {
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
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
            
            Text("=")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.3))
            
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
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }
    
    private var staticAmountView: some View {
        Text("\(currencySymbol) \(formatNumber(participant.amount))")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.neonGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.neonGreen.opacity(0.1))
            .cornerRadius(8)
    }
    
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
    let currencySymbol: String
    
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
                                
                                Text("\(Int(percentage))% = \(currencySymbol) \(formatNumber((percentage / 100.0) * totalAmount))")
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
                                Text(currencySymbol)
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
            amount = 0
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
    let currencySymbol: String
    
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
                                    Text(currencySymbol)
                                        .font(.subheadline)
                                        .foregroundStyle(.glassText)
                                    
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
struct ContactPickerView: UIViewControllerRepresentable {
    @Binding var participants: [SplitParticipant]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView
        init(_ parent: ContactPickerView) { self.parent = parent }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            DispatchQueue.main.async {
                for contact in contacts {
                    let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    let finalName = name.isEmpty ? (contact.organizationName.isEmpty ? "Unknown" : contact.organizationName) : name
                    if !self.parent.participants.contains(where: { $0.name == finalName }) {
                        self.parent.participants.append(SplitParticipant(name: finalName, amount: 0))
                    }
                }
            }
        }
    }
}

struct SingleContactPickerView: UIViewControllerRepresentable {
    @Binding var name: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: SingleContactPickerView
        init(_ parent: SingleContactPickerView) { self.parent = parent }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            DispatchQueue.main.async {
                let fullName = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                self.parent.name = fullName.isEmpty ? (contact.organizationName.isEmpty ? "Unknown" : contact.organizationName) : fullName
            }
        }
    }
}
#endif

// MARK: - Assign Participants Sheet

struct AssignParticipantsSheet: View {
    @Binding var item: SplitItem
    let participants: [SplitParticipant]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Item info header
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 40))
                            .foregroundStyle(.neonGreen)
                        
                        Text(item.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        
                        Text("\(item.qty)x @ Rp \(formatNumber(item.price))")
                            .font(.subheadline)
                            .foregroundStyle(.glassText)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glassEffect(in: .rect(cornerRadius: 16))
                    
                    if participants.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 50))
                                .foregroundStyle(.neonRed)
                            
                            Text("No Participants Yet")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("Add participants first before assigning items")
                                .font(.subheadline)
                                .foregroundStyle(.glassText)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("WHO SHARES THIS ITEM?")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.glassText)
                                Spacer()
                                Text("\(item.assigned.count) selected")
                                    .font(.caption)
                                    .foregroundStyle(.neonGreen)
                            }
                            
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(participants) { participant in
                                        Button {
                                            toggleAssignment(for: participant.id)
                                        } label: {
                                            HStack {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.neonGreen.opacity(0.15))
                                                        .frame(width: 36, height: 36)
                                                    
                                                    Text(participant.name.prefix(1).uppercased())
                                                        .font(.subheadline.weight(.bold))
                                                        .foregroundStyle(.neonGreen)
                                                }
                                                
                                                Text(participant.name)
                                                    .font(.body)
                                                    .foregroundStyle(.white)
                                                
                                                Spacer()
                                                
                                                if item.assigned.contains(participant.id) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.title3)
                                                        .foregroundStyle(.neonGreen)
                                                } else {
                                                    Image(systemName: "circle")
                                                        .font(.title3)
                                                        .foregroundStyle(.glassText)
                                                }
                                            }
                                            .padding(14)
                                            .glassEffect(in: .rect(cornerRadius: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // Quick actions
                            HStack(spacing: 12) {
                                Button("Select All") {
                                    item.assigned = Set(participants.map { $0.id })
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.neonGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .glassEffect(in: .rect(cornerRadius: 10))
                                
                                Button("Clear All") {
                                    item.assigned.removeAll()
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.neonRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .glassEffect(in: .rect(cornerRadius: 10))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Done")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                    }
                    .buttonStyle(.glassProminent)
                }
                .padding()
            }
            .navigationTitle("Assign Participants")
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
    
    private func toggleAssignment(for participantId: UUID) {
        if item.assigned.contains(participantId) {
            item.assigned.remove(participantId)
        } else {
            item.assigned.insert(participantId)
        }
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

#Preview {
    SplitBillView()
        .environment(AppStore())
        .environment(\.categoryManager, CategoryManager())
}
