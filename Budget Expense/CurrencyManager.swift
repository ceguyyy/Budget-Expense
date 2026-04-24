//
//  CurrencyManager.swift
//  Budget Expense
//

import SwiftUI
import Observation

@MainActor
@Observable
class CurrencyManager {
    // ✅ Shared singleton instance
    static let shared = CurrencyManager()
    
    // Base currency for displaying all amounts
    var baseCurrency: Currency = .idr {
        didSet {
            print("💱 [CurrencyManager] Base currency changed: \(oldValue.rawValue) → \(baseCurrency.rawValue)")
            
            // Only save the change, don't auto-fetch
            saveBaseCurrency()
            
            // Only fetch if rates are not available or very old (> 7 days)
            if exchangeRates.isEmpty {
                print("⚠️ [CurrencyManager] No rates cached, fetching...")
                Task {
                    await fetchExchangeRates()
                }
            } else if shouldForceRefresh() {
                print("⏰ [CurrencyManager] Rates are old (> 7 days), fetching...")
                Task {
                    await fetchExchangeRates()
                }
            } else {
                print("✅ [CurrencyManager] Using cached rates (still fresh)")
            }
        }
    }
    
    // Exchange rates relative to base currency
    var exchangeRates: [Currency: Double] = [:]
    
    // Last update time
    var lastUpdateDate: Date?
    
    // Loading state
    var isLoadingRates = false
    
    // Error message
    var errorMessage: String?
    
    // ✅ Track last fetch attempt to prevent spamming
    private var lastFetchAttempt: Date?
    private let minimumFetchInterval: TimeInterval = 60 // 1 minute minimum between fetches
    
    private let baseCurrencyKey = "app_base_currency"
    private let ratesKey = "app_exchange_rates"
    private let lastUpdateKey = "app_rates_last_update"
    
    private init() {
        loadBaseCurrency()
        loadCachedRates()
        
        print("💰 CurrencyManager initialized with \(exchangeRates.count) cached rates")
        
        // ✅ ONLY fetch if we have NO rates at all
        // Don't auto-fetch on every init - let user manually refresh
        if exchangeRates.isEmpty {
            print("⚠️ No cached rates found, will fetch on first use")
        }
    }
    
    // MARK: - Conversion
    
    /// Convert amount from one currency to another
    func convert(amount: Double, from: Currency, to: Currency) -> Double {
        if from == to {
            return amount
        }
        
        // If converting to base currency
        if to == baseCurrency {
            guard let rate = exchangeRates[from] else { return amount }
            return amount / rate
        }
        
        // If converting from base currency
        if from == baseCurrency {
            guard let rate = exchangeRates[to] else { return amount }
            return amount * rate
        }
        
        // Cross-currency conversion (via base currency)
        guard let fromRate = exchangeRates[from],
              let toRate = exchangeRates[to] else {
            return amount
        }
        
        // Convert to base first, then to target
        let inBase = amount / fromRate
        return inBase * toRate
    }
    
    /// Convert amount to base currency
    func toBaseCurrency(amount: Double, from currency: Currency) -> Double {
        return convert(amount: amount, from: currency, to: baseCurrency)
    }
    
    /// Get exchange rate between two currencies
    func getRate(from: Currency, to: Currency) -> Double {
        if from == to { return 1.0 }
        
        if to == baseCurrency {
            return 1.0 / (exchangeRates[from] ?? 1.0)
        }
        
        if from == baseCurrency {
            return exchangeRates[to] ?? 1.0
        }
        
        let fromRate = exchangeRates[from] ?? 1.0
        let toRate = exchangeRates[to] ?? 1.0
        return toRate / fromRate
    }
    
    // MARK: - Formatting
    
    /// Format amount in specified currency
    func format(amount: Double, currency: Currency, showSymbol: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0.00"
        
        if showSymbol {
            return "\(currency.symbol) \(formatted)"
        } else {
            return formatted
        }
    }
    
    /// Format amount converted to base currency
    func formatInBaseCurrency(amount: Double, from currency: Currency) -> String {
        let converted = toBaseCurrency(amount: amount, from: currency)
        return format(amount: converted, currency: baseCurrency)
    }
    
    // MARK: - Fetch Exchange Rates
    
