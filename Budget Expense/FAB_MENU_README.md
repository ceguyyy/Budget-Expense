# FAB Menu & Split Bill Feature

## Overview
The Dashboard now features an expandable Floating Action Button (FAB) menu that provides quick access to multiple expense-related actions.

## FAB Menu Options

### 1. Add Expense ✅
- Opens the universal add transaction view
- Supports adding expenses to wallets or credit cards
- Full category and amount tracking

### 2. OCR Expense 🚧
- **Future Feature** - Currently disabled
- Will allow scanning receipts with camera
- Automatically extract transaction details from images

### 3. Split Bill ✅
- **NEW FEATURE** - Fully functional
- Split expenses among multiple participants
- Three split methods: Equal, Percentage, Custom
- Automatically creates receivables for tracking

## Split Bill Feature Details

### How It Works
1. Enter the total bill amount
2. Add a description and category
3. Select which wallet paid the bill
4. Choose a split method:
   - **Equal**: Divides bill evenly among all participants
   - **Percentage**: Assign percentage shares to each participant
   - **Custom**: Manually specify each person's amount
5. Add participants
6. Save to create:
   - An expense transaction for the payer
   - Receivables (debts) for each participant

### Split Methods

#### Equal Split
- Automatically divides the total amount equally
- Updates when participants are added/removed
- Perfect for simple group expenses

#### Percentage Split
- Use slider to assign percentage to each participant
- Real-time amount calculation
- Ensures total = 100%

#### Custom Split
- Manually enter exact amounts for each participant
- Flexible for uneven splits
- Validates that allocated amounts match total

### Integration with App
- **Expense Transaction**: Created in selected wallet with "outflow" type
- **Receivables**: Each participant creates a debt record
- **Category Tracking**: Uses existing expense categories
- **Multi-Currency**: Supports both IDR and USD wallets
- **Date Tracking**: Records when the bill occurred

## User Interface

### FAB Menu
- **Location**: Bottom-right corner of Dashboard
- **Color**: Orange (matches app accent)
- **Animation**: Smooth spring animation on expand/collapse
- **Interaction**: Tap to expand, X to close

### Menu Items
Each menu item displays:
- Icon representing the action
- Label text
- Color-coded circular button
- Disabled state for future features (OCR)

## Files

### Core Components
- `FABMenuView.swift` - Expandable FAB menu component
- `SplitBillView.swift` - Complete split bill interface
- `DashboardView.swift` - Updated to integrate FAB menu

### Models Used
- `WalletTransaction` - For recording the expense
- `Debt` - For tracking receivables from participants
- `Wallet` - For selecting which account paid
- `Currency` - Multi-currency support

## Usage Example

**Scenario**: Dinner with friends, total bill Rp 300,000

1. Tap FAB → Select "Split Bill"
2. Enter amount: 300,000
3. Description: "Dinner at Italian Restaurant"
4. Category: "Food"
5. Select your wallet as payer
6. Choose "Equal" split method
7. Add participants: Alice, Bob, Charlie (3 people)
8. Each person's share: Rp 100,000
9. Save

**Result**:
- Your wallet: -Rp 300,000 (expense)
- Receivables: 
  - Alice owes Rp 100,000
  - Bob owes Rp 100,000
  - Charlie owes Rp 100,000

## Future Enhancements

### OCR Expense Scanner
- Camera integration with `AVFoundation`
- Receipt image processing
- Text extraction for amount, merchant, date
- Auto-populate transaction form
- Support for multiple receipt formats

### Potential Split Bill Improvements
- Group presets (save frequent participant groups)
- Split by items (itemized bills)
- Export split summary
- Send payment requests
- Mark participants as paid
- History of split bills

## Design Notes

- Consistent glass morphism design throughout
- Orange accent color for primary actions
- Smooth animations for better UX
- Validation to prevent errors
- Clear visual feedback for disabled features
