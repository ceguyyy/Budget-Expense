//
//  CreditCardDetailView.swift
//  Budget Expense
//

import SwiftUI

struct CreditCardDetailView: View {
    let cardId: UUID
    @Environment(AppStore.self) private var store
    
    @State private var showAddTx     = false
    @State private var editTxTarget: CCTransaction?
    
    @State private var showAddInst   = false
    @State private var editInstTarget: Installment?

    private var card: CreditCard? { store.creditCards.first { $0.id == cardId } }
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            if let card {
                List {
                    cardHeroView(card)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 14, trailing: 16))
                        
                    billingInfoCard(card)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 14, trailing: 16))
                        
                    payNowButton(card)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 20, trailing: 16))
                        
                    // Unrolled sections using @ViewBuilder directly into the List
                    transactionsSection(card)
                        
                    installmentsSection(card)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(card?.name ?? "Credit Card")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showAddTx   = true } label: { Label("Add Transaction",  systemImage: "plus.circle") }
                    Button { showAddInst = true } label: { Label("Add Installment",  systemImage: "clock.badge") }
                } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
                .buttonStyle(.glass)
            }
        }
        .sheet(isPresented: $showAddTx) {
            if let card { AddCreditCardTransactionView(card: card).environment(store) }
        }
        .sheet(item: $editTxTarget) { tx in
            if let card { AddCreditCardTransactionView(card: card, editTarget: tx).environment(store) }
        }
        .sheet(isPresented: $showAddInst) {
            if let card { AddInstallmentView(editTarget: nil, cardId: card.id).environment(store) }
        }
        .sheet(item: $editInstTarget) { inst in
            if let card { AddInstallmentView(editTarget: inst, cardId: card.id).environment(store) }
        }
    }

    // MARK: Card Hero (visual card)

    private func cardHeroView(_ card: CreditCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.bank)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.8))
                    Text(card.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                
                // Chip icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Color(white: 0.9), Color(white: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 45, height: 32)
                    .overlay(
                        VStack(spacing: 5) {
                            ForEach(0..<4) { _ in
                                Rectangle().fill(Color.black.opacity(0.1)).frame(height: 1.2)
                            }
                        }
                    )
            }
            .padding(.bottom, 32)
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL OUTSTANDING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .kerning(1.2)
                    Text(formatCurrency(card.totalUsedLimit, currency: card.currency))
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "creditcard.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.2))
            }
            
            Spacer(minLength: 24)
            
            VStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.white, .white.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * card.usedPercent, height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LIMIT").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                        Text(formatCurrency(card.limit, currency: card.currency)).font(.caption.bold()).foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("REMAINING").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                        Text(formatCurrency(card.remainingLimit, currency: card.currency))
                            .font(.caption.bold())
                            .foregroundStyle(card.usedPercent > 0.8 ? Color.neonRed : .white.opacity(0.9))
                    }
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                LinearGradient(
                    colors: [card.cardColor, card.cardColor.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Reflections
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 250, height: 100)
                    .rotationEffect(.degrees(-35))
                    .offset(x: 100, y: -80)
                
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 200, height: 200)
                    .offset(x: -100, y: 80)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: card.cardColor.opacity(0.4), radius: 12, x: 0, y: 6)
    }

    // MARK: Billing Info

    private func billingInfoCard(_ card: CreditCard) -> some View {
        let (cycleStart, cycleEnd) = store.billingCycleDates(for: card)
        let due = store.billingCycleDueDate(for: card)
        let df = DateFormatter(); df.dateFormat = "d MMM"

        return VStack(spacing: 16) {
            HStack {
                infoItem("Statement Cycle", "\(df.string(from: cycleStart)) - \(df.string(from: cycleEnd))", "calendar")
                Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                infoItem("Due Date", df.string(from: due), "clock.badge.exclamationmark")
                    .foregroundStyle(isNearDue(due) ? Color.neonRed : .white)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(spacing: 12) {
                HStack {
                    Text("Cycle Transactions").font(.caption).foregroundStyle(.glassText)
                    Spacer()
                    Text(formatCurrency(store.currentCycleBill(for: card), currency: card.currency)).font(.subheadline.bold())
                }
                HStack {
                    Text("Monthly Installments").font(.caption).foregroundStyle(.glassText)
                    Spacer()
                    Text(formatCurrency(store.currentMonthInstallments(for: card), currency: card.currency)).font(.subheadline.bold())
                }
                
                HStack {
                    Text("TOTAL DUE THIS MONTH")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(formatCurrency(store.totalDueThisMonth(for: card), currency: card.currency))
                        .font(.title3.bold())
                        .foregroundStyle(Color.neonRed)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 22))
    }
    
    private func isNearDue(_ date: Date) -> Bool {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 10
        return days <= 3 && days >= 0
    }

    // MARK: Pay Button

    private func payNowButton(_ card: CreditCard) -> some View {
        Button { store.payCurrentCycleBill(for: card.id) } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text("Mark as Paid").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 15)
        }
        .buttonStyle(.glassProminent)
        .disabled(store.totalDueThisMonth(for: card) == 0)
        .opacity(store.totalDueThisMonth(for: card) > 0 ? 1 : 0.38)
    }

    // MARK: Transactions Section (ViewBuilder allows rendering rows directly in List)

    @ViewBuilder
    private func transactionsSection(_ card: CreditCard) -> some View {
        let txs = store.currentCycleTransactions(for: card).sorted { $0.date > $1.date }
        
        sectionHeader("THIS CYCLE'S TRANSACTIONS", count: txs.count)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16))
            
        if txs.isEmpty {
            emptySection("No transactions this cycle")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 20, trailing: 16))
        } else {
            ForEach(txs) { tx in
                CCTransactionRow(tx: tx, currency: card.currency)
                    // Context Menu
                    .contextMenu {
                        Button { editTxTarget = tx }
                        label: { Label("Edit", systemImage: "pencil") }
                        
                        Button(role: .destructive) { store.deleteCCTransaction(tx.id, from: card.id) }
                        label: { Label("Delete", systemImage: "trash") }
                    }
                    // Swipe Actions
                    .swipeActions(edge: .leading) {
                        Button { editTxTarget = tx }
                        label: { Label("Edit", systemImage: "pencil") }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { store.deleteCCTransaction(tx.id, from: card.id) }
                        label: { Label("Delete", systemImage: "trash") }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16))
            }
        }
    }

    // MARK: Installments Section

    @ViewBuilder
    private func installmentsSection(_ card: CreditCard) -> some View {
        let active = card.installments.filter { !$0.isCompleted }
        let done   = card.installments.filter {  $0.isCompleted }
        
        sectionHeader("ACTIVE INSTALLMENTS", count: active.count)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            
        if active.isEmpty {
            emptySection("No active installments")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 20, trailing: 16))
        } else {
            ForEach(active) { inst in
                InstallmentRow(inst: inst, currency: card.currency)
                    // Context Menu
                    .contextMenu {
                        Button { editInstTarget = inst }
                        label: { Label("Edit", systemImage: "pencil") }
                        
                        Button(role: .destructive) { store.deleteInstallment(inst.id, from: card.id) }
                        label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                        Button { editInstTarget = inst }
                        label: { Label("Edit", systemImage: "pencil") }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { store.deleteInstallment(inst.id, from: card.id) }
                        label: { Label("Delete", systemImage: "trash") }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16))
            }
        }
        
        if !done.isEmpty {
            DisclosureGroup {
                ForEach(done) { inst in 
                    InstallmentRow(inst: inst, currency: card.currency)
                        .padding(.vertical, 4)
                }
            } label: {
                Text("Completed (\(done.count))")
                    .font(.caption).foregroundStyle(.dimText)
            }
            .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 40, trailing: 16))
        }
    }

    // MARK: Helpers

    private func infoItem(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.caption).foregroundStyle(.glassText)
            Text(value).font(.caption.bold()).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.dimText)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(1.2)
            Spacer()
            Text("\(count)").font(.caption2).foregroundStyle(.dimText)
        }
        .padding(.horizontal, 4)
    }

    private func emptySection(_ msg: String) -> some View {
        Text(msg).font(.subheadline).foregroundStyle(.glassText)
            .frame(maxWidth: .infinity).padding(20)
            .glassEffect(in: .rect(cornerRadius: 14))
    }
}

