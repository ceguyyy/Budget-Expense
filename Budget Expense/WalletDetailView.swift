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
                                // Context menu for long press editing
                                .contextMenu {
                                    Button {
                                        activeSheet = .edit(tx)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        store.deleteTransaction(tx)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                // Swipe to Edit
                                .swipeActions(edge: .leading) {
                                    Button {
                                        activeSheet = .edit(tx)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                // Swipe to Delete
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
            
            // FAB
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
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    if let imgData = wallet.imageData, let uiImage = UIImage(data: imgData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(wallet.accentColor.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(wallet.accentColor.opacity(0.12)).frame(width: 64, height: 64)
                        Text(wallet.initials).font(.title2.bold()).foregroundStyle(wallet.accentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(wallet.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Text(wallet.currency.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.1), in: Capsule())
                            .foregroundStyle(.glassText)
                        
                        Text(wallet.isPositive ? "Asset" : "Liability")
                            .font(.caption2.bold())
                            .foregroundStyle(wallet.accentColor)
                    }
                }
                Spacer()
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("CURRENT BALANCE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.glassText)
                    .kerning(1.2)
                
                Text(wallet.formattedAmount())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(wallet.accentColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(
            ZStack {
                Color(white: 0.12)
                LinearGradient(
                    colors: [wallet.accentColor.opacity(0.1), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: Transaction Header
    private var transactionHeader: some View {
        HStack {
            Label("TRANSACTIONS", systemImage: "arrow.up.arrow.down")
                .font(.caption.weight(.bold)).foregroundStyle(.glassText).kerning(1.2)
            Spacer()
            Text("\(transactions.count)")
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1), in: Capsule())
                .foregroundStyle(.dimText)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Empty State
    private var emptyTransactions: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 72, height: 72)
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.dimText)
            }
            Text("No transactions yet")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text("Your activity will be listed here.")
                .font(.caption)
                .foregroundStyle(.glassText)
        }
        .frame(maxWidth: .infinity).padding(48)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let tx: WalletTransaction
    let currency: Currency

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tx.type.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: tx.type.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tx.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tx.category.isEmpty ? tx.type.rawValue : tx.category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 10))
                    .foregroundStyle(.dimText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(tx.formattedAmount(currency: currency))
                    .font(.subheadline.bold())
                    .foregroundStyle(tx.type.color)
                
                if !tx.note.isEmpty {
                    Text(tx.note)
                        .font(.system(size: 9))
                        .foregroundStyle(.glassText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 18))
    }
}
