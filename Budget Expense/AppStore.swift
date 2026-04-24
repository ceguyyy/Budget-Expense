//
//  AppStore.swift
//  Budget Expense
//

import SwiftUI
import Observation

// MARK: - Currency

enum Currency: String, CaseIterable, Codable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case cny = "CNY"
    case inr = "INR"
    case aud = "AUD"
    case cad = "CAD"
    case chf = "CHF"
    case sgd = "SGD"
    case myr = "MYR"
    case thb = "THB"
    case idr = "IDR"
    case krw = "KRW"
    case rub = "RUB"
    case brl = "BRL"
    
    var symbol: String {
        switch self {
        case .usd, .aud, .cad, .sgd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy, .cny: return "¥"
        case .inr: return "₹"
        case .chf: return "₣"
        case .myr: return "RM"
        case .thb: return "฿"
        case .idr: return "Rp"
        case .krw: return "₩"
        case .rub: return "₽"
        case .brl: return "R$"
        }
    }
    
    var name: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .jpy: return "Japanese Yen"
        case .cny: return "Chinese Yuan"
        case .inr: return "Indian Rupee"
        case .aud: return "Australian Dollar"
        case .cad: return "Canadian Dollar"
        case .chf: return "Swiss Franc"
        case .sgd: return "Singapore Dollar"
        case .myr: return "Malaysian Ringgit"
        case .thb: return "Thai Baht"
        case .idr: return "Indonesian Rupiah"
        case .krw: return "South Korean Won"
        case .rub: return "Russian Ruble"
        case .brl: return "Brazilian Real"
        }
    }
    
    var flag: String {
        switch self {
        case .usd: return "🇺🇸"
        case .eur: return "🇪🇺"
        case .gbp: return "🇬🇧"
        case .jpy: return "🇯🇵"
        case .cny: return "🇨🇳"
        case .inr: return "🇮🇳"
        case .aud: return "🇦🇺"
        case .cad: return "🇨🇦"
        case .chf: return "🇨🇭"
        case .sgd: return "🇸🇬"
        case .myr: return "🇲🇾"
        case .thb: return "🇹🇭"
        case .idr: return "🇮🇩"
        case .krw: return "🇰🇷"
        case .rub: return "🇷🇺"
        case .brl: return "🇧🇷"
        }
    }
}

// MARK: - Debit Wallet

struct Wallet: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var balance: Double
    var currency: Currency
    var isPositive: Bool
    var imageData: Data?

    var signedBalance: Double { isPositive ? balance : -balance }
    var initials: String { String(name.prefix(2)).uppercased() }
    var accentColor: Color { isPositive ? .neonGreen : .neonRed }

    func formattedAmount(showSign: Bool = true) -> String {
        let sign = showSign ? (isPositive ? "+" : "-") : ""
        return sign + formatCurrency(balance, currency: currency)
    }
}

// MARK: - Wallet Transaction

enum TransactionType: String, Codable, CaseIterable {
    case inflow = "Inflow"
    case outflow = "Outflow"
    var icon: String { self == .inflow ? "arrow.down.circle.fill" : "arrow.up.circle.fill" }
    var color: Color { self == .inflow ? .neonGreen : .neonRed }
    var sign: String { self == .inflow ? "+" : "-" }
}

struct WalletTransaction: Identifiable, Codable {
    var id: UUID = UUID()
    var walletId: UUID
    var amount: Double
    var type: TransactionType
    var category: String
    var note: String
    var date: Date

    func formattedAmount(currency: Currency) -> String {
        type.sign + formatCurrency(amount, currency: currency)
    }
}

// MARK: - Credit Card

