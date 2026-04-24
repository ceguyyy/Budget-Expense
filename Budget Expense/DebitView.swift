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
    
    // MARK: - Computed Properties
    
    private var totalAssets: Double {
        store.wallets.filter { $0.isPositive }.reduce(0) { sum, wallet in
            sum + store.currencyManager.toBaseCurrency(amount: wallet.balance, from: wallet.currency)
        }
    }
    
    private var totalLiabilities: Double {
        store.wallets.filter { !$0.isPositive }.reduce(0) { sum, wallet in
            sum + store.currencyManager.toBaseCurrency(amount: wallet.balance, from: wallet.currency)
        }
    }
    
    private var netTotal: Double {
        totalAssets - totalLiabilities
    }
    
    private var baseCurrency: Currency {
        store.currencyManager.baseCurrency
    }
    
    // New Indicators
    private var assetCount: Int {
        store.wallets.filter { $0.isPositive }.count
    }
    
    private var liabilityCount: Int {
        store.wallets.filter { !$0.isPositive }.count
    }
    
    private var debtToAssetRatio: Double {
        guard totalAssets > 0 else { return 0 }
        return (totalLiabilities / totalAssets) * 100
    }
    
    private var liquidityRatio: Double {
        guard totalLiabilities > 0 else { return totalAssets > 0 ? 999 : 0 }
        return totalAssets / totalLiabilities
    }
    
    // Credit Card Indicators
    private var totalCreditLimit: Double {
        store.creditCards.reduce(0) { sum, card in
            sum + store.currencyManager.toBaseCurrency(amount: card.limit, from: card.currency)
        }
    }
    
    private var totalCreditUsed: Double {
        store.creditCards.reduce(0) { sum, card in
            sum + store.currencyManager.toBaseCurrency(amount: card.totalUsedLimit, from: card.currency)
        }
    }
    
    private var totalCreditAvailable: Double {
        store.creditCards.reduce(0) { sum, card in
            sum + store.currencyManager.toBaseCurrency(amount: card.remainingLimit, from: card.currency)
        }
    }
    
    private var creditUtilizationRatio: Double {
        guard totalCreditLimit > 0 else { return 0 }
        return (totalCreditUsed / totalCreditLimit) * 100
    }
    
    private var totalMonthlyDue: Double {
        store.creditCards.reduce(0) { sum, card in
            sum + store.currencyManager.toBaseCurrency(amount: store.totalDueThisMonth(for: card), from: card.currency)
        }
    }
    
    private var creditCardCount: Int {
        store.creditCards.count
    }
    
    private var averageUtilizationPerCard: Double {
        guard !store.creditCards.isEmpty else { return 0 }
        let totalUtilization = store.creditCards.reduce(0.0) { $0 + $1.usedPercent }
        return (totalUtilization / Double(store.creditCards.count)) * 100
    }
    
    private var utilizationColor: Color {
        switch creditUtilizationRatio {
        case 0..<30: return .neonGreen
        case 30..<50: return Color(red: 0.4, green: 0.8, blue: 0.4)
        case 50..<70: return .yellow
        case 70..<90: return .orange
        default: return .neonRed
        }
    }
    
    private var utilizationStatus: String {
        switch creditUtilizationRatio {
        case 0..<30: return "Excellent"
        case 30..<50: return "Good"
        case 50..<70: return "Fair"
        case 70..<90: return "High"
        default: return "Critical"
        }
    }
    
    private var financialHealthScore: Int {
        // Score dari 0-100 based on various factors
        var score = 50 // Base score
        
        // Net worth factor (30 points)
        if netTotal > 0 {
            score += 15
            if netTotal > totalAssets * 0.5 {
                score += 15
            }
        } else {
            score -= 15
        }
        
        // Debt ratio factor (25 points)
        if debtToAssetRatio < 30 {
            score += 25
        } else if debtToAssetRatio < 50 {
            score += 12
        } else {
            score -= 10
        }
        
        // Liquidity factor (20 points)
        if liquidityRatio > 2 {
            score += 20
        } else if liquidityRatio > 1 {
            score += 10
        }
        
        // Credit utilization factor (25 points)
        if creditUtilizationRatio < 30 {
            score += 25
        } else if creditUtilizationRatio < 50 {
            score += 15
        } else if creditUtilizationRatio < 70 {
            score += 5
        } else {
            score -= 15
        }
        
        return max(0, min(100, score))
    }
    
    private var healthScoreColor: Color {
        switch financialHealthScore {
        case 80...100: return .neonGreen
        case 60..<80: return Color(red: 0.4, green: 0.8, blue: 0.4)
        case 40..<60: return .yellow
        case 20..<40: return .orange
        default: return .neonRed
        }
    }
    
    private var healthScoreText: String {
        switch financialHealthScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        case 20..<40: return "Poor"
        default: return "Critical"
        }
    }

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
            // Summary Cards Section
            Section {
                summaryCards
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            
            // Wallets Section
            Section {
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
    
    // MARK: - Summary Cards
    
    private var summaryCards: some View {
        VStack(spacing: 16) {
            // Main Balance Card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOTAL NET WORTH")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.glassText)
                            .kerning(1.2)
                        Text(formatCurrency(netTotal, currency: baseCurrency))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(netTotal >= 0 ? .white : .neonRed)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(netTotal >= 0 ? Color.neonGreen.opacity(0.1) : Color.neonRed.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(netTotal >= 0 ? .neonGreen : .neonRed)
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.neonGreen)
                        VStack(alignment: .leading) {
                            Text("ASSETS").font(.system(size: 8, weight: .bold)).foregroundStyle(.dimText)
                            Text(formatCurrency(totalAssets, currency: baseCurrency)).font(.caption.bold()).foregroundStyle(.white)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.neonRed)
                        VStack(alignment: .leading) {
                            Text("LIABILITIES").font(.system(size: 8, weight: .bold)).foregroundStyle(.dimText)
                            Text(formatCurrency(totalLiabilities, currency: baseCurrency)).font(.caption.bold()).foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(24)
            .background(
                ZStack {
                    Color(white: 0.12)
                    LinearGradient(
                        colors: [Color.blue.opacity(0.15), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            activeSheet = .add
        } label: {
            Image(systemName: "plus")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
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
        HStack(spacing: 16) {
            // Icon / Image
            ZStack {
                if let imgData = wallet.imageData, let uiImage = UIImage(data: imgData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(wallet.accentColor.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(wallet.accentColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    
                    Text(wallet.initials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(wallet.accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(wallet.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(wallet.currency.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .foregroundStyle(.glassText)

                    Text(wallet.isPositive ? "Asset" : "Liability")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(wallet.accentColor.opacity(0.8))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(wallet.formattedAmount())
                    .font(.subheadline.bold())
                    .foregroundStyle(wallet.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 3) {
                    Image(systemName: wallet.isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                    Text(wallet.isPositive ? "Positive" : "Negative")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.dimText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}
