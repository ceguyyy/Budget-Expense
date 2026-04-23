//
//  SettingView.swift
//  Budget Expense
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingView: View {
    @Environment(AppStore.self) private var store
    
    @State private var showingExporter = false
    @State private var csvDocument: CSVDocument?
    
    var body: some View {
        List {
            Section(header: Text("Data Management").foregroundStyle(.glassText)) {
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
        // ✅ Native file exporter for saving the CSV document
        .fileExporter(
            isPresented: $showingExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "BudgetExpense_Export_\(Date().formatted(date: .numeric, time: .omitted))"
        ) { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                print("Failed to save: \(error.localizedDescription)")
            }
        }
    }
    
    private func exportToCSV() {
        // 1. Setup CSV Headers
        var csvString = "Date,Account Type,Account Name,Transaction Type,Category,Description,Amount\n"
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        
        // 2. Append Wallet Transactions
        for tx in store.walletTransactions {
            let date = df.string(from: tx.date)
            let accountName = store.wallets.first(where: { $0.id == tx.walletId })?.name ?? "Unknown Wallet"
            let type = tx.type.rawValue // Inflow / Outflow
            
            // Strip out commas from user input to prevent breaking the CSV format
            let category = tx.category.replacingOccurrences(of: ",", with: " ")
            let note = tx.note.replacingOccurrences(of: ",", with: " ")
            let amount = "\(tx.amount)"
            
            csvString += "\(date),Debit Wallet,\(accountName),\(type),\(category),\(note),\(amount)\n"
        }
        
        // 3. Append Credit Card Transactions
        for card in store.creditCards {
            for tx in card.transactions {
                let date = df.string(from: tx.date)
                let accountName = card.name
                let type = "Outflow" // CC transactions are primarily expenses
                
                let category = tx.category.replacingOccurrences(of: ",", with: " ")
                let description = tx.description.replacingOccurrences(of: ",", with: " ")
                let amount = "\(tx.amount)"
                
                csvString += "\(date),Credit Card,\(accountName),\(type),\(category),\(description),\(amount)\n"
            }
        }
        
        // 4. Create document and trigger sheet
        csvDocument = CSVDocument(initialText: csvString)
        showingExporter = true
    }
}

// MARK: - CSV Document Wrapper
struct CSVDocument: FileDocument {
    // Tell the system we support .csv
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var text: String
    
    init(initialText: String = "") {
        text = initialText
    }
    
    // Read from file
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let decoded = String(data: data, encoding: .utf8) {
            text = decoded
        } else {
            text = ""
        }
    }
    
    // Write to file
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}


#Preview {
    SettingView()
}
