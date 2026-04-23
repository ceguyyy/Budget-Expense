//
//  CloudKitManager.swift
//  Budget Expense
//

import SwiftUI
import CloudKit
import Observation

@MainActor
@Observable
class CloudKitManager {
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?
    var isCloudKitAvailable = false
    
    private var container: CKContainer?
    private var privateDatabase: CKDatabase?
    
    // Flag to enable/disable CloudKit (useful for debugging)
    // Set to false to disable CloudKit during development
    private let isCloudKitEnabled = false
    
    // Record Types
    private let walletRecordType = "Wallet"
    private let transactionRecordType = "WalletTransaction"
    private let creditCardRecordType = "CreditCard"
    private let ccTransactionRecordType = "CCTransaction"
    private let installmentRecordType = "Installment"
    private let debtRecordType = "Debt"
    private let splitBillRecordType = "SplitBillRecord"
    
    private let lastSyncKey = "cloudkit_last_sync_date"
    private var hasCheckedAvailability = false
    
    init() {
        print("🔧 CloudKitManager initializing...")
        
        // Only initialize CloudKit if enabled
        if isCloudKitEnabled {
            // Initialize container - use default container
            self.container = CKContainer.default()
            self.privateDatabase = container?.privateCloudDatabase
            
            print("✅ CloudKit containers initialized")
            print("📦 Container ID: \(container?.containerIdentifier ?? "unknown")")
            
            // Check availability asynchronously after init
            Task {
                await checkCloudKitAvailability()
            }
        } else {
            print("⚠️ CloudKit is disabled - skipping initialization")
            self.container = nil
            self.privateDatabase = nil
            self.isCloudKitAvailable = false
        }
        
        // Load last sync date from UserDefaults
        if let savedDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            self.lastSyncDate = savedDate
            print("📅 Loaded last sync date: \(savedDate)")
        }
        
