
//
//  WalletDetailView.swift
//  Budget Expense
//

import SwiftUI

struct WalletDetailView: View {
    let walletId: UUID
    @Environment(AppStore.self) private var store
    @State private var showAddTx = false

    private var wallet: Wallet? { store.wallets.first { $0.id == walletId } }
    private var transactions: [WalletTransaction] { store.transactions(for: walletId) }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            if let wallet {
                ScrollView {
                    VStack(spacing: 14) {
                        walletHeroCard(wallet)
                        transactionSection
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 40)
                }
            }
        }
        .navigationTitle(wallet?.name ?? "Wallet")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            Button { showAddTx = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold()).frame(width: 58, height: 58)
                    .glassEffect(.regular.tint(Color(white: 0.65)).interactive(), in: Circle())
            }
            .buttonStyle(.plain).padding(.trailing, 20).padding(.bottom, 12)
        }
        .sheet(isPresented: $showAddTx) {
            if let wallet {
                AddTransactionView(wallet: wallet).environment(store)
            }
        }
    }

    // MARK: Hero Card

    private func walletHeroCard(_ wallet: Wallet) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(wallet.accentColor.opacity(0.12)).frame(width: 60, height: 60)
                Text(wallet.initials).font(.title3.bold()).foregroundStyle(wallet.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(wallet.formattedAmount())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(wallet.accentColor).minimumScaleFactor(0.5).lineLimit(1)
                HStack(spacing: 6) {
                    Text(wallet.currency.rawValue)
                        .font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(white: 0.12), in: Capsule()).foregroundStyle(.glassText)
                    Text(wallet.isPositive ? "Aset" : "Liabilitas")
                        .font(.caption2).foregroundStyle(wallet.accentColor.opacity(0.8))
                }
            }
            Spacer()
        }
        .padding(18).glassEffect(in: .rect(cornerRadius: 20))
    }

    // MARK: Transaction Section

    private var transactionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TRANSAKSI")
                    .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(1.2)
                Spacer()
                Text("\(transactions.count) transaksi")
                    .font(.caption2).foregroundStyle(.dimText)
            }
            .padding(.horizontal, 4)

            if transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray").font(.system(size: 36)).foregroundStyle(Color(white: 0.25))
                    Text("Belum ada transaksi").font(.subheadline).foregroundStyle(.glassText)
                }
                .frame(maxWidth: .infinity).padding(40)
                .glassEffect(in: .rect(cornerRadius: 18))
            } else {
                ForEach(transactions) { tx in
                    TransactionRow(tx: tx, currency: wallet?.currency ?? .idr)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { store.deleteTransaction(tx) }
                            label: { Label("Hapus", systemImage: "trash") }
                        }
                }
            }
        }
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let tx: WalletTransaction
    let currency: Currency

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tx.type.color.opacity(0.12)).frame(width: 42, height: 42)
                Image(systemName: tx.type.icon).font(.subheadline).foregroundStyle(tx.type.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.category.isEmpty ? tx.type.rawValue : tx.category)
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white).lineLimit(1)
                if !tx.note.isEmpty {
                    Text(tx.note).font(.caption).foregroundStyle(.glassText).lineLimit(1)
                }
                Text(tx.date, style: .date).font(.caption2).foregroundStyle(.dimText)
            }
            Spacer()
            Text(tx.formattedAmount(currency: currency))
                .font(.subheadline.weight(.semibold)).foregroundStyle(tx.type.color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
