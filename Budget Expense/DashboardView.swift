//
//  DashboardView.swift
//  Budget Expense
//

import SwiftUI
import Charts
import UIKit

// MARK: - Chart Range Enum
enum ChartRange: String, CaseIterable {
    case last3Months = "Last 3 Months"
    case last6Months = "Last 6 Months"
    case thisYear = "This Year"
}

// MARK: - Exchange Rate Response (Dashboard-specific)
struct DashboardExchangeRateResponse: Codable {
    let conversion_rates: [String: Double]?
}

// MARK: - Helper Types for Combined Transactions
enum AnyTransaction: Identifiable {
    case wallet(WalletTransaction)
    case cc(CCTransaction, cardId: UUID)
    
    var id: UUID {
        switch self {
        case .wallet(let tx): return tx.id
        case .cc(let tx, _): return tx.id
        }
    }
    var date: Date {
        switch self {
        case .wallet(let tx): return tx.date
        case .cc(let tx, _): return tx.date
        }
    }
}

struct CCEditWrapper: Identifiable {
    let id = UUID()
    let cardId: UUID
    let tx: CCTransaction
}

// MARK: - Dashboard

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.appleSignInManager) private var signInManager
    
    @State private var ocrResult: OCRResult?
    
    // ✅ State for universal add sheet & edits
    @State private var showUniversalAdd = false
    @State private var editCCTarget: CreditCard? // For editing the card itself
    
    // ✅ State for editing transactions directly from dashboard
    @State private var editWalletTx: WalletTransaction?
    @State private var editCCTxWrapper: CCEditWrapper?
    
    // ✅ State for FAB Menu Options
    @State private var showSplitBill = false
    @State private var showOCRScanner = false
    
    // ✅ State for Swiping Cards, Show/Hide Balance, & Chart Filter
    @State private var currentCardIndex = 0
    @AppStorage("showBalances") private var showBalances: Bool = true
    @State private var selectedChartRange: ChartRange = .last6Months
    @State private var viewModel: DashboardViewModel?
    
    // ✅ AppStorage for dynamically updated USD -> IDR exchange rate
    @AppStorage("usdToIdrRate") private var usdToIdrRate: Double = 16200.0
    @AppStorage("lastRateFetchTime") private var lastFetchDate: Double = 0.0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.appBg
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerBar
                        swipeableCards
                        metricsGrid
                        Divider()
                        financialIndicators
                        Divider()
                        featureCardsSection
                        analyticsSection
                        recentTransactionsSection
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 120) 
                }
                
                HStack {
                    Spacer()
                    FABMenuView(
                        showUniversalAdd: $showUniversalAdd,
                        showSplitBill: $showSplitBill,
                        showOCRScanner: $showOCRScanner,
                        ocrResult: $ocrResult
                    )
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            
            // Adding/Editing Sheets
            .sheet(isPresented: $showUniversalAdd, onDismiss: {
                ocrResult = nil
            }) {
                UniversalAddTransactionView(prefilledOCR: ocrResult)
                    .environment(store)
            }
            .sheet(isPresented: $showSplitBill, onDismiss: {
                ocrResult = nil
            }) {
                SplitBillView(prefilledOCR: ocrResult)
                    .environment(store)
            }

            .sheet(item: $editCCTarget) { card in
                AddEditCreditCardView(editTarget: card)
                    .environment(store)
            }
            
            // Edit Wallet Transaction Sheet
            .sheet(item: $editWalletTx) { tx in
                if let w = store.wallets.first(where: { $0.id == tx.walletId }) {
                    AddTransactionView(wallet: w, editTarget: tx)
                        .environment(store)
                }
            }
            
            // Edit CC Transaction Sheet
            .sheet(item: $editCCTxWrapper) { wrapper in
                if let c = store.creditCards.first(where: { $0.id == wrapper.cardId }) {
                    AddCreditCardTransactionView(card: c, editTarget: wrapper.tx)
                        .environment(store)
                }
            }
            
            .task {
                await fetchExchangeRateIfNeeded()
                if let vm = viewModel {
                    await vm.fetchExchangeRateIfNeeded()
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = DashboardViewModel(store: store)
                }
            }
        }
    }

    private func fetchExchangeRateIfNeeded() async {
        let oneWeekInSeconds: TimeInterval = 7 * 24 * 60 * 60
        let now = Date().timeIntervalSince1970
        guard now - lastFetchDate > oneWeekInSeconds else { return }
        guard let url = URL(string: "https://v6.exchangerate-api.com/v6/b6b3a1fcd087d7ff89f558a1/latest/USD") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(DashboardExchangeRateResponse.self, from: data)
            if let rates = response.conversion_rates, let idrRate = rates["IDR"] {
                await MainActor.run {
                    self.usdToIdrRate = idrRate
                    self.lastFetchDate = now
                }
            }
        } catch {
            print("Failed to fetch exchange rate: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Converted Calculated Properties (Multi-Currency Support)
    
    private var currencyManager: CurrencyManager {
        store.currencyManager
    }
    
    private var baseCurrency: Currency {
        currencyManager.baseCurrency
    }
    
    private var totalNetWorthIDR: Double {
        totalWalletBalanceIDR + totalReceivablesIDR - store.totalOutstandingCC
    }
    
    private var totalWalletBalanceIDR: Double {
        store.wallets.reduce(0) { sum, w in
            let amountInBase = currencyManager.toBaseCurrency(amount: w.signedBalance, from: w.currency)
            return sum + amountInBase
        }
    }
    
    private var totalReceivablesIDR: Double {
        store.debts.filter { !$0.isSettled }.reduce(0) { sum, d in
            let amountInBase = currencyManager.toBaseCurrency(amount: d.amount, from: d.currency)
            return sum + amountInBase
        }
    }
    
    private var totalLiability: Double {
        store.wallets.filter { !$0.isPositive }.reduce(0) { sum, w in
            let amountInBase = currencyManager.toBaseCurrency(amount: w.balance, from: w.currency)
            return sum + amountInBase
        }
    }
    
    private var totalCCLimitRemaining: Double {
        store.creditCards.reduce(0) { $0 + $1.remainingLimit }
    }
    
    private var totalCCTotalLimit: Double {
        store.creditCards.reduce(0) { $0 + $1.limit }
    }

    private var totalCCUsed: Double {
        max(0, totalCCTotalLimit - totalCCLimitRemaining)
    }
    
    // MARK: - Financial Health Metrics
    
    private var totalAssets: Double {
        store.wallets.filter { $0.isPositive }.reduce(0) { sum, wallet in
            sum + currencyManager.toBaseCurrency(amount: wallet.balance, from: wallet.currency)
        }
    }
    
    private var totalLiabilitiesFromWallets: Double {
        store.wallets.filter { !$0.isPositive }.reduce(0) { sum, wallet in
            sum + currencyManager.toBaseCurrency(amount: wallet.balance, from: wallet.currency)
        }
    }
    
    private var debtToAssetRatio: Double {
        guard totalAssets > 0 else { return 0 }
        return (totalLiabilitiesFromWallets / totalAssets) * 100
    }
    
    private var liquidityRatio: Double {
        guard totalLiabilitiesFromWallets > 0 else { return totalAssets > 0 ? 999 : 0 }
        return totalAssets / totalLiabilitiesFromWallets
    }
    
    private var totalCreditLimit: Double {
        store.creditCards.reduce(0) { sum, card in
            sum + currencyManager.toBaseCurrency(amount: card.limit, from: card.currency)
        }
    }
    
    private var totalCreditUsed: Double {
        store.creditCards.reduce(0) { sum, card in
            sum + currencyManager.toBaseCurrency(amount: card.totalUsedLimit, from: card.currency)
        }
    }
    
    private var totalCreditAvailable: Double {
        store.creditCards.reduce(0) { sum, card in
            sum + currencyManager.toBaseCurrency(amount: card.remainingLimit, from: card.currency)
        }
    }
    
    private var creditUtilizationRatio: Double {
        guard totalCreditLimit > 0 else { return 0 }
        return (totalCreditUsed / totalCreditLimit) * 100
    }
    
    private var totalMonthlyDue: Double {
        store.creditCards.reduce(0) { sum, card in
            sum + currencyManager.toBaseCurrency(amount: store.totalDueThisMonth(for: card), from: card.currency)
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
        var score = 50
        
        if totalNetWorthIDR > 0 {
            score += 15
            if totalNetWorthIDR > totalAssets * 0.5 {
                score += 15
            }
        } else {
            score -= 15
        }
        
        if debtToAssetRatio < 30 {
            score += 25
        } else if debtToAssetRatio < 50 {
            score += 12
        } else {
            score -= 10
        }
        
        if liquidityRatio > 2 {
            score += 20
        } else if liquidityRatio > 1 {
            score += 10
        }
        
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
    
    private func displayAmount(_ amount: Double) -> String {
        if showBalances {
            return currencyManager.format(amount: amount, currency: baseCurrency)
        } else {
            return "\(baseCurrency.symbol) ••••••••"
        }
    }
    
    private var convertedChartData: [MonthlyChartData] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        let monthCount: Int
        switch selectedChartRange {
        case .last3Months: monthCount = 3
        case .last6Months: monthCount = 6
        case .thisYear: monthCount = max(1, cal.component(.month, from: Date()))
        }
        
        return (0..<monthCount).reversed().map { n in
            let date = cal.date(byAdding: .month, value: -n, to: Date())!
            let y = cal.component(.year, from: date)
            let m = cal.component(.month, from: date)
            let txs = store.walletTransactions.filter {
                cal.component(.year, from: $0.date) == y &&
                cal.component(.month, from: $0.date) == m
            }
            
            let inflow = txs.filter { $0.type == .inflow }.reduce(0) { sum, tx in
                let wallet = store.wallets.first { $0.id == tx.walletId }
                guard let walletCurrency = wallet?.currency else { return sum }
                let amountInBase = currencyManager.toBaseCurrency(amount: tx.amount, from: walletCurrency)
                return sum + amountInBase
            }
            let outflow = txs.filter { $0.type == .outflow }.reduce(0) { sum, tx in
                let wallet = store.wallets.first { $0.id == tx.walletId }
                guard let walletCurrency = wallet?.currency else { return sum }
                let amountInBase = currencyManager.toBaseCurrency(amount: tx.amount, from: walletCurrency)
                return sum + amountInBase
            }
            
            return MonthlyChartData(month: fmt.string(from: date), inflow: inflow, outflow: outflow)
        }
    }
    
    // MARK: - Custom Header
    
    private var headerBar: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.45, green: 0.2, blue: 0.9).opacity(0.2))
                    .frame(width: 44, height: 44)
                Image("image_logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Spacer()
            Text("Home")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    withAnimation { showBalances.toggle() }
                } label: {
                    Image(systemName: showBalances ? "eye" : "eye.slash")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Swipeable Balance Cards

    private var swipeableCards: some View {
        VStack(spacing: 16) {
            TabView(selection: $currentCardIndex) {
                balanceCard(
                    title: "Total Balance",
                    amount: totalNetWorthIDR,
                    gradient: [
                        Color(red: 0.15, green: 0.15, blue: 0.25),
                        Color(red: 0.25, green: 0.15, blue: 0.35),
                        Color(red: 0.08, green: 0.08, blue: 0.15)
                    ],
                    icon: "chart.line.uptrend.xyaxis",
                    accentColor: totalNetWorthIDR >= 0 ? .neonGreen : .neonRed,
                    badge: totalNetWorthIDR >= 0 ? "Positive" : "Negative"
                ).tag(0)
                
                balanceCard(
                    title: "Wallet Balance",
                    amount: totalWalletBalanceIDR,
                    gradient: [
                        Color(red: 0.05, green: 0.4, blue: 0.3),
                        Color(red: 0.08, green: 0.5, blue: 0.35),
                        Color(red: 0.02, green: 0.2, blue: 0.15)
                    ],
                    icon: "wallet.bifold.fill",
                    accentColor: .neonGreen,
                    badge: "\(store.wallets.count) wallet\(store.wallets.count != 1 ? "s" : "")"
                ).tag(1)
                
                balanceCard(
                    title: "Credit Available",
                    amount: totalCCLimitRemaining,
                    gradient: [
                        Color(red: 0.5, green: 0.2, blue: 0.95),
                        Color(red: 0.6, green: 0.25, blue: 1.0),
                        Color(red: 0.25, green: 0.1, blue: 0.45)
                    ],
                    icon: "creditcard.fill",
                    accentColor: utilizationColor,
                    badge: "\(creditCardCount) card\(creditCardCount != 1 ? "s" : "")",
                    progress: (used: totalCCUsed, total: totalCCTotalLimit)
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)
            
            // Custom Page Indicator
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(currentCardIndex == index ? Color.white : Color.white.opacity(0.3))
                        .frame(width: currentCardIndex == index ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentCardIndex)
                }
            }
        }
    }

    private func balanceCard(
        title: String,
        amount: Double,
        gradient: [Color],
        icon: String,
        accentColor: Color,
        badge: String,
        progress: (used: Double, total: Double)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Icon and Badge
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.15), in: Capsule())
            }
            .padding(.bottom, 16)
            
            // Amount
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(baseCurrency.symbol)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                
                if showBalances {
                    Text(formatNumber(amount))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                } else {
                    Text("••••••••")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.bottom, progress != nil ? 12 : 0)
            
            // Progress Section (for Credit Card)
            if let progress {
                let ratio = progress.total > 0 ? min(max(progress.used / progress.total, 0), 1) : 0
                let percentUsed = progress.total > 0 ? (progress.used / progress.total) * 100 : 0
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Utilization")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%%", percentUsed))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accentColor)
                    }
                    
                    // Enhanced Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 10)
                            
                            // Filled Progress
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor, accentColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * ratio, height: 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            LinearGradient(
                                                colors: [.white.opacity(0.3), .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                        }
                    }
                    .frame(height: 10)
                    
                    // Stats Row
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Used")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(formatNumber(progress.used))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Available")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(formatNumber(progress.total - progress.used))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(accentColor)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Footer
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                    
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                }
                
                Spacer()
                
                // Card Network Icons (visa/mastercard style)
                HStack(spacing: -8) {
                    Circle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(Color.orange.opacity(0.7))
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(24)
        .frame(height: 200)
        .background(
            ZStack {
                // Main gradient background
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle pattern overlay
                GeometryReader { geo in
                    Circle()
                        .fill(.white.opacity(0.03))
                        .frame(width: 200, height: 200)
                        .offset(x: geo.size.width * 0.7, y: -50)
                    
                    Circle()
                        .fill(.white.opacity(0.02))
                        .frame(width: 150, height: 150)
                        .offset(x: -30, y: geo.size.height * 0.6)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .shadow(color: accentColor.opacity(0.2), radius: 15, x: 0, y: 8)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                EnhancedMetricTile(
                    icon: "arrow.down.circle.fill",
                    title: "Total Liability",
                    value: displayAmount(totalLiability),
                    color: .neonRed,
                    gradient: [
                        Color(red: 0.4, green: 0.1, blue: 0.1),
                        Color(red: 0.2, green: 0.05, blue: 0.05)
                    ],
                    badge: "\(store.wallets.filter { !$0.isPositive }.count) wallet\(store.wallets.filter { !$0.isPositive }.count != 1 ? "s" : "")"
                )
                
                EnhancedMetricTile(
                    icon: "creditcard.fill",
                    title: "CC Bill/mo",
                    value: displayAmount(store.totalMonthlyPayable),
                    color: .neonRed,
                    gradient: [
                        Color(red: 0.45, green: 0.2, blue: 0.9),
                        Color(red: 0.25, green: 0.1, blue: 0.45)
                    ],
                    badge: "Monthly"
                )
            }
            
            HStack(spacing: 12) {
                EnhancedMetricTile(
                    icon: "person.2.fill",
                    title: "Receivables",
                    value: displayAmount(totalReceivablesIDR),
                    color: Color(red: 0.3, green: 0.6, blue: 1.0),
                    gradient: [
                        Color(red: 0.2, green: 0.4, blue: 0.8),
                        Color(red: 0.1, green: 0.2, blue: 0.4)
                    ],
                    badge: "\(store.debts.filter { !$0.isSettled }.count) debt\(store.debts.filter { !$0.isSettled }.count != 1 ? "s" : "")"
                )
                
                EnhancedMetricTile(
                    icon: "clock.badge.fill",
                    title: "Installments/mo",
                    value: displayAmount(store.totalMonthlyInstallments),
                    color: Color(red: 0.92, green: 0.66, blue: 0.10),
                    gradient: [
                        Color(red: 0.7, green: 0.5, blue: 0.08),
                        Color(red: 0.35, green: 0.25, blue: 0.04)
                    ],
                    badge: "Monthly"
                )
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Financial Indicators
    
    private var financialIndicators: some View {
        Group {
            if let vm = viewModel {
                VStack(spacing: 16) {
                    // Section Header with Icon
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(vm.healthScoreColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(vm.healthScoreColor)
                        }
                        
                        Text("Financial Health")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Button {
                            vm.showHealthExplanation = true
                        } label: {
                            Image(systemName: "apple.intelligence")
                                .font(.title3)
                                .foregroundStyle(vm.healthScoreColor.opacity(0.8))
                                .symbolEffect(.breathe)
                        }
                        .sheet(isPresented: Binding(get: { vm.showHealthExplanation }, set: { vm.showHealthExplanation = $0 })) {
                            FinancialHealthExplanationSheet(vm: vm)
                                .presentationDetents([.medium, .large])
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Financial Health Score - Enhanced
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(vm.healthScoreColor.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "heart.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(vm.healthScoreColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Financial Health Score")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Text("Based on 4 key metrics")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(vm.financialHealthScore)")
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundStyle(vm.healthScoreColor)
                                
                                Text(vm.healthScoreText)
                                    .font(.caption.bold())
                                    .foregroundStyle(vm.healthScoreColor.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(vm.healthScoreColor.opacity(0.15), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        
                        // Enhanced Progress Bar
                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(white: 0.12))
                                        .frame(height: 16)
                                    
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            LinearGradient(
                                                colors: [vm.healthScoreColor, vm.healthScoreColor.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * CGFloat(vm.financialHealthScore) / 100, height: 16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.white.opacity(0.3), .clear],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                        )
                                        .shadow(color: vm.healthScoreColor.opacity(0.4), radius: 4, x: 0, y: 2)
                                }
                            }
                            .frame(height: 16)
                            
                            HStack {
                                ForEach([("0", 0), ("25", 25), ("50", 50), ("75", 75), ("100", 100)], id: \.1) { marker in
                                    if marker.1 == 0 {
                                        Text(marker.0).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                                    } else {
                                        Spacer()
                                        Text(marker.0).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(
                        ZStack {
                            LinearGradient(colors: [vm.healthScoreColor.opacity(0.08), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            GeometryReader { geo in
                                Circle().fill(vm.healthScoreColor.opacity(0.05)).frame(width: 120, height: 120).offset(x: geo.size.width - 60, y: -30)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [vm.healthScoreColor.opacity(0.3), vm.healthScoreColor.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                    .padding(.horizontal, 16)
                    
                    // Key Metrics Row - Enhanced
                    HStack(spacing: 12) {
                        enhancedMetricCard(
                            title: "Debt Ratio",
                            value: String(format: "%.1f%%", vm.debtToAssetRatio),
                            icon: "chart.pie.fill",
                            color: vm.debtToAssetRatio < 30 ? .neonGreen : vm.debtToAssetRatio < 50 ? .yellow : .neonRed,
                            subtitle: vm.debtToAssetRatio < 30 ? "Healthy" : vm.debtToAssetRatio < 50 ? "Moderate" : "High",
                            gradient: vm.debtToAssetRatio < 30 
                                ? [Color(red: 0.05, green: 0.4, blue: 0.3), Color(red: 0.02, green: 0.2, blue: 0.15)]
                                : vm.debtToAssetRatio < 50
                                ? [Color(red: 0.6, green: 0.5, blue: 0.05), Color(red: 0.3, green: 0.25, blue: 0.02)]
                                : [Color(red: 0.4, green: 0.1, blue: 0.1), Color(red: 0.2, green: 0.05, blue: 0.05)]
                        )
                        
                        enhancedMetricCard(
                            title: "Liquidity",
                            value: String(format: "%.2fx", vm.liquidityRatio),
                            icon: "drop.fill",
                            color: vm.liquidityRatio > 2 ? .neonGreen : vm.liquidityRatio > 1 ? .yellow : .neonRed,
                            subtitle: vm.liquidityRatio > 2 ? "Strong" : vm.liquidityRatio > 1 ? "Adequate" : "Low",
                            gradient: vm.liquidityRatio > 2
                                ? [Color(red: 0.05, green: 0.4, blue: 0.3), Color(red: 0.02, green: 0.2, blue: 0.15)]
                                : vm.liquidityRatio > 1
                                ? [Color(red: 0.6, green: 0.5, blue: 0.05), Color(red: 0.3, green: 0.25, blue: 0.02)]
                                : [Color(red: 0.4, green: 0.1, blue: 0.1), Color(red: 0.2, green: 0.05, blue: 0.05)]
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // Credit Card Indicators Section
                    if !store.creditCards.isEmpty {
                        creditCardOverview
                        cardUtilizationBreakdown
                    }
                    
                    // Portfolio Distribution
                    if vm.totalAssets + vm.totalLiabilitiesFromWallets > 0 {
                        portfolioDistribution
                    }
                    }
                    }
                    }
                    }
    private func enhancedMetricCard(title: String, value: String, icon: String, color: Color, subtitle: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }
            .padding(.bottom, 12)
            
            // Title
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 8)
            
            // Value
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 6)
            
            // Subtitle badge
            Text(subtitle)
                .font(.caption2.bold())
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.15), in: Capsule())
            
            Spacer(minLength: 0)
            
            // Accent bar
            HStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .frame(maxWidth: 50)
                
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(
            ZStack {
                LinearGradient(
                    colors: gradient + [Color(white: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                GeometryReader { geo in
                    Circle()
                        .fill(color.opacity(0.08))
                        .frame(width: 80, height: 80)
                        .offset(x: geo.size.width - 40, y: geo.size.height - 40)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.4), color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    private var creditCardOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundStyle(utilizationColor)
                
                Text("Credit Card Overview")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(creditCardCount)")
                        .font(.title2.bold())
                        .foregroundStyle(utilizationColor)
                    Text("card\(creditCardCount != 1 ? "s" : "")")
                        .font(.caption2)
                        .foregroundStyle(utilizationColor.opacity(0.8))
                }
            }
            
            // Credit Utilization Progress
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Credit Utilization")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", creditUtilizationRatio))
                        .font(.subheadline.bold())
                        .foregroundStyle(utilizationColor)
                    
                    Text(utilizationStatus)
                        .font(.caption2)
                        .foregroundStyle(utilizationColor.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(utilizationColor.opacity(0.15), in: Capsule())
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(white: 0.15))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [utilizationColor, utilizationColor.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(1.0, creditUtilizationRatio / 100), height: 12)
                    }
                }
                .frame(height: 12)
            }
            
            // Credit Stats
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Used")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    HStack(spacing: 2) {
                        Text(baseCurrency.symbol)
                            .font(.caption)
                            .foregroundStyle(.neonRed.opacity(0.8))
                        Text(formatNumber(totalCreditUsed))
                            .font(.subheadline.bold())
                            .foregroundStyle(.neonRed)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                    .background(.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    HStack(spacing: 2) {
                        Text(baseCurrency.symbol)
                            .font(.caption)
                            .foregroundStyle(.neonGreen.opacity(0.8))
                        Text(formatNumber(totalCreditAvailable))
                            .font(.subheadline.bold())
                            .foregroundStyle(.neonGreen)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                    .background(.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Limit")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    HStack(spacing: 2) {
                        Text(baseCurrency.symbol)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(formatNumber(totalCreditLimit))
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
            
            Divider()
                .background(.white.opacity(0.1))
            
            // Monthly Payment Due
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        
                        Text("This Month's Due")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    HStack(spacing: 4) {
                        Text(baseCurrency.symbol)
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text(formatNumber(totalMonthlyDue))
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(utilizationColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private var cardUtilizationBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
                Text("Card Utilization Breakdown")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text("Avg: \(String(format: "%.1f%%", averageUtilizationPerCard))")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            ForEach(store.creditCards.prefix(3)) { card in
                VStack(spacing: 6) {
                    HStack {
                        Text(card.name)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%%", card.usedPercent * 100))
                            .font(.caption.bold())
                            .foregroundStyle(cardUtilizationColor(card.usedPercent * 100))
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(white: 0.15))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cardUtilizationColor(card.usedPercent * 100))
                                .frame(width: geo.size.width * min(1.0, card.usedPercent), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            
            if store.creditCards.count > 3 {
                Text("+ \(store.creditCards.count - 3) more card\(store.creditCards.count - 3 != 1 ? "s" : "")")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private var portfolioDistribution: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
                Text("Portfolio Distribution")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
            }
            
            GeometryReader { geo in
                HStack(spacing: 0) {
                    let totalValue = totalAssets + totalLiabilitiesFromWallets
                    let assetsPercentage = totalAssets / totalValue
                    let liabilitiesPercentage = totalLiabilitiesFromWallets / totalValue
                    
                    // Assets bar
                    if assetsPercentage > 0 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.neonGreen, .neonGreen.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * assetsPercentage)
                            .overlay(
                                Text(String(format: "%.0f%%", assetsPercentage * 100))
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .opacity(assetsPercentage > 0.1 ? 1 : 0)
                            )
                    }
                    
                    // Liabilities bar
                    if liabilitiesPercentage > 0 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.neonRed.opacity(0.7), .neonRed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * liabilitiesPercentage)
                            .overlay(
                                Text(String(format: "%.0f%%", liabilitiesPercentage * 100))
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .opacity(liabilitiesPercentage > 0.1 ? 1 : 0)
                            )
                    }
                }
            }
            .frame(height: 32)
            
            HStack {
                Label("Assets", systemImage: "arrow.up")
                    .font(.caption2)
                    .foregroundStyle(.neonGreen)
                
                Spacer()
                
                Label("Liabilities", systemImage: "arrow.down")
                    .font(.caption2)
                    .foregroundStyle(.neonRed)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private func metricCard(title: String, value: String, icon: String, color: Color, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func cardUtilizationColor(_ percent: Double) -> Color {
        switch percent {
        case 0..<30: return .neonGreen
        case 30..<50: return Color(red: 0.4, green: 0.8, blue: 0.4)
        case 50..<70: return .yellow
        case 70..<90: return .orange
        default: return .neonRed
        }
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    // MARK: - Custom Feature Cards (History & Stock)
    
    private var featureCardsSection: some View {
        VStack(spacing: 12) {
            // Section Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0))
                }
                
                Text("Quick Actions")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            HStack(spacing: 12) {
                // Split Bill History - Enhanced
                NavigationLink(destination: SplitBillHistoryView().environment(store)) {
                    EnhancedFeatureTile(
                        icon: "doc.text.fill",
                        title: "Split Bills",
                        subtitle: "View history",
                        color: Color(red: 0.3, green: 0.6, blue: 1.0),
                        gradient: [
                            Color(red: 0.2, green: 0.4, blue: 0.8),
                            Color(red: 0.1, green: 0.2, blue: 0.4)
                        ],
                        count: store.splitBills.count
                    )
                }
                .buttonStyle(.plain)
                
                // Stock Input (Future) - Enhanced
                Button {
                    if let url = URL(string: "stockbit://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    EnhancedFeatureTile(
                        icon: "shippingbox.fill",
                        title: "StockBit",
                        subtitle: "Open app",
                        color: Color(red: 0.92, green: 0.66, blue: 0.10),
                        gradient: [
                            Color(red: 0.7, green: 0.5, blue: 0.08),
                            Color(red: 0.35, green: 0.25, blue: 0.04)
                        ],
                        count: nil
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Analytics (Enhanced Bar Chart)

    private var analyticsSection: some View {
        VStack(spacing: 0) {
            // Enhanced Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.neonGreen.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neonGreen)
                }
                
                Text("Analytics")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Enhanced Filter Menu
                Menu {
                    ForEach(ChartRange.allCases, id: \.self) { range in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedChartRange = range
                            }
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                Spacer()
                                if selectedChartRange == range {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.neonGreen)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedChartRange.rawValue)
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.4, blue: 0.2),
                                Color(red: 0.85, green: 0.3, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.95, green: 0.4, blue: 0.2).opacity(0.3), radius: 4, x: 0, y: 2)
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Summary Stats Row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Inflow")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    let totalInflow = convertedChartData.reduce(0) { $0 + $1.inflow }
                    Text(formatNumber(totalInflow))
                        .font(.subheadline.bold())
                        .foregroundStyle(.neonGreen)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.neonGreen.opacity(0.1))
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Outflow")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    let totalOutflow = convertedChartData.reduce(0) { $0 + $1.outflow }
                    Text(formatNumber(totalOutflow))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(red: 0.45, green: 0.2, blue: 0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.45, green: 0.2, blue: 0.9).opacity(0.1))
                )
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Enhanced Chart
            Chart {
                ForEach(convertedChartData) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.inflow)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neonGreen, .neonGreen.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .position(by: .value("Type", "Inflow"))
                    .cornerRadius(6)
                    
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.outflow)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.2, blue: 0.9),
                                Color(red: 0.35, green: 0.15, blue: 0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .position(by: .value("Type", "Outflow"))
                    .cornerRadius(6)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.white.opacity(0.5))
                        .font(.caption2.weight(.medium))
                }
            }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 200)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Enhanced Legend
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.neonGreen, .neonGreen.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 12, height: 12)
                    
                    Text("Inflow")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.2, blue: 0.9),
                                    Color(red: 0.35, green: 0.15, blue: 0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 12, height: 12)
                    
                    Text("Outflow")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Net Change Indicator
                let totalInflow = convertedChartData.reduce(0) { $0 + $1.inflow }
                let totalOutflow = convertedChartData.reduce(0) { $0 + $1.outflow }
                let netChange = totalInflow - totalOutflow
                
                HStack(spacing: 4) {
                    Image(systemName: netChange >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(netChange >= 0 ? .neonGreen : .neonRed)
                    
                    Text("Net: \(formatNumber(abs(netChange)))")
                        .font(.caption2.bold())
                        .foregroundStyle(netChange >= 0 ? .neonGreen : .neonRed)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill((netChange >= 0 ? Color.neonGreen : Color.neonRed).opacity(0.15))
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color(white: 0.10), Color(white: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Decorative elements
                GeometryReader { geo in
                    Circle()
                        .fill(Color.neonGreen.opacity(0.03))
                        .frame(width: 150, height: 150)
                        .offset(x: -40, y: geo.size.height - 80)
                    
                    Circle()
                        .fill(Color(red: 0.45, green: 0.2, blue: 0.9).opacity(0.03))
                        .frame(width: 120, height: 120)
                        .offset(x: geo.size.width - 50, y: -20)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.1), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 16)
    }

    // MARK: - Transactions List (Combined Wallet & CC)

    private var recentTransactionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Transactions")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 16)

            // ✅ Combine both CC and Wallet transactions for recent view
            let wTxs = store.walletTransactions.map { AnyTransaction.wallet($0) }
            let cTxs = store.creditCards.flatMap { card in
                card.transactions.map { AnyTransaction.cc($0, cardId: card.id) }
            }
            let recentTxs = (wTxs + cTxs).sorted { $0.date > $1.date }.prefix(4)
            
            if recentTxs.isEmpty {
                Text("No recent transactions")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.5))
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentTxs.enumerated()), id: \.element.id) { index, item in
                        Button {
                            switch item {
                            case .wallet(let tx):
                                editWalletTx = tx
                            case .cc(let tx, let cardId):
                                editCCTxWrapper = CCEditWrapper(cardId: cardId, tx: tx)
                            }
                        } label: {
                            AnyTransactionRow(item: item, store: store, showBalances: showBalances)
                        }
                        .buttonStyle(.plain)
                        
                        if index < recentTxs.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 64)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .background(Color(white: 0.08))
                .cornerRadius(20)
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Subcomponents

struct EnhancedFeatureTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let gradient: [Color]
    let count: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon and Badge
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                Spacer()
                
                if let count = count {
                    Text("\(count)")
                        .font(.caption.bold())
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.15), in: Capsule())
                }
            }
            .padding(.bottom, 16)
            
            // Title
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.bottom, 4)
            
            // Subtitle
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            
            Spacer(minLength: 0)
            
            // Arrow indicator
            HStack {
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color.opacity(0.7))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            ZStack {
                LinearGradient(
                    colors: gradient + [Color(white: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                GeometryReader { geo in
                    Circle()
                        .fill(color.opacity(0.08))
                        .frame(width: 80, height: 80)
                        .offset(x: geo.size.width - 40, y: geo.size.height - 40)
                    
                    Circle()
                        .fill(.white.opacity(0.02))
                        .frame(width: 60, height: 60)
                        .offset(x: -20, y: 20)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct FeatureTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.headline).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.dimText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

// ✅ New row capable of rendering both transaction types and enabling tap-to-edit
struct AnyTransactionRow: View {
    let item: AnyTransaction
    let store: AppStore
    let showBalances: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 48, height: 48)
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(categoryName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text(accountName)
                    .font(.caption2)
                    .foregroundStyle(Color(white: 0.5))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(showBalances ? amountString : "••••••")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(amountColor)
                
                Text(item.date, format: .dateTime.day().month().year())
                    .font(.caption2)
                    .foregroundStyle(Color(white: 0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle()) // Makes entire row area tappable
    }
    
    private var isIncome: Bool {
        switch item {
        case .wallet(let tx): return tx.type == .inflow
        case .cc: return false
        }
    }
    
    private var iconName: String {
        switch item {
        case .wallet(let tx): return tx.type.icon
        case .cc: return "creditcard.fill"
        }
    }
    
    private var iconColor: Color { isIncome ? .neonGreen : .white }
    
    private var categoryName: String {
        switch item {
        case .wallet(let tx): return tx.category.isEmpty ? tx.type.rawValue : tx.category
        case .cc(let tx, _): return tx.category.isEmpty ? "Credit Card" : tx.category
        }
    }
    
    private var accountName: String {
        switch item {
        case .wallet(let tx): return store.wallets.first(where: { $0.id == tx.walletId })?.name ?? "Wallet"
        case .cc(_, let cardId): return store.creditCards.first(where: { $0.id == cardId })?.name ?? "Credit Card"
        }
    }
    
    private var amountString: String {
        switch item {
        case .wallet(let tx):
            let currency = store.wallets.first(where: { $0.id == tx.walletId })?.currency ?? .idr
            return tx.type.sign + formatCurrency(tx.amount, currency: currency)
        case .cc(let tx, _):
            return "-" + formatCurrency(tx.amount, currency: .idr) // Assuming base is IDR
        }
    }
    
    private var amountColor: Color { isIncome ? .neonGreen : .white }
    
    private func formatCurrency(_ value: Double, currency: Currency) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        let num = f.string(from: NSNumber(value: value)) ?? "0"
        return "\(currency.symbol) \(num)"
    }
}

struct EnhancedMetricTile: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let gradient: [Color]
    let badge: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Icon and Badge
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                Spacer()
                
                Text(badge)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.15), in: Capsule())
            }
            .padding(.bottom, 12)
            
            // Title
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
            
            // Value
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            Spacer(minLength: 0)
            
            // Subtle accent line at bottom
            HStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .frame(maxWidth: 60)
                
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            ZStack {
                // Main gradient background
                LinearGradient(
                    colors: gradient + [Color(white: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle pattern overlay
                GeometryReader { geo in
                    Circle()
                        .fill(color.opacity(0.08))
                        .frame(width: 80, height: 80)
                        .offset(x: geo.size.width - 40, y: geo.size.height - 40)
                    
                    Circle()
                        .fill(.white.opacity(0.02))
                        .frame(width: 50, height: 50)
                        .offset(x: -10, y: 10)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct MetricTile: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(color.opacity(0.8))
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(title)
                .font(.caption2).foregroundStyle(.dimText).lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

struct UniversalAddTransactionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.categoryManager) private var categoryManager
    @Environment(\.ocrDataManager) private var ocrManager
    @Environment(\.dismiss) private var dismiss
    
    let prefilledOCR: OCRResult?

    @State private var selectedAccountId = ""
    @State private var txType = TransactionType.outflow
    @State private var amountText = ""
    @State private var category = ""
    @State private var note = ""
    @State private var date = Date()

    init(prefilledOCR: OCRResult? = nil) {
        self.prefilledOCR = prefilledOCR
    }

    private var isCC: Bool { selectedAccountId.hasPrefix("C-") }
    
    private var categories: [String] {
        if isCC || txType == .outflow {
            return categoryManager.categoryNames(for: .outflow)
        } else {
            return categoryManager.categoryNames(for: .inflow)
        }
    }
    
    private var currencySymbol: String {
        if let w = store.wallets.first(where: { "W-\($0.id)" == selectedAccountId }) { return w.currency.symbol }
        return "Rp" 
    }

    private var canSave: Bool {
        !selectedAccountId.isEmpty &&
        (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 &&
        (!isCC || !note.trimmingCharacters(in: .whitespaces).isEmpty) 
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        accountPicker
                        if !isCC { typeSelector }
                        amountField
                        categoryField
                        noteField
                        datePicker
                        saveBtn
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle("New Transaction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.glassText)
                }
            }
            .task {
                // ✅ Use .task instead of .onAppear - runs only once per view instance
                print("🎯 UniversalAdd: Initializing...")
                
                // Set default account
                if let firstWallet = store.wallets.first {
                    selectedAccountId = "W-\(firstWallet.id)"
                } else if let firstCC = store.creditCards.first {
                    selectedAccountId = "C-\(firstCC.id)"
                }
                
                // Try to load OCR data from multiple sources (priority order)
                var ocrData: OCRResult?
                
                // 1. Try from parameter (highest priority)
                if let prefilled = prefilledOCR {
                    ocrData = prefilled
                    print("✅ UniversalAdd: Using OCR data from parameter")
                }
                // 2. Try from OCRDataManager
                else if let managerData = ocrManager.consumePendingResult() {
                    ocrData = managerData
                    print("✅ UniversalAdd: Using OCR data from OCRDataManager")
                }
                // 3. Fallback to UserDefaults (for backward compatibility)
                else if let data = UserDefaults.standard.data(forKey: "pending_ocr_result"),
                        let decodedData = try? JSONDecoder().decode(OCRResult.self, from: data) {
                    ocrData = decodedData
                    UserDefaults.standard.removeObject(forKey: "pending_ocr_result")
                    print("✅ UniversalAdd: Using OCR data from UserDefaults (fallback)")
                }
                else {
                    print("ℹ️ UniversalAdd: No OCR data available - starting fresh")
                }
                
                // Populate fields if we have OCR data
                if let ocr = ocrData {
                    print("📝 UniversalAdd: Populating fields with OCR data:")
                    print("   - Merchant: \(ocr.merchant ?? "nil")")
                    print("   - Amount: \(ocr.totalAmount ?? 0)")
                    print("   - Date: \(ocr.date?.description ?? "nil")")
                    print("   - Items: \(ocr.receiptItems?.count ?? 0)")
                    
                    if let total = ocr.totalAmount {
                        amountText = String(format: "%.2f", total)
                    }
                    if let ocrDate = ocr.date {
                        date = ocrDate
                    }
                    if let merchant = ocr.merchant {
                        note = merchant
                    }
                    
                    print("✅ UniversalAdd: Fields populated successfully")
                    print("   - amountText: '\(amountText)'")
                    print("   - note: '\(note)'")
                    print("   - date: \(date)")
                }
            }
        }
    }

    private var accountPicker: some View {
        field("ACCOUNT", "building.columns") {
            Menu {
                if !store.wallets.isEmpty {
                    Section("Wallets") { ForEach(store.wallets) { w in Button(w.name) { selectedAccountId = "W-\(w.id)" } } }
                }
                if !store.creditCards.isEmpty {
                    Section("Credit Cards") { ForEach(store.creditCards) { c in Button("\(c.bank) \(c.name)") { selectedAccountId = "C-\(c.id)" } } }
                }
                if store.wallets.isEmpty && store.creditCards.isEmpty {
                    Button("No accounts available") {}.disabled(true)
                }
            } label: {
                HStack {
                    Text(accountLabel)
                        .foregroundStyle(selectedAccountId.isEmpty ? Color(white: 0.35) : .white)
                        .font(.body).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.dimText)
                }
                .frame(maxWidth: .infinity).padding(14)
                .background(Color.white.opacity(0.001)) 
                .glassEffect(in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain) 
        }
    }
    
    private var accountLabel: String {
        if let w = store.wallets.first(where: { "W-\($0.id)" == selectedAccountId }) { return "Wallet: \(w.name)" }
        if let c = store.creditCards.first(where: { "C-\($0.id)" == selectedAccountId }) { return "CC: \(c.bank) \(c.name)" }
        return "Select Account…"
    }

    private var typeSelector: some View {
        HStack(spacing: 10) {
            txTypeBtn(.inflow,  "Inflow",  "arrow.down.circle.fill", .neonGreen)
            txTypeBtn(.outflow, "Outflow", "arrow.up.circle.fill",   .neonRed)
        }
    }

    private var amountField: some View {
        field("AMOUNT", "banknote") {
            HStack(spacing: 10) {
                Text(currencySymbol).font(.headline).foregroundStyle(.glassText).frame(minWidth: 24)
                TextField("0", text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .textFieldStyle(.plain).font(.title3.bold()).foregroundStyle(.white)
            }
            .padding(14).glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    private var categoryField: some View {
        field("CATEGORY", "tag") {
            Menu {
                ForEach(categories, id: \.self) { cat in Button(cat) { category = cat } }
            } label: {
                HStack {
                    Text(category.isEmpty ? "Select category…" : category)
                        .foregroundStyle(category.isEmpty ? Color(white: 0.35) : .white).font(.body).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.dimText)
                }
                .frame(maxWidth: .infinity).padding(14)
                .background(Color.white.opacity(0.001)) 
                .glassEffect(in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    private var noteField: some View {
        field(isCC ? "DESCRIPTION" : "NOTE (optional)", isCC ? "text.alignleft" : "note.text") {
            TextField(isCC ? "e.g. Shopee purchase…" : "e.g. Lunch, groceries…", text: $note)
                .textFieldStyle(.plain).font(.body).foregroundStyle(.white)
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    private var datePicker: some View {
        field("DATE", "calendar") {
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact).labelsHidden()
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var saveBtn: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Save Transaction").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 17)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canSave).opacity(canSave ? 1 : 0.38)
    }

    @ViewBuilder
    private func field<C: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(0.8)
            content()
        }
    }

    @ViewBuilder
    private func txTypeBtn(_ type: TransactionType, _ label: String, _ icon: String, _ color: Color) -> some View {
        Button { withAnimation(.spring(duration: 0.2)) { txType = type; category = "" } } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(txType == type ? color : Color(white: 0.3))
                Text(label).font(.subheadline.weight(txType == type ? .semibold : .regular))
                    .foregroundStyle(txType == type ? .white : Color(white: 0.38))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .glassEffect(txType == type ? .regular.tint(color) : .regular, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard amount > 0 else { return }

        if selectedAccountId.hasPrefix("W-") {
            let wid = UUID(uuidString: String(selectedAccountId.dropFirst(2)))!
            let tx = WalletTransaction(walletId: wid, amount: amount, type: txType, category: category, note: note, date: date)
            store.addTransaction(tx)
        } else if selectedAccountId.hasPrefix("C-") {
            let cid = UUID(uuidString: String(selectedAccountId.dropFirst(2)))!
            let desc = note.trimmingCharacters(in: .whitespaces)
            let tx = CCTransaction(description: desc.isEmpty ? (category.isEmpty ? "Expense" : category) : desc, amount: amount, category: category, date: date)
            store.addCCTransaction(tx, to: cid)
        }
        dismiss()
    }
}

// MARK: - History Views Added for Dashboard

struct FinancialHealthExplanationSheet: View {
    let vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Score Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(vm.healthScoreColor.opacity(0.1), lineWidth: 10)
                                    .frame(width: 100, height: 100)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(vm.financialHealthScore) / 100)
                                    .stroke(vm.healthScoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                    .frame(width: 100, height: 100)
                                    .rotationEffect(.degrees(-90))
                                
                                Text("\(vm.financialHealthScore)")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(vm.healthScoreColor)
                            }
                            
                            Text(vm.healthScoreText)
                                .font(.title3.bold())
                                .foregroundStyle(vm.healthScoreColor)
                        }
                        .padding(.top, 20)
                        
                        // Breakdown Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Metric Breakdown")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            VStack(spacing: 12) {
                                explanationRow(title: "Net Worth", value: vm.currencyManager.format(amount: vm.totalNetWorth, currency: vm.baseCurrency), desc: "The total value of your assets minus your liabilities. Positive is good.")
                                Divider().background(Color.white.opacity(0.1))
                                explanationRow(title: "Debt Ratio", value: String(format: "%.1f%%", vm.debtToAssetRatio), desc: "Percentage of assets financed by debt. Below 30% is ideal.")
                                Divider().background(Color.white.opacity(0.1))
                                explanationRow(title: "Liquidity", value: String(format: "%.2fx", vm.liquidityRatio), desc: "Your ability to pay off short-term debts. Above 1.5x is strong.")
                                Divider().background(Color.white.opacity(0.1))
                                explanationRow(title: "Credit Usage", value: String(format: "%.1f%%", vm.creditUtilizationRatio), desc: "How much of your credit limit you're using. Keep it under 30%.")
                            }
                            .padding(16)
                            .glassEffect(in: .rect(cornerRadius: 18))
                        }
                        
                        // AI Recommendations
                        aiRecommendationsSection(vm)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Financial Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func aiRecommendationsSection(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("AI Recommendations", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.purple)
                Spacer()
                if vm.isLoadingAI {
                    ProgressView().tint(.purple)
                }
            }
            
            if let recommendation = vm.aiRecommendation {
                VStack(alignment: .trailing, spacing: 10) {
                    Text(recommendation)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.purple.opacity(0.2), lineWidth: 1))
                    
                    Button {
                        Task { await vm.fetchAIRecommendation() }
                    } label: {
                        Label("Refresh Advice", systemImage: "arrow.clockwise")
                            .font(.caption.bold())
                            .foregroundStyle(.purple)
                    }
                    .disabled(vm.isLoadingAI)
                }
            } else {
                Text("Click below to get personalized AI advice based on your current financial status.")
                    .font(.caption)
                    .foregroundStyle(.dimText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            
            if vm.aiRecommendation == nil {
                Button {
                    Task { await vm.fetchAIRecommendation() }
                } label: {
                    HStack(spacing: 10) {
                        if vm.isLoadingAI {
                            ProgressView().tint(.white)
                            Text("Generating...")
                        } else {
                            Image(systemName: "sparkles")
                            Text("Generate AI Advice")
                        }
                    }
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .tint(.purple)
                .disabled(vm.isLoadingAI)
            }
        }
    }
    
    private func explanationRow(title: String, value: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.bold()).foregroundStyle(.white)
                Spacer()
                Text(value).font(.subheadline.bold()).foregroundStyle(.white)
            }
            Text(desc).font(.caption2).foregroundStyle(.dimText)
        }
    }
}

struct SplitBillHistoryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            
            if store.splitBills.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 100, height: 100)
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.dimText)
                    }
                    Text("No Split Bills Saved")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Your split bill history will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.glassText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                List {
                    ForEach(store.splitBills.sorted { $0.date > $1.date }) { record in
                        NavigationLink(destination: SplitBillDetailView(record: record)) {
                            SplitBillHistoryRow(record: record)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { indices in
                        let records = store.splitBills.sorted { $0.date > $1.date }
                        for idx in indices {
                            store.deleteSplitBill(records[idx].id)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Split Bill History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct SplitBillHistoryRow: View {
    let record: SplitBillRecord
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "receipt")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.billName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                    Text("By \(record.payerName)")
                }
                .font(.caption2)
                .foregroundStyle(.glassText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(record.currency.symbol) \(formatNumber(record.totalAmount))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0))
                
                Text(record.date, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.dimText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 18))
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct SplitBillDetailView: View {
    let record: SplitBillRecord
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header Card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.neonGreen.opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.neonGreen)
                        }
                        
                        VStack(spacing: 4) {
                            Text(record.billName)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(record.date.formatted(date: .long, time: .omitted))
                                .font(.subheadline)
                                .foregroundStyle(.dimText)
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack(spacing: 20) {
                            detailHeaderItem(label: "TOTAL BILL", value: "\(record.currency.symbol) \(formatNumber(record.totalAmount))", color: .neonGreen)
                            Divider().background(Color.white.opacity(0.1)).frame(height: 40)
                            detailHeaderItem(label: "PAID BY", value: record.payerName, color: .white)
                        }
                    }
                    .padding(24)
                    .glassEffect(in: .rect(cornerRadius: 24))
                    
                    // Participants Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("PARTICIPANTS", systemImage: "person.2.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.glassText)
                                .kerning(1.2)
                            Spacer()
                            Text("\(record.participants.count)").font(.caption2).foregroundStyle(.dimText)
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(record.participants) { p in
                                HStack {
                                    Circle()
                                        .fill(Color(white: 0.15))
                                        .frame(width: 32, height: 32)
                                        .overlay(Text(String(p.name.prefix(1))).font(.caption.bold()).foregroundStyle(.white))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.white)
                                        Text("\(String(format: "%.1f", p.percentage))% of total")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.dimText)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(record.currency.symbol) \(formatNumber(p.amount))")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                
                                if p.id != record.participants.last?.id {
                                    Divider().background(Color.white.opacity(0.08)).padding(.leading, 60)
                                }
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: 20))
                    }
                    
                    // Items Section (if any)
                    if !record.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("RECEIPT ITEMS", systemImage: "list.bullet.rectangle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.glassText)
                                    .kerning(1.2)
                                Spacer()
                                Text("\(record.items.count)").font(.caption2).foregroundStyle(.dimText)
                            }
                            .padding(.horizontal, 4)
                            
                            VStack(spacing: 0) {
                                ForEach(record.items) { item in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.05))
                                                .frame(width: 40, height: 40)
                                            Text("\(item.qty)x").font(.caption.bold()).foregroundStyle(.glassText)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.white)
                                            Text("@ \(formatNumber(item.price))")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.dimText)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(record.currency.symbol) \(formatNumber(item.price * Double(item.qty)))")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    
                                    if item.id != record.items.last?.id {
                                        Divider().background(Color.white.opacity(0.08)).padding(.leading, 68)
                                    }
                                }
                            }
                            .glassEffect(in: .rect(cornerRadius: 20))
                        }
                    }
                    
                    // Actions
                    Button {
                        shareAsPDF()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up.fill")
                            Text("Share as PDF Statement").fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glassProminent)
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Bill Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func detailHeaderItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.glassText)
                .kerning(1)
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - PDF Generation & Sharing
    
    private func shareAsPDF() {
        let pdfData = generatePDF()
        
        let fileName = "\(record.billName.replacingOccurrences(of: " ", with: "_")).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: tempURL)
            
            // Present share sheet directly from the root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                
                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                
                // On iPad, present as popover
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("❌ Failed to save PDF: \(error)")
        }
    }
    
    private func generatePDF() -> Data {
        let pageWidth: CGFloat = 612   // US Letter width
        let pageHeight: CGFloat = 792  // US Letter height
        let margin: CGFloat = 48
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        return renderer.pdfData { ctx in
            ctx.beginPage()
            
            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let sectionFont = UIFont.boldSystemFont(ofSize: 16)
            let bodyFont = UIFont.systemFont(ofSize: 13)
            let amountFont = UIFont.boldSystemFont(ofSize: 13)
            let smallFont = UIFont.systemFont(ofSize: 10)
            
            var y: CGFloat = margin
            
            // ── Title ──
            let title = record.billName
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: titleFont, .foregroundColor: UIColor.black
            ])
            y += title.size(withAttributes: [.font: titleFont]).height + 8
            
            // ── Date ──
            let dateStr = "Date: \(record.date.formatted(date: .long, time: .omitted))"
            dateStr.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: smallFont, .foregroundColor: UIColor.gray
            ])
            y += 32
            
            // ── Separator ──
            ctx.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            ctx.cgContext.setLineWidth(0.5)
            ctx.cgContext.move(to: CGPoint(x: margin, y: y))
            ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            ctx.cgContext.strokePath()
            y += 16
            
            // ── Total Amount ──
            let totalLabel = "Total Amount"
            totalLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: bodyFont, .foregroundColor: UIColor.darkGray
            ])
            let totalValue = "\(record.currency.symbol) \(formatNumber(record.totalAmount))"
            let totalW = totalValue.size(withAttributes: [.font: amountFont]).width
            totalValue.draw(at: CGPoint(x: pageWidth - margin - totalW, y: y), withAttributes: [
                .font: amountFont, .foregroundColor: UIColor.systemBlue
            ])
            y += 22
            
            // ── Paid By ──
            let paidStr = "Paid By: \(record.payerName)"
            paidStr.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: bodyFont, .foregroundColor: UIColor.black
            ])
            y += 40
            
            // ── Participants Section ──
            let partLabel = "Participants (\(record.participants.count))"
            partLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: sectionFont, .foregroundColor: UIColor.black
            ])
            y += 28
            
            for p in record.participants {
                let name = p.name
                let amount = "\(record.currency.symbol) \(formatNumber(p.amount))"
                let amountW = amount.size(withAttributes: [.font: amountFont]).width
                
                name.draw(at: CGPoint(x: margin + 8, y: y), withAttributes: [
                    .font: bodyFont, .foregroundColor: UIColor.black
                ])
                amount.draw(at: CGPoint(x: pageWidth - margin - amountW, y: y), withAttributes: [
                    .font: amountFont, .foregroundColor: UIColor.systemBlue
                ])
                
                y += 22
                
                if p.id != record.participants.last?.id {
                    ctx.cgContext.setStrokeColor(UIColor(white: 0.85, alpha: 1.0).cgColor)
                    ctx.cgContext.move(to: CGPoint(x: margin + 8, y: y - 8))
                    ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y - 8))
                    ctx.cgContext.strokePath()
                }
            }
            
            y += 36
            
            // ── Items Section ──
            if !record.items.isEmpty {
                let itemLabel = "Receipt Items (\(record.items.count))"
                itemLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: sectionFont, .foregroundColor: UIColor.black
                ])
                y += 28
                
                for item in record.items {
                    let itemTotal = item.price * Double(item.qty)
                    let itemName = item.name
                    let qtyStr = "\(item.qty)x @ \(record.currency.symbol) \(formatNumber(item.price))"
                    let totalStr = "\(record.currency.symbol) \(formatNumber(itemTotal))"
                    let totalW = totalStr.size(withAttributes: [.font: bodyFont]).width
                    
                    itemName.draw(at: CGPoint(x: margin + 8, y: y), withAttributes: [
                        .font: bodyFont, .foregroundColor: UIColor.black
                    ])
                    y += 18
                    
                    qtyStr.draw(at: CGPoint(x: margin + 8, y: y), withAttributes: [
                        .font: smallFont, .foregroundColor: UIColor.gray
                    ])
                    
                    totalStr.draw(at: CGPoint(x: pageWidth - margin - totalW, y: y), withAttributes: [
                        .font: bodyFont, .foregroundColor: UIColor.black
                    ])
                    
                    y += 24
                    
                    if item.id != record.items.last?.id {
                        ctx.cgContext.setStrokeColor(UIColor(white: 0.85, alpha: 1.0).cgColor)
                        ctx.cgContext.move(to: CGPoint(x: margin + 8, y: y - 6))
                        ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y - 6))
                        ctx.cgContext.strokePath()
                    }
                }
            }
            
            // ── Footer ──
            let footer = "Generated by Duit Gw Woi Alias DGW Anjay App"
            let footerW = footer.size(withAttributes: [.font: smallFont]).width
            footer.draw(at: CGPoint(x: (pageWidth - footerW) / 2, y: pageHeight - 36), withAttributes: [
                .font: smallFont, .foregroundColor: UIColor.gray
            ])
        }
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