struct CreditCard: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String         // nickname / last 4 digits label
    var bank: String
    var limit: Double
    var currency: Currency = .idr  // ✅ Add currency support
    var billingCycleDay: Int // 1–28: day new billing cycle starts
    var dueDay: Int          // payment due day
    var colorIndex: Int = 0
    var customHexColor: String? = nil // ✅ Added support for custom colors
    var transactions: [CCTransaction] = []
    var installments: [Installment] = []

    var initials: String { String(bank.prefix(2)).uppercased() }
    var cardColor: Color {
        if let hex = customHexColor {
            return Color(hex: hex) ?? CreditCard.palette[colorIndex % CreditCard.palette.count]
        }
        return CreditCard.palette[colorIndex % CreditCard.palette.count]
    }

    var totalOutstanding: Double {
        transactions.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    
    // Total sisa cicilan yang belum lunas
    var totalInstallmentOutstanding: Double {
        installments.filter { !$0.isCompleted }.reduce(0) { $0 + $1.remainingAmount }
    }
    
    // Total yang menggunakan limit = transaksi belum bayar + sisa cicilan
    var totalUsedLimit: Double {
        totalOutstanding + totalInstallmentOutstanding
    }
    
    var remainingLimit: Double { max(0, limit - totalUsedLimit) }
    var usedPercent: Double { limit > 0 ? min(1, totalUsedLimit / limit) : 0 }

    static let palette: [Color] = [
        Color(red: 0.20, green: 0.45, blue: 0.90),
        Color(red: 0.58, green: 0.18, blue: 0.88),
        Color(red: 0.90, green: 0.28, blue: 0.18),
        Color(red: 0.15, green: 0.72, blue: 0.42),
        Color(red: 0.88, green: 0.65, blue: 0.08),
        Color(red: 0.40, green: 0.40, blue: 0.45)
    ]
}

struct CCTransaction: Identifiable, Codable {
    var id: UUID = UUID()
    var description: String
    var amount: Double
    var category: String
    var date: Date
    var isPaid: Bool = false
}

struct Installment: Identifiable, Codable {
    var id: UUID = UUID()
    var description: String
    var totalPrincipal: Double
    var annualInterestRate: Double // e.g. 0.24 for 24%
    var totalMonths: Int
    var startDate: Date
    var paidMonths: Int = 0

    // Simple flat interest monthly payment
    var monthlyPayment: Double {
        let totalInterest = totalPrincipal * annualInterestRate * Double(totalMonths) / 12
        return (totalPrincipal + totalInterest) / Double(totalMonths)
    }
    var remainingMonths: Int { max(0, totalMonths - paidMonths) }
    var isCompleted: Bool { paidMonths >= totalMonths }
    var totalPayable: Double { monthlyPayment * Double(totalMonths) }
    var remainingAmount: Double { monthlyPayment * Double(remainingMonths) }
}

// MARK: - Debt (Piutang)

struct DebtItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var amount: Double
}

struct Debt: Identifiable, Codable {
    var id: UUID = UUID()
    var personName: String
    var amount: Double
    var currency: Currency
    var note: String
    var date: Date
    var dueDate: Date?
    var isSettled: Bool = false
    var items: [DebtItem]? = nil // Optional field to store receipt items

    var initials: String { String(personName.prefix(2)).uppercased() }
    func formattedAmount() -> String { formatCurrency(amount, currency: currency) }
}

// MARK: - Split Bill Records (History)

struct SplitItemRecord: Identifiable, Codable {
    var id = UUID()
    var name: String
    var price: Double
    var qty: Int
}

struct SplitParticipantRecord: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Double
    var percentage: Double
}

struct SplitBillRecord: Identifiable, Codable {
    var id = UUID()
    var billName: String
    var payerName: String
    var totalAmount: Double
    var currency: Currency
    var date: Date
    var items: [SplitItemRecord]
    var participants: [SplitParticipantRecord]
}

// MARK: - Chart Data

struct MonthlyChartData: Identifiable {
    let id = UUID()
    let month: String
    let inflow: Double
    let outflow: Double
}

// MARK: - App Store

@Observable
class AppStore {
    var wallets: [Wallet] = []
    var walletTransactions: [WalletTransaction] = []
    var creditCards: [CreditCard] = []
    var debts: [Debt] = []
    var splitBills: [SplitBillRecord] = []
    
    // ✅ Currency Manager for multi-currency support
    var currencyManager: CurrencyManager
    
    private let walletsKey   = "budget_expense_wallets"
    private let txKey        = "store_wallet_tx_v2"
    private let ccKey        = "store_credit_cards_v2"
    private let debtKey      = "store_debts_v2"
    private let splitBillKey = "store_split_bills_v2"

    init() {
        // ✅ Use shared singleton instance to prevent multiple inits
        self.currencyManager = CurrencyManager.shared
        load()
    }

