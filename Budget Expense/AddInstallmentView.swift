//
//  AddInstallmentView.swift
//  Budget Expense
//

import SwiftUI

struct AddInstallmentView: View {
    let editTarget: Installment?
    let cardId: UUID
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var desc          = ""
    @State private var principalText = ""
    @State private var interestText  = "0"
    @State private var monthsText    = "12" // ✅ Diubah menjadi String agar bisa diketik custom
    @State private var startDate     = Date()

    private var isEditMode: Bool { editTarget != nil }
    private var principal: Double { Double(principalText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var annualRate: Double { (Double(interestText.replacingOccurrences(of: ",", with: ".")) ?? 0) / 100 }
    private var months: Int { Int(monthsText) ?? 0 } // ✅ Konversi ke Int
    
    private var monthly: Double {
        guard principal > 0, months > 0 else { return 0 }
        let interest = principal * annualRate * Double(months) / 12
        return (principal + interest) / Double(months)
    }
    private var canSave: Bool {
        !desc.trimmingCharacters(in: .whitespaces).isEmpty && principal > 0 && months > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        // Preview card
                        if principal > 0 {
                            installmentPreview
                        }
                        fields
                        saveBtn
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditMode ? "Edit Installment" : "New Installment")
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

    // MARK: Preview

    private var installmentPreview: some View {
        VStack(spacing: 10) {
            HStack {
                Text("INSTALLMENT ESTIMATE")
                    .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(1.2)
                Spacer()
            }
            HStack(spacing: 0) {
                previewPill("Principal", formatIDR(principal), Color(red: 0.3, green: 0.6, blue: 1))
                previewPill("Int/mo", annualRate > 0 ? String(format: "%.2f%%", annualRate * 100 / 12) : "0%",
                             Color(red: 0.92, green: 0.66, blue: 0.10))
                previewPill("/month", formatIDR(monthly), .neonGreen)
            }
            .padding(16).glassEffect(in: .rect(cornerRadius: 16))
        }
    }

    private func previewPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.dimText)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Fields

    private var fields: some View {
        VStack(spacing: 20) {
            field("DESCRIPTION", "text.alignleft") {
                TextField("e.g. iPhone 15, Kulkas…", text: $desc)
                    .textFieldStyle(.plain).font(.body).foregroundStyle(.white)
                    .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            field("TOTAL AMOUNT", "banknote") {
                HStack(spacing: 10) {
                    Text("Rp").font(.headline).foregroundStyle(.glassText)
                    TextField("0", text: $principalText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .textFieldStyle(.plain).font(.headline).foregroundStyle(.white)
                }
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            field("ANNUAL INTEREST (%)", "percent") {
                HStack(spacing: 10) {
                    TextField("0", text: $interestText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .textFieldStyle(.plain).font(.headline).foregroundStyle(.white)
                    Text("%").font(.headline).foregroundStyle(.glassText)
                }
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            // ✅ Diubah menjadi TextField agar bisa input custom
            field("INSTALLMENT MONTHS", "calendar.badge.clock") {
                HStack(spacing: 10) {
                    TextField("e.g. 12", text: $monthsText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .textFieldStyle(.plain).font(.headline).foregroundStyle(.white)
                    Text("Months").font(.headline).foregroundStyle(.glassText)
                }
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            field("START DATE", "calendar") {
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact).labelsHidden()
                    .padding(14).glassEffect(in: .rect(cornerRadius: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var saveBtn: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: isEditMode ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(isEditMode ? "Save Installment" : "Add Installment").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 17)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canSave).opacity(canSave ? 1 : 0.38)
    }

    @ViewBuilder
    private func field<C: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(0.8)
            content()
        }
    }

    private func prefill() {
        guard let i = editTarget else { return }
        desc          = i.description
        principalText = "\(Int(i.totalPrincipal))"
        interestText  = String(format: "%.1f", i.annualInterestRate * 100)
        monthsText    = "\(i.totalMonths)" // ✅ Load old month data correctly
        startDate     = i.startDate
    }

    private func save() {
        let inst = Installment(
            id: editTarget?.id ?? UUID(),
            description: desc.trimmingCharacters(in: .whitespaces),
            totalPrincipal: principal,
            annualInterestRate: annualRate,
            totalMonths: months,
            startDate: startDate,
            paidMonths: editTarget?.paidMonths ?? 0
        )
        if isEditMode { store.updateInstallment(inst, in: cardId) }
        else          { store.addInstallment(inst, to: cardId) }
        dismiss()
    }
}
