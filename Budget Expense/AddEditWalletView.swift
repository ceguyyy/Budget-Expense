//
//  AddEditWalletView.swift
//  Budget Expense
//

import SwiftUI
import PhotosUI

struct AddEditWalletView: View {
    let editTarget: Wallet?
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name        = ""
    @State private var balanceText = ""
    @State private var currency    = Currency.idr
    @State private var isPositive  = true
    
    // Stock support
    @State private var isStock = false
    @State private var stocks: [StockData] = []
    
    // UI state for adding/editing a stock
    @State private var editingStockId: UUID? = nil
    @State private var stockSymbol = ""
    @State private var stockLots = ""
    @State private var stockPriceStr = ""
    
    // ✅ State for Image Picking
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?

    private var isEditMode: Bool { editTarget != nil }
    private var canSave: Bool {
        if isStock {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && !stocks.isEmpty
        }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(balanceText.replacingOccurrences(of: ",", with: ".")) != nil
    }
    private var parsedBalance: Double {
        if isStock {
            return stocks.reduce(0) { $0 + $1.totalValue }
        }
        return Double(balanceText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var previewWallet: Wallet {
        var w = Wallet(name: name.isEmpty ? (isStock ? "Stock Portfolio" : "Wallet Name") : name,
               balance: parsedBalance, currency: currency, isPositive: isPositive, imageData: imageData)
        w.isStock = isStock
        if isStock {
            w.stocks = stocks
            w.currency = .idr 
        }
        return w
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        previewCard
                        imagePicker 
                        stockToggle
                        fields
                        saveBtn
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditMode ? "Edit Wallet" : "New Wallet")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.glassText)
                }
            }
            .onAppear { prefill() }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
        }
    }

    // MARK: Live Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PREVIEW").font(.caption2.weight(.semibold)).foregroundStyle(.dimText).kerning(1.5)
                .padding(.leading, 4)
            WalletListRow(wallet: previewWallet)
        }
    }

    // MARK: Image Picker
    
    private var imagePicker: some View {
        field(title: "WALLET IMAGE", icon: "photo") {
            HStack(spacing: 12) {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.12))
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "photo").foregroundStyle(.glassText))
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Text(imageData == nil ? "Select Image" : "Change Image")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.15), in: Capsule())
                }
                
                if imageData != nil {
                    Button(role: .destructive) {
                        imageData = nil
                        selectedPhotoItem = nil
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.neonRed)
                    }
                }
                
                Spacer()
            }
            .padding(14).glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    // MARK: - Stock Toggle
    private var stockToggle: some View {
        Toggle(isOn: $isStock) {
            Label("Stock (Indonesian Market)", systemImage: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .padding(14)
        .glassEffect(isStock ? .regular.tint(.neonGreen) : .regular, in: .rect(cornerRadius: 14))
        .onChange(of: isStock) { _, newValue in
            if newValue {
                currency = .idr
                isPositive = true
            }
        }
    }

    // MARK: Fields

    private var fields: some View {
        VStack(spacing: 20) {
            // Name - Always visible
            field(title: isStock ? "ACCOUNT DISPLAY NAME" : "WALLET NAME", icon: "wallet.bifold") {
                TextField(isStock ? "e.g. Portfolio Saham" : "e.g. BCA, GoPay, Dana…", text: $name)
                    .textFieldStyle(.plain).font(.body).foregroundStyle(.white)
                    .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            if isStock {
                // Stock List
                VStack(alignment: .leading, spacing: 12) {
                    Label("YOUR STOCKS", systemImage: "list.bullet")
                        .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(0.8)
                    
                    ForEach(stocks) { s in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(s.symbol).font(.headline).foregroundStyle(.white)
                                Text("\(s.lots) Lots · Rp \(formatNumber(s.currentPrice))").font(.caption).foregroundStyle(.dimText)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(formatIDR(s.totalValue)).font(.subheadline.bold()).foregroundStyle(.neonGreen)
                                HStack(spacing: 12) {
                                    Button {
                                        startEditing(s)
                                    } label: {
                                        Image(systemName: "pencil.circle.fill").foregroundStyle(.blue)
                                    }
                                    Button {
                                        stocks.removeAll { $0.id == s.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill").foregroundStyle(.neonRed)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Add/Edit Stock Input Section
                    VStack(spacing: 12) {
                        HStack {
                            Text(editingStockId == nil ? "ADD NEW STOCK" : "EDITING STOCK")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.orange)
                            Spacer()
                            if editingStockId != nil {
                                Button("Cancel Edit") { cancelEditing() }
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack(spacing: 10) {
                            TextField("Symbol (BMRI)", text: $stockSymbol)
                                .textFieldStyle(.plain).font(.subheadline).padding(10)
                                .background(Color(white: 0.2)).clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            TextField("Lots", text: $stockLots)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .textFieldStyle(.plain).font(.subheadline).padding(10)
                                .background(Color(white: 0.2)).clipShape(RoundedRectangle(cornerRadius: 8))
                                .frame(width: 80)
                        }
                        
                        // Price Field
                        HStack {
                            Text("Rp")
                                .font(.subheadline.bold()).foregroundStyle(.neonGreen)
                            TextField("Price per share...", text: $stockPriceStr)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .textFieldStyle(.plain).font(.subheadline.bold()).foregroundStyle(.white)
                        }
                        .padding(12)
                        .background(Color(white: 0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Button {
                            confirmStock()
                        } label: {
                            Label(editingStockId == nil ? "Add to Portfolio" : "Update Stock", systemImage: editingStockId == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(canConfirmStock ? .neonGreen : .gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                        }
                        .disabled(!canConfirmStock)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
            } else {
                field(title: "CURRENCY", icon: "globe") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Currency.allCases, id: \.self) { c in
                                Button { 
                                    withAnimation(.spring(duration: 0.2)) { currency = c } 
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(c.flag).font(.title2)
                                        Text(c.symbol).font(.headline.bold())
                                        Text(c.rawValue).font(.caption2.weight(.semibold))
                                    }
                                    .frame(width: 70)
                                    .padding(.vertical, 12)
                                    .glassEffect(currency == c ? .regular.tint(Color(white: 0.6)) : .regular, in: .rect(cornerRadius: 12))
                                    .foregroundStyle(currency == c ? .white : Color(white: 0.38))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2).padding(.vertical, 2)
                    }
                }

                field(title: "BALANCE", icon: "banknote") {
                    HStack(spacing: 10) {
                        Text(currency.symbol).font(.headline).foregroundStyle(.glassText).frame(minWidth: 24)
                        TextField("0", text: $balanceText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .textFieldStyle(.plain).font(.headline).foregroundStyle(.white)
                    }
                    .padding(14).glassEffect(in: .rect(cornerRadius: 14))
                }

                field(title: "TYPE", icon: "plusminus") {
                    HStack(spacing: 10) {
                        typeBtn("Asset / Inflow", "arrow.up.circle.fill", true,  .neonGreen)
                        typeBtn("Liability",      "arrow.down.circle.fill", false, .neonRed)
                    }
                }
            }
        }
    }

    private var canConfirmStock: Bool {
        !stockSymbol.isEmpty && !stockLots.isEmpty && Double(stockPriceStr) != nil
    }

    private var saveBtn: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: isEditMode ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(isEditMode ? "Save Changes" : "Add Wallet").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 17)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canSave).opacity(canSave ? 1 : 0.38)
    }

    // MARK: Helpers

    @ViewBuilder
    private func field<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(0.8)
            content()
        }
    }

    @ViewBuilder
    private func typeBtn(_ title: String, _ icon: String, _ value: Bool, _ color: Color) -> some View {
        Button { withAnimation(.spring(duration: 0.2)) { isPositive = value } } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3)
                    .foregroundStyle(isPositive == value ? color : Color(white: 0.28))
                Text(title).font(.caption2.weight(isPositive == value ? .semibold : .regular))
                    .foregroundStyle(isPositive == value ? .white : Color(white: 0.38))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .glassEffect(isPositive == value ? .regular.tint(color) : .regular, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
    
    private func startEditing(_ stock: StockData) {
        editingStockId = stock.id
        stockSymbol = stock.symbol
        stockLots = "\(stock.lots)"
        stockPriceStr = "\(Int(stock.currentPrice))"
    }
    
    private func cancelEditing() {
        editingStockId = nil
        stockSymbol = ""
        stockLots = ""
        stockPriceStr = ""
    }

    private func confirmStock() {
        guard let lots = Int(stockLots), let price = Double(stockPriceStr) else { return }
        
        if let id = editingStockId, let idx = stocks.firstIndex(where: { $0.id == id }) {
            // Update existing
            stocks[idx].symbol = stockSymbol.uppercased()
            stocks[idx].lots = lots
            stocks[idx].currentPrice = price
            stocks[idx].lastUpdated = Date()
        } else {
            // Add new
            let stock = StockData(symbol: stockSymbol.uppercased(), lots: lots, currentPrice: price, lastUpdated: Date())
            stocks.append(stock)
        }
        
        // Reset
        cancelEditing()
    }

    private func prefill() {
        guard let w = editTarget else { return }
        name        = w.name
        balanceText = "\(Int(w.balance))"
        currency    = w.currency
        isPositive  = w.isPositive
        imageData   = w.imageData
        isStock     = w.isStock
        stocks      = w.stocks
    }

    private func save() {
        var w = Wallet(id: editTarget?.id ?? UUID(),
                       name: name.trimmingCharacters(in: .whitespaces),
                       balance: isStock ? 0 : parsedBalance, 
                       currency: currency, 
                       isPositive: isPositive,
                       imageData: imageData)
        w.isStock = isStock
        if isStock {
            w.stocks = stocks
            w.currency = .idr
            w.balance = stocks.reduce(0) { $0 + $1.totalValue }
        }
        
        if isEditMode { store.updateWallet(w) } else { store.addWallet(w) }
        dismiss()
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}