    func fetchExchangeRates() async {
        // ✅ Prevent multiple simultaneous fetches
        if isLoadingRates {
            print("⏳ Already fetching rates, skipping...")
            return
        }
        
        // ✅ Rate limiting: Don't fetch if we just fetched recently
        if let lastAttempt = lastFetchAttempt {
            let timeSinceLastFetch = Date().timeIntervalSince(lastAttempt)
            if timeSinceLastFetch < minimumFetchInterval {
                print("⏱️ Too soon to fetch again (last fetch: \(Int(timeSinceLastFetch))s ago, minimum: \(Int(minimumFetchInterval))s)")
                return
            }
        }
        
        lastFetchAttempt = Date()
        isLoadingRates = true
        errorMessage = nil
        
        print("🔄 [CurrencyManager] Starting fetch for \(baseCurrency.rawValue)...")
        
        // Use free API: exchangerate-api.com
        let urlString = "https://v6.exchangerate-api.com/v6/1184a7843bf2f5403c4d651e/latest/\(baseCurrency.rawValue)"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid API URL"
            isLoadingRates = false
            print("❌ [CurrencyManager] Invalid URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "Server returned an error"
                isLoadingRates = false
                print("❌ [CurrencyManager] Server error")
                return
            }
            
            let result = try JSONDecoder().decode(ExchangeRateAPIResponse.self, from: data)
            
            // Convert to our Currency enum
            var rates: [Currency: Double] = [:]
            for currency in Currency.allCases {
                if let rate = result.conversion_rates[currency.rawValue] {
                    rates[currency] = rate
                }
            }
            
            // Base currency always has rate of 1.0
            rates[baseCurrency] = 1.0
            
            self.exchangeRates = rates
            self.lastUpdateDate = Date()
            
            saveRates()
            
            print("✅ [CurrencyManager] Successfully fetched \(rates.count) rates")
            
        } catch {
            errorMessage = "Failed to fetch rates: \(error.localizedDescription)"
            print("❌ [CurrencyManager] Fetch error: \(error)")
        }
        
        isLoadingRates = false
    }
    
    // ✅ Manual refresh that bypasses rate limiting (for user-initiated refresh)
    func forceRefreshRates() async {
        print("🔄 [CurrencyManager] Force refresh requested by user")
        lastFetchAttempt = nil // Reset the timer
        await fetchExchangeRates()
    }
    
    // MARK: - Persistence
    
    private func saveBaseCurrency() {
        UserDefaults.standard.set(baseCurrency.rawValue, forKey: baseCurrencyKey)
        print("💾 Saved base currency: \(baseCurrency.rawValue)")
    }
    
    private func loadBaseCurrency() {
        if let saved = UserDefaults.standard.string(forKey: baseCurrencyKey),
           let currency = Currency(rawValue: saved) {
            baseCurrency = currency
            print("✅ Loaded base currency: \(currency.rawValue)")
        } else {
            baseCurrency = .idr // Default
        }
    }
    
    private func saveRates() {
        // Convert to [String: Double] for encoding
        let ratesDict = exchangeRates.reduce(into: [String: Double]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        
        if let encoded = try? JSONEncoder().encode(ratesDict) {
            UserDefaults.standard.set(encoded, forKey: ratesKey)
        }
        
        if let lastUpdate = lastUpdateDate {
            UserDefaults.standard.set(lastUpdate.timeIntervalSince1970, forKey: lastUpdateKey)
        }
        
        print("💾 Saved \(exchangeRates.count) exchange rates")
    }
    
    private func loadCachedRates() {
        // Load rates
        if let data = UserDefaults.standard.data(forKey: ratesKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            
            var rates: [Currency: Double] = [:]
            for (key, value) in decoded {
                if let currency = Currency(rawValue: key) {
                    rates[currency] = value
                }
            }
            
            exchangeRates = rates
            print("✅ Loaded \(rates.count) cached exchange rates")
        }
        
        // Load last update date
        if let timestamp = UserDefaults.standard.object(forKey: lastUpdateKey) as? TimeInterval {
            lastUpdateDate = Date(timeIntervalSince1970: timestamp)
            print("📅 Last rates update: \(lastUpdateDate!)")
        }
    }
    
    private func shouldRefreshRates() -> Bool {
        guard let lastUpdate = lastUpdateDate else { return true }
        
        let dayInSeconds: TimeInterval = 24 * 60 * 60
        return Date().timeIntervalSince(lastUpdate) > dayInSeconds
    }
    
    // ✅ Force refresh when rates are very old (7 days)
    private func shouldForceRefresh() -> Bool {
        guard let lastUpdate = lastUpdateDate else { return true }
        
        let weekInSeconds: TimeInterval = 7 * 24 * 60 * 60
        return Date().timeIntervalSince(lastUpdate) > weekInSeconds
    }
}

// MARK: - API Response Model

struct ExchangeRateAPIResponse: Codable {
    let result: String
    let base_code: String
    let conversion_rates: [String: Double]
}

// MARK: - Environment Key

private struct CurrencyManagerKey: EnvironmentKey {
    // ✅ Use shared singleton as default value
    static let defaultValue = CurrencyManager.shared
}

extension EnvironmentValues {
    var currencyManager: CurrencyManager {
        get { self[CurrencyManagerKey.self] }
        set { self[CurrencyManagerKey.self] = newValue }
    }
}
