
//
//  AddEditCreditCardView.swift
//  Budget Expense
//

import SwiftUI

struct AddEditCreditCardView: View {
    let editTarget: CreditCard?
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name           = ""
    @State private var bank           = ""
    @State private var limitText      = ""
    @State private var billingDay     = 25
    @State private var dueDay         = 10
    @State private var colorIndex     = 0

    private var isEditMode: Bool { editTarget != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !bank.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(limitText.replacingOccurrences(of: ",", with: ".")) != nil
    }
    private var parsedLimit: Double {
        Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        cardPreview
                        fields
                        saveBtn
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditMode ? "Edit Credit Card" : "New Credit Card")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.glassText)
                }
            }
            .onAppear { prefill() }
        }
    }

    // MARK: Card Preview

    private var cardPreview: some View {
        let previewCard = CreditCard(name: name.isEmpty ? "Card Name" : name,
                                     bank: bank.isEmpty ? "Bank" : bank,
                                     limit: parsedLimit, billingCycleDay: billingDay,
                                     dueDay: dueDay, colorIndex: colorIndex)
        return ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [previewCard.cardColor, previewCard.cardColor.opacity(0.55)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 150)
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bank.isEmpty ? "Bank" : bank)
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                        Text(name.isEmpty ? "Card Name" : name)
                            .font(.headline.bold()).foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "creditcard.fill").font(.title2).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text("Limit: \(formatIDR(parsedLimit))").font(.caption.bold()).foregroundStyle(.white)
            }
            .padding(18)
        }
    }

    // MARK: Fields

    private var fields: some View {
        VStack(spacing: 20) {
            // Name
            field("CARD NAME", "creditcard") {
                TextField("e.g. BCA Platinum, Visa 1234", text: $name)
                    .textFieldStyle(.plain).font(.body).foregroundStyle(.white)
                    .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            // Bank
            field("BANK", "building.columns") {
                TextField("e.g. BCA, Mandiri, BNI", text: $bank)
                    .textFieldStyle(.plain).font(.body).foregroundStyle(.white)
                    .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            // Limit
            field("CARD LIMIT", "banknote") {
                HStack(spacing: 10) {
                    Text("Rp").font(.headline).foregroundStyle(.glassText)
                    TextField("0", text: $limitText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .textFieldStyle(.plain).font(.headline).foregroundStyle(.white)
                }
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            // Billing & Due days
            field("BILLING CYCLE", "calendar") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cycle Start Day").font(.caption2).foregroundStyle(.dimText)
                        Stepper("\(billingDay)", value: $billingDay, in: 1...28)
                            .foregroundStyle(.white)
                            .padding(10).glassEffect(in: .rect(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Due Day").font(.caption2).foregroundStyle(.dimText)
                        Stepper("\(dueDay)", value: $dueDay, in: 1...28)
                            .foregroundStyle(.white)
                            .padding(10).glassEffect(in: .rect(cornerRadius: 12))
                    }
                }
            }

            // Color
            field("CARD COLOR", "paintpalette") {
                HStack(spacing: 10) {
                    ForEach(CreditCard.palette.indices, id: \.self) { i in
                        Button { withAnimation { colorIndex = i } } label: {
                            ZStack {
                                Circle().fill(CreditCard.palette[i]).frame(width: 36, height: 36)
                                if colorIndex == i {
                                    Circle().stroke(.white, lineWidth: 2.5).frame(width: 36, height: 36)
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(12).glassEffect(in: .rect(cornerRadius: 14))
            }
        }
    }

    private var saveBtn: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: isEditMode ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(isEditMode ? "Save Changes" : "Add Card").fontWeight(.semibold)
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

    private func prefill() {
        guard let c = editTarget else { return }
        name       = c.name
        bank       = c.bank
        limitText  = "\(Int(c.limit))"
        billingDay = c.billingCycleDay
        dueDay     = c.dueDay
        colorIndex = c.colorIndex
    }

    private func save() {
        let card = CreditCard(
            id: editTarget?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            bank: bank.trimmingCharacters(in: .whitespaces),
            limit: parsedLimit, billingCycleDay: billingDay, dueDay: dueDay,
            colorIndex: colorIndex,
            transactions: editTarget?.transactions ?? [],
            installments: editTarget?.installments ?? []
        )
        if isEditMode { store.updateCreditCard(card) } else { store.addCreditCard(card) }
        dismiss()
    }
}

// MARK: - Add CC Transaction View

struct AddCCTransactionView: View {
    let card: CreditCard
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var descText  = ""
    @State private var amountText = ""
    @State private var category  = ""
    @State private var date      = Date()

    private let cats = ["Shopping", "Food", "Transport", "Entertainment", "Bills", "Travel", "Health", "Other"]
    private var canSave: Bool {
        !descText.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(amountText.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Description
                        field("DESCRIPTION", "text.alignleft") {
                            TextField("e.g. Shopee purchase…", text: $descText)
                                .textFieldStyle(.plain).font(.body).foregroundStyle(.white)
                                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
                        }
                        // Amount
                        field("AMOUNT (IDR)", "banknote") {
                            HStack(spacing: 10) {
                                Text("Rp").font(.headline).foregroundStyle(.glassText)
                                TextField("0", text: $amountText)
                                    #if os(iOS)
                                    .keyboardType(.numberPad)
                                    #endif
                                    .textFieldStyle(.plain).font(.headline).foregroundStyle(.white)
                            }
                            .padding(14).glassEffect(in: .rect(cornerRadius: 14))
                        }
                        // Category
                        field("CATEGORY", "tag") {
                            Menu {
                                ForEach(cats, id: \.self) { c in Button(c) { category = c } }
                            } label: {
                                HStack {
                                    Text(category.isEmpty ? "Select category…" : category)
                                        .foregroundStyle(category.isEmpty ? Color(white: 0.35) : .white).font(.body)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.dimText)
                                }
                                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                        // Date
                        field("DATE", "calendar") {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact).labelsHidden()
                                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // Save
                        Button(action: save) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Transaction").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 17)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave).opacity(canSave ? 1 : 0.38)
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle("Credit Card Transaction")
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

    @ViewBuilder
    private func field<C: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(0.8)
            content()
        }
    }

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let tx = CCTransaction(description: descText.trimmingCharacters(in: .whitespaces),
                               amount: amount, category: category, date: date)
        store.addCCTransaction(tx, to: card.id)
        dismiss()
    }
}