        print("✅ CloudKitManager initialized")
    }
    
    // Call this after the view appears to check availability
    func checkAvailabilityIfNeeded() async {
        guard !hasCheckedAvailability else { return }
        hasCheckedAvailability = true
        await checkCloudKitAvailability()
    }
    
    // MARK: - CloudKit Availability
    
    func checkCloudKitAvailability() async {
        guard let container = container else {
            print("⚠️ CloudKit container not initialized")
            isCloudKitAvailable = false
            return
        }
        
        print("🔍 Checking CloudKit availability...")
        
        do {
            let status = try await container.accountStatus()
            isCloudKitAvailable = status == .available
            
            if !isCloudKitAvailable {
                switch status {
                case .available:
                    break
                case .noAccount:
                    syncError = "No iCloud account found. Please sign in to iCloud in Settings."
                    print("⚠️ No iCloud account")
                case .restricted:
                    syncError = "iCloud is restricted on this device."
                    print("⚠️ iCloud restricted")
                case .couldNotDetermine:
                    syncError = "Could not determine iCloud status."
                    print("⚠️ Could not determine iCloud status")
                case .temporarilyUnavailable:
                    syncError = "iCloud is temporarily unavailable."
                    print("⚠️ iCloud temporarily unavailable")
                @unknown default:
                    syncError = "Unknown iCloud status."
                    print("⚠️ Unknown iCloud status")
                }
            } else {
                print("✅ CloudKit is available")
                syncError = nil
            }
        } catch {
            isCloudKitAvailable = false
            syncError = "Failed to check iCloud status: \(error.localizedDescription)"
            print("❌ CloudKit availability check failed: \(error)")
        }
    }
    
    // MARK: - Backup to CloudKit
    
    func backupToCloud(store: AppStore) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            print("🔄 Starting backup to iCloud...")
            
            // Backup Wallets
            print("💼 Backing up \(store.wallets.count) wallets...")
            try await backupWallets(store.wallets)
            
            // Backup Wallet Transactions
            print("💳 Backing up \(store.walletTransactions.count) wallet transactions...")
            try await backupWalletTransactions(store.walletTransactions)
            
            // Backup Credit Cards
            print("💰 Backing up \(store.creditCards.count) credit cards...")
            try await backupCreditCards(store.creditCards)
            
            // Backup Debts
            print("📝 Backing up \(store.debts.count) debts...")
            try await backupDebts(store.debts)
            
            // Backup Split Bills
            print("🧾 Backing up \(store.splitBills.count) split bills...")
            try await backupSplitBills(store.splitBills)
            
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
            
            print("✅ Backup completed successfully!")
            isSyncing = false
        } catch {
            print("❌ Backup failed: \(error)")
            isSyncing = false
            syncError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Restore from CloudKit
    
    func restoreFromCloud() async throws -> AppStore {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        isSyncing = true
        syncError = nil
        
        let store = AppStore()
        
        do {
            print("🔄 Starting restore from iCloud...")
            
            // Restore Wallets
            print("💼 Restoring wallets...")
            store.wallets = try await fetchWallets()
            print("✅ Restored \(store.wallets.count) wallets")
            
            // Restore Wallet Transactions
            print("💳 Restoring wallet transactions...")
            store.walletTransactions = try await fetchWalletTransactions()
            print("✅ Restored \(store.walletTransactions.count) transactions")
            
            // Restore Credit Cards (with transactions and installments)
            print("💰 Restoring credit cards...")
            store.creditCards = try await fetchCreditCards()
            print("✅ Restored \(store.creditCards.count) credit cards")
            
            // Restore Debts
            print("📝 Restoring debts...")
            store.debts = try await fetchDebts()
            print("✅ Restored \(store.debts.count) debts")
            
            // Restore Split Bills
            print("🧾 Restoring split bills...")
            store.splitBills = try await fetchSplitBills()
            print("✅ Restored \(store.splitBills.count) split bills")
            
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
            
            print("✅ Restore completed successfully!")
            isSyncing = false
            return store
        } catch {
            print("❌ Restore failed: \(error)")
            isSyncing = false
            syncError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Backup Individual Record Types
    
    private func backupWallets(_ wallets: [Wallet]) async throws {
        let records = wallets.map { wallet -> CKRecord in
            let record = CKRecord(recordType: walletRecordType, recordID: CKRecord.ID(recordName: wallet.id.uuidString))
            record["name"] = wallet.name as CKRecordValue
            record["balance"] = wallet.balance as CKRecordValue
            record["currency"] = wallet.currency.rawValue as CKRecordValue
            record["isPositive"] = (wallet.isPositive ? 1 : 0) as CKRecordValue
            if let imageData = wallet.imageData {
                record["imageData"] = imageData as CKRecordValue
            }
            return record
        }
        
        try await saveRecords(records)
    }
    
    private func backupWalletTransactions(_ transactions: [WalletTransaction]) async throws {
        let records = transactions.map { tx -> CKRecord in
            let record = CKRecord(recordType: transactionRecordType, recordID: CKRecord.ID(recordName: tx.id.uuidString))
            record["walletId"] = tx.walletId.uuidString as CKRecordValue
            record["amount"] = tx.amount as CKRecordValue
            record["type"] = tx.type.rawValue as CKRecordValue
            record["category"] = tx.category as CKRecordValue
            record["note"] = tx.note as CKRecordValue
            record["date"] = tx.date as CKRecordValue
            return record
        }
        
        try await saveRecords(records)
    }
    
    private func backupCreditCards(_ cards: [CreditCard]) async throws {
        // Save credit card records
        let cardRecords = cards.map { card -> CKRecord in
            let record = CKRecord(recordType: creditCardRecordType, recordID: CKRecord.ID(recordName: card.id.uuidString))
            record["name"] = card.name as CKRecordValue
            record["bank"] = card.bank as CKRecordValue
            record["limit"] = card.limit as CKRecordValue
            record["billingCycleDay"] = card.billingCycleDay as CKRecordValue
            record["dueDay"] = card.dueDay as CKRecordValue
            record["colorIndex"] = card.colorIndex as CKRecordValue
            return record
        }
        
        try await saveRecords(cardRecords)
        
        // Save CC transactions
        for card in cards {
            let txRecords = card.transactions.map { tx -> CKRecord in
                let record = CKRecord(recordType: ccTransactionRecordType, recordID: CKRecord.ID(recordName: tx.id.uuidString))
                record["cardId"] = card.id.uuidString as CKRecordValue
                record["description"] = tx.description as CKRecordValue
                record["amount"] = tx.amount as CKRecordValue
                record["category"] = tx.category as CKRecordValue
                record["date"] = tx.date as CKRecordValue
                record["isPaid"] = (tx.isPaid ? 1 : 0) as CKRecordValue
                return record
            }
            try await saveRecords(txRecords)
            
            // Save installments
            let instRecords = card.installments.map { inst -> CKRecord in
                let record = CKRecord(recordType: installmentRecordType, recordID: CKRecord.ID(recordName: inst.id.uuidString))
                record["cardId"] = card.id.uuidString as CKRecordValue
                record["description"] = inst.description as CKRecordValue
                record["totalPrincipal"] = inst.totalPrincipal as CKRecordValue
                record["annualInterestRate"] = inst.annualInterestRate as CKRecordValue
                record["totalMonths"] = inst.totalMonths as CKRecordValue
                record["startDate"] = inst.startDate as CKRecordValue
                record["paidMonths"] = inst.paidMonths as CKRecordValue
                return record
            }
            try await saveRecords(instRecords)
        }
    }
    
    private func backupDebts(_ debts: [Debt]) async throws {
        let records = debts.map { debt -> CKRecord in
            let record = CKRecord(recordType: debtRecordType, recordID: CKRecord.ID(recordName: debt.id.uuidString))
            record["personName"] = debt.personName as CKRecordValue
            record["amount"] = debt.amount as CKRecordValue
            record["currency"] = debt.currency.rawValue as CKRecordValue
            record["note"] = debt.note as CKRecordValue
            record["date"] = debt.date as CKRecordValue
            if let dueDate = debt.dueDate {
                record["dueDate"] = dueDate as CKRecordValue
            }
            record["isSettled"] = (debt.isSettled ? 1 : 0) as CKRecordValue
            return record
        }
        
        try await saveRecords(records)
    }
    
    private func backupSplitBills(_ bills: [SplitBillRecord]) async throws {
        let records = bills.map { bill -> CKRecord in
            let record = CKRecord(recordType: splitBillRecordType, recordID: CKRecord.ID(recordName: bill.id.uuidString))
            record["billName"] = bill.billName as CKRecordValue
            record["payerName"] = bill.payerName as CKRecordValue
            record["totalAmount"] = bill.totalAmount as CKRecordValue
            record["currency"] = bill.currency.rawValue as CKRecordValue
            record["date"] = bill.date as CKRecordValue
            
            // Store items and participants as JSON
            if let itemsData = try? JSONEncoder().encode(bill.items) {
                record["items"] = itemsData as CKRecordValue
            }
            if let participantsData = try? JSONEncoder().encode(bill.participants) {
                record["participants"] = participantsData as CKRecordValue
            }
            
            return record
        }
        
        try await saveRecords(records)
    }
    
    // MARK: - Fetch Individual Record Types
    
    private func fetchWallets() async throws -> [Wallet] {
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notAvailable
        }
        
        let query = CKQuery(recordType: walletRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)
        
        var wallets: [Wallet] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            guard let name = record["name"] as? String,
                  let balance = record["balance"] as? Double,
                  let currencyRaw = record["currency"] as? String,
                  let currency = Currency(rawValue: currencyRaw),
                  let isPositiveInt = record["isPositive"] as? Int,
                  let id = UUID(uuidString: record.recordID.recordName) else {
                continue
            }
            
            let wallet = Wallet(
                id: id,
                name: name,
                balance: balance,
                currency: currency,
                isPositive: isPositiveInt == 1,
                imageData: record["imageData"] as? Data
            )
            wallets.append(wallet)
        }
        
        return wallets
    }
    
    private func fetchWalletTransactions() async throws -> [WalletTransaction] {
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notAvailable
        }
        
        let query = CKQuery(recordType: transactionRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)
        
        var transactions: [WalletTransaction] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            guard let walletIdStr = record["walletId"] as? String,
                  let walletId = UUID(uuidString: walletIdStr),
                  let amount = record["amount"] as? Double,
                  let typeRaw = record["type"] as? String,
                  let type = TransactionType(rawValue: typeRaw),
                  let category = record["category"] as? String,
                  let note = record["note"] as? String,
                  let date = record["date"] as? Date,
                  let id = UUID(uuidString: record.recordID.recordName) else {
                continue
            }
            
            let tx = WalletTransaction(
                id: id,
                walletId: walletId,
                amount: amount,
                type: type,
                category: category,
                note: note,
                date: date
            )
            transactions.append(tx)
        }
        
        return transactions
    }
    
    private func fetchCreditCards() async throws -> [CreditCard] {
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notAvailable
        }
        
        let query = CKQuery(recordType: creditCardRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)
        
        var cards: [CreditCard] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            guard let name = record["name"] as? String,
                  let bank = record["bank"] as? String,
                  let limit = record["limit"] as? Double,
                  let billingCycleDay = record["billingCycleDay"] as? Int,
                  let dueDay = record["dueDay"] as? Int,
                  let colorIndex = record["colorIndex"] as? Int,
                  let id = UUID(uuidString: record.recordID.recordName) else {
                continue
            }
            
            var card = CreditCard(
                id: id,
                name: name,
                bank: bank,
                limit: limit,
                billingCycleDay: billingCycleDay,
                dueDay: dueDay,
                colorIndex: colorIndex
            )
            
            // Fetch transactions for this card
            card.transactions = try await fetchCCTransactions(for: id)
            card.installments = try await fetchInstallments(for: id)
            
            cards.append(card)
        }
        
        return cards
    }
    
    private func fetchCCTransactions(for cardId: UUID) async throws -> [CCTransaction] {
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notAvailable
        }
        
        let predicate = NSPredicate(format: "cardId == %@", cardId.uuidString)
        let query = CKQuery(recordType: ccTransactionRecordType, predicate: predicate)
        let results = try await privateDatabase.records(matching: query)
        
        var transactions: [CCTransaction] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            guard let description = record["description"] as? String,
                  let amount = record["amount"] as? Double,
                  let category = record["category"] as? String,
                  let date = record["date"] as? Date,
                  let isPaidInt = record["isPaid"] as? Int,
                  let id = UUID(uuidString: record.recordID.recordName) else {
                continue
            }
            
            let tx = CCTransaction(
                id: id,
                description: description,
                amount: amount,
                category: category,
                date: date,
                isPaid: isPaidInt == 1
            )
            transactions.append(tx)
        }
        
        return transactions
    }
    
    private func fetchInstallments(for cardId: UUID) async throws -> [Installment] {
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notAvailable
        }
        
        let predicate = NSPredicate(format: "cardId == %@", cardId.uuidString)
        let query = CKQuery(recordType: installmentRecordType, predicate: predicate)
        let results = try await privateDatabase.records(matching: query)
        
        var installments: [Installment] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            guard let description = record["description"] as? String,
                  let totalPrincipal = record["totalPrincipal"] as? Double,
                  let annualInterestRate = record["annualInterestRate"] as? Double,
                  let totalMonths = record["totalMonths"] as? Int,
                  let startDate = record["startDate"] as? Date,
                  let paidMonths = record["paidMonths"] as? Int,
                  let id = UUID(uuidString: record.recordID.recordName) else {
                continue
            }
            
            let inst = Installment(
                id: id,
                description: description,
                totalPrincipal: totalPrincipal,
                annualInterestRate: annualInterestRate,
                totalMonths: totalMonths,
                startDate: startDate,
                paidMonths: paidMonths
            )
            installments.append(inst)
        }
        
        return installments
    }
    
    private func fetchDebts() async throws -> [Debt] {
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notAvailable
        }
        
        let query = CKQuery(recordType: debtRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)
        
        var debts: [Debt] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            guard let personName = record["personName"] as? String,
                  let amount = record["amount"] as? Double,
                  let currencyRaw = record["currency"] as? String,
                  let currency = Currency(rawValue: currencyRaw),
                  let note = record["note"] as? String,
                  let date = record["date"] as? Date,
                  let isSettledInt = record["isSettled"] as? Int,
                  let id = UUID(uuidString: record.recordID.recordName) else {
                continue
            }
            
            let debt = Debt(
                id: id,
                personName: personName,
                amount: amount,
                currency: currency,
                note: note,
                date: date,
                dueDate: record["dueDate"] as? Date,
                isSettled: isSettledInt == 1
            )
            debts.append(debt)
        }
        
        return debts
    }
    
    private func fetchSplitBills() async throws -> [SplitBillRecord] {
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notAvailable
        }
        
        let query = CKQuery(recordType: splitBillRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)
        
        var bills: [SplitBillRecord] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            guard let billName = record["billName"] as? String,
                  let payerName = record["payerName"] as? String,
                  let totalAmount = record["totalAmount"] as? Double,
                  let currencyRaw = record["currency"] as? String,
                  let currency = Currency(rawValue: currencyRaw),
                  let date = record["date"] as? Date,
                  let id = UUID(uuidString: record.recordID.recordName) else {
                continue
            }
            
            var items: [SplitItemRecord] = []
            if let itemsData = record["items"] as? Data {
                items = (try? JSONDecoder().decode([SplitItemRecord].self, from: itemsData)) ?? []
            }
            
            var participants: [SplitParticipantRecord] = []
            if let participantsData = record["participants"] as? Data {
                participants = (try? JSONDecoder().decode([SplitParticipantRecord].self, from: participantsData)) ?? []
            }
            
            let bill = SplitBillRecord(
                id: id,
                billName: billName,
                payerName: payerName,
                totalAmount: totalAmount,
                currency: currency,
                date: date,
                items: items,
                participants: participants
            )
            bills.append(bill)
        }
        
        return bills
    }
    
    // MARK: - Helper Methods
    
    private func saveRecords(_ records: [CKRecord]) async throws {
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notAvailable
        }
        
        guard !records.isEmpty else { 
            print("⚠️ No records to save")
            return 
        }
        
        print("💾 Saving \(records.count) records of type: \(records.first?.recordType ?? "unknown")")
        
        let batchSize = 100
        let batches = stride(from: 0, to: records.count, by: batchSize).map {
            Array(records[$0..<min($0 + batchSize, records.count)])
        }
        
        for (index, batch) in batches.enumerated() {
            print("📦 Processing batch \(index + 1)/\(batches.count) (\(batch.count) records)")
            do {
                let result = try await privateDatabase.modifyRecords(saving: batch, deleting: [])
                print("✅ Batch \(index + 1) saved successfully")
                
                // Log any partial failures
                if !result.saveResults.isEmpty {
                    let failedSaves = result.saveResults.filter { 
                        if case .failure = $0.value { return true }
                        return false
                    }
                    if !failedSaves.isEmpty {
                        print("⚠️ Some records failed to save in batch \(index + 1): \(failedSaves.count)")
                    }
                }
            } catch {
                print("❌ Failed to save batch \(index + 1): \(error)")
                throw error
            }
        }
    }
    
    // MARK: - Clear Cloud Data
    
    func clearCloudData() async throws {
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notAvailable
        }
        
        let recordTypes = [
            walletRecordType,
            transactionRecordType,
            creditCardRecordType,
            ccTransactionRecordType,
            installmentRecordType,
            debtRecordType,
            splitBillRecordType
        ]
        
        for recordType in recordTypes {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            let results = try await privateDatabase.records(matching: query)
            
            let recordIDs = results.matchResults.compactMap { _, result in
                try? result.get().recordID
            }
            
            if !recordIDs.isEmpty {
                _ = try await privateDatabase.modifyRecords(saving: [], deleting: recordIDs)
            }
        }
    }
}

// MARK: - CloudKit Error

enum CloudKitError: LocalizedError {
    case notAvailable
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        }
    }
}

// MARK: - Environment Key

struct CloudKitManagerKey: EnvironmentKey {
    static let defaultValue = CloudKitManager()
}

extension EnvironmentValues {
    var cloudKitManager: CloudKitManager {
        get { self[CloudKitManagerKey.self] }
        set { self[CloudKitManagerKey.self] = newValue }
    }
}
