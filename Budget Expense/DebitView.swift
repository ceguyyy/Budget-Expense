//
//  DebitView.swift
//  Budget Expense
//

import SwiftUI

enum DebitActiveSheet: Identifiable {
    case add
    case edit(Wallet)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let w): return w.id.uuidString
        }
    }
}

struct DebitView: View {
    @Environment(AppStore.self) private var store
    @State private var activeSheet: DebitActiveSheet?

    var body: some View {
        NavigationStack {
            // ✅ ZStack dengan alignment bottomTrailing untuk FAB
            ZStack(alignment: .bottomTrailing) {
                
                Color.appBg
                    .ignoresSafeArea()

                if store.wallets.isEmpty {
                    emptyState
                } else {
                    walletList
                }
                
                // ✅ FAB dipindah ke dalam ZStack agar selalu responsif (sekali klik)
                fab
            }
            .navigationTitle("Wallets")
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    AddEditWalletView(editTarget: nil)
                        .environment(store)
                case .edit(let wallet):
                    AddEditWalletView(editTarget: wallet)
                        .environment(store)
                }
            }
        }
    }

    // MARK: - Wallet List

    private var walletList: some View {
        List {
            ForEach(store.wallets) { wallet in
                NavigationLink {
                    WalletDetailView(walletId: wallet.id)
                        .environment(store)
                } label: {
                    WalletListRow(wallet: wallet)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                
                // ✅ Tambahan Context Menu (Tahan / Long Press untuk Edit)
                .contextMenu {
                    Button {
                        activeSheet = .edit(wallet)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        store.deleteWallet(wallet.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                
                // Swipe Action Tetap Ada
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.deleteWallet(wallet.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        activeSheet = .edit(wallet)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                    
                }
                .swipeActions(edge: .leading) {
                    Button {
                        activeSheet = .edit(wallet)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }

            // spacing bawah biar gak ketiban FAB
            Color.clear
                .frame(height: 100) // ✅ Area bawah dilegakan
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - FAB

//    private var fab: some View {
//        Button {
//           
//        } label: {
//            Image(systemName: "plus")
//                .font(.title2.bold())
//                .frame(width: 60, height: 60)
//                .contentShape(Circle()) // ✅ Memastikan seluruh area bulat bisa di-klik
//                .glassEffect(
//                    .regular.tint(Color(white: 0.7)),
//                    in: Circle()
//                )
//        }
//        .buttonStyle(.plain)
//        .padding(.trailing, 20)
//        .padding(.bottom, 12)
//    }
    
    
    private var fab: some View {
        Button {
            activeSheet = .add
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(white: 0.07))
                    .frame(width: 96, height: 96)

                Image(systemName: "wallet.bifold")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(white: 0.28))
            }

            VStack(spacing: 6) {
                Text("No Wallets Yet")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("Tap + to add a wallet")
                    .font(.subheadline)
                    .foregroundStyle(.glassText)
            }

            Spacer()
        }
        // Pastikan empty state berada di tengah
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Wallet List Row

struct WalletListRow: View {
    let wallet: Wallet

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                // ✅ Check if there is image data and show it
                if let imgData = wallet.imageData, let uiImage = UIImage(data: imgData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        // ✅ Border logic matching the accent color (Green for Asset, Red for Liability)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(wallet.accentColor, lineWidth: 2)
                        )
                } else {
                    // Fallback to initials
                    RoundedRectangle(cornerRadius: 12)
                        .fill(wallet.accentColor.opacity(0.12))
                        .frame(width: 50, height: 50)
                        // ✅ Adding border to the fallback shape as well for consistency
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(wallet.accentColor.opacity(0.5), lineWidth: 1.5)
                        )

                    Text(wallet.initials)
                        .font(.headline.bold())
                        .foregroundStyle(wallet.accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(wallet.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(wallet.currency.rawValue)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(white: 0.12), in: Capsule())
                        .foregroundStyle(.glassText)

                    HStack(spacing: 3) {
                        Image(systemName: wallet.isPositive ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(wallet.isPositive ? "Asset" : "Liability")
                            .font(.caption2)
                    }
                    .foregroundStyle(wallet.accentColor.opacity(0.85))
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(wallet.formattedAmount())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(wallet.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(wallet.isPositive ? "Asset" : "Liability")
                    .font(.caption2)
                    .foregroundStyle(.dimText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 18))
    }
}
