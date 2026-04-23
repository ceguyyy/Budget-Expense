//
//  AddCCTransactionView.swift
//  Budget Expense
//

import SwiftUI

struct AddCreditCardTransactionView: View {
    let card: CreditCard
    var editTarget: CCTransaction? = nil
    
    @Environment(AppStore.self) private var store
    @Environment(\.categoryManager) private var categoryManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var amountText = ""
    @State private var category   = ""
    @State private var description = ""
    @State private var date       = Date()
    
    private var categories: [String] {
        // Credit card transactions are always outflow (expenses)
        categoryManager.categoryNames(for: .outflow)
    }
    
    private var canSave: Bool {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 > 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        amountField
                        categoryField
                        noteField
                        datePicker
                        saveBtn
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle(editTarget != nil ? "Edit Transaction" : "New Transaction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.glassText)
                }
            }
            .onAppear {
                prefill()
            }
        }
    }
    
    // MARK: - Amount
    
    private var amountField: some View {
        field("AMOUNT", "banknote") {
            HStack(spacing: 10) {
                Text("Rp").font(.headline).foregroundStyle(.glassText).frame(minWidth: 24)
                TextField("0", text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .textFieldStyle(.plain).font(.title3.bold()).foregroundStyle(.white)
            }
            .padding(14).glassEffect(in: .rect(cornerRadius: 14))
        }
    }
    
    // MARK: - Category
    
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
                        .font(.caption).foregroundStyle(.dimText)
                }
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Description
    
    private var noteField: some View {
        field("DESCRIPTION (optional)", "note.text") {
            TextField("e.g. Lunch, groceries…", text: $description)
                .textFieldStyle(.plain).font(.body).foregroundStyle(.white)
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
        }
    }
    
    // MARK: - Date
    
    private var datePicker: some View {
        field("DATE", "calendar") {
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Save
    
    private var saveBtn: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(editTarget != nil ? "Save Changes" : "Save Transaction").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 17)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canSave).opacity(canSave ? 1 : 0.38)
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func field<C: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(0.8)
            content()
        }
    }
    
    private func prefill() {
        guard let tx = editTarget else { return }
        amountText = tx.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", tx.amount) : "\(tx.amount)"
        category = tx.category
        description = tx.description
        date = tx.date
    }
    
    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard amount > 0 else { return }
        let tx = CCTransaction(
            id: editTarget?.id ?? UUID(),
            description: description,
            amount: amount,
            category: category,
            date: date
        )
        
        if let oldTx = editTarget {
            // Delete old transaction and add updated one
            store.deleteCCTransaction(oldTx.id, from: card.id)
            store.addCCTransaction(tx, to: card.id)
        } else {
            store.addCCTransaction(tx, to: card.id)
        }
        dismiss()
    }
}
