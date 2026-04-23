
//
//  AddTransactionView.swift
//  Budget Expense
//

import SwiftUI

struct AddTransactionView: View {
    let wallet: Wallet
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var txType     = TransactionType.outflow
    @State private var amountText = ""
    @State private var category   = ""
    @State private var note       = ""
    @State private var date       = Date()

    private let inflowCats  = ["Salary", "Transfer In", "Sales", "Refund", "Gift", "Other"]
    private let outflowCats = ["Food", "Transport", "Shopping", "Bills", "Entertainment", "Health", "Other"]
    private var categories: [String] { txType == .inflow ? inflowCats : outflowCats }

    private var canSave: Bool {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        typeSelector
                        amountField
                        categoryField
                        noteField
                        datePicker
                        saveBtn
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle("New Transaction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.glassText)
                }
            }
        }
    }

    // MARK: Type Selector

    private var typeSelector: some View {
        HStack(spacing: 10) {
            txTypeBtn(.inflow,  "Inflow",  "arrow.down.circle.fill", .neonGreen)
            txTypeBtn(.outflow, "Outflow", "arrow.up.circle.fill",   .neonRed)
        }
    }

    // MARK: Amount

    private var amountField: some View {
        field("AMOUNT", "banknote") {
            HStack(spacing: 10) {
                Text(wallet.currency.symbol).font(.headline).foregroundStyle(.glassText).frame(minWidth: 24)
                TextField("0", text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .textFieldStyle(.plain).font(.title3.bold()).foregroundStyle(.white)
            }
            .padding(14).glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    // MARK: Category

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

    // MARK: Note

    private var noteField: some View {
        field("NOTE (optional)", "note.text") {
            TextField("e.g. Lunch, groceries…", text: $note)
                .textFieldStyle(.plain).font(.body).foregroundStyle(.white)
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    // MARK: Date

    private var datePicker: some View {
        field("DATE", "calendar") {
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Save

    private var saveBtn: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Save Transaction").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 17)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canSave).opacity(canSave ? 1 : 0.38)
    }

    // MARK: Helpers

    @ViewBuilder
    private func field<C: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(0.8)
            content()
        }
    }

    @ViewBuilder
    private func txTypeBtn(_ type: TransactionType, _ label: String, _ icon: String, _ color: Color) -> some View {
        Button { withAnimation(.spring(duration: 0.2)) { txType = type; category = "" } } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(txType == type ? color : Color(white: 0.3))
                Text(label).font(.subheadline.weight(txType == type ? .semibold : .regular))
                    .foregroundStyle(txType == type ? .white : Color(white: 0.38))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .glassEffect(txType == type ? .regular.tint(color) : .regular, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard amount > 0 else { return }
        let tx = WalletTransaction(
            walletId: wallet.id, amount: amount, type: txType,
            category: category, note: note, date: date
        )
        store.addTransaction(tx)
        dismiss()
    }
}
