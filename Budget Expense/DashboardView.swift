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

// MARK: - CC Liability Mode Enum
enum CCLiabilityMode: String, CaseIterable {
    case total = "Total"
    case monthly = "Monthly"
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
    @State private var showBalanceBreakdown = false
    @AppStorage("showBalances") private var showBalances: Bool = true
    @AppStorage("ccLiabilityMode") private var ccLiabilityMode: CCLiabilityMode = .total
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
            .sheet(isPresented: $showBalanceBreakdown) {
                BalanceBreakdownSheet(
                    totalWalletBalance: totalWalletBalanceIDR,
                    totalReceivables: totalReceivablesIDR,
                    totalCCDebt: ccLiabilityMode == .total ? store.totalOutstandingCC : store.totalMonthlyPayable,
                    totalNetWorth: totalNetWorthIDR,
                    liabilityMode: $ccLiabilityMode
                )
                .environment(store)
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
        let ccLiability = ccLiabilityMode == .total ? store.totalOutstandingCC : store.totalMonthlyPayable
        return totalWalletBalanceIDR + totalReceivablesIDR - ccLiability
    }
    
    private var totalWalletBalanceIDR: Double {
        store.wallets.reduce(0) { sum, w in
            let amountInBase = currencyManager.toBaseCurrency(amount: w.signedBalance, from: w.currency)
            return sum + amountInBase
        }
    }
    
