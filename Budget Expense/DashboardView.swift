//
//  DashboardView.swift
//  Budget Expense
//

import SwiftUI
import Charts

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

// MARK: - Dashboard

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    
    // ✅ State for universal add sheet & CC edit
    @State private var showUniversalAdd = false
    @State private var editCCTarget: CreditCard?
    
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
                // Background full screen
                Color.appBg
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerBar
                        
                        // Swipeable Cards
                        swipeableCards
                        
                        // Metrics Grid (Liability, CC Bill, Receivables, Installment)
                        metricsGrid
                        
                        // Working Analytics Section with Filters
                        analyticsSection
                        
                        recentTransactionsSection
                        
                        
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 120) // Extra padding so FAB doesn't block content
                }
                
                // FAB Menu with expandable options
                HStack {
                    Spacer()
                    FABMenuView(
                        showUniversalAdd: $showUniversalAdd,
                        showSplitBill: $showSplitBill,
                        showOCRScanner: $showOCRScanner
                    )
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showUniversalAdd) {
                UniversalAddTransactionView()
                    .environment(store)
            }
            .sheet(isPresented: $showSplitBill) {
                SplitBillView()
                    .environment(store)
            }
            .sheet(item: $editCCTarget) { card in
                AddEditCreditCardView(editTarget: card)
                    .environment(store)
            }
            // ✅ Fetch Exchange Rate when Dashboard appears
            .task {
                await fetchExchangeRateIfNeeded()
            }
        }
    }

    // MARK: - Fetch Exchange Rate
    
    private func fetchExchangeRateIfNeeded() async {
        let oneWeekInSeconds: TimeInterval = 7 * 24 * 60 * 60
        let now = Date().timeIntervalSince1970
        
        // Only fetch if 1 week has passed since the last successful fetch
        guard now - lastFetchDate > oneWeekInSeconds else { return }
        
        guard let url = URL(string: "https://v6.exchangerate-api.com/v6/1184a7843bf2f5403c4d651e/latest/USD") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(DashboardExchangeRateResponse.self, from: data)
            
            if let rates = response.conversion_rates, let idrRate = rates["IDR"] {
                await MainActor.run {
                    self.usdToIdrRate = idrRate
                    self.lastFetchDate = now
                    print("Exchange rate updated: 1 USD = \(idrRate) IDR")
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
    
    private func displayAmount(_ amount: Double) -> String {
        return showBalances ? formatIDR(amount) : "Rp ••••••••"
    }
    
    // Custom Filtered & Converted Chart Data
    private var convertedChartData: [MonthlyChartData] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        
        let monthCount: Int
        switch selectedChartRange {
        case .last3Months:
            monthCount = 3
        case .last6Months:
            monthCount = 6
        case .thisYear:
            monthCount = max(1, cal.component(.month, from: Date()))
        }
        
        return (0..<monthCount).reversed().map { n in
            let date = cal.date(byAdding: .month, value: -n, to: Date())!
            let y = cal.component(.year, from: date)
            let m = cal.component(.month, from: date)
            let txs = store.walletTransactions.filter {
                cal.component(.year, from: $0.date) == y &&
                cal.component(.month, from: $0.date) == m
            }
            
            // Konversi tx USD ke IDR untuk grafik
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
            
            return MonthlyChartData(
                month: fmt.string(from: date),
                inflow:  inflow,
                outflow: outflow
            )
        }
    }
    
    // MARK: - Custom Header
    
    private var headerBar: some View {
        HStack {
            // Profile Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.45, green: 0.2, blue: 0.9).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image("image_logo") // nama asset kamu di Assets.xcassets
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
                // Toggle Show/Hide Balance
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
            
            // Card 1: Total Balance / Net Worth (Sudah di-convert)
            balanceCard(
                title: "Total Balance",
                amount: totalNetWorthIDR,
                gradient: [Color(red: 0.15, green: 0.15, blue: 0.22), Color(red: 0.08, green: 0.08, blue: 0.12)],
                icon: "chart.line.uptrend.xyaxis"
            ).tag(0)
            
            // Card 2: Wallet Debit (Sudah di-convert)
            balanceCard(
                title: "Wallet Debit",
                amount: totalWalletBalanceIDR,
                gradient: [Color(red: 0.05, green: 0.35, blue: 0.25), Color(red: 0.02, green: 0.15, blue: 0.1)],
                icon: "wallet.bifold.fill"
            ).tag(1)
            
            // Card 3: Remaining Credit Limit (Memang IDR)
            balanceCard(
                title: "Remaining CC Limit",
                amount: totalCCLimitRemaining,
                gradient: [Color(red: 0.45, green: 0.2, blue: 0.9), Color(red: 0.2, green: 0.1, blue: 0.4)],
                icon: "creditcard.fill"
            ).tag(2)
            
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 220) // Adjust height to make room for page dots
    }

    private func balanceCard(title: String, amount: Double, gradient: [Color], icon: String) -> some View {
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
            
            Spacer() // Push page dots down
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

    // MARK: - Analytics (Working Bar Chart)

    private var analyticsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Analytics")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Chart Range Filter Menu
                Menu {
                    ForEach(ChartRange.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            withAnimation {
                                selectedChartRange = range
                            }
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
                    .background(Color(red: 0.95, green: 0.4, blue: 0.2)) // Orange pill
                    .cornerRadius(10)
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            
            // Dynamic Grouped Bar Chart based on Selected Range
            Chart {
                ForEach(convertedChartData) { item in
                    // Inflow Bar
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.inflow)
                    )
                    .foregroundStyle(Color.neonGreen.gradient)
                    .position(by: .value("Type", "Inflow"))
                    .cornerRadius(4)
                    
                    // Outflow Bar
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.outflow)
                    )
                    .foregroundStyle(Color(red: 0.45, green: 0.2, blue: 0.9).gradient) // Purple for outflow
                    .position(by: .value("Type", "Outflow"))
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color(white: 0.5)).font(.caption2)
                }
            }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 180)
            .padding(.horizontal, 16)
            
            // Custom Legend
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

    // MARK: - Transactions List

    private var recentTransactionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Transactions")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)

            let recentTxs = store.walletTransactions.sorted { $0.date > $1.date }.prefix(4)
            
            if recentTxs.isEmpty {
                Text("No recent transactions")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.5))
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentTxs.enumerated()), id: \.element.id) { index, tx in
                        TransactionRefRow(tx: tx, store: store, showBalances: showBalances)
                        
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

// MARK: - Transaction Ref Row

struct TransactionRefRow: View {
    let tx: WalletTransaction
    let store: AppStore
    let showBalances: Bool
    
    private var walletCurrency: Currency {
        store.wallets.first(where: { $0.id == tx.walletId })?.currency ?? .idr
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 48, height: 48)
                Image(systemName: tx.type.icon)
                    .font(.title3)
                    .foregroundStyle(tx.type == .inflow ? .neonGreen : .white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tx.category.isEmpty ? tx.type.rawValue : tx.category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text(walletName)
                    .font(.caption2)
                    .foregroundStyle(Color(white: 0.5))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Mempertahankan simbol IDR/USD sesuai wallet-nya
                Text(showBalances ? tx.type.sign + formatCurrency(tx.amount, currency: walletCurrency) : "••••••")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tx.type == .inflow ? .neonGreen : .white)
                
                Text(tx.date, format: .dateTime.day().month().year())
                    .font(.caption2)
                    .foregroundStyle(Color(white: 0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private var walletName: String {
        store.wallets.first(where: { $0.id == tx.walletId })?.name ?? "Wallet"
    }
}

// MARK: - Metric Tile

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

// MARK: - Universal Add Transaction View

struct UniversalAddTransactionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.categoryManager) private var categoryManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAccountId = ""
    @State private var txType = TransactionType.outflow
    @State private var amountText = ""
    @State private var category = ""
    @State private var note = ""
    @State private var date = Date()

    private var isCC: Bool { selectedAccountId.hasPrefix("C-") }
    
    // ✅ Getting Dynamic Categories from CategoryManager
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
            .onAppear {
                if let firstWallet = store.wallets.first {
                    selectedAccountId = "W-\(firstWallet.id)"
                } else if let firstCC = store.creditCards.first {
                    selectedAccountId = "C-\(firstCC.id)"
                }
            }
        }
    }
    
    // MARK: Fields

    private var accountPicker: some View {
        field("ACCOUNT", "building.columns") {
            Menu {
                if !store.wallets.isEmpty {
                    Section("Wallets") {
                        ForEach(store.wallets) { w in Button(w.name) { selectedAccountId = "W-\(w.id)" } }
                    }
                }
                if !store.creditCards.isEmpty {
                    Section("Credit Cards") {
                        ForEach(store.creditCards) { c in Button("\(c.bank) \(c.name)") { selectedAccountId = "C-\(c.id)" } }
                    }
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
