//
//  DebtListView.swift
//  Budget Expense
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
            ZStack(alignment: .bottomTrailing) {
                Color.appBg
                    .ignoresSafeArea()

                if store.debts.isEmpty {
                    emptyState
                } else {
                    debtList
                }
                
                fab
            }
            .navigationTitle("Receivables")
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
            if !activeDebts.isEmpty {
                VStack(spacing: 10) {
                    HStack {
                        Label("Total Active Receivables", systemImage: "person.2.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.glassText)
                        Spacer()
                        Text("\(activeDebts.count) people")
                            .font(.caption2)
                            .foregroundStyle(.dimText)
                    }

                    HStack(spacing: 0) {
                        if store.totalReceivablesIDR > 0 {
                            summaryPill("IDR", formatIDR(store.totalReceivablesIDR),
                                        Color(red: 0.3, green: 0.6, blue: 1.0))
                        }
                        if store.totalReceivablesUSD > 0 {
                            summaryPill("USD",
                                        String(format: "$%.2f", store.totalReceivablesUSD),
                                        .neonGreen)
                        }
                    }
                }
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 18))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                ForEach(activeDebts) { debt in
                    DebtRow(debt: debt)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .contextMenu {
                            Button {
                                editTarget = debt
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                var updated = debt
                                updated.isSettled = true
                                store.updateDebt(updated)
                            } label: {
                                Label("Mark Settled", systemImage: "checkmark.circle")
                            }
                            Button(role: .destructive) {
                                store.deleteDebt(debt.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                store.deleteDebt(debt.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                var updated = debt
                                updated.isSettled = true
                                store.updateDebt(updated)
                            } label: {
                                Label("Settled", systemImage: "checkmark.circle")
                            }
                            .tint(.neonGreen)
                        }
                        .swipeActions(edge: .leading) {
                            Button { editTarget = debt } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }

            if !settledDebts.isEmpty {
                DisclosureGroup(isExpanded: $showSettled) {
                    ForEach(settledDebts) { debt in
                        DebtRow(debt: debt)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.deleteDebt(debt.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } label: {
                    Text("Settled (\(settledDebts.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.glassText)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }

            Color.clear.frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - FAB

    private var fab: some View {
        Button {
            showAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color(red: 0.95, green: 0.4, blue: 0.2)) // Orange FAB
                .clipShape(Circle())
                .shadow(color: Color(red: 0.95, green: 0.4, blue: 0.2).opacity(0.4), radius: 8, x: 0, y: 4)
                .glassEffect(
                    .regular.tint(Color(white: 0.7)),
                    in: Circle()
                )
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private func summaryPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.dimText)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(white: 0.07))
                    .frame(width: 96, height: 96)

                Image(systemName: "person.2")
                    .font(.system(size: 38))
                    .foregroundStyle(Color(white: 0.28))
            }

            VStack(spacing: 6) {
                Text("No Receivables Yet")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("Tap + to add a receivable")
                    .font(.subheadline)
                    .foregroundStyle(.glassText)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Row

struct DebtRow: View {
    let debt: Debt
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(debt.isSettled ? Color.neonGreen.opacity(0.1)
                                             : Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.12))
                        .frame(width: 46, height: 46)

                    Text(debt.initials)
                        .font(.subheadline.bold())
                        .foregroundStyle(debt.isSettled ? .neonGreen
                                                        : Color(red: 0.3, green: 0.6, blue: 1.0))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(debt.personName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !debt.note.isEmpty {
                        Text(debt.note)
                            .font(.caption)
                            .foregroundStyle(.glassText)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        Text(debt.date, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.dimText)

                        if let due = debt.dueDate {
                            Text("·").foregroundStyle(.dimText)
                            Text("Due: \(due, style: .date)")
                                .font(.caption2)
                                .foregroundStyle(due < Date() && !debt.isSettled ? .neonRed : .dimText)
                        }
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(debt.formattedAmount())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(debt.isSettled ? .neonGreen
                                                        : Color(red: 0.3, green: 0.6, blue: 1.0))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(debt.isSettled ? "Settled" : "Outstanding")
                        .font(.caption2)
                        .foregroundStyle(debt.isSettled ? .neonGreen.opacity(0.7) : .dimText)
                }
                
                // Expand chevron if there are items
                if let items = debt.items, !items.isEmpty {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(.dimText)
                        .font(.caption)
                        .padding(.leading, 4)
                }
            }
            .contentShape(Rectangle()) // Makes the whole area tappable for expanding
            .onTapGesture {
                if let items = debt.items, !items.isEmpty {
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }
            }
            
            // Expandable Items List
            if isExpanded, let items = debt.items, !items.isEmpty {
                VStack(spacing: 8) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 6)
                    
                    ForEach(items) { item in
                        HStack {
                            Text(item.name)
                                .font(.caption)
                                .foregroundStyle(.glassText)
                            Spacer()
                            Text("\(debt.currency.symbol) \(formatNumber(item.amount))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassEffect(in: .rect(cornerRadius: 17))
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
