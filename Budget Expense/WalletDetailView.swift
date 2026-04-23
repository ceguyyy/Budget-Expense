//
//  WalletDetailView.swift
//  Budget Expense
//

import SwiftUI

enum DetailActiveSheet: Identifiable {
    case add
    case edit(WalletTransaction)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let tx): return tx.id.uuidString
        }
    }
}

struct WalletDetailView: View {
    let walletId: UUID
    @Environment(AppStore.self) private var store
    
    @State private var activeSheet: DetailActiveSheet?

    private var wallet: Wallet? { store.wallets.first { $0.id == walletId } }
    private var transactions: [WalletTransaction] { store.transactions(for: walletId) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.appBg
                .ignoresSafeArea()
            
            if let wallet {
                // ✅ Changed from ScrollView to List so swipeActions will work
                List {
                    walletHeroCard(wallet)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 14, trailing: 16))
                    
                    transactionHeader
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16))
                    
                    if transactions.isEmpty {
                        emptyTransactions
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 40, trailing: 16))
                    } else {
                        ForEach(transactions) { tx in
                            TransactionRow(tx: tx, currency: wallet.currency)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
                                // ✅ Swipe to Edit
                                .swipeActions(edge: .leading) {
                                    Button {
                                        activeSheet = .edit(tx)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                // ✅ Swipe to Delete
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        store.deleteTransaction(tx)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        
                        // Spacing at the bottom so the FAB doesn't block the last item
                        Color.clear
                            .frame(height: 80)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            // ✅ FAB moved out of safeAreaInset into ZStack for better 1-click response
            Button { activeSheet = .add } label: {
                Image(systemName: "plus")
                    .font(.title2.bold()).frame(width: 58, height: 58)
                    .contentShape(Circle())
                    .glassEffect(.regular.tint(Color(white: 0.65)), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle(wallet?.name ?? "Wallet")
        .sheet(item: $activeSheet) { sheet in
            if let wallet {
                switch sheet {
                case .add:
                    AddTransactionView(wallet: wallet).environment(store)
                case .edit(let tx):
                    AddTransactionView(wallet: wallet, editTarget: tx).environment(store)
                }
            }
        }
    }

    // MARK: Hero Card

    private func walletHeroCard(_ wallet: Wallet) -> some View {
        HStack(spacing: 16) {
            ZStack {
                if let imgData = wallet.imageData, let uiImage = UIImage(data: imgData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(wallet.accentColor, lineWidth: 2)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(wallet.accentColor.opacity(0.12)).frame(width: 60, height: 60)
                    Text(wallet.initials).font(.title3.bold()).foregroundStyle(wallet.accentColor)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(wallet.formattedAmount())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(wallet.accentColor).minimumScaleFactor(0.5).lineLimit(1)
                HStack(spacing: 6) {
                    Text(wallet.currency.rawValue)
                        .font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(white: 0.12), in: Capsule()).foregroundStyle(.glassText)
                    Text(wallet.isPositive ? "Asset" : "Liability")
                        .font(.caption2).foregroundStyle(wallet.accentColor.opacity(0.8))
                }
            }
            Spacer()
        }
        .padding(18).glassEffect(in: .rect(cornerRadius: 20))
    }

    // MARK: Transaction Header
    private var transactionHeader: some View {
        HStack {
            Text("TRANSACTIONS")
                .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(1.2)
            Spacer()
            Text("\(transactions.count) transactions")
                .font(.caption2).foregroundStyle(.dimText)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Empty State
    private var emptyTransactions: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 36)).foregroundStyle(Color(white: 0.25))
            Text("No transactions yet").font(.subheadline).foregroundStyle(.glassText)
        }
        .frame(maxWidth: .infinity).padding(40)
        .glassEffect(in: .rect(cornerRadius: 18))
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
