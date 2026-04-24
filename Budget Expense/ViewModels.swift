import SwiftUI
import Observation

// MARK: - Wallets ViewModel

@Observable
class WalletsViewModel {
    private let store: AppStore
    
    var activeSheet: DebitActiveSheet?
    
    init(store: AppStore) {
        self.store = store
    }
    
    var wallets: [Wallet] {
        store.wallets
    }
    
    var totalAssets: Double {
        store.wallets.filter { $0.isPositive }.reduce(0) { sum, wallet in
            sum + store.currencyManager.toBaseCurrency(amount: wallet.balance, from: wallet.currency)
        }
    }
    
    var totalLiabilities: Double {
        store.wallets.filter { !$0.isPositive }.reduce(0) { sum, wallet in
            sum + store.currencyManager.toBaseCurrency(amount: wallet.balance, from: wallet.currency)
        }
    }
    
    var netTotal: Double {
        totalAssets - totalLiabilities
    }
    
    var assetCount: Int {
        store.wallets.filter { $0.isPositive }.count
    }
    
    var liabilityCount: Int {
        store.wallets.filter { !$0.isPositive }.count
    }
    
    var baseCurrency: Currency {
        store.currencyManager.baseCurrency
    }
    
    func deleteWallet(_ id: UUID) {
        store.deleteWallet(id)
    }
}

// MARK: - Wallet Detail ViewModel

@Observable
class WalletDetailViewModel {
    private let store: AppStore
    let walletId: UUID
    
    var activeSheet: DetailActiveSheet?
    
    init(store: AppStore, walletId: UUID) {
        self.store = store
        self.walletId = walletId
    }
    
    var wallet: Wallet? {
        store.wallets.first { $0.id == walletId }
    }
    
    var transactions: [WalletTransaction] {
        store.transactions(for: walletId)
    }
    
    func deleteTransaction(_ tx: WalletTransaction) {
        store.deleteTransaction(tx)
    }
}

// MARK: - Credit Cards ViewModel

@Observable
class CreditCardsViewModel {
    private let store: AppStore
    
    var showAdd = false
    
    init(store: AppStore) {
        self.store = store
    }
    
    var creditCards: [CreditCard] {
        store.creditCards
    }
    
    func deleteCreditCard(at offsets: IndexSet) {
        store.deleteCreditCards(at: offsets)
    }
    
    func totalDue(for card: CreditCard) -> Double {
        store.totalDueThisMonth(for: card)
    }
}

// MARK: - Credit Card Detail ViewModel

@Observable
class CreditCardDetailViewModel {
    private let store: AppStore
    let cardId: UUID
    
    var showAddTx = false
    var showAddInst = false
    var editTxTarget: CCTransaction?
    var editInstTarget: Installment?
    
    init(store: AppStore, cardId: UUID) {
        self.store = store
        self.cardId = cardId
    }
    
    var card: CreditCard? {
        store.creditCards.first { $0.id == cardId }
    }
    
    var currentCycleTransactions: [CCTransaction] {
        guard let card = card else { return [] }
        return store.currentCycleTransactions(for: card).sorted { $0.date > $1.date }
    }
    
    var currentCycleBill: Double {
        guard let card = card else { return 0 }
        return store.currentCycleBill(for: card)
    }
    
    var currentMonthInstallments: Double {
        guard let card = card else { return 0 }
        return store.currentMonthInstallments(for: card)
    }
    
    var totalDueThisMonth: Double {
        guard let card = card else { return 0 }
        return store.totalDueThisMonth(for: card)
    }
    
    var billingCycleDates: (start: Date, end: Date) {
        guard let card = card else { return (Date(), Date()) }
        return store.billingCycleDates(for: card)
    }
    
    var billingCycleDueDate: Date {
        guard let card = card else { return Date() }
        return store.billingCycleDueDate(for: card)
    }
    
    func payCurrentCycleBill() {
        store.payCurrentCycleBill(for: cardId)
    }
    
    func deleteTransaction(_ txId: UUID) {
        store.deleteCCTransaction(txId, from: cardId)
    }
    
    func deleteInstallment(_ instId: UUID) {
        store.deleteInstallment(instId, from: cardId)
    }
}

// MARK: - Dashboard ViewModel

@Observable
class DashboardViewModel {
    private let store: AppStore
    
    var currentCardIndex = 0
    var selectedChartRange: ChartRange = .last6Months
    var showHealthExplanation = false
    var aiRecommendation: String?
    var isLoadingAI = false
    