    // MARK: Wallet CRUD

    func addWallet(_ w: Wallet)    { wallets.append(w); saveWallets() }
    func updateWallet(_ w: Wallet) { replace(&wallets, id: w.id, with: w); saveWallets() }
    func deleteWallet(_ id: UUID)  {
        wallets.removeAll { $0.id == id }
        walletTransactions.removeAll { $0.walletId == id }
        saveWallets(); saveTx()
    }
    func deleteWallets(at offsets: IndexSet) {
        let ids = offsets.map { wallets[$0].id }
        wallets.remove(atOffsets: offsets)
        walletTransactions.removeAll { ids.contains($0.walletId) }
        saveWallets(); saveTx()
    }

    // MARK: Wallet Transactions

    func transactions(for walletId: UUID) -> [WalletTransaction] {
        walletTransactions.filter { $0.walletId == walletId }.sorted { $0.date > $1.date }
    }

    func addTransaction(_ tx: WalletTransaction) {
        walletTransactions.append(tx)
        applyBalanceChange(tx: tx, factor: 1)
        saveWallets(); saveTx()
    }

    func updateTransaction(oldTx: WalletTransaction, newTx: WalletTransaction) {
        // Revert old transaction's effect on balance
        applyBalanceChange(tx: oldTx, factor: -1)
        // Apply new transaction's effect on balance
        applyBalanceChange(tx: newTx, factor: 1)
        replace(&walletTransactions, id: newTx.id, with: newTx)
        saveWallets(); saveTx()
    }

    func deleteTransaction(_ tx: WalletTransaction) {
        applyBalanceChange(tx: tx, factor: -1)
        walletTransactions.removeAll { $0.id == tx.id }
        saveWallets(); saveTx()
    }

    private func applyBalanceChange(tx: WalletTransaction, factor: Double) {
        guard let idx = wallets.firstIndex(where: { $0.id == tx.walletId }) else { return }
        let delta: Double
        if wallets[idx].isPositive {
            delta = tx.type == .inflow ? tx.amount : -tx.amount
        } else {
            delta = tx.type == .outflow ? tx.amount : -tx.amount
        }
        wallets[idx].balance = max(0, wallets[idx].balance + delta * factor)
    }

    // MARK: Credit Card CRUD

    func addCreditCard(_ c: CreditCard)    { creditCards.append(c); saveCC() }
    func updateCreditCard(_ c: CreditCard) { replace(&creditCards, id: c.id, with: c); saveCC() }
    func deleteCreditCard(_ id: UUID)      { creditCards.removeAll { $0.id == id }; saveCC() }
    func deleteCreditCards(at offsets: IndexSet) { creditCards.remove(atOffsets: offsets); saveCC() }

    // MARK: CC Transactions

    func addCCTransaction(_ tx: CCTransaction, to cardId: UUID) {
        mutateCard(cardId) { $0.transactions.append(tx) }
    }
    func deleteCCTransaction(_ txId: UUID, from cardId: UUID) {
        mutateCard(cardId) { $0.transactions.removeAll { $0.id == txId } }
    }

    func payCurrentCycleBill(for cardId: UUID) {
        guard let idx = creditCards.firstIndex(where: { $0.id == cardId }) else { return }
        let (start, end) = billingCycleDates(for: creditCards[idx])
        for i in creditCards[idx].transactions.indices {
            if creditCards[idx].transactions[i].date >= start,
               creditCards[idx].transactions[i].date < end {
                creditCards[idx].transactions[i].isPaid = true
            }
        }
        for i in creditCards[idx].installments.indices where !creditCards[idx].installments[i].isCompleted {
            creditCards[idx].installments[i].paidMonths += 1
        }
        saveCC()
    }

    // MARK: Installments

    func addInstallment(_ inst: Installment, to cardId: UUID) {
        mutateCard(cardId) { $0.installments.append(inst) }
    }
    func updateInstallment(_ inst: Installment, in cardId: UUID) {
        mutateCard(cardId) { card in
            if let i = card.installments.firstIndex(where: { $0.id == inst.id }) {
                card.installments[i] = inst
            }
        }
    }
    func deleteInstallment(_ instId: UUID, from cardId: UUID) {
        mutateCard(cardId) { $0.installments.removeAll { $0.id == instId } }
    }