    private var totalReceivablesIDR: Double {
        if ccLiabilityMode == .total {
            return store.totalReceivables
        } else {
            return store.totalReceivablesMonthly
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
                    .fill(Color.warmOrange)
                    .frame(width: 42, height: 42)
                Image("image_logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
            VStack(spacing: 1) {
                Text("Dashboard")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.warmCard)
                Text(Date().formatted(.dateTime.weekday(.wide).day().month()))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.warmCard.opacity(0.45))
            }
            Spacer()
            Button {
                withAnimation { showBalances.toggle() }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.warmDark)
                        .frame(width: 38, height: 38)
                    Image(systemName: showBalances ? "eye" : "eye.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.warmCard)
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
                    cardColor: Color.warmCard,
                    orbColors: [Color.warmOrange, Color(red: 0.18, green: 0.14, blue: 0.12)],
                    icon: "chart.line.uptrend.xyaxis",
                    accentColor: totalNetWorthIDR >= 0 ? Color.warmOrange : Color.neonRed,
                    badge: ccLiabilityMode == .total ? "Total Liability" : "Monthly Due"
                )
                .tag(0)
                .onTapGesture {
                    showBalanceBreakdown = true
                }
                .contextMenu {
                    Button(action: { ccLiabilityMode = .total }) {
                        Label("Subtract Total CC Debt", systemImage: ccLiabilityMode == .total ? "checkmark.circle.fill" : "circle")
                    }
                    Button(action: { ccLiabilityMode = .monthly }) {
                        Label("Subtract This Month's CC Due", systemImage: ccLiabilityMode == .monthly ? "checkmark.circle.fill" : "circle")
                    }
                }

                balanceCard(
                    title: "Wallet Balance",
                    amount: totalWalletBalanceIDR,
                    cardColor: Color(red: 0.18, green: 0.14, blue: 0.12),
                    orbColors: [Color.warmOrange, Color.warmCard.opacity(0.15)],
                    icon: "wallet.bifold.fill",
                    accentColor: Color.warmCard,
                    badge: "\(store.wallets.count) wallet\(store.wallets.count != 1 ? "s" : "")"
                ).tag(1)

                balanceCard(
                    title: "Credit Available",
                    amount: totalCCLimitRemaining,
                    cardColor: Color.warmOrange,
                    orbColors: [Color.warmCard.opacity(0.25), Color(red: 0.18, green: 0.14, blue: 0.12)],
                    icon: "creditcard.fill",
                    accentColor: Color.warmCard,
                    badge: "\(creditCardCount) card\(creditCardCount != 1 ? "s" : "")",
                    progress: (used: totalCCUsed, total: totalCCTotalLimit)
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)
            
            // Custom Page Indicator
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(currentCardIndex == index ? Color.warmOrange : Color.warmCard.opacity(0.25))
                        .frame(width: currentCardIndex == index ? 22 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentCardIndex)
                }
            }
        }
    }

    private func balanceCard(
        title: String,
        amount: Double,
        cardColor: Color,
        orbColors: [Color],
        icon: String,
        accentColor: Color,
        badge: String,
        progress: (used: Double, total: Double)? = nil
    ) -> some View {
        let isDark = cardColor == Color.warmCard ? false : true
        let textPrimary: Color = isDark ? Color.warmCard : Color(red: 0.11, green: 0.09, blue: 0.08)
        let textSecondary: Color = isDark ? Color.warmCard.opacity(0.55) : Color(red: 0.11, green: 0.09, blue: 0.08).opacity(0.5)

        return ZStack(alignment: .bottomTrailing) {
            // Geometric orb decorations (like the Dribbble reference)
            Circle()
                .fill(orbColors[0])
                .frame(width: 130, height: 130)
                .offset(x: 55, y: 55)

            Circle()
                .fill(orbColors.count > 1 ? orbColors[1] : orbColors[0].opacity(0.5))
                .frame(width: 90, height: 90)
                .offset(x: 10, y: 35)

            // Card content
            VStack(alignment: .leading, spacing: 0) {
                // Title row
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentColor.opacity(isDark ? 0.2 : 0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(accentColor)
                        }
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textSecondary)
                    }
                    Spacer()
                    Text(badge)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(isDark ? Color.warmCard : Color.warmOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(isDark ? Color.warmCard.opacity(0.15) : Color.warmOrange.opacity(0.12))
                        )
                }
                .padding(.bottom, 14)

                // Amount
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(baseCurrency.symbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(textSecondary)
                    if showBalances {
                        Text(formatNumber(amount))
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(textPrimary)
                            .minimumScaleFactor(0.55)
                            .lineLimit(1)
                    } else {
                        Text("••••••")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(textSecondary)
                    }
                }
                .padding(.bottom, progress != nil ? 10 : 0)

                // Progress (Credit card)
                if let progress {
                    let ratio = progress.total > 0 ? min(max(progress.used / progress.total, 0), 1) : 0
                    let pct   = progress.total > 0 ? (progress.used / progress.total) * 100 : 0
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Used")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(textSecondary)
                            Spacer()
                            Text(String(format: "%.0f%%", pct))
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(accentColor)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(textPrimary.opacity(0.12))
                                    .frame(height: 7)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(accentColor)
                                    .frame(width: geo.size.width * ratio, height: 7)
                            }
                        }
                        .frame(height: 7)
                    }
                }

                Spacer(minLength: 0)

                // Footer
                HStack {
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(textSecondary)
                        .monospacedDigit()
                    Spacer()
                    HStack(spacing: -6) {
                        Circle().fill(Color.warmOrange).frame(width: 20, height: 20)
                        Circle().fill(textPrimary.opacity(0.25)).frame(width: 20, height: 20)
                    }
                }
            }
            .padding(22)
            .frame(height: 200)
        }
        .frame(height: 200)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
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
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.warmOrange.opacity(0.18))
                                .frame(width: 36, height: 36)
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.warmOrange)
                        }

                        Text("Financial Health")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.warmCard)
                        
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
                                        .fill(vm.healthScoreColor.opacity(0.15))
                                        .frame(width: 50, height: 50)
                                        .overlay(Circle().stroke(vm.healthScoreColor.opacity(0.3), lineWidth: 1))
                                        .shadow(color: vm.healthScoreColor.opacity(0.35), radius: 12, x: 0, y: 0)

                                    Image(systemName: "heart.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(vm.healthScoreColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Financial Health Score")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(Color.warmCard)

                                    Text("Based on 4 key metrics")
                                        .font(.caption2)
                                        .foregroundStyle(Color.warmCard.opacity(0.5))
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
                                        .fill(Color.warmCard.opacity(0.1))
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
                                        Text(marker.0).font(.system(size: 9, weight: .medium)).foregroundStyle(Color.warmCard.opacity(0.35))
                                    } else {
                                        Spacer()
                                        Text(marker.0).font(.system(size: 9, weight: .medium)).foregroundStyle(Color.warmCard.opacity(0.35))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(Color.warmDark)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
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
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.warmOrange.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.warmOrange)
            }
            .padding(.bottom, 10)
            
            // Title
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.warmCard.opacity(0.5))
                .padding(.bottom, 6)

            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.warmCard)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 6)

            Text(subtitle)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Color.warmOrange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.warmOrange.opacity(0.15), in: Capsule())

            Spacer(minLength: 0)

            Rectangle()
                .fill(Color.warmOrange)
                .frame(height: 3)
                .frame(maxWidth: 36)
                .clipShape(Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Color.warmDark)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
    }

    private var creditCardOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundStyle(Color.warmOrange)

                Text("Credit Card Overview")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.warmCard)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(creditCardCount)")
                        .font(.title2.bold())
                        .foregroundStyle(Color.warmOrange)
                    Text("card\(creditCardCount != 1 ? "s" : "")")
                        .font(.caption2)
                        .foregroundStyle(Color.warmCard.opacity(0.5))
                }
            }
            
            // Credit Utilization Progress
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Credit Utilization")
                        .font(.subheadline)
                        .foregroundStyle(Color.warmCard.opacity(0.6))
                    
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
                            .fill(Color.warmCard.opacity(0.12))
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
                        .foregroundStyle(Color.warmCard.opacity(0.5))

                    HStack(spacing: 2) {
                        Text(baseCurrency.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.neonRed.opacity(0.8))
                        Text(formatNumber(totalCreditUsed))
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.neonRed)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                    .background(.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available")
                        .font(.caption2)
                        .foregroundStyle(Color.warmCard.opacity(0.5))

                    HStack(spacing: 2) {
                        Text(baseCurrency.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.neonGreen.opacity(0.8))
                        Text(formatNumber(totalCreditAvailable))
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.neonGreen)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                    .background(.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Limit")
                        .font(.caption2)
                        .foregroundStyle(Color.warmCard.opacity(0.5))

                    HStack(spacing: 2) {
                        Text(baseCurrency.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.warmCard.opacity(0.6))
                        Text(formatNumber(totalCreditLimit))
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.warmCard)
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
                            .foregroundStyle(Color.warmCard.opacity(0.6))
                    }

                    HStack(spacing: 4) {
                        Text(baseCurrency.symbol)
                            .font(.headline)
                            .foregroundStyle(Color.warmOrange)
                        Text(formatNumber(totalMonthlyDue))
                            .font(.title3.bold())
                            .foregroundStyle(Color.warmCard)
                    }
                }

                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.warmOrange.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.warmDark, Color.warmDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 16)
    }

    private var cardUtilizationBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.warmOrange)

                Text("Card Utilization Breakdown")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.warmCard)

                Spacer()

                Text("Avg: \(String(format: "%.1f%%", averageUtilizationPerCard))")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.warmCard.opacity(0.45))
            }
            
            ForEach(store.creditCards.prefix(3)) { card in
                VStack(spacing: 6) {
                    HStack {
                        Text(card.name)
                            .font(.caption)
                            .foregroundStyle(Color.warmCard.opacity(0.8))
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%%", card.usedPercent * 100))
                            .font(.caption.bold())
                            .foregroundStyle(cardUtilizationColor(card.usedPercent * 100))
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.warmCard.opacity(0.1))
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
                    .foregroundStyle(Color.warmCard.opacity(0.45))
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.warmDark, Color.warmDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 16)
    }

    private var portfolioDistribution: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.warmOrange)

                Text("Portfolio Distribution")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.warmCard)
                
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
                colors: [Color.warmDark, Color.warmDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
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
                colors: [Color.warmDark, Color.warmDark],
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.warmOrange.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.warmOrange)
                }

                Text("Quick Actions")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.warmCard)
                
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.warmOrange.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.warmOrange)
                }

                Text("Analytics")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.warmCard)
                
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
                    .background(Color.warmOrange)
                    .clipShape(Capsule())
                    .shadow(color: Color.warmOrange.opacity(0.35), radius: 6, x: 0, y: 2)
                    .foregroundStyle(Color.warmCard)
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
                        .foregroundStyle(Color.warmCard.opacity(0.5))
                    
                    let totalInflow = convertedChartData.reduce(0) { $0 + $1.inflow }
                    Text(formatNumber(totalInflow))
                        .font(.subheadline.bold())
                        .foregroundStyle(.neonGreen)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.neonGreen.opacity(0.1))
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Outflow")
                        .font(.caption2)
                        .foregroundStyle(Color.warmCard.opacity(0.5))
                    
                    let totalOutflow = convertedChartData.reduce(0) { $0 + $1.outflow }
                    Text(formatNumber(totalOutflow))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.warmOrange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.warmOrange.opacity(0.1))
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
                            colors: [Color.warmOrange, Color.warmOrange.opacity(0.6)],
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
                        .foregroundStyle(Color.warmCard.opacity(0.45))
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.warmCard.opacity(0.7))
                }
                
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.warmOrange)
                        .frame(width: 12, height: 12)

                    Text("Outflow")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.warmCard.opacity(0.7))
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
        .background(Color.warmDark)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 16)
    }

    // MARK: - Transactions List (Combined Wallet & CC)

    private var recentTransactionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Transactions")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color.warmCard)
                    Rectangle()
                        .fill(Color.warmOrange)
                        .frame(width: 28, height: 3)
                        .clipShape(Capsule())
                }
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
                    .foregroundStyle(Color.warmCard.opacity(0.4))
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
                                .background(Color.warmCard.opacity(0.08))
                                .padding(.leading, 74)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .background(Color.warmDark)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
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
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.warmOrange)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.warmCard)
                }
                Spacer()
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.warmOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.warmOrange.opacity(0.15), in: Capsule())
                }
            }
            .padding(.bottom, 14)

            Text(title)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.warmCard)
                .padding(.bottom, 3)

            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.warmCard.opacity(0.45))

            Spacer(minLength: 0)

            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.warmOrange)
                        .frame(width: 28, height: 28)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.warmCard)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(Color.warmDark)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
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
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isIncome ? Color.neonGreen.opacity(0.15) : Color.warmOrange.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isIncome ? Color.neonGreen : Color.warmOrange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(categoryName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.warmCard)
                Text(accountName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.warmCard.opacity(0.45))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(showBalances ? amountString : "••••••")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(isIncome ? Color.neonGreen : Color.warmCard)
                Text(item.date, format: .dateTime.day().month().year())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.warmCard.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
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
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.warmOrange.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.warmOrange)
                }
                Spacer()
                Text(badge)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color.warmOrange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.warmOrange.opacity(0.15), in: Capsule())
            }
            .padding(.bottom, 10)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.warmCard.opacity(0.5))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 5)

            Text(value)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color.warmCard)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 0)

            Rectangle()
                .fill(Color.warmOrange)
                .frame(height: 3)
                .frame(maxWidth: 36)
                .clipShape(Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(Color.warmDark)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        scoreHeroCard
                        metricsSection
                        aiSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.warmOrange.opacity(0.18))
                                .frame(width: 28, height: 28)
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.warmOrange)
                        }
                        Text("Financial Health")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Color.warmCard)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.warmDark)
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color.warmCard)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Score Hero Card (cream card like the balance cards)
    private var scoreHeroCard: some View {
        ZStack(alignment: .bottomTrailing) {
            // Geometric orb decoration
            Circle()
                .fill(Color.warmOrange)
                .frame(width: 140, height: 140)
                .offset(x: 55, y: 55)
            Circle()
                .fill(Color(red: 0.18, green: 0.14, blue: 0.12))
                .frame(width: 95, height: 95)
                .offset(x: 12, y: 38)

            VStack(alignment: .leading, spacing: 0) {
                // Top row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health Score")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0.11, green: 0.09, blue: 0.08).opacity(0.5))
                        Text("Your financial overview")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(red: 0.11, green: 0.09, blue: 0.08).opacity(0.38))
                    }
                    Spacer()
                    Text(vm.healthScoreText)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.warmOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.warmOrange.opacity(0.12), in: Capsule())
                }
                .padding(.bottom, 12)

                // Big score number
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(vm.financialHealthScore)")
                        .font(.system(size: 64, weight: .black))
                        .foregroundStyle(Color(red: 0.11, green: 0.09, blue: 0.08))
                    Text("/ 100")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(red: 0.11, green: 0.09, blue: 0.08).opacity(0.35))
                        .padding(.bottom, 6)
                }

                // Score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.11, green: 0.09, blue: 0.08).opacity(0.1))
                            .frame(height: 7)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.warmOrange)
                            .frame(width: geo.size.width * CGFloat(vm.financialHealthScore) / 100, height: 7)
                    }
                }
                .frame(height: 7)
                .padding(.bottom, 10)

                // Contextual hint
                Text(vm.financialHealthScore >= 80 ? "You're in great shape — keep optimizing!"
                     : vm.financialHealthScore >= 60 ? "Solid foundation, a few things to tighten up."
                     : vm.financialHealthScore >= 40 ? "Some areas need your attention."
                     : "Action needed — let's fix this together.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.11, green: 0.09, blue: 0.08).opacity(0.55))
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(Color.warmCard)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
    }

    // MARK: - 4 Metric Tiles
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "chart.pie.fill", title: "Metric Breakdown")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricTile(
                    icon: "dollarsign.circle.fill",
                    title: "Net Worth",
                    value: vm.currencyManager.format(amount: vm.totalNetWorth, currency: vm.baseCurrency),
                    desc: "Assets minus liabilities",
                    status: vm.totalNetWorth >= 0 ? "Positive" : "Negative",
                    statusOk: vm.totalNetWorth >= 0
                )
                metricTile(
                    icon: "chart.pie.fill",
                    title: "Debt Ratio",
                    value: String(format: "%.1f%%", vm.debtToAssetRatio),
                    desc: "Debt vs assets. < 30% is ideal",
                    status: vm.debtToAssetRatio < 30 ? "Healthy" : vm.debtToAssetRatio < 50 ? "Moderate" : "High",
                    statusOk: vm.debtToAssetRatio < 30
                )
                metricTile(
                    icon: "drop.fill",
                    title: "Liquidity",
                    value: String(format: "%.2fx", vm.liquidityRatio),
                    desc: "Ability to cover short-term debt",
                    status: vm.liquidityRatio > 2 ? "Strong" : vm.liquidityRatio > 1 ? "Adequate" : "Low",
                    statusOk: vm.liquidityRatio > 1.5
                )
                metricTile(
                    icon: "creditcard.fill",
                    title: "Credit Usage",
                    value: String(format: "%.1f%%", vm.creditUtilizationRatio),
                    desc: "% of credit limit used. < 30%",
                    status: vm.creditUtilizationRatio < 30 ? "Good" : vm.creditUtilizationRatio < 50 ? "Caution" : "High",
                    statusOk: vm.creditUtilizationRatio < 30
                )
            }
        }
    }

    // MARK: - AI Section
    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(icon: "sparkles", title: "AI Advice")
                Spacer()
                if vm.isLoadingAI {
                    HStack(spacing: 6) {
                        ProgressView()
                            .tint(Color.warmOrange)
                            .scaleEffect(0.8)
                        Text("Thinking...")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.warmCard.opacity(0.5))
                    }
                }
            }

            if let recommendation = vm.aiRecommendation {
                // Recommendation card
                VStack(alignment: .leading, spacing: 0) {
                    // Card header
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.warmOrange)
                                .frame(width: 38, height: 38)
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.warmCard)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gemini AI")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(Color.warmCard)
                            Text("Personalized financial advice")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.warmCard.opacity(0.45))
                        }
                        Spacer()
                        Button {
                            Task { await vm.fetchAIRecommendation() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.warmOrange.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.warmOrange)
                                    .rotationEffect(vm.isLoadingAI ? .degrees(360) : .zero)
                                    .animation(vm.isLoadingAI ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.isLoadingAI)
                            }
                        }
                        .disabled(vm.isLoadingAI)
                    }
                    .padding(16)

                    Rectangle()
                        .fill(Color.warmCard.opacity(0.08))
                        .frame(height: 1)

                    Text(recommendation)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.warmCard.opacity(0.85))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                }
                .background(Color.warmDark)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)

            } else {
                // Empty state + generate button
                VStack(spacing: 16) {
                    // Empty state card
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.warmOrange.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: "sparkles")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Color.warmOrange)
                        }
                        Text("Get Personalized Advice")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.warmCard)
                        Text("Gemini AI will analyze your 4 key metrics and give you a concrete action plan.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.warmCard.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.warmDark)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)

                    // Generate button
                    Button {
                        Task { await vm.fetchAIRecommendation() }
                    } label: {
                        HStack(spacing: 10) {
                            if vm.isLoadingAI {
                                ProgressView().tint(Color.warmCard).scaleEffect(0.85)
                                Text("Generating...")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(Color.warmCard)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.warmCard)
                                Text("Generate AI Advice")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(Color.warmCard)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(vm.isLoadingAI ? Color.warmOrange.opacity(0.6) : Color.warmOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.warmOrange.opacity(0.35), radius: 8, x: 0, y: 3)
                    }
                    .disabled(vm.isLoadingAI)
                }
            }
        }
    }

    // MARK: - Helpers
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.warmOrange.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.warmOrange)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.warmCard)
                Rectangle()
                    .fill(Color.warmOrange)
                    .frame(width: 20, height: 3)
                    .clipShape(Capsule())
            }
        }
    }

    private func metricTile(icon: String, title: String, value: String, desc: String, status: String, statusOk: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.warmOrange.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.warmOrange)
                }
                Spacer()
                Text(status)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(statusOk ? Color.neonGreen : Color.neonRed)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((statusOk ? Color.neonGreen : Color.neonRed).opacity(0.12), in: Capsule())
            }
            .padding(.bottom, 10)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.warmCard.opacity(0.45))
                .padding(.bottom, 4)

            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.warmCard)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.bottom, 6)

            Text(desc)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.warmCard.opacity(0.35))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Rectangle()
                .fill(Color.warmOrange)
                .frame(height: 3)
                .frame(maxWidth: 28)
                .clipShape(Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 165)
        .background(Color.warmDark)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
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
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.warmOrange)
                    .frame(width: 46, height: 46)
                Image(systemName: "receipt")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.warmCard)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.billName)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.warmCard)

                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("By \(record.payerName)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.warmCard.opacity(0.45))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(record.currency.symbol) \(formatNumber(record.totalAmount))")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.warmOrange)

                Text(record.date, style: .date)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.warmCard.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.warmDark)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 3)
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