    func fetchAIRecommendation() async {
        isLoadingAI = true
        defer { isLoadingAI = false }
        
        let metrics = """
                Net Worth: \(currencyManager.format(amount: totalNetWorth, currency: baseCurrency))
                Debt-to-Asset Ratio: \(String(format: "%.1f%%", debtToAssetRatio))
                Liquidity Ratio: \(String(format: "%.2fx", liquidityRatio))
                Credit Utilization: \(String(format: "%.1f%%", creditUtilizationRatio))
                Financial Health Score: \(financialHealthScore)/100
                """

        let prompt = """
                You are a highly strategic, upbeat, and interactive financial coach. 

                Analyze the user's financial condition using the metrics below. Your goal is to tell them EXACTLY what to do next in a fun, straightforward way, without any confusing financial jargon.

                STRICT INSTRUCTIONS:
                - Base every recommendation ONLY on the provided metrics.
                - Use clear financial benchmarks:
                  • Debt-to-Asset: <30% = 🟢 Healthy, 30–60% = 🟡 Moderate, >60% = 🔴 Risky
                  • Liquidity Ratio: <1.0 = 🔴 Weak, 1.0–2.0 = 🟡 Acceptable, >2.0 = 🟢 Strong
                  • Credit Utilization: <30% = 🟢 Good, 30–50% = 🟡 Caution, >50% = 🔴 High Risk
                - If a metric is strong → suggest ways to optimize and "level up."
                - If weak → give an urgent, straightforward corrective action.
                - Tone: Fun, motivating, interactive, and straight to the point. Give direct commands (e.g., "Do this first:").

                STRUCTURE YOUR RESPONSE AS FOLLOWS:

                🔥 THE VIBE CHECK (Quick Summary)
                Give a 1-2 sentence punchy summary of their overall financial health based on their score. 

                🛠️ YOUR ACTION PLAN (Sort by highest risk first!)
                For each metric, provide:
                - 📊 Metric & Status: [Name of Metric] ([Value]) -> [Emoji Status from Benchmarks]
                - 👉 What You Must Do: (1-2 clear, specific, straightforward steps with numbers or % targets)
                - 🚀 The Payoff: (What exactly improves if they do this)

                🗓️ YOUR 1-YEAR GAME PLAN
                Map out a fun, actionable 12-month timeline based on their biggest weak spots and strengths:
                - 🎯 Months 1-3: Immediate Action (What needs fixing right now)
                - 🏃‍♂️ Months 4-8: Building Momentum (Stabilizing and growing)
                - 🚀 Months 9-12: Leveling Up (Optimizing net worth and looking ahead)

                METRICS TO ANALYZE:
                \(metrics)
                """
        
        do {
            aiRecommendation = try await VertexAIService.getFinancialRecommendation(prompt: prompt)
            print(aiRecommendation ?? "Error")
        } catch {
            aiRecommendation = "Failed to get AI recommendation: \(error.localizedDescription)"
        }
    }
    
    // Exchange rate data (managed via UserDefaults since @AppStorage is view-specific)
    var usdToIdrRate: Double {
        get { UserDefaults.standard.double(forKey: "usdToIdrRate") == 0 ? 16200.0 : UserDefaults.standard.double(forKey: "usdToIdrRate") }
        set { UserDefaults.standard.set(newValue, forKey: "usdToIdrRate") }
    }
    
    var lastFetchDate: Double {
        get { UserDefaults.standard.double(forKey: "lastRateFetchTime") }
        set { UserDefaults.standard.set(newValue, forKey: "lastRateFetchTime") }
    }
    
    init(store: AppStore) {
        self.store = store
    }
    
    var currencyManager: CurrencyManager { store.currencyManager }
    var baseCurrency: Currency { currencyManager.baseCurrency }
    
    // MARK: - Metrics
    
    var totalNetWorth: Double {
        totalWalletBalance + totalReceivables - store.totalOutstandingCC
    }
    
    var totalWalletBalance: Double {
        store.wallets.reduce(0) { sum, w in
            sum + currencyManager.toBaseCurrency(amount: w.signedBalance, from: w.currency)
        }
    }
    
    var totalReceivables: Double {
        store.debts.filter { !$0.isSettled }.reduce(0) { sum, d in
            sum + currencyManager.toBaseCurrency(amount: d.amount, from: d.currency)
        }
    }
    
    var totalCCLimitRemaining: Double {
        store.creditCards.reduce(0) { $0 + $1.remainingLimit }
    }
    
    var totalCCTotalLimit: Double {
        store.creditCards.reduce(0) { $0 + $1.limit }
    }

    var totalCCUsed: Double {
        max(0, totalCCTotalLimit - totalCCLimitRemaining)
    }
    
    var totalAssets: Double {
        store.wallets.filter { $0.isPositive }.reduce(0) { sum, wallet in
            sum + currencyManager.toBaseCurrency(amount: wallet.balance, from: wallet.currency)
        }
    }
    
    var totalLiabilitiesFromWallets: Double {
        store.wallets.filter { !$0.isPositive }.reduce(0) { sum, wallet in
            sum + currencyManager.toBaseCurrency(amount: wallet.balance, from: wallet.currency)
        }
    }
    
    var debtToAssetRatio: Double {
        guard totalAssets > 0 else { return 0 }
        return (totalLiabilitiesFromWallets / totalAssets) * 100
    }
    
