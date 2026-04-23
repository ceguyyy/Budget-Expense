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
            }
        }
    }

    private func fetchExchangeRateIfNeeded() async {
        let oneWeekInSeconds: TimeInterval = 7 * 24 * 60 * 60
        let now = Date().timeIntervalSince1970
        guard now - lastFetchDate > oneWeekInSeconds else { return }
        guard let url = URL(string: "https://v6.exchangerate-api.com/v6/1184a7843bf2f5403c4d651e/latest/USD") else { return }
        
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
    
    // MARK: - Converted Calculated Properties
    
    private var totalNetWorthIDR: Double {
        totalWalletBalanceIDR + totalReceivablesIDR - store.totalOutstandingCC
    }
    
    private var totalWalletBalanceIDR: Double {
        store.wallets.reduce(0) { sum, w in
            sum + (w.currency == .usd ? w.signedBalance * usdToIdrRate : w.signedBalance)
        }
    }
    
    private var totalReceivablesIDR: Double {
        store.debts.filter { !$0.isSettled }.reduce(0) { sum, d in
            sum + (d.currency == .usd ? d.amount * usdToIdrRate : d.amount)
        }
    }
    
    private var totalLiability: Double {
        store.wallets.filter { !$0.isPositive }.reduce(0) { sum, w in
            sum + (w.currency == .usd ? w.balance * usdToIdrRate : w.balance)
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
    
    private func displayAmount(_ amount: Double) -> String {
        return showBalances ? formatIDR(amount) : "Rp ••••••••"
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
                let rate = wallet?.currency == .usd ? usdToIdrRate : 1.0
                return sum + (tx.amount * rate)
            }
            let outflow = txs.filter { $0.type == .outflow }.reduce(0) { sum, tx in
                let wallet = store.wallets.first { $0.id == tx.walletId }
                let rate = wallet?.currency == .usd ? usdToIdrRate : 1.0
                return sum + (tx.amount * rate)
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
        TabView(selection: $currentCardIndex) {
            balanceCard(
                title: "Total Balance",
                amount: totalNetWorthIDR,
                gradient: [Color(red: 0.15, green: 0.15, blue: 0.22), Color(red: 0.08, green: 0.08, blue: 0.12)],
                icon: "chart.line.uptrend.xyaxis"
            ).tag(0)
            
            balanceCard(
                title: "Wallet Debit",
                amount: totalWalletBalanceIDR,
                gradient: [Color(red: 0.05, green: 0.35, blue: 0.25), Color(red: 0.02, green: 0.15, blue: 0.1)],
                icon: "wallet.bifold.fill"
            ).tag(1)
            
            balanceCard(
                title: "Remaining CC Limit",
                amount: totalCCLimitRemaining,
                gradient: [Color(red: 0.45, green: 0.2, blue: 0.9), Color(red: 0.2, green: 0.1, blue: 0.4)],
                icon: "creditcard.fill",
                progress: (used: totalCCUsed, total: totalCCTotalLimit)
            ).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 220)
    }

    private func balanceCard(title: String, amount: Double, gradient: [Color], icon: String, progress: (used: Double, total: Double)? = nil) -> some View {
        VStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: icon)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 8)
                
                Text(displayAmount(amount))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                if let progress {
                    let ratio = progress.total > 0 ? min(max(progress.used / progress.total, 0), 1) : 0
                    VStack(alignment: .leading, spacing: 6) {
                        // Progress bar
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 8)
                            Capsule()
                                .fill(Color.neonGreen)
                                .frame(width: max(0, ratio) * 1.0 *  (UIScreen.main.bounds.width - 32 - 48), height: 8)
                        }
                        // Labels
                        HStack {
                            Text("Used: \(formatIDR(progress.used))")
                                .font(.caption2).foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Text("Limit: \(formatIDR(progress.total))")
                                .font(.caption2).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
                
                HStack {
                    Text("Christian Gunawan")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                    Spacer()
                    HStack() {
                        Circle().fill(Color.red.opacity(0.8)).frame(width: 26, height: 26)
                        Circle().fill(Color.orange.opacity(0.8)).frame(width: 26, height: 26)
                    }
                }
            }
            .padding(24)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            
            Spacer()
        }
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MetricTile(
                    icon: "arrow.down.circle.fill",
                    title: "Total Liability",
                    value: displayAmount(totalLiability),
                    color: .neonRed
                )
                MetricTile(
                    icon: "creditcard.fill",
                    title: "CC Bill/mo",
                    value: displayAmount(store.totalMonthlyPayable),
                    color: .neonRed
                )
            }
            HStack(spacing: 12) {
                MetricTile(
                    icon: "person.2.fill",
                    title: "Receivables",
                    value: displayAmount(totalReceivablesIDR),
                    color: Color(red: 0.3, green: 0.6, blue: 1.0)
                )
                MetricTile(
                    icon: "clock.badge.fill",
                    title: "Installments/mo",
                    value: displayAmount(store.totalMonthlyInstallments),
                    color: Color(red: 0.92, green: 0.66, blue: 0.10)
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Custom Feature Cards (History & Stock)
    
    private var featureCardsSection: some View {
        HStack(spacing: 12) {
            // Split Bill History
            NavigationLink(destination: SplitBillHistoryView().environment(store)) {
                FeatureTile(
                    icon: "doc.text.fill",
                    title: "Split Bills",
                    subtitle: "History",
                    color: Color(red: 0.3, green: 0.6, blue: 1.0)
                )
            }
            
            // Stock Input (Future)
            Button {
                if let url = URL(string: "stockbit://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                FeatureTile(
                    icon: "shippingbox.fill",
                    title: "StockBit",
                    subtitle: "Open App",
                    color: Color(white: 0.5)
                )
            }
            
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Analytics (Working Bar Chart)

    private var analyticsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Analytics")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Spacer()
                Menu {
                    ForEach(ChartRange.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            withAnimation { selectedChartRange = range }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedChartRange.rawValue)
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.95, green: 0.4, blue: 0.2))
                    .cornerRadius(10)
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            
            Chart {
                ForEach(convertedChartData) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.inflow)
                    )
                    .foregroundStyle(Color.neonGreen.gradient)
                    .position(by: .value("Type", "Inflow"))
                    .cornerRadius(4)
                    
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.outflow)
                    )
                    .foregroundStyle(Color(red: 0.45, green: 0.2, blue: 0.9).gradient)
                    .position(by: .value("Type", "Outflow"))
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(Color(white: 0.5)).font(.caption2) }
            }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 180)
            .padding(.horizontal, 16)
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color.neonGreen).frame(width: 8, height: 8)
                    Text("Inflow").font(.caption).foregroundStyle(.glassText)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color(red: 0.45, green: 0.2, blue: 0.9)).frame(width: 8, height: 8)
                    Text("Outflow").font(.caption).foregroundStyle(.glassText)
                }
            }
        }
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
        .cornerRadius(20)
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

