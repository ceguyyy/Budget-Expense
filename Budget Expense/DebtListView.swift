//
//  DebtListView.swift
//  Budget Expense
//

import SwiftUI

struct DebtListView: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd    = false
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
              
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                ForEach(activeDebts) { debt in
                    // Navigate to detail view rather than expanding inline
                    NavigationLink(destination: DebtDetailView(debt: debt).environment(store)) {
                        DebtRow(debt: debt)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
                }
            }

            if !settledDebts.isEmpty {
                DisclosureGroup(isExpanded: $showSettled) {
                    ForEach(settledDebts) { debt in
                        NavigationLink(destination: DebtDetailView(debt: debt).environment(store)) {
                            DebtRow(debt: debt)
                        }
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

    var body: some View {
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
            
            // Remove chevron logic here since NavigationLink adds its own chevron
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassEffect(in: .rect(cornerRadius: 17))
    }
}

// MARK: - Detail View (Read-Only)

struct DebtDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    
    let debt: Debt
    
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Main Status Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(debt.isSettled ? Color.neonGreen.opacity(0.15)
                                                     : Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.15))
                                .frame(width: 72, height: 72)
                            
                            Text(debt.initials)
                                .font(.title.bold())
                                .foregroundStyle(debt.isSettled ? .neonGreen
                                                                : Color(red: 0.3, green: 0.6, blue: 1.0))
                        }
                        
                        Text(debt.personName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text(debt.formattedAmount())
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(debt.isSettled ? .neonGreen : .white)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(debt.isSettled ? Color.neonGreen : Color.neonRed)
                                .frame(width: 8, height: 8)
                            Text(debt.isSettled ? "Settled" : "Outstanding")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(debt.isSettled ? .neonGreen : .neonRed)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glassEffect(in: .rect(cornerRadius: 20))
                    
                    // Info Section
                    VStack(spacing: 0) {
                        detailRow(label: "Date", value: debt.date.formatted(date: .long, time: .omitted))
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 16)
                        if let due = debt.dueDate {
                            detailRow(label: "Due Date", value: due.formatted(date: .long, time: .omitted))
                                .foregroundStyle(due < Date() && !debt.isSettled ? .neonRed : .white)
                            Divider().background(Color.white.opacity(0.1)).padding(.leading, 16)
                        }
                        detailRow(label: "Note", value: debt.note.isEmpty ? "None" : debt.note)
                    }
                    .glassEffect(in: .rect(cornerRadius: 16))
                    
                    // Specific Split Bill Items Breakdown (If Any)
                    if let items = debt.items, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Allocated Items")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.glassText)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                ForEach(items) { item in
                                    HStack {
                                        Text(item.name)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text("\(debt.currency.symbol) \(formatNumber(item.amount))")
                                            .foregroundStyle(.white)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    
                                    if item.id != items.last?.id {
                                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 16)
                                    }
                                }
                            }
                            .glassEffect(in: .rect(cornerRadius: 16))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showEdit = true
                }
                .tint(Color(red: 0.3, green: 0.6, blue: 1.0))
            }
        }
        .sheet(isPresented: $showEdit) {
            AddEditDebtView(editTarget: debt)
                .environment(store)
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.glassText)
                .frame(width: 80, alignment: .leading)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}


#Preview {
    DebtListView()
        .environment(AppStore())
        .environment(\.categoryManager, CategoryManager())
}