    var liquidityRatio: Double {
        guard totalLiabilitiesFromWallets > 0 else { return totalAssets > 0 ? 999 : 0 }
        return totalAssets / totalLiabilitiesFromWallets
    }
    
    var totalCreditLimit: Double {
        store.creditCards.reduce(0) { sum, card in
            sum + currencyManager.toBaseCurrency(amount: card.limit, from: card.currency)
        }
    }
    
    var totalCreditUsed: Double {
        store.creditCards.reduce(0) { sum, card in
            sum + currencyManager.toBaseCurrency(amount: card.totalUsedLimit, from: card.currency)
        }
    }
    
    var creditUtilizationRatio: Double {
        guard totalCreditLimit > 0 else { return 0 }
        return (totalCreditUsed / totalCreditLimit) * 100
    }
    
    var creditCardCount: Int { store.creditCards.count }
    
    var utilizationColor: Color {
        switch creditUtilizationRatio {
        case 0..<30: return .neonGreen
        case 30..<50: return Color(red: 0.4, green: 0.8, blue: 0.4)
        case 50..<70: return .yellow
        case 70..<90: return .orange
        default: return .neonRed
        }
    }
    
    var financialHealthScore: Int {
        var score = 50
        if totalNetWorth > 0 {
            score += 15
            if totalNetWorth > totalAssets * 0.5 { score += 15 }
        } else { score -= 15 }
        
        if debtToAssetRatio < 30 { score += 25 }
        else if debtToAssetRatio < 50 { score += 12 }
        else { score -= 10 }
        
        if liquidityRatio > 2 { score += 20 }
        else if liquidityRatio > 1 { score += 10 }
        
        if creditUtilizationRatio < 30 { score += 25 }
        else if creditUtilizationRatio < 50 { score += 15 }
        else if creditUtilizationRatio < 70 { score += 5 }
        else { score -= 15 }
        
        return max(0, min(100, score))
    }
    
    var healthScoreColor: Color {
        switch financialHealthScore {
        case 80...100: return .neonGreen
        case 60..<80: return Color(red: 0.4, green: 0.8, blue: 0.4)
        case 40..<60: return .yellow
        case 20..<40: return .orange
        default: return .neonRed
        }
    }
    
    var healthScoreText: String {
        switch financialHealthScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        case 20..<40: return "Poor"
        default: return "Critical"
        }
    }
    
    var convertedChartData: [MonthlyChartData] {
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
                return sum + currencyManager.toBaseCurrency(amount: tx.amount, from: walletCurrency)
            }
            let outflow = txs.filter { $0.type == .outflow }.reduce(0) { sum, tx in
                let wallet = store.wallets.first { $0.id == tx.walletId }
                guard let walletCurrency = wallet?.currency else { return sum }
                return sum + currencyManager.toBaseCurrency(amount: tx.amount, from: walletCurrency)
            }
            
            return MonthlyChartData(month: fmt.string(from: date), inflow: inflow, outflow: outflow)
        }
    }
    
    func fetchExchangeRateIfNeeded() async {
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
}

// MARK: - Receivables ViewModel

@Observable
class ReceivablesViewModel {
    private let store: AppStore
    
    var showAdd = false
    var showSettled = false
    
    init(store: AppStore) {
        self.store = store
    }
    
    var activeDebts: [Debt] {
        store.debts.filter { !$0.isSettled }.sorted { $0.date > $1.date }
    }
    
    var settledDebts: [Debt] {
        store.debts.filter { $0.isSettled }.sorted { $0.date > $1.date }
    }
    
    var totalDebit: Double { store.totalDebit }
    var liquidity: Double { store.liquidity }
    
    func deleteDebt(_ id: UUID) {
        store.deleteDebt(id)
    }
    
    func settleDebt(_ debt: Debt) {
        var updated = debt
        updated.isSettled = true
        store.updateDebt(updated)
    }
}

// MARK: - Receivable Detail ViewModel

@Observable
class ReceivableDetailViewModel {
    private let store: AppStore
    let debtId: UUID
    
    var showEdit = false
    
    init(store: AppStore, debtId: UUID) {
        self.store = store
        self.debtId = debtId
    }
    
    var debt: Debt? {
        store.debts.first { $0.id == debtId }
    }
    
    func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Split Bills ViewModel

@Observable
class SplitBillsViewModel {
    private let store: AppStore
    
    init(store: AppStore) {
        self.store = store
    }
    
    var splitBills: [SplitBillRecord] {
        store.splitBills.sorted { $0.date > $1.date }
    }
    
    func deleteSplitBill(_ id: UUID) {
        store.deleteSplitBill(id)
    }
}

// MARK: - Split Bill Detail ViewModel

@Observable
class SplitBillDetailViewModel {
    private let store: AppStore
    let record: SplitBillRecord
    
    init(store: AppStore, record: SplitBillRecord) {
        self.store = store
        self.record = record
    }
    
    func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