struct SplitBillHistoryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            
            if store.splitBills.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.dimText)
                    Text("No Split Bills Saved")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            } else {
                List {
                    ForEach(store.splitBills.sorted { $0.date > $1.date }) { record in
                        NavigationLink(destination: SplitBillDetailView(record: record)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.billName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                HStack {
                                    Text("Paid by \(record.payerName)")
                                    Spacer()
                                    Text("\(record.currency.symbol) \(formatNumber(record.totalAmount))")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0))
                                }
                                .font(.caption)
                                .foregroundStyle(.glassText)
                                
                                Text(record.date, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.dimText)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                        .listRowSeparatorTint(Color.white.opacity(0.1))
                    }
                    .onDelete { indices in
                        let records = store.splitBills.sorted { $0.date > $1.date }
                        for idx in indices {
                            store.deleteSplitBill(records[idx].id)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Split Bill History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// ... existing SplitBillHistoryView stays the same above ...

struct SplitBillDetailView: View {
    let record: SplitBillRecord
    
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(record.billName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text(record.date, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.dimText)
                        
                        Divider().background(Color.white.opacity(0.1)).padding(.vertical, 8)
                        
                        HStack {
                            Text("Total Amount")
                            Spacer()
                            Text("\(record.currency.symbol) \(formatNumber(record.totalAmount))")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.neonGreen)
                        }
                        HStack {
                            Text("Paid By")
                            Spacer()
                            Text(record.payerName)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(16)
                    .glassEffect(in: .rect(cornerRadius: 16))
                    
                    // Participants
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Participants (\(record.participants.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.glassText)
                        
                        VStack(spacing: 0) {
                            ForEach(record.participants) { p in
                                HStack {
                                    Text(p.name)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(record.currency.symbol) \(formatNumber(p.amount))")
                                        .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                
                                if p.id != record.participants.last?.id {
                                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 16)
                                }
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: 16))
                    }
                    
                    // Items (if any)
                    if !record.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Receipt Items")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.glassText)
                            
                            VStack(spacing: 0) {
                                ForEach(record.items) { item in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(item.name).foregroundStyle(.white)
                                            Text("\(item.qty)x @ \(formatNumber(item.price))")
                                                .font(.caption2)
                                                .foregroundStyle(.dimText)
                                        }
                                        Spacer()
                                        Text("\(record.currency.symbol) \(formatNumber(item.price * Double(item.qty)))")
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    
                                    if item.id != record.items.last?.id {
                                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 16)
                                    }
                                }
                            }
                            .glassEffect(in: .rect(cornerRadius: 16))
                        }
                    }
                    
                    // Share Button inside the scroll view content
                    Button {
                        shareAsPDF()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share as PDF")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal, 16)
                }
                .padding()
            }
        }
        .navigationTitle("Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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


