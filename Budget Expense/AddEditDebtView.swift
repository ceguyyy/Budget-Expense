import SwiftUI

struct AddEditDebtView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let editTarget: Debt?

    @State private var personName = ""
    @State private var amountStr = ""
    @State private var currency: Currency = .idr
    @State private var note = ""
    @State private var date = Date()
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(86400 * 30)
    @State private var isSettled = false

    private var isEditing: Bool { editTarget != nil }
    private var title: String { isEditing ? "Edit Receivable" : "Add Receivable" }

    private var parsedAmount: Double {
        Double(amountStr.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var canSave: Bool {
        !personName.trimmingCharacters(in: .whitespaces).isEmpty && parsedAmount > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Preview card
                    previewCard
                        .padding(.top, 8)

                    // Form fields
                    VStack(spacing: 12) {
                        formSection {
                            fieldRow(label: "Name", systemImage: "person.fill") {
                                TextField("Who owes you?", text: $personName)
                                    .foregroundStyle(.white)
                            }
                        }

                        formSection {
                            // Currency Dropdown
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Currency", systemImage: "dollarsign.circle")
                                    .foregroundStyle(.white.opacity(0.7))
                                    .font(.subheadline)
                                
                                Menu {
                                    ForEach(Currency.allCases, id: \.self) { curr in
                                        Button {
                                            currency = curr
                                        } label: {
                                            HStack(spacing: 8) {
                                                Text(curr.flag)
                                                    .font(.body)
                                                Text(curr.name)
                                                Text("(\(curr.rawValue))")
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                Text(curr.symbol)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(currency.flag)
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(currency.name)
                                                .foregroundStyle(.white)
                                                .font(.body)
                                            Text(currency.rawValue)
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                        Spacer()
                                        Text(currency.symbol)
                                            .foregroundStyle(.white.opacity(0.6))
                                            .font(.headline)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    .padding(12)
                                    .background(Color(white: 0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }

                            Divider().background(.white.opacity(0.15))

                            fieldRow(label: "Amount", systemImage: "banknote") {
                                HStack(spacing: 8) {
                                    Text(currency.symbol)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .font(.subheadline)
                                    TextField("0", text: $amountStr)
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.trailing)
                                        #if os(iOS)
                                        .keyboardType(.decimalPad)
                                        #endif
                                }
                            }
                        }

                        formSection {
                            fieldRow(label: "Note", systemImage: "note.text") {
                                TextField("Optional", text: $note)
                                    .foregroundStyle(.white)
                            }

                            Divider().background(.white.opacity(0.15))

                            DatePicker("Date", selection: $date, displayedComponents: .date)
                                .foregroundStyle(.white.opacity(0.7))
                                .font(.subheadline)
                        }

                        formSection {
                            Toggle(isOn: $hasDueDate) {
                                Label("Due Date", systemImage: "calendar.badge.exclamationmark")
                                    .foregroundStyle(.white.opacity(0.7))
                                    .font(.subheadline)
                            }
                            .tint(Color.neonGreen)

                            if hasDueDate {
                                Divider().background(.white.opacity(0.15))
                                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .font(.subheadline)
                            }
                        }

                        if isEditing {
                            formSection {
                                Toggle(isOn: $isSettled) {
                                    Label("Settled", systemImage: "checkmark.seal.fill")
                                        .foregroundStyle(.white.opacity(0.7))
                                        .font(.subheadline)
                                }
                                .tint(Color.neonGreen)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(canSave ? Color.neonGreen : .white.opacity(0.3))
                        .disabled(!canSave)
                }
            }
            .onAppear { prefill() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.neonGreen.opacity(0.25))
                        .frame(width: 48, height: 48)
                    Text(personName.isEmpty ? "?" : String(personName.prefix(2)).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.neonGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(personName.isEmpty ? "Borrower's Name" : personName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if hasDueDate {
                        Text("Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(dueDate < Date() ? Color.neonRed : .white.opacity(0.6))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(currency == .idr ? formatIDR(parsedAmount) : "$\(String(format: "%.2f", parsedAmount))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.neonGreen)
                    Text(currency.rawValue)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func formSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func fieldRow<Content: View>(label: String, systemImage: String, @ViewBuilder field: () -> Content) -> some View {
        HStack {
            Label(label, systemImage: systemImage)
                .foregroundStyle(.white.opacity(0.7))
                .font(.subheadline)
                .frame(width: 100, alignment: .leading)
            Spacer()
            field()
        }
    }

    // MARK: - Actions

    private func prefill() {
        guard let t = editTarget else { return }
        personName = t.personName
        amountStr = String(format: "%.0f", t.amount)
        currency = t.currency
        note = t.note
        date = t.date
        if let dd = t.dueDate {
            hasDueDate = true
            dueDate = dd
        }
        isSettled = t.isSettled
    }

    private func save() {
        let trimmed = personName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, parsedAmount > 0 else { return }

        if let existing = editTarget {
            var updated = existing
            updated.personName = trimmed
            updated.amount = parsedAmount
            updated.currency = currency
            updated.note = note
            updated.date = date
            updated.dueDate = hasDueDate ? dueDate : nil
            updated.isSettled = isSettled
            store.updateDebt(updated)
        } else {
            let debt = Debt(
                personName: trimmed,
                amount: parsedAmount,
                currency: currency,
                note: note,
                date: date,
                dueDate: hasDueDate ? dueDate : nil,
                isSettled: false
            )
            store.addDebt(debt)
        }
        dismiss()
    }
}

#Preview {
    AddEditDebtView(editTarget: nil)
        .environment(AppStore())
}
