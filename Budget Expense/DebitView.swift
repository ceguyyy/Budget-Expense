
//
//  DebitView.swift
//  Budget Expense
//

import SwiftUI

struct DebitView: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd = false
    @State private var editTarget: Wallet?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                if store.wallets.isEmpty { emptyState } else { walletList }
            }
            .navigationTitle("Wallets")
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) { fab }
            .sheet(isPresented: $showAdd) {
                AddEditWalletView(editTarget: nil).environment(store)
            }
            .sheet(item: $editTarget) { w in
                AddEditWalletView(editTarget: w).environment(store)
            }
        }
    }

    private var walletList: some View {
        List {
            ForEach(store.wallets) { wallet in
                NavigationLink {
                    WalletDetailView(walletId: wallet.id).environment(store)
                } label: {
                    WalletListRow(wallet: wallet)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { store.deleteWallet(wallet.id) }
                    label: { Label("Hapus", systemImage: "trash") }
                }
                .swipeActions(edge: .leading) {
                    Button { editTarget = wallet }
                    label: { Label("Edit", systemImage: "pencil") }
                    .tint(.blue)
                }
            }
            Color.clear.frame(height: 80)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var fab: some View {
        Button { showAdd = true } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .frame(width: 60, height: 60)
                .glassEffect(.regular.tint(Color(white: 0.7)).interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20).padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.07)).frame(width: 96, height: 96)
                Image(systemName: "wallet.bifold").font(.system(size: 40)).foregroundStyle(Color(white: 0.28))
            }
            VStack(spacing: 6) {
                Text("Belum Ada Wallet").font(.title3.bold()).foregroundStyle(.white)
                Text("Tap + untuk menambah wallet").font(.subheadline).foregroundStyle(.glassText)
            }
            Spacer()
        }
    }
}

// MARK: - Wallet List Row

struct WalletListRow: View {
    let wallet: Wallet
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(wallet.accentColor.opacity(0.12)).frame(width: 50, height: 50)
                Text(wallet.initials).font(.headline.bold()).foregroundStyle(wallet.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(wallet.name).font(.headline).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 6) {
                    Text(wallet.currency.rawValue)
                        .font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(white: 0.12), in: Capsule()).foregroundStyle(.glassText)
                    HStack(spacing: 3) {
                        Image(systemName: wallet.isPositive ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(wallet.isPositive ? "Aset" : "Liabilitas").font(.caption2)
                    }
                    .foregroundStyle(wallet.accentColor.opacity(0.85))
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(wallet.formattedAmount())
                    .font(.subheadline.weight(.semibold)).foregroundStyle(wallet.accentColor)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(wallet.isPositive ? "Aset" : "Liabilitas")
                    .font(.caption2).foregroundStyle(.dimText)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 18))
    }
}
