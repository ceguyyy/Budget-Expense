# Budget Expense App - Multi-Currency Feature Documentation

## Overview
This document provides comprehensive information about the **Multi-Currency Support** feature in the Budget Expense App (DGW - Duit Gw Woi).

## Table of Contents
1. [Supported Currencies](#supported-currencies)
2. [Architecture](#architecture)
3. [Features](#features)
4. [Components](#components)
5. [Usage Guide](#usage-guide)
6. [API Integration](#api-integration)
7. [Data Flow](#data-flow)

---

## Supported Currencies

The app supports **16 major world currencies**:

| Code | Currency | Symbol | Flag |
|------|----------|--------|------|
| USD | US Dollar | $ | 🇺🇸 |
| EUR | Euro | € | 🇪🇺 |
| GBP | British Pound | £ | 🇬🇧 |
| JPY | Japanese Yen | ¥ | 🇯🇵 |
| CNY | Chinese Yuan | ¥ | 🇨🇳 |
| INR | Indian Rupee | ₹ | 🇮🇳 |
| AUD | Australian Dollar | $ | 🇦🇺 |
| CAD | Canadian Dollar | $ | 🇨🇦 |
| CHF | Swiss Franc | ₣ | 🇨🇭 |
| SGD | Singapore Dollar | $ | 🇸🇬 |
| MYR | Malaysian Ringgit | RM | 🇲🇾 |
| THB | Thai Baht | ฿ | 🇹🇭 |
| IDR | Indonesian Rupiah | Rp | 🇮🇩 |
| KRW | South Korean Won | ₩ | 🇰🇷 |
| RUB | Russian Ruble | ₽ | 🇷🇺 |
| BRL | Brazilian Real | R$ | 🇧🇷 |

---

## Architecture

### Core Components

1. **Currency Enum** (`Currency.swift`)
   - Defines all supported currencies
   - Provides symbol, name, and flag emoji
   - Implements `Codable` for persistence

2. **CurrencyManager** (`CurrencyManager.swift`)
   - Manages base currency selection
   - Handles exchange rate fetching and caching
   - Provides conversion utilities
   - Observable class for SwiftUI integration

3. **AppStore Integration**
   - Holds `CurrencyManager` instance
   - Makes currency manager available throughout the app

### Data Models

```swift
enum Currency: String, CaseIterable, Codable {
    case usd = "USD"
    case eur = "EUR"
    // ... more currencies
    
    var symbol: String { /* ... */ }
    var name: String { /* ... */ }
    var flag: String { /* ... */ }
}
```

---

## Features

### 1. Base Currency Selection
- Users can set a **base currency** in Settings
- All monetary amounts in the app are displayed in the base currency
- Automatic conversion from account currencies to base currency

### 2. Multi-Account Support
- Create wallets in **any supported currency**
- Create debts/receivables in **any supported currency**
- Credit cards default to IDR (Indonesian market standard)

### 3. Automatic Currency Conversion
- Real-time conversion to base currency
- Cached exchange rates (updated every 24 hours)
- Manual refresh option available

### 4. Smart Display
- Dashboard shows all amounts in base currency
- Individual accounts show original currency
- Exchange rate indicators in selection views

---

## Components

### 1. CurrencyManager

**Location:** `/repo/CurrencyManager.swift`

**Key Methods:**

```swift
class CurrencyManager {
    // Convert between currencies
    func convert(amount: Double, from: Currency, to: Currency) -> Double
    
    // Convert to base currency
    func toBaseCurrency(amount: Double, from currency: Currency) -> Double
    
    // Get exchange rate
    func getRate(from: Currency, to: Currency) -> Double
    
    // Format amount
    func format(amount: Double, currency: Currency, showSymbol: Bool = true) -> String
    
    // Fetch latest rates
    func fetchExchangeRates() async
}
```

**Properties:**
- `baseCurrency: Currency` - Currently selected base currency
- `exchangeRates: [Currency: Double]` - Exchange rates relative to base
- `lastUpdateDate: Date?` - Last fetch timestamp
- `isLoadingRates: Bool` - Loading state indicator

### 2. BaseCurrencySelectorView

**Location:** `/repo/SettingView.swift`

**Features:**
- Search functionality
- Popular currencies section
- Live exchange rate display
- Manual refresh button
- Visual selection feedback

### 3. CurrencySelectionRowView

**Features:**
- Flag emoji display
- Currency code and name
- Exchange rate indicator
- Selection state visualization

---

## Usage Guide

### For Users

#### Changing Base Currency

1. Open **Settings** (gear icon in tab bar)
2. Tap **"Base Currency"** in System section
3. Search or browse available currencies
4. Tap desired currency
5. All amounts will update automatically

#### Creating Multi-Currency Accounts

1. **Wallets:**
   - Create wallet → Select currency from dropdown
   - Available: All 16 supported currencies

2. **Debts/Receivables:**
   - Create debt → Select currency
   - Amount will convert to base currency in dashboard

3. **Credit Cards:**
   - Currently defaults to IDR
   - Transactions always in IDR

#### Understanding Conversions

- **Dashboard:** All amounts in base currency
- **Account Details:** Shows original currency
- **Transactions:** Listed in account currency
- **Charts:** Aggregated in base currency

### For Developers

#### Adding New Currency

1. **Update Currency Enum:**
```swift
enum Currency: String, CaseIterable, Codable {
    // ... existing
    case xxx = "XXX"  // Add new currency
    
    var symbol: String {
        // ... existing cases
        case .xxx: return "₲"
    }
    
    var name: String {
        // ... existing cases
        case .xxx: return "New Currency Name"
    }
    
    var flag: String {
        // ... existing cases
        case .xxx: return "🏴"
    }
}
```

2. **No other changes needed** - API will automatically include it

#### Using CurrencyManager

```swift
@Environment(AppStore.self) private var store

// Access currency manager
let currencyManager = store.currencyManager

// Convert amounts
let usdAmount = 100.0
let idrEquivalent = currencyManager.convert(
    amount: usdAmount, 
    from: .usd, 
    to: .idr
)

// Format for display
let formatted = currencyManager.format(
    amount: idrEquivalent, 
    currency: .idr
)
// Output: "Rp 1,620,000.00"
```

---

## API Integration

### Exchange Rate API

**Provider:** ExchangeRate-API.com  
**Endpoint:** `https://v6.exchangerate-api.com/v6/{API_KEY}/latest/{BASE_CURRENCY}`

**API Key:** `1184a7843bf2f5403c4d651e`

### Response Structure

```json
{
  "result": "success",
  "base_code": "USD",
  "conversion_rates": {
    "USD": 1.0,
    "EUR": 0.92,
    "GBP": 0.79,
    "JPY": 149.50,
    "IDR": 16200.00,
    ...
  }
}
```

### Caching Strategy

- **Cache Duration:** 24 hours
- **Storage:** UserDefaults
- **Keys:**
  - `app_base_currency` - Selected base currency
  - `app_exchange_rates` - JSON encoded rates dictionary
  - `app_rates_last_update` - Timestamp of last fetch

### Error Handling

- Network errors: Uses cached rates
- Invalid response: Falls back to 1:1 conversion
- Missing rate: Falls back to base currency value

---

## Data Flow

### 1. App Launch
```
App Launch
  ↓
CurrencyManager.init()
  ↓
Load base currency from UserDefaults
  ↓
Load cached exchange rates
  ↓
Check if rates are stale (> 24h)
  ↓
Fetch new rates (if needed)
```

### 2. Base Currency Change
```
User selects new currency
  ↓
CurrencyManager.baseCurrency = newCurrency
  ↓
Save to UserDefaults
  ↓
Fetch exchange rates for new base
  ↓
Dashboard auto-updates
  ↓
All amounts recalculated
```

### 3. Amount Display
```
Get amount from data model
  ↓
Identify currency of amount
  ↓
CurrencyManager.toBaseCurrency()
  ↓
Look up exchange rate
  ↓
Calculate converted amount
  ↓
CurrencyManager.format()
  ↓
Display to user
```

---

## Dashboard Integration

### Multi-Currency Calculations

**Total Balance:**
```swift
private var totalWalletBalanceIDR: Double {
    store.wallets.reduce(0) { sum, w in
        let amountInBase = currencyManager.toBaseCurrency(
            amount: w.signedBalance, 
            from: w.currency
        )
        return sum + amountInBase
    }
}
```

**Chart Data:**
```swift
let inflow = txs.filter { $0.type == .inflow }.reduce(0) { sum, tx in
    let wallet = store.wallets.first { $0.id == tx.walletId }
    guard let walletCurrency = wallet?.currency else { return sum }
    let amountInBase = currencyManager.toBaseCurrency(
        amount: tx.amount, 
        from: walletCurrency
    )
    return sum + amountInBase
}
```

---

## Settings UI

### Base Currency Section

**Location:** Settings → System → Base Currency

**Features:**
1. Current base currency display (flag + code)
2. Navigation to selector view
3. Last update indicator
4. Refresh button

**Visual Design:**
- Neon green accent color
- Flag emoji for visual identification
- Exchange rate preview
- Search functionality
- Popular currencies section

---

## Performance Considerations

### Optimization

1. **Rate Caching**
   - Reduces API calls
   - Instant app launch
   - Works offline

2. **Lazy Loading**
   - Exchange rates loaded on demand
   - Background updates

3. **Efficient Conversion**
   - O(1) lookup for rates
   - Memoized calculations
   - Batch processing for charts

### Memory Usage

- Exchange rates: ~2KB in memory
- Cached rates: ~3KB in UserDefaults
- Minimal overhead per currency

---

## Testing Scenarios

### Test Cases

1. **Base Currency Change**
   - ✅ All dashboard amounts update
   - ✅ Charts recalculate
   - ✅ Settings reflect change
   - ✅ UserDefaults persists

2. **Multi-Currency Wallets**
   - ✅ USD wallet shows correctly
   - ✅ EUR wallet shows correctly
   - ✅ IDR wallet shows correctly
   - ✅ Total balance accurate

3. **Offline Mode**
   - ✅ Uses cached rates
   - ✅ No crashes
   - ✅ Shows last update time

4. **Rate Refresh**
   - ✅ Manual refresh works
   - ✅ Auto-refresh after 24h
   - ✅ Loading indicator shows
   - ✅ Error handling works

---

## Future Enhancements

### Planned Features

1. **Custom Exchange Rates**
   - Allow manual rate input
   - Useful for historical transactions
   - Override API rates

2. **Multiple Base Currencies**
   - View toggle between currencies
   - Quick conversion
   - Favorite currencies

3. **Rate Alerts**
   - Notify when rate changes
   - Set threshold alerts
   - Historical rate charts

4. **Cryptocurrency Support**
   - BTC, ETH, USDT
   - Real-time rates
   - Volatility indicators

---

## Troubleshooting

### Common Issues

**Rates not updating:**
- Check internet connection
- Verify API key validity
- Check last update timestamp
- Try manual refresh

**Incorrect conversions:**
- Verify base currency setting
- Check cached rates
- Force refresh rates
- Restart app

**Missing currencies:**
- Update app to latest version
- Check API response
- Verify currency enum

---

## Code Examples

### Example 1: Create Multi-Currency Wallet

```swift
let usdWallet = Wallet(
    name: "US Bank Account",
    balance: 5000.0,
    currency: .usd,
    isPositive: true
)
store.addWallet(usdWallet)

let eurWallet = Wallet(
    name: "European Account",
    balance: 3000.0,
    currency: .eur,
    isPositive: true
)
store.addWallet(eurWallet)
```

### Example 2: Display Converted Amount

```swift
struct BalanceView: View {
    @Environment(AppStore.self) private var store
    let wallet: Wallet
    
    var body: some View {
        VStack {
            // Original amount
            Text(store.currencyManager.format(
                amount: wallet.balance,
                currency: wallet.currency
            ))
            
            // Converted to base
            Text(store.currencyManager.formatInBaseCurrency(
                amount: wallet.balance,
                from: wallet.currency
            ))
            .font(.caption)
            .foregroundStyle(.gray)
        }
    }
}
```

### Example 3: Calculate Total in Base Currency

```swift
func calculateTotalAssets() -> Double {
    store.wallets
        .filter { $0.isPositive }
        .reduce(0) { total, wallet in
            let converted = store.currencyManager.toBaseCurrency(
                amount: wallet.balance,
                from: wallet.currency
            )
            return total + converted
        }
}
```

---

## API Reference

### CurrencyManager Methods

#### `convert(amount:from:to:)`
Converts amount between two currencies.

**Parameters:**
- `amount: Double` - Amount to convert
- `from: Currency` - Source currency
- `to: Currency` - Target currency

**Returns:** `Double` - Converted amount

**Example:**
```swift
let usdToEur = currencyManager.convert(
    amount: 100, 
    from: .usd, 
    to: .eur
)
// Returns: ~92.00
```

#### `toBaseCurrency(amount:from:)`
Converts amount to currently selected base currency.

**Parameters:**
- `amount: Double` - Amount to convert
- `from: Currency` - Source currency

**Returns:** `Double` - Amount in base currency

#### `getRate(from:to:)`
Gets exchange rate between two currencies.

**Parameters:**
- `from: Currency` - Source currency
- `to: Currency` - Target currency

**Returns:** `Double` - Exchange rate

#### `format(amount:currency:showSymbol:)`
Formats amount with currency symbol.

**Parameters:**
- `amount: Double` - Amount to format
- `currency: Currency` - Currency for formatting
- `showSymbol: Bool` - Whether to show currency symbol

**Returns:** `String` - Formatted string

**Example:**
```swift
currencyManager.format(amount: 1500000, currency: .idr)
// Returns: "Rp 1,500,000.00"
```

---

## Changelog

### Version 1.0.0 (Current)
- ✅ 16 currency support
- ✅ Base currency selection
- ✅ Automatic conversion
- ✅ Rate caching
- ✅ Manual refresh
- ✅ Multi-currency wallets
- ✅ Multi-currency debts

### Planned for 1.1.0
- ⏳ Custom exchange rates
- ⏳ Rate history charts
- ⏳ Cryptocurrency support
- ⏳ Multiple base currency views

---

## Support

For issues or questions:
1. Check this documentation
2. Review code comments
3. Contact development team
4. Submit issue on repository

---

*Last Updated: April 24, 2026*
*Version: 1.0.0*
*Author: Budget Expense Team*
