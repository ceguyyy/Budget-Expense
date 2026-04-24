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
                // Summary Card
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TOTAL RECEIVABLES")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.glassText)
                                .kerning(1)
                            Text("\(activeDebts.count) Active People")
                                .font(.caption2)
                                .foregroundStyle(.dimText)
                        }
                        Spacer()
                    }

                    HStack(spacing: 0) {
                        summaryItem("IDR", store.totalDebit, Color(red: 0.3, green: 0.6, blue: 1.0))
                        Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                        summaryItem("LIQUIDITY", store.liquidity, .neonGreen)
                    }
                }
                .padding(20)
                .glassEffect(in: .rect(cornerRadius: 22))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))

                ForEach(activeDebts) { debt in
                    NavigationLink(destination: DebtDetailView(debt: debt).environment(store)) {
                        DebtRow(debt: debt)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
                    }
                } label: {
                    HStack {
                        Text("Settled History")
                        Spacer()
                        Text("\(settledDebts.count)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1), in: Capsule())
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.glassText)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Color.clear.frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func summaryItem(_ label: String, _ amount: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.dimText)
            Text(formatCurrency(amount, currency: .idr))
                .font(.headline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
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
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(debt.isSettled ? Color.neonGreen.opacity(0.1)
                                         : Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.12))
                    .frame(width: 48, height: 48)

                Text(debt.initials)
                    .font(.subheadline.bold())
                    .foregroundStyle(debt.isSettled ? .neonGreen
                                                    : Color(red: 0.3, green: 0.6, blue: 1.0))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(debt.personName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(debt.date, style: .date)
                        .font(.system(size: 10))
                        .foregroundStyle(.dimText)

                    if let due = debt.dueDate {
                        Circle().fill(Color.white.opacity(0.2)).frame(width: 2, height: 2)
                        Text("Due \(due, style: .date)")
                            .font(.system(size: 10))
                            .foregroundStyle(due < Date() && !debt.isSettled ? .neonRed : .dimText)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(debt.formattedAmount())
                    .font(.subheadline.bold())
                    .foregroundStyle(debt.isSettled ? .neonGreen : .white)
                
                Text(debt.isSettled ? "Settled" : "Outstanding")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(debt.isSettled ? Color.neonGreen.opacity(0.15) : Color.white.opacity(0.05), in: Capsule())
                    .foregroundStyle(debt.isSettled ? .neonGreen : .dimText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 20))
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
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Status Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(debt.isSettled ? Color.neonGreen.opacity(0.15)
                                                     : Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Text(debt.initials)
                                .font(.title.bold())
                                .foregroundStyle(debt.isSettled ? .neonGreen
                                                                : Color(red: 0.3, green: 0.6, blue: 1.0))
                        }
                        
                        VStack(spacing: 8) {
                            Text(debt.personName)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            Text(debt.formattedAmount())
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(debt.isSettled ? .neonGreen : .white)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: debt.isSettled ? "checkmark.circle.fill" : "clock.fill")
                            Text(debt.isSettled ? "Payment Settled" : "Awaiting Payment")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(debt.isSettled ? .neonGreen : Color(red: 0.3, green: 0.6, blue: 1.0))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(debt.isSettled ? Color.neonGreen.opacity(0.1) : Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity)
                    .glassEffect(in: .rect(cornerRadius: 26))
                    
                    // Info List
                    VStack(alignment: .leading, spacing: 12) {
                        Label("INFORMATION", systemImage: "info.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.glassText)
                            .kerning(1.2)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            detailRow(label: "Issued Date", value: debt.date.formatted(date: .long, time: .omitted), icon: "calendar")
                            Divider().background(Color.white.opacity(0.08)).padding(.leading, 44)
                            
                            if let due = debt.dueDate {
                                detailRow(label: "Due Date", value: due.formatted(date: .long, time: .omitted), icon: "clock.badge.exclamationmark")
                                    .foregroundStyle(due < Date() && !debt.isSettled ? .neonRed : .white)
                                Divider().background(Color.white.opacity(0.08)).padding(.leading, 44)
                            }
                            
                            detailRow(label: "Note", value: debt.note.isEmpty ? "No notes added" : debt.note, icon: "note.text")
                        }
                        .glassEffect(in: .rect(cornerRadius: 22))
                    }
                    
                    // Allocated Items
                    if let items = debt.items, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("ALLOCATED ITEMS", systemImage: "list.bullet.rectangle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.glassText)
                                .kerning(1.2)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 0) {
                                ForEach(items) { item in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.05))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: "tag.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.glassText)
                                        }
                                        
                                        Text(item.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                        
                                        Text("\(debt.currency.symbol) \(formatNumber(item.amount))")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    
                                    if item.id != items.last?.id {
                                        Divider().background(Color.white.opacity(0.08)).padding(.leading, 64)
                                    }
                                }
                            }
                            .glassEffect(in: .rect(cornerRadius: 22))
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Receivable Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                }
                .tint(Color(red: 0.3, green: 0.6, blue: 1.0))
            }
        }
        .sheet(isPresented: $showEdit) {
            AddEditDebtView(editTarget: debt)
                .environment(store)
        }
    }
    
    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.glassText)
            }
            
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.glassText)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
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