// MARK: - CC Transaction Row

struct CCTransactionRow: View {
    let tx: CCTransaction
    let currency: Currency
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tx.isPaid ? Color.neonGreen.opacity(0.12) : Color.neonRed.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: tx.isPaid ? "checkmark.circle.fill" : "cart.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tx.isPaid ? .neonGreen : .neonRed)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.description).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 6) {
                    if !tx.category.isEmpty {
                        Text(tx.category).font(.caption2).foregroundStyle(.glassText)
                        Circle().fill(Color.white.opacity(0.2)).frame(width: 3, height: 3)
                    }
                    Text(tx.date, style: .date).font(.caption2).foregroundStyle(.dimText)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(formatCurrency(tx.amount, currency: currency)).font(.subheadline.bold())
                    .foregroundStyle(tx.isPaid ? .neonGreen : .white)
                Text(tx.isPaid ? "Paid" : "Unpaid")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tx.isPaid ? Color.neonGreen.opacity(0.15) : Color.white.opacity(0.05), in: Capsule())
                    .foregroundStyle(tx.isPaid ? .neonGreen : .dimText)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 18))
    }
}

// MARK: - Installment Row

struct InstallmentRow: View {
    let inst: Installment
    let currency: Currency
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(red: 0.92, green: 0.66, blue: 0.10).opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: inst.isCompleted ? "checkmark.circle.fill" : "clock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(inst.isCompleted ? .neonGreen : Color(red: 0.92, green: 0.66, blue: 0.10))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(inst.description).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                Text("\(inst.paidMonths)/\(inst.totalMonths) months · Left \(formatCurrency(inst.remainingAmount, currency: currency))")
                    .font(.caption2).foregroundStyle(.glassText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if !inst.isCompleted {
                    Text(formatCurrency(inst.monthlyPayment, currency: currency))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(red: 0.92, green: 0.66, blue: 0.10))
                    Text("/month").font(.system(size: 9)).foregroundStyle(.dimText)
                } else {
                    Text("Completed").font(.caption2.bold()).foregroundStyle(.neonGreen)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 18))
    }
}
