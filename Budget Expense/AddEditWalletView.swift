
//
//  AddEditWalletView.swift
//  Budget Expense
//

import SwiftUI

struct AddEditWalletView: View {
    let editTarget: Wallet?
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name        = ""
    @State private var balanceText = ""
    @State private var currency    = Currency.idr
    @State private var isPositive  = true

    private var isEditMode: Bool { editTarget != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(balanceText.replacingOccurrences(of: ",", with: ".")) != nil
    }
    private var parsedBalance: Double {
        Double(balanceText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var previewWallet: Wallet {
        Wallet(name: name.isEmpty ? "Nama Wallet" : name,
               balance: parsedBalance, currency: currency, isPositive: isPositive)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        previewCard
                        fields
                        saveBtn
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditMode ? "Edit Wallet" : "Wallet Baru")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }.foregroundStyle(.glassText)
                }
            }
            .onAppear { prefill() }
        }
    }

    // MARK: Live Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PREVIEW").font(.caption2.weight(.semibold)).foregroundStyle(.dimText).kerning(1.5)
                .padding(.leading, 4)
            WalletListRow(wallet: previewWallet)
        }
    }

    // MARK: Fields

    private var fields: some View {
        VStack(spacing: 20) {
            // Name
            field(title: "NAMA WALLET", icon: "wallet.bifold") {
                TextField("e.g. BCA, GoPay, Dana…", text: $name)
                    .textFieldStyle(.plain).font(.body).foregroundStyle(.white)
                    .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            // Currency
            field(title: "MATA UANG", icon: "globe") {
                HStack(spacing: 10) {
                    ForEach(Currency.allCases, id: \.self) { c in
                        Button { withAnimation(.spring(duration: 0.2)) { currency = c } } label: {
                            VStack(spacing: 3) {
                                Text(c.symbol).font(.title3.bold())
                                Text(c.rawValue).font(.caption2.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .glassEffect(currency == c ? .regular.tint(Color(white: 0.6)) : .regular,
                                         in: .rect(cornerRadius: 12))
                            .foregroundStyle(currency == c ? .white : Color(white: 0.38))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Balance
            field(title: "SALDO", icon: "banknote") {
                HStack(spacing: 10) {
                    Text(currency.symbol).font(.headline).foregroundStyle(.glassText).frame(minWidth: 24)
                    TextField("0", text: $balanceText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .textFieldStyle(.plain).font(.headline).foregroundStyle(.white)
                }
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            // Type
            field(title: "TIPE", icon: "plusminus") {
                HStack(spacing: 10) {
                    typeBtn("Aset / Masuk", "arrow.up.circle.fill", true,  .neonGreen)
                    typeBtn("Liabilitas",   "arrow.down.circle.fill", false, .neonRed)
                }
            }
        }
    }

    private var saveBtn: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: isEditMode ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(isEditMode ? "Simpan Perubahan" : "Tambah Wallet").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 17)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canSave).opacity(canSave ? 1 : 0.38)
    }

    // MARK: Helpers

    @ViewBuilder
    private func field<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(0.8)
            content()
        }
    }

    @ViewBuilder
    private func typeBtn(_ title: String, _ icon: String, _ value: Bool, _ color: Color) -> some View {
        Button { withAnimation(.spring(duration: 0.2)) { isPositive = value } } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3)
                    .foregroundStyle(isPositive == value ? color : Color(white: 0.28))
                Text(title).font(.caption2.weight(isPositive == value ? .semibold : .regular))
                    .foregroundStyle(isPositive == value ? .white : Color(white: 0.38))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .glassEffect(isPositive == value ? .regular.tint(color) : .regular, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func prefill() {
        guard let w = editTarget else { return }
        name        = w.name
        balanceText = "\(Int(w.balance))"
        currency    = w.currency
        isPositive  = w.isPositive
    }

    private func save() {
        let w = Wallet(id: editTarget?.id ?? UUID(),
                       name: name.trimmingCharacters(in: .whitespaces),
                       balance: parsedBalance, currency: currency, isPositive: isPositive)
        if isEditMode { store.updateWallet(w) } else { store.addWallet(w) }
        dismiss()
    }
}
