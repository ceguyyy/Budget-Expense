
//
//  CreditCardListView.swift
//  Budget Expense
//

import SwiftUI

struct CreditCardListView: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd = false
    @State private var editTarget: CreditCard?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                if store.creditCards.isEmpty { emptyState } else { cardList }
            }
            .navigationTitle("Kartu Kredit")
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) { fab }
            .sheet(isPresented: $showAdd) {
                AddEditCreditCardView(editTarget: nil).environment(store)
            }
            .sheet(item: $editTarget) { card in
                AddEditCreditCardView(editTarget: card).environment(store)
            }
        }
    }

    private var cardList: some View {
        List {
            ForEach(store.creditCards) { card in
                NavigationLink {
                    CreditCardDetailView(cardId: card.id).environment(store)
                } label: {
                    CreditCardListRow(card: card, store: store)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { store.deleteCreditCard(card.id) }
                    label: { Label("Hapus", systemImage: "trash") }
                }
                .swipeActions(edge: .leading) {
                    Button { editTarget = card }
                    label: { Label("Edit", systemImage: "pencil") }
                    .tint(.blue)
                }
            }
            Color.clear.frame(height: 80)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
    }

    private var fab: some View {
        Button { showAdd = true } label: {
            Image(systemName: "plus")
                .font(.title2.bold()).frame(width: 60, height: 60)
                .glassEffect(.regular.tint(Color(white: 0.7)).interactive(), in: Circle())
        }
        .buttonStyle(.plain).padding(.trailing, 20).padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.07)).frame(width: 96, height: 96)
                Image(systemName: "creditcard").font(.system(size: 40)).foregroundStyle(Color(white: 0.28))
            }
            VStack(spacing: 6) {
                Text("Belum Ada Kartu Kredit").font(.title3.bold()).foregroundStyle(.white)
                Text("Tap + untuk menambah kartu kredit").font(.subheadline).foregroundStyle(.glassText)
            }
            Spacer()
        }
    }
}

// MARK: - Credit Card List Row

struct CreditCardListRow: View {
    let card: CreditCard
    let store: AppStore

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(card.cardColor.opacity(0.18)).frame(width: 50, height: 50)
                Text(card.initials).font(.headline.bold()).foregroundStyle(card.cardColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name).font(.headline).foregroundStyle(.white).lineLimit(1)
                Text(card.bank).font(.caption).foregroundStyle(.glassText)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("Tagihan: \(formatIDR(store.totalDueThisMonth(for: card)))")
                    .font(.caption.bold()).foregroundStyle(.neonRed)
                Text("Sisa: \(formatIDR(card.remainingLimit))")
                    .font(.caption2).foregroundStyle(.glassText)
                // Limit bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.12)).frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(card.usedPercent > 0.8 ? Color.neonRed : card.cardColor)
                            .frame(width: geo.size.width * card.usedPercent, height: 3)
                    }
                }
                .frame(width: 80, height: 3)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 18))
    }
}