struct BalanceBreakdownSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    let totalWalletBalance: Double
    let totalReceivables: Double
    let totalCCDebt: Double
    let totalNetWorth: Double
    @Binding var liabilityMode: CCLiabilityMode
    
    private var currencyManager: CurrencyManager {
        store.currencyManager
    }
    
    private var baseCurrency: Currency {
        currencyManager.baseCurrency
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Liability Mode Selector
                        Picker("CC Liability Mode", selection: $liabilityMode) {
                            Text("Total Debt").tag(CCLiabilityMode.total)
                            Text("Monthly Due").tag(CCLiabilityMode.monthly)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        // Summary Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.warmOrange.opacity(0.12))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "equal.circle.fill")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(Color.warmOrange)
                            }
                            
                            VStack(spacing: 4) {
                                Text("Total Net Worth")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.warmOrange)
                                    .kerning(1.2)
                                    .textCase(.uppercase)
                                
                                Text(currencyManager.format(amount: totalNetWorth, currency: baseCurrency))
                                    .font(.system(size: 34, weight: .black))
                                    .foregroundStyle(Color.warmCard)
                            }
                        }
                        
                        // Calculation Breakdown
                        VStack(spacing: 0) {
                            breakdownRow(
                                title: "Wallet Balances",
                                description: "Cash and bank accounts",
                                amount: totalWalletBalance,
                                icon: "wallet.bifold.fill",
                                color: .neonGreen,
                                isPositive: true
                            )
                            
                            Divider().background(Color.white.opacity(0.05)).padding(.leading, 60)
                            
                            breakdownRow(
                                title: "Receivables",
                                description: liabilityMode == .total ? "Total remaining balance" : "Total installments due this month",
                                amount: totalReceivables,
                                icon: "person.2.fill",
                                color: Color(red: 0.3, green: 0.6, blue: 1.0),
                                isPositive: true
                            )
                            
                            Divider().background(Color.white.opacity(0.05)).padding(.leading, 60)
                            
                            breakdownRow(
                                title: "Credit Card Debt",
                                description: liabilityMode == .total ? "Total outstanding liabilities" : "Total due this month",
                                amount: totalCCDebt,
                                icon: "creditcard.fill",
                                color: .neonRed,
                                isPositive: false
                            )
                        }
                        .background(Color.warmDark)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                        
                        // Educational Note
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(Color.warmOrange)
                                Text("The Formula")
                                    .font(.headline)
                                    .foregroundStyle(Color.warmCard)
                            }
                            
                            Text("Total Balance = (Wallets + Receivables) - CC \(liabilityMode == .total ? "Total" : "Monthly Due")")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.warmCard.opacity(0.8))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.warmOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            
                            Text(liabilityMode == .total 
                                ? "This mode subtracts all your outstanding credit card transactions and remaining installment principal, giving you a full long-term view of your net worth."
                                : "This mode only subtracts what you must pay this month (current bill + installments), showing your immediate liquidity after monthly obligations.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.warmCard.opacity(0.5))
                                .lineSpacing(4)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.warmDark.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Balance Calculation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.warmOrange)
                }
            }
        }
    }
    
    private func breakdownRow(title: String, description: String, amount: Double, icon: String, color: Color, isPositive: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.warmCard)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.warmCard.opacity(0.4))
            }
            
            Spacer()
            
            Text((isPositive ? "" : "-") + currencyManager.format(amount: amount, currency: baseCurrency))
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(isPositive ? Color.warmCard : .neonRed)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }
}
