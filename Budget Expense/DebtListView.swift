
//
//  DebtListView.swift
//  Budget Expense
//  Piutang — money that others owe you
//

import SwiftUI

struct DebtListView: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd    = false
    @State private var editTarget: Debt?
    @State private var showSettled = false

    private var activeDebts:  [Debt] { store.debts.filter { !$0.isSettled }.sorted { $0.date > $1.date } }
    private var settledDebts: [Debt] { store.debts.filter {  $0.isSettled }.sorted { $0.date > $1.date } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                if store.debts.isEmpty { emptyState } else { debtList }
            }
            .navigationTitle("Piutang")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                    .buttonStyle(.glass)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditDebtView(editTarget: nil).environment(store)
            }
            .sheet(item: $editTarget) { d in
                AddEditDebtView(editTarget: d).environment(store)
            }
        }
    }

    // MARK: Debt List

    private var debtList: some View {
        List {
            // Summary header
            if !activeDebts.isEmpty {
                VStack(spacing: 10) {
                    HStack {
                        Label("Total Piutang Aktif", systemImage: "person.2.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(.glassText)
                        Spacer()
                        Text("\(activeDebts.count) orang").font(.caption2).foregroundStyle(.dimText)
                    }
                    HStack(spacing: 0) {
                        if store.totalReceivablesIDR > 0 {
                            summaryPill("IDR", formatIDR(store.totalReceivablesIDR), Color(red: 0.3, green: 0.6, blue: 1.0))
                        }
                        if store.totalReceivablesUSD > 0 {
                            summaryPill("USD", String(format: "$%.2f", store.totalReceivablesUSD), .neonGreen)
                        }
                    }
                }
                .padding(16).glassEffect(in: .rect(cornerRadius: 18))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                // Active debts
                ForEach(activeDebts) { debt in
                    DebtRow(debt: debt)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { store.deleteDebt(debt.id) }
                            label: { Label("Hapus", systemImage: "trash") }

                            Button {
                                var updated = debt; updated.isSettled = true
                                store.updateDebt(updated)
                            } label: {
                                Label("Lunas", systemImage: "checkmark.circle")
                            }
                            .tint(.neonGreen)
                        }
                        .swipeActions(edge: .leading) {
                            Button { editTarget = debt }
                            label: { Label("Edit", systemImage: "pencil") }
                            .tint(.blue)
                        }
                }
            }

            // Settled debts disclosure
            if !settledDebts.isEmpty {
                DisclosureGroup(isExpanded: $showSettled) {
                    ForEach(settledDebts) { debt in
                        DebtRow(debt: debt)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { store.deleteDebt(debt.id) }
                                label: { Label("Hapus", systemImage: "trash") }
                            }
                    }
                } label: {
                    Text("Sudah Lunas (\(settledDebts.count))")
                        .font(.caption.weight(.semibold)).foregroundStyle(.glassText)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }

            Color.clear.frame(height: 40).listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
    }

    private func summaryPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.dimText)
            Text(value).font(.subheadline.bold()).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.07)).frame(width: 96, height: 96)
                Image(systemName: "person.2").font(.system(size: 38)).foregroundStyle(Color(white: 0.28))
            }
            VStack(spacing: 6) {
                Text("Belum Ada Piutang").font(.title3.bold()).foregroundStyle(.white)
                Text("Tap + untuk mencatat piutang").font(.subheadline).foregroundStyle(.glassText)
            }
            Spacer()
        }
    }
}

// MARK: - Debt Row

struct DebtRow: View {
    let debt: Debt
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(debt.isSettled ? Color.neonGreen.opacity(0.1) : Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.12))
                    .frame(width: 46, height: 46)
                Text(debt.initials).font(.subheadline.bold())
                    .foregroundStyle(debt.isSettled ? .neonGreen : Color(red: 0.3, green: 0.6, blue: 1.0))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(debt.personName).font(.headline).foregroundStyle(.white).lineLimit(1)
                if !debt.note.isEmpty {
                    Text(debt.note).font(.caption).foregroundStyle(.glassText).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(debt.date, style: .date).font(.caption2).foregroundStyle(.dimText)
                    if let due = debt.dueDate {
                        Text("·").foregroundStyle(.dimText).font(.caption2)
                        Text("Due: \(due, style: .date)").font(.caption2)
                            .foregroundStyle(due < Date() && !debt.isSettled ? .neonRed : .dimText)
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(debt.formattedAmount())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(debt.isSettled ? .neonGreen : Color(red: 0.3, green: 0.6, blue: 1.0))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(debt.isSettled ? "Lunas" : "Belum Bayar")
                    .font(.caption2)
                    .foregroundStyle(debt.isSettled ? .neonGreen.opacity(0.7) : .dimText)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .glassEffect(in: .rect(cornerRadius: 17))
    }
}
