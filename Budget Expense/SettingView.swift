//
//  SettingView.swift
//  Budget Expense
//

import SwiftUI
import UniformTypeIdentifiers
import Combine
import CryptoKit

struct SettingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.authenticationManager) private var authManager
    @Environment(\.appleSignInManager) private var signInManager
    @Environment(\.cloudKitManager) private var cloudKitManager
    
    @State private var showingExporter = false
    @State private var exportURL: URL?
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showCurrencyRates = false
    @State private var showResetPIN = false
    @State private var showCategoryManagement = false
    @State private var showSignInSheet = false
    @State private var isSyncing = false
    @State private var showSyncSuccess = false
    @State private var showRestoreConfirmation = false
    
    // JSON Export/Import
    @State private var showingJSONExporter = false
    @State private var jsonExportURL: URL?
    @State private var showingJSONImporter = false
    @State private var showImportConfirmation = false
    @State private var pendingImportURL: URL?
    
    // Split Bill Detail Sheet
    @State private var showSplitBillDetail = false
    
    var body: some View {
        List {
            // MARK: - Account Section
            Section(header: Text("Account").foregroundStyle(.glassText)) {
                if signInManager.isSignedIn {
                    // Signed In State
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title)
                                .foregroundStyle(.neonGreen)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(signInManager.getDisplayName())
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                if let email = signInManager.userEmail {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.glassText)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        
                        Button {
                            signInManager.signOut()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                Text("Sign Out")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.neonRed)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color(white: 0.12))
                    
                } else {
                    // Sign In Button
                    Button {
                        showSignInSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundStyle(.neonGreen)
                                .frame(width: 24)
                            Text("Sign in with Apple")
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.gray)
                                .font(.caption)
                        }
                    }
                    .listRowBackground(Color(white: 0.12))
                }
            }
            
            // MARK: - iCloud Sync Section
            if signInManager.isSignedIn {
                Section(header: Text("iCloud Backup").foregroundStyle(.glassText)) {
                    // Cloud Status
                    HStack {
                        Image(systemName: cloudKitManager.isCloudKitAvailable ? "icloud.fill" : "icloud.slash")
                            .foregroundStyle(cloudKitManager.isCloudKitAvailable ? .neonGreen : .neonRed)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud Status")
                                .foregroundStyle(.white)
                            Text(cloudKitManager.isCloudKitAvailable ? "Available" : "Not Available")
                                .font(.caption)
                                .foregroundStyle(cloudKitManager.isCloudKitAvailable ? .neonGreen : .neonRed)
                        }
                        
                        Spacer()
                    }
                    .listRowBackground(Color(white: 0.12))
                    
                    // Last Sync
                    if let lastSync = cloudKitManager.lastSyncDate {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.glassText)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last Backup")
                                    .foregroundStyle(.white)
                                Text(lastSync, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.glassText)
                            }
                            
                            Spacer()
                        }
                        .listRowBackground(Color(white: 0.12))
                    }
                    
                    // Backup Button
                    Button {
                        Task {
                            await backupToCloud()
                        }
                    } label: {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .tint(.white)
                                    .frame(width: 24)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(.neonGreen)
                                    .frame(width: 24)
                            }
                            Text(isSyncing ? "Backing up..." : "Backup to iCloud")
                                .foregroundStyle(.white)
                            Spacer()
                        }
                    }
                    .disabled(isSyncing || !cloudKitManager.isCloudKitAvailable)
                    .listRowBackground(Color(white: 0.12))
                    
                    // Restore Button
                    Button {
                        showRestoreConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0))
                                .frame(width: 24)
                            Text("Restore from iCloud")
                                .foregroundStyle(.white)
                            Spacer()
                        }
                    }
                    .disabled(isSyncing || !cloudKitManager.isCloudKitAvailable)
                    .listRowBackground(Color(white: 0.12))
                }
            }
            
            // MARK: - Security Section
            Section(header: Text("Security").foregroundStyle(.glassText)) {
                // Face ID / Touch ID Toggle
                Toggle(isOn: Binding(
                    get: { authManager.isFaceIDEnabled },
                    set: { newValue in
                        if authManager.biometricType != .none {
                            authManager.isFaceIDEnabled = newValue
                        } else {
                            errorMessage = "Biometric authentication is not available on this device"
                            showErrorAlert = true
                        }
                    }
                )) {
                    HStack {
                        Image(systemName: authManager.biometricType.icon)
                            .foregroundStyle(.neonGreen)
                            .frame(width: 24)
                        Text(authManager.biometricType == .none ? "Biometric Auth (Not Available)" : "Use \(authManager.biometricType.displayName)")
                            .foregroundStyle(.white)
                    }
                }
                .disabled(authManager.biometricType == .none)
                .listRowBackground(Color(white: 0.12))
                .tint(.neonGreen)
                
                // Reset PIN Button
                Button {
                    showResetPIN = true
                } label: {
                    HStack {
                        Label("Reset PIN", systemImage: "lock.rotation")
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                }
                .listRowBackground(Color(white: 0.12))
            }
            
            Section(header: Text("System").foregroundStyle(.glassText)) {
                Button {
                    showCurrencyRates = true
                } label: {
                    HStack {
                        Label("Currency Rates", systemImage: "dollarsign.circle.fill")
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                }
                .listRowBackground(Color(white: 0.12))
                
                Button {
                    showCategoryManagement = true
                } label: {
                    HStack {
                        Label("Manage Categories", systemImage: "tag.fill")
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                }
                .listRowBackground(Color(white: 0.12))
                
                // Split Bill Detail Button - NEW
//                Button {
//                    showSplitBillDetail = true
//                } label: {
//                    HStack {
//                        Label("Split Bill Detail", systemImage: "person.2.crop.circle.badge.plus")
//                            .foregroundStyle(.white)
//                        Spacer()
//                        Image(systemName: "chevron.right")
//                            .foregroundStyle(.gray)
//                            .font(.caption)
//                    }
//                }
//                .listRowBackground(Color(white: 0.12))
            }
            
            Section(header: Text("Data Management").foregroundStyle(.glassText)) {
                // Export to JSON
                Button {
                    exportToJSON()
                } label: {
                    HStack {
                        Label("Export All Data to JSON", systemImage: "square.and.arrow.up.on.square")
                            .foregroundStyle(.neonGreen)
                        Spacer()
                    }
                }
                .listRowBackground(Color(white: 0.12))
                
                // Import from JSON
                Button {
                    showingJSONImporter = true
                } label: {
                    HStack {
                        Label("Import Data from JSON", systemImage: "square.and.arrow.down.on.square")
                            .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0))
                        Spacer()
                    }
                }
                .listRowBackground(Color(white: 0.12))
                
                // Export to CSV (existing)
                Button {
                    exportToCSV()
                } label: {
                    HStack {
                        Label("Export Transactions to CSV", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.white)
                        Spacer()
                    }
                }
                .listRowBackground(Color(white: 0.12))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBg.ignoresSafeArea())
        .task {
            // Check CloudKit availability when view appears
            await cloudKitManager.checkAvailabilityIfNeeded()
        }
        // ✅ Native file exporter for saving the CSV file
        .fileExporter(
            isPresented: $showingExporter,
            document: CSVFile(url: exportURL),
            contentType: .commaSeparatedText,
            defaultFilename: "BudgetExpense_Export_\(Date().formatted(date: .numeric, time: .omitted))"
        ) { result in
            switch result {
            case .success(let url):
                print("✅ CSV successfully saved to \(url)")
                showSuccessAlert = true
                // Clean up temp file
                if let tempURL = exportURL {
                    try? FileManager.default.removeItem(at: tempURL)
                }
            case .failure(let error):
                print("❌ Failed to save: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
        .alert("Export Successful", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your data has been exported successfully.")
        }
        .alert("Export Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showCurrencyRates) {
            CurrencyRatesView()
        }
        .sheet(isPresented: $showResetPIN) {
            ResetPINView()
        }
        .sheet(isPresented: $showCategoryManagement) {
            CategoryManagementView()
        }
        .sheet(isPresented: $showSignInSheet) {
            AppleSignInSheet()
        }
        .alert("Backup Successful", isPresented: $showSyncSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your data has been backed up to iCloud successfully.")
        }
        .alert("Restore from iCloud", isPresented: $showRestoreConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                Task {
                    await restoreFromCloud()
                }
            }
        } message: {
            Text("This will replace all current data with data from iCloud. This action cannot be undone.")
        }
        // JSON Export
        .fileExporter(
            isPresented: $showingJSONExporter,
            document: JSONBackupFile(url: jsonExportURL),
            contentType: .json,
            defaultFilename: "BudgetExpense_Backup_\(Date().formatted(date: .numeric, time: .omitted)).json"
        ) { result in
            switch result {
            case .success(let url):
                print("✅ JSON backup successfully saved to \(url)")
                showSuccessAlert = true
                // Clean up temp file
                if let tempURL = jsonExportURL {
                    try? FileManager.default.removeItem(at: tempURL)
                }
            case .failure(let error):
                print("❌ Failed to save JSON: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
        // JSON Import
        .fileImporter(
            isPresented: $showingJSONImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pendingImportURL = url
                    showImportConfirmation = true
                }
            case .failure(let error):
                print("❌ Failed to select file: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
        .alert("Import Backup", isPresented: $showImportConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingImportURL = nil
            }
            Button("Import", role: .destructive) {
                if let url = pendingImportURL {
                    importFromJSON(url: url)
                    pendingImportURL = nil
                }
            }
        } message: {
            Text("This will replace all current data with data from the backup file. This action cannot be undone.")
        }
        // Split Bill Detail Sheet
        .sheet(isPresented: $showSplitBillDetail) {
            SplitBillView()
                .environment(store)
        }
    }
    
    private func backupToCloud() async {
        isSyncing = true
        do {
            try await cloudKitManager.backupToCloud(store: store)
            showSyncSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
        isSyncing = false
    }
    
    private func restoreFromCloud() async {
        isSyncing = true
        do {
            let restoredStore = try await cloudKitManager.restoreFromCloud()
            // Replace current store data with restored data
            store.wallets = restoredStore.wallets
            store.walletTransactions = restoredStore.walletTransactions
            store.creditCards = restoredStore.creditCards
            store.debts = restoredStore.debts
            store.splitBills = restoredStore.splitBills
            
            showSuccessAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
        isSyncing = false
    }
    
    private func printSuccess() {
        print("🔄 Sucess")
    }
    
    // MARK: - JSON Export/Import Functions
    
    private func exportToJSON() {
        print("🔄 Starting JSON export...")
        
        let backup = AppStoreBackup(
            wallets: store.wallets,
            walletTransactions: store.walletTransactions,
            creditCards: store.creditCards,
            debts: store.debts,
            splitBills: store.splitBills
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            
            let jsonData = try encoder.encode(backup)
            
            // Write to temporary file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("backup.json")
            try jsonData.write(to: tempURL)
            
            print("✅ JSON backup created with:")
            print("   - \(store.wallets.count) wallets")
            print("   - \(store.walletTransactions.count) wallet transactions")
            print("   - \(store.creditCards.count) credit cards")
            print("   - \(store.debts.count) debts")
            print("   - \(store.splitBills.count) split bills")
            
            jsonExportURL = tempURL
            showingJSONExporter = true
        } catch {
            print("❌ Failed to create JSON backup: \(error)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func importFromJSON(url: URL) {
        print("🔄 Starting JSON import from: \(url)")
        
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access the selected file"
            showErrorAlert = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let jsonData = try Data(contentsOf: url)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let backup = try decoder.decode(AppStoreBackup.self, from: jsonData)
            
            // Replace current store data with imported data
            store.wallets = backup.wallets
            store.walletTransactions = backup.walletTransactions
            store.creditCards = backup.creditCards
            store.debts = backup.debts
            store.splitBills = backup.splitBills
            
            print("✅ JSON import successful:")
            print("   - \(backup.wallets.count) wallets")
            print("   - \(backup.walletTransactions.count) wallet transactions")
            print("   - \(backup.creditCards.count) credit cards")
            print("   - \(backup.debts.count) debts")
            print("   - \(backup.splitBills.count) split bills")
            
            showSuccessAlert = true
        } catch {
            print("❌ Failed to import JSON: \(error)")
            errorMessage = "Failed to import backup: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func exportToCSV() {
        print("🔄 Starting CSV export...")
        
        // 1. Setup CSV Headers
        var csvString = "Date,Account Type,Account Name,Transaction Type,Category,Description,Amount,Status\n"
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        
        // 2. Append Wallet Transactions (Debit Card)
        print("📊 Exporting \(store.walletTransactions.count) wallet transactions")
        for tx in store.walletTransactions {
            let date = df.string(from: tx.date)
            let accountName = store.wallets.first(where: { $0.id == tx.walletId })?.name ?? "Unknown Wallet"
            let type = tx.type.rawValue // Inflow / Outflow
            
            // Escape commas and quotes to prevent breaking CSV format
            let category = escapeCSV(tx.category)
            let note = escapeCSV(tx.note)
            let amount = "\(tx.amount)"
            
            csvString += "\"\(date)\",\"Debit Wallet\",\"\(accountName)\",\"\(type)\",\"\(category)\",\"\(note)\",\(amount),\"Completed\"\n"
        }
        
        // 3. Append Credit Card Transactions
        print("💳 Exporting from \(store.creditCards.count) credit cards")
        for card in store.creditCards {
            print("  - Card: \(card.name), \(card.transactions.count) transactions, \(card.installments.count) installments")
            for tx in card.transactions {
                let date = df.string(from: tx.date)
                let accountName = card.name
                let type = "Outflow" // CC transactions are primarily expenses
                let status = tx.isPaid ? "Paid" : "Unpaid"
                
                let category = escapeCSV(tx.category)
                let description = escapeCSV(tx.description)
                let amount = "\(tx.amount)"
                
                csvString += "\"\(date)\",\"Credit Card\",\"\(accountName)\",\"\(type)\",\"\(category)\",\"\(description)\",\(amount),\"\(status)\"\n"
            }
            
            // 4. Append Credit Card Installments
            for inst in card.installments {
                let dateString = df.string(from: inst.startDate)
                let accountName = card.name
                let status = inst.isCompleted ? "Completed" : "Active (\(inst.paidMonths)/\(inst.totalMonths))"
                let description = escapeCSV(inst.description)
                let monthlyAmount = String(format: "%.2f", inst.monthlyPayment)
                
                csvString += "\"\(dateString)\",\"Credit Card Installment\",\"\(accountName)\",\"Outflow\",\"Installment\",\"\(description)\",\(monthlyAmount),\"\(status)\"\n"
            }
        }
        
        print("✅ CSV generated with \(csvString.split(separator: "\n").count - 1) rows")
        print("📝 CSV preview (first 500 chars):\n\(String(csvString.prefix(500)))")
        
        // 5. Write to temporary file and show exporter
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("export.csv")
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            print("💾 Temporary file created at: \(tempURL)")
            exportURL = tempURL
            showingExporter = true
        } catch {
            print("❌ Failed to create temp file: \(error)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    // Helper function to escape CSV values
    private func escapeCSV(_ value: String) -> String {
        // Replace quotes with double quotes and handle commas
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return escaped
    }
}

// MARK: - Currency Rates View
struct CurrencyRatesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CurrencyRatesViewModel()
    @State private var showingBaseCurrencyPicker = false
    @State private var showingCurrencySelector = false
    @State private var searchText = ""
    
    var filteredRates: [(key: String, value: Double)] {
        let baseRates = viewModel.filteredRates
        
        if searchText.isEmpty {
            return baseRates
        }
        
        return baseRates.filter { currency, _ in
            currency.localizedCaseInsensitiveContains(searchText) ||
            currencyName(for: currency).localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.rates.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.neonGreen)
                        Text("Fetching exchange rates...")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                } else if viewModel.rates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No exchange rates available")
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Tap Sync to fetch rates")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.white.opacity(0.5))
                                TextField("Search currencies", text: $searchText)
                                    .foregroundStyle(.white)
                                    .autocorrectionDisabled()
                                
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                            }
                            .padding()
                            .background(Color(white: 0.12))
                            .cornerRadius(12)
                            
                            // Last Updated Section
                            if let lastUpdate = viewModel.lastUpdated {
                                VStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: "clock.fill")
                                            .foregroundStyle(.neonGreen)
                                        Text("Last Updated")
                                            .foregroundStyle(.white.opacity(0.7))
                                        Spacer()
                                    }
                                    
                                    HStack {
                                        Text(lastUpdate, style: .relative)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text("ago")
                                            .foregroundStyle(.white.opacity(0.7))
                                        Spacer()
                                    }
                                }
                                .padding()
                                .background(Color(white: 0.12))
                                .cornerRadius(12)
                            }
                            
                            // Base Currency Selector
                            Button {
                                showingBaseCurrencyPicker = true
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Base Currency")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.neonGreen)
                                    }
                                    
                                    HStack {
                                        Text(viewModel.baseCurrency)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.neonGreen)
                                        
                                        Text("= 1.00")
                                            .foregroundStyle(.white.opacity(0.7))
                                        
                                        Spacer()
                                    }
                                }
                                .padding()
                                .background(Color(white: 0.12))
                                .cornerRadius(12)
                            }
                            
                            // Currency Filter Button
                            Button {
                                showingCurrencySelector = true
                            } label: {
                                HStack {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .foregroundStyle(.neonGreen)
                                    Text("Select Currencies (\(viewModel.selectedCurrencies.count))")
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .padding()
                                .background(Color(white: 0.12))
                                .cornerRadius(12)
                            }
                            
                            // Exchange Rates List
                            VStack(spacing: 12) {
                                if filteredRates.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.white.opacity(0.3))
                                        Text("No currencies found")
                                            .foregroundStyle(.white.opacity(0.7))
                                        Text("Try a different search term")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    ForEach(filteredRates, id: \.key) { currency, rate in
                                        CurrencyRateRow(
                                            currency: currency,
                                            rate: rate,
                                            baseCurrency: viewModel.baseCurrency
                                        )
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Exchange Rates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.fetchRates()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync")
                        }
                        .foregroundStyle(viewModel.isLoading ? .gray : .neonGreen)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .toolbarBackground(Color(white: 0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $showingBaseCurrencyPicker) {
            BaseCurrencyPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingCurrencySelector) {
            CurrencySelectorView(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private func currencyName(for code: String) -> String {
        let names: [String: String] = [
            "USD": "US Dollar", "EUR": "Euro", "GBP": "British Pound",
            "JPY": "Japanese Yen", "CNY": "Chinese Yuan", "INR": "Indian Rupee",
            "AUD": "Australian Dollar", "CAD": "Canadian Dollar",
            "CHF": "Swiss Franc", "SGD": "Singapore Dollar",
            "MYR": "Malaysian Ringgit", "THB": "Thai Baht",
            "IDR": "Indonesian Rupiah", "KRW": "South Korean Won",
            "RUB": "Russian Ruble", "BRL": "Brazilian Real"
        ]
        return names[code] ?? code
    }
}

// MARK: - Base Currency Picker
struct BaseCurrencyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CurrencyRatesViewModel
    
    let popularCurrencies = ["USD", "EUR", "GBP", "JPY", "CNY", "INR", "AUD", "CAD"]
    
    var allCurrencies: [String] {
        Set(viewModel.rates.keys + [viewModel.baseCurrency]).sorted()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Popular Currencies
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Popular")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal)
                            
                            ForEach(popularCurrencies, id: \.self) { currency in
                                CurrencyPickerRow(
                                    currency: currency,
                                    isSelected: viewModel.baseCurrency == currency
                                ) {
                                    selectBaseCurrency(currency)
                                }
                            }
                        }
                        
                        // All Currencies
                        VStack(alignment: .leading, spacing: 12) {
                            Text("All Currencies")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal)
                            
                            ForEach(allCurrencies, id: \.self) { currency in
                                if !popularCurrencies.contains(currency) {
                                    CurrencyPickerRow(
                                        currency: currency,
                                        isSelected: viewModel.baseCurrency == currency
                                    ) {
                                        selectBaseCurrency(currency)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Select Base Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.neonGreen)
                }
            }
            .toolbarBackground(Color(white: 0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    private func selectBaseCurrency(_ currency: String) {
        viewModel.baseCurrency = currency
        viewModel.saveBaseCurrency()
        Task {
            await viewModel.fetchRates()
        }
        dismiss()
    }
}

// MARK: - Currency Selector View
struct CurrencySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CurrencyRatesViewModel
    @State private var searchText = ""
    
    var allCurrencies: [String] {
        Array(viewModel.rates.keys).sorted()
    }
    
    var filteredCurrencies: [String] {
        if searchText.isEmpty {
            return allCurrencies
        }
        return allCurrencies.filter { currency in
            currency.localizedCaseInsensitiveContains(searchText) ||
            currencyName(for: currency).localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("Search currencies", text: $searchText)
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                    }
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    .padding()
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        Button {
                            viewModel.selectAllCurrencies()
                        } label: {
                            Text("Select All")
                                .font(.caption)
                                .foregroundStyle(.neonGreen)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.neonGreen.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        Button {
                            viewModel.deselectAllCurrencies()
                        } label: {
                            Text("Deselect All")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(white: 0.12))
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    
                    // Currency List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filteredCurrencies, id: \.self) { currency in
                                CurrencySelectionRow(
                                    currency: currency,
                                    isSelected: viewModel.selectedCurrencies.contains(currency)
                                ) {
                                    viewModel.toggleCurrency(currency)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Currencies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.neonGreen)
                }
            }
            .toolbarBackground(Color(white: 0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    private func currencyName(for code: String) -> String {
        let names: [String: String] = [
            "USD": "US Dollar", "EUR": "Euro", "GBP": "British Pound",
            "JPY": "Japanese Yen", "CNY": "Chinese Yuan", "INR": "Indian Rupee",
            "AUD": "Australian Dollar", "CAD": "Canadian Dollar",
            "CHF": "Swiss Franc", "SGD": "Singapore Dollar",
            "MYR": "Malaysian Ringgit", "THB": "Thai Baht",
            "IDR": "Indonesian Rupiah", "KRW": "South Korean Won",
            "RUB": "Russian Ruble", "BRL": "Brazilian Real"
        ]
        return names[code] ?? code
    }
}

// MARK: - Currency Picker Row
struct CurrencyPickerRow: View {
    let currency: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.neonGreen.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Text(currencySymbol(for: currency))
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(currency)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(currencyName(for: currency))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.neonGreen)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.neonGreen.opacity(0.1) : Color(white: 0.12))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.neonGreen : Color.clear, lineWidth: 2)
            )
        }
        .padding(.horizontal)
    }
    
    private func currencySymbol(for code: String) -> String {
        let symbols: [String: String] = [
            "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥",
            "CNY": "¥", "INR": "₹", "AUD": "$", "CAD": "$",
            "CHF": "₣", "SGD": "$", "MYR": "RM", "THB": "฿",
            "IDR": "Rp", "KRW": "₩", "RUB": "₽", "BRL": "R$"
        ]
        return symbols[code] ?? code.prefix(1).uppercased()
    }
    
    private func currencyName(for code: String) -> String {
        let names: [String: String] = [
            "USD": "US Dollar", "EUR": "Euro", "GBP": "British Pound",
            "JPY": "Japanese Yen", "CNY": "Chinese Yuan", "INR": "Indian Rupee",
            "AUD": "Australian Dollar", "CAD": "Canadian Dollar",
            "CHF": "Swiss Franc", "SGD": "Singapore Dollar",
            "MYR": "Malaysian Ringgit", "THB": "Thai Baht",
            "IDR": "Indonesian Rupiah", "KRW": "South Korean Won",
            "RUB": "Russian Ruble", "BRL": "Brazilian Real"
        ]
        return names[code] ?? code
    }
}

// MARK: - Currency Selection Row
struct CurrencySelectionRow: View {
    let currency: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.neonGreen.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Text(currencySymbol(for: currency))
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(currency)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(currencyName(for: currency))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .neonGreen : .white.opacity(0.3))
                    .font(.title3)
            }
            .padding()
            .background(Color(white: 0.12))
            .cornerRadius(12)
        }
    }
    
    private func currencySymbol(for code: String) -> String {
        let symbols: [String: String] = [
            "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥",
            "CNY": "¥", "INR": "₹", "AUD": "$", "CAD": "$",
            "CHF": "₣", "SGD": "$", "MYR": "RM", "THB": "฿",
            "IDR": "Rp", "KRW": "₩", "RUB": "₽", "BRL": "R$"
        ]
        return symbols[code] ?? code.prefix(1).uppercased()
    }
    
    private func currencyName(for code: String) -> String {
        let names: [String: String] = [
            "USD": "US Dollar", "EUR": "Euro", "GBP": "British Pound",
            "JPY": "Japanese Yen", "CNY": "Chinese Yuan", "INR": "Indian Rupee",
            "AUD": "Australian Dollar", "CAD": "Canadian Dollar",
            "CHF": "Swiss Franc", "SGD": "Singapore Dollar",
            "MYR": "Malaysian Ringgit", "THB": "Thai Baht",
            "IDR": "Indonesian Rupiah", "KRW": "South Korean Won",
            "RUB": "Russian Ruble", "BRL": "Brazilian Real"
        ]
        return names[code] ?? code
    }
}

