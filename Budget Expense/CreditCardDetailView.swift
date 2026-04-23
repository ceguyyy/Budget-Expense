
//
//  CreditCardDetailView.swift
//  Budget Expense
//

import SwiftUI

struct CreditCardDetailView: View {
    let cardId: UUID
    @Environment(AppStore.self) private var store
    @State private var showAddTx     = false
    @State private var showAddInst   = false
    @State private var editInstTarget: Installment?

    private var card: CreditCard? { store.creditCards.first { $0.id == cardId } }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            if let card {
                ScrollView {
                    VStack(spacing: 14) {
                        cardHeroView(card)
                        billingInfoCard(card)
                        payNowButton(card)
                        transactionsSection(card)
                        installmentsSection(card)
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 40)
                }
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
                    Button { showAddInst = true } label: { Label("Add Installment",  systemImage: "clock.badge.plus") }
                } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
                .buttonStyle(.glass)
            }
        }
        .sheet(isPresented: $showAddTx) {
            if let card { AddCCTransactionView(card: card).environment(store) }
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
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [card.cardColor, card.cardColor.opacity(0.55)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 170)

            // Card content
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.bank).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        Text(card.name).font(.headline.bold()).foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "creditcard.fill").font(.title2).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LIMIT").font(.caption2).foregroundStyle(.white.opacity(0.6))
                        Text(formatIDR(card.limit)).font(.subheadline.bold()).foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("REMAINING").font(.caption2).foregroundStyle(.white.opacity(0.6))
                        Text(formatIDR(card.remainingLimit))
                            .font(.subheadline.bold())
                            .foregroundStyle(card.usedPercent > 0.8 ? Color(red: 1, green: 0.5, blue: 0.5) : .white)
                    }
                }
                .padding(.top, 6)

                // Usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.2)).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(card.usedPercent > 0.8 ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                            .frame(width: geo.size.width * card.usedPercent, height: 5)
                    }
                }
                .frame(height: 5).padding(.top, 10)
            }
            .padding(20)
        }
    }

    // MARK: Billing Info

    private func billingInfoCard(_ card: CreditCard) -> some View {
        let (cycleStart, cycleEnd) = store.billingCycleDates(for: card)
        let due = store.billingCycleDueDate(for: card)
        let df = DateFormatter(); df.dateFormat = "d MMM"

        return VStack(spacing: 12) {
            HStack {
                infoItem("Cycle", "\(df.string(from: cycleStart)) → \(df.string(from: cycleEnd))", "calendar")
                Divider().background(Color(white: 0.15)).frame(height: 30)
                infoItem("Due Date", df.string(from: due), "exclamationmark.circle")
            }
            Divider().background(Color(white: 0.15))
            HStack {
                infoItem("Cycle Bill", formatIDR(store.currentCycleBill(for: card)), "creditcard")
                Divider().background(Color(white: 0.15)).frame(height: 30)
                infoItem("Monthly Installment", formatIDR(store.currentMonthInstallments(for: card)), "clock")
            }
            Divider().background(Color(white: 0.15))
            HStack {
                Text("TOTAL DUE THIS MONTH")
                    .font(.caption.weight(.semibold)).foregroundStyle(.glassText)
                Spacer()
                Text(formatIDR(store.totalDueThisMonth(for: card)))
                    .font(.headline.bold()).foregroundStyle(.neonRed)
            }
        }
        .padding(18).glassEffect(in: .rect(cornerRadius: 20))
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

    // MARK: Transactions Section

    private func transactionsSection(_ card: CreditCard) -> some View {
        let txs = store.currentCycleTransactions(for: card).sorted { $0.date > $1.date }
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("THIS CYCLE'S TRANSACTIONS", count: txs.count)
            if txs.isEmpty {
                emptySection("No transactions this cycle")
            } else {
                ForEach(txs) { tx in
                    CCTransactionRow(tx: tx)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { store.deleteCCTransaction(tx.id, from: card.id) }
                            label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
        }
    }

    // MARK: Installments Section

    private func installmentsSection(_ card: CreditCard) -> some View {
        let active = card.installments.filter { !$0.isCompleted }
        let done   = card.installments.filter {  $0.isCompleted }
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ACTIVE INSTALLMENTS", count: active.count)
            if active.isEmpty {
                emptySection("No active installments")
            } else {
                ForEach(active) { inst in
                    InstallmentRow(inst: inst)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { store.deleteInstallment(inst.id, from: card.id) }
                            label: { Label("Delete", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading) {
                            Button { editInstTarget = inst }
                            label: { Label("Edit", systemImage: "pencil") }
                            .tint(.blue)
                        }
                }
            }
            if !done.isEmpty {
                DisclosureGroup {
                    ForEach(done) { inst in InstallmentRow(inst: inst) }
                } label: {
                    Text("Completed (\(done.count))")
                        .font(.caption).foregroundStyle(.dimText)
                }
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }
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
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tx.isPaid ? Color.neonGreen.opacity(0.10) : Color.neonRed.opacity(0.10))
                    .frame(width: 42, height: 42)
                Image(systemName: tx.isPaid ? "checkmark.circle.fill" : "creditcard.fill")
                    .font(.subheadline).foregroundStyle(tx.isPaid ? .neonGreen : .neonRed)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.description).font(.subheadline.weight(.medium)).foregroundStyle(.white).lineLimit(1)
                if !tx.category.isEmpty {
                    Text(tx.category).font(.caption2).foregroundStyle(.glassText)
                }
                Text(tx.date, style: .date).font(.caption2).foregroundStyle(.dimText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(formatIDR(tx.amount)).font(.subheadline.weight(.semibold))
                    .foregroundStyle(tx.isPaid ? .neonGreen : .neonRed)
                Text(tx.isPaid ? "Paid" : "Unpaid")
                    .font(.caption2).foregroundStyle(tx.isPaid ? .neonGreen.opacity(0.7) : .dimText)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

// MARK: - Installment Row

struct InstallmentRow: View {
    let inst: Installment
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(red: 0.92, green: 0.66, blue: 0.10).opacity(0.12)).frame(width: 42, height: 42)
                Image(systemName: inst.isCompleted ? "checkmark.circle.fill" : "clock.fill")
                    .font(.subheadline)
                    .foregroundStyle(inst.isCompleted ? .neonGreen : Color(red: 0.92, green: 0.66, blue: 0.10))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(inst.description).font(.subheadline.weight(.medium)).foregroundStyle(.white).lineLimit(1)
                Text("\(inst.paidMonths)/\(inst.totalMonths) months · Left \(formatIDR(inst.remainingAmount))")
                    .font(.caption2).foregroundStyle(.glassText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(inst.isCompleted ? "Paid off" : "/month")
                    .font(.caption2).foregroundStyle(.dimText)
                if !inst.isCompleted {
                    Text(formatIDR(inst.monthlyPayment))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.92, green: 0.66, blue: 0.10))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