    // MARK: Debt (Piutang) CRUD

    func addDebt(_ d: Debt)    { debts.append(d); saveDebt() }
    func updateDebt(_ d: Debt) { replace(&debts, id: d.id, with: d); saveDebt() }
    func deleteDebt(_ id: UUID){ debts.removeAll { $0.id == id }; saveDebt() }
    func deleteDebts(at offsets: IndexSet) { debts.remove(atOffsets: offsets); saveDebt() }

    // MARK: Split Bill History CRUD
    func addSplitBill(_ record: SplitBillRecord) { splitBills.append(record); saveSplitBills() }
    func deleteSplitBill(_ id: UUID) { splitBills.removeAll { $0.id == id }; saveSplitBills() }

    // MARK: Billing Cycle Logic

    func billingCycleDates(for card: CreditCard) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        let day = cal.component(.day, from: now)
        let m   = cal.component(.month, from: now)
        let y   = cal.component(.year, from: now)
        let cycleDay = min(card.billingCycleDay, 28)

        var comps = DateComponents()
        comps.day = cycleDay
        if day >= cycleDay {
            comps.year = y; comps.month = m
        } else {
            comps.year  = m == 1 ? y - 1 : y
            comps.month = m == 1 ? 12 : m - 1
        }
        let start = cal.date(from: comps) ?? now
        let end   = cal.date(byAdding: .month, value: 1, to: start) ?? now
        return (start, end)
    }

    func currentCycleTransactions(for card: CreditCard) -> [CCTransaction] {
        let (s, e) = billingCycleDates(for: card)
        return card.transactions.filter { $0.date >= s && $0.date < e }
    }

    func currentCycleBill(for card: CreditCard) -> Double {
        currentCycleTransactions(for: card).filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    func currentMonthInstallments(for card: CreditCard) -> Double {
        card.installments.filter { !$0.isCompleted }.reduce(0) { $0 + $1.monthlyPayment }
    }

    func totalDueThisMonth(for card: CreditCard) -> Double {
        currentCycleBill(for: card) + currentMonthInstallments(for: card)
    }

    func billingCycleDueDate(for card: CreditCard) -> Date {
        let cal = Calendar.current
        let (_, cycleEnd) = billingCycleDates(for: card)
        var comps = cal.dateComponents([.year, .month], from: cycleEnd)
        comps.day = min(card.dueDay, 28)
        return cal.date(from: comps) ?? cycleEnd
    }

    // MARK: Dashboard Metrics (Multi-Currency)

    // ✅ Total wallet balance in base currency
    var totalDebit: Double {
        wallets.reduce(0) { sum, wallet in
            sum + currencyManager.toBaseCurrency(amount: wallet.signedBalance, from: wallet.currency)
        }
    }
    
    // ✅ Total receivables in base currency
    var totalReceivables: Double {
        debts.filter { !$0.isSettled }.reduce(0) { sum, debt in
            sum + currencyManager.toBaseCurrency(amount: debt.amount, from: debt.currency)
        }
    }
    
    // ✅ Total CC outstanding in base currency
    var totalOutstandingCC: Double {
        creditCards.reduce(0) { sum, card in
            sum + currencyManager.toBaseCurrency(amount: card.totalUsedLimit, from: card.currency)
        }
    }
    
    // ✅ Total monthly installments in base currency
    var totalMonthlyInstallments: Double {
        creditCards.flatMap { $0.installments }.filter { !$0.isCompleted }.reduce(0) { sum, inst in
            let card = creditCards.first { $0.installments.contains { $0.id == inst.id } }
            let currency = card?.currency ?? .idr
            return sum + currencyManager.toBaseCurrency(amount: inst.monthlyPayment, from: currency)
        }
    }
    
    // ✅ Total monthly payable in base currency
    var totalMonthlyPayable: Double {
        creditCards.reduce(0) { sum, card in
            let due = totalDueThisMonth(for: card)
            return sum + currencyManager.toBaseCurrency(amount: due, from: card.currency)
        }
    }
    
    // ✅ Net worth in base currency
    var netWorth: Double { totalDebit + totalReceivables - totalOutstandingCC }
    
    // ✅ Liquidity in base currency
    var liquidity: Double {
        let liquid = wallets.filter { $0.isPositive }.reduce(0) { sum, wallet in
            sum + currencyManager.toBaseCurrency(amount: wallet.balance, from: wallet.currency)
        }
        return liquid - totalMonthlyPayable
    }
    
    // Legacy properties for backward compatibility (deprecated)
    @available(*, deprecated, message: "Use totalDebit instead")
    var totalDebitIDR: Double { wallets.filter { $0.currency == .idr }.reduce(0) { $0 + $1.signedBalance } }
    @available(*, deprecated, message: "Use totalDebit instead")
    var totalDebitUSD: Double { wallets.filter { $0.currency == .usd }.reduce(0) { $0 + $1.signedBalance } }
    @available(*, deprecated, message: "Use totalReceivables instead")
    var totalReceivablesIDR: Double { debts.filter { !$0.isSettled && $0.currency == .idr }.reduce(0) { $0 + $1.amount } }
    @available(*, deprecated, message: "Use totalReceivables instead")
    var totalReceivablesUSD: Double { debts.filter { !$0.isSettled && $0.currency == .usd }.reduce(0) { $0 + $1.amount } }
    @available(*, deprecated, message: "Use netWorth instead")
    var netWorthIDR: Double { totalDebitIDR + totalReceivablesIDR - totalOutstandingCC }
    @available(*, deprecated, message: "Use liquidity instead")
    var liquidityIDR: Double {
        let liquid = wallets.filter { $0.currency == .idr && $0.isPositive }.reduce(0) { $0 + $1.balance }
        return liquid - totalMonthlyPayable
    }

    var hasIDR: Bool { wallets.contains { $0.currency == .idr } }
    var hasUSD: Bool { wallets.contains { $0.currency == .usd } }
    var assetCount: Int { wallets.filter { $0.isPositive }.count }
    var liabilityCount: Int { wallets.filter { !$0.isPositive }.count }
    var activeDebtCount: Int { debts.filter { !$0.isSettled }.count }

    // MARK: Chart Data

    var monthlyChartData: [MonthlyChartData] {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "MMM"
        return (0..<6).reversed().map { n in
            let date = cal.date(byAdding: .month, value: -n, to: Date())!
            let y = cal.component(.year, from: date)
            let m = cal.component(.month, from: date)
            let txs = walletTransactions.filter {
                cal.component(.year, from: $0.date) == y &&
                cal.component(.month, from: $0.date) == m
            }
            return MonthlyChartData(
                month: fmt.string(from: date),
                inflow:  txs.filter { $0.type == .inflow  }.reduce(0) { $0 + $1.amount },
                outflow: txs.filter { $0.type == .outflow }.reduce(0) { $0 + $1.amount }
            )
        }
    }

    // MARK: Persistence

    private func mutateCard(_ id: UUID, _ body: (inout CreditCard) -> Void) {
        if let i = creditCards.firstIndex(where: { $0.id == id }) {
            body(&creditCards[i]); saveCC()
        }
    }
    private func replace<T: Identifiable>(_ arr: inout [T], id: T.ID, with item: T) {
        if let i = arr.firstIndex(where: { $0.id == id }) { arr[i] = item }
    }

    private func saveWallets() { encode(wallets, key: walletsKey) }
    private func saveTx()      { encode(walletTransactions, key: txKey) }
    private func saveCC()      { encode(creditCards, key: ccKey) }
    private func saveDebt()    { encode(debts, key: debtKey) }
    private func saveSplitBills() { encode(splitBills, key: splitBillKey) }

    private func encode<T: Encodable>(_ value: T, key: String) {
        if let d = try? JSONEncoder().encode(value) { UserDefaults.standard.set(d, forKey: key) }
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let d = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: d)
    }

    private func load() {
        wallets             = decode([Wallet].self,            key: walletsKey) ?? []
        walletTransactions  = decode([WalletTransaction].self, key: txKey)      ?? []
        creditCards         = decode([CreditCard].self,        key: ccKey)      ?? []
        debts               = decode([Debt].self,              key: debtKey)    ?? []
        splitBills          = decode([SplitBillRecord].self,   key: splitBillKey) ?? []
    }
}