// MARK: - Currency Rate Row
struct CurrencyRateRow: View {
    let currency: String
    let rate: Double
    let baseCurrency: String
    
    var body: some View {
        HStack {
            // Currency Flag/Icon
            ZStack {
                Circle()
                    .fill(Color.neonGreen.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Text(currencySymbol(for: currency))
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(currency)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(currencyName(for: currency))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.4f", rate))
                    .font(.headline)
                    .foregroundStyle(.neonGreen)
                
                Text("1 \(baseCurrency)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }
    
    private func currencySymbol(for code: String) -> String {
        let symbols: [String: String] = [
            "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥",
            "CNY": "¥", "INR": "₹", "AUD": "$", "CAD": "$",
            "CHF": "₣", "SGD": "$", "MYR": "RM", "THB": "฿",
            "IDR": "Rp", "KRW": "₩", "RUB": "₽", "BRL": "R$"
        ]
        return symbols[code] ?? code.prefix(1).uppercased()
    }
    
    private func currencyName(for code: String) -> String {
        let names: [String: String] = [
            "USD": "US Dollar", "EUR": "Euro", "GBP": "British Pound",
            "JPY": "Japanese Yen", "CNY": "Chinese Yuan", "INR": "Indian Rupee",
            "AUD": "Australian Dollar", "CAD": "Canadian Dollar",
            "CHF": "Swiss Franc", "SGD": "Singapore Dollar",
            "MYR": "Malaysian Ringgit", "THB": "Thai Baht",
            "IDR": "Indonesian Rupiah", "KRW": "South Korean Won",
            "RUB": "Russian Ruble", "BRL": "Brazilian Real"
        ]
        return names[code] ?? code
    }
}

// MARK: - Currency Rates ViewModel
@MainActor
class CurrencyRatesViewModel: ObservableObject {
    @Published var rates: [String: Double] = [:]
    @Published var baseCurrency = "USD"
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCurrencies: Set<String> = []
    
    private let apiURL = "https://api.exchangerate-api.com/v4/latest/"
    private let cacheKey = "cachedCurrencyRates"
    private let lastUpdateKey = "cachedRatesLastUpdate"
    private let baseCurrencyKey = "cachedBaseCurrency"
    private let selectedCurrenciesKey = "selectedCurrencies"
    
    // Default popular currencies
    private let defaultCurrencies: Set<String> = ["USD", "EUR", "GBP", "JPY", "CNY", "INR", "AUD", "CAD", "CHF", "SGD"]
    
    var filteredRates: [(key: String, value: Double)] {
        if selectedCurrencies.isEmpty {
            return Array(rates.sorted(by: { $0.key < $1.key }))
        }
        return rates.filter { selectedCurrencies.contains($0.key) }.sorted(by: { $0.key < $1.key })
    }
    
    init() {
        loadCachedRates()
        loadSelectedCurrencies()
    }
    
    private func loadCachedRates() {
        // Load cached rates from UserDefaults
        if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
           let cachedRates = try? JSONDecoder().decode([String: Double].self, from: cachedData) {
            rates = cachedRates
            print("✅ Loaded \(cachedRates.count) cached currency rates")
        }
        
        // Load last update date
        if let lastUpdateTimestamp = UserDefaults.standard.object(forKey: lastUpdateKey) as? TimeInterval {
            lastUpdated = Date(timeIntervalSince1970: lastUpdateTimestamp)
            print("📅 Last update was: \(lastUpdated!)")
        }
        
        // Load base currency
        if let cachedBase = UserDefaults.standard.string(forKey: baseCurrencyKey) {
            baseCurrency = cachedBase
        }
    }
    
    private func loadSelectedCurrencies() {
        if let savedCurrencies = UserDefaults.standard.array(forKey: selectedCurrenciesKey) as? [String] {
            selectedCurrencies = Set(savedCurrencies)
            print("✅ Loaded \(selectedCurrencies.count) selected currencies")
        } else {
            // First time - use default currencies
            selectedCurrencies = defaultCurrencies
            saveSelectedCurrencies()
        }
    }
    
    private func saveSelectedCurrencies() {
        UserDefaults.standard.set(Array(selectedCurrencies), forKey: selectedCurrenciesKey)
        print("💾 Saved \(selectedCurrencies.count) selected currencies")
    }
    
    func saveBaseCurrency() {
        UserDefaults.standard.set(baseCurrency, forKey: baseCurrencyKey)
        print("💾 Saved base currency: \(baseCurrency)")
    }
    
    private func cacheRates() {
        // Save rates to UserDefaults
        if let encoded = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
        
        // Save last update timestamp
        if let lastUpdated = lastUpdated {
            UserDefaults.standard.set(lastUpdated.timeIntervalSince1970, forKey: lastUpdateKey)
        }
        
        // Save base currency
        UserDefaults.standard.set(baseCurrency, forKey: baseCurrencyKey)
        
        print("💾 Cached \(rates.count) currency rates")
    }
    
    func toggleCurrency(_ currency: String) {
        if selectedCurrencies.contains(currency) {
            selectedCurrencies.remove(currency)
        } else {
            selectedCurrencies.insert(currency)
        }
        saveSelectedCurrencies()
    }
    
    func selectAllCurrencies() {
        selectedCurrencies = Set(rates.keys)
        saveSelectedCurrencies()
    }
    
    func deselectAllCurrencies() {
        selectedCurrencies.removeAll()
        saveSelectedCurrencies()
    }
    
    func fetchRates() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: apiURL + baseCurrency) else {
            errorMessage = "Invalid API URL"
            isLoading = false
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "Server returned an error"
                isLoading = false
                return
            }
            
            let result = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            
            // Update on main thread
            rates = result.rates
            lastUpdated = Date()
            isLoading = false
            
            // Cache the new rates
            cacheRates()
            
            print("✅ Fetched \(rates.count) exchange rates")
            
        } catch {
            errorMessage = "Failed to fetch rates: \(error.localizedDescription)"
            isLoading = false
            print("❌ Error fetching rates: \(error)")
        }
    }
}

// MARK: - API Response Model
struct ExchangeRateResponse: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
}

// MARK: - Backup Models

struct AppStoreBackup: Codable {
    let wallets: [Wallet]
    let walletTransactions: [WalletTransaction]
    let creditCards: [CreditCard]
    let debts: [Debt]
    let splitBills: [SplitBillRecord]
}

// MARK: - JSON Backup File Document Wrapper
struct JSONBackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var url: URL?
    
    init(url: URL?) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        // Not needed for export-only
        url = nil
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = url else {
            throw CocoaError(.fileNoSuchFile)
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        
        return try FileWrapper(url: url)
    }
}

// MARK: - CSV File Document Wrapper
struct CSVFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var url: URL?
    
    init(url: URL?) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        // Not needed for export-only
        url = nil
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = url else {
            throw CocoaError(.fileNoSuchFile)
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        
        return try FileWrapper(url: url)
    }
}


#Preview {
    SettingView()
        .environment(\.authenticationManager, AuthenticationManager())
        .environment(AppStore())
}

