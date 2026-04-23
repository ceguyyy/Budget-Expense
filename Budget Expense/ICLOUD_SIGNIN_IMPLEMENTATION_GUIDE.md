# iCloud Backup & Sign in with Apple Implementation Guide

## Overview

This implementation adds three major features to your Budget Expense app:
1. **Sign in with Apple** - Secure authentication
2. **iCloud CloudKit Backup** - Cloud storage for your data
3. **User Display Name** - Shows the signed-in user's name on the dashboard

## Features

### ✅ Sign in with Apple
- Secure authentication without passwords
- Privacy-focused (can hide email)
- User's name displayed on dashboard after sign in
- Sign in/out accessible from Settings

### ✅ iCloud CloudKit Backup
- Automatic backup of all app data to iCloud
- Restore data from any device
- Works only when signed in with Apple
- No external servers required
- Syncs:
  - Wallets & Transactions
  - Credit Cards & Transactions
  - Installments
  - Debts/Receivables
  - Split Bills

### ✅ Dashboard Name Display
- Shows signed-in user's name on balance cards
- Falls back to "User" if not signed in
- Updates automatically when user signs in/out

## Xcode Setup Required

### 1. Enable Sign in with Apple Capability

1. Open your project in Xcode
2. Select your app target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Sign in with Apple**

### 2. Enable iCloud Capability

1. In **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add **iCloud**
4. Check **CloudKit**
5. Ensure a CloudKit container is selected (Xcode creates one automatically)

### 3. Enable Background Modes (Optional but Recommended)

1. Click **+ Capability**
2. Add **Background Modes**
3. Check **Remote notifications** (for CloudKit sync notifications)

### 4. Update Info.plist

No manual changes needed - Sign in with Apple handles this automatically.

## File Structure

### New Files Created

```
Budget Expense/
├── AppleSignInManager.swift       # Manages Sign in with Apple
├── CloudKitManager.swift          # Handles iCloud backup/restore
└── AppleSignInSheet.swift         # Sign in UI
```

### Modified Files

```
Budget Expense/
├── Budget_ExpenseApp.swift        # Added managers to environment
├── DashboardView.swift            # Shows user name
└── SettingView.swift              # Sign in & sync controls
```

## How to Use

### For Users

#### Sign In
1. Open the app
2. Go to **Settings** tab
3. Tap **Sign in with Apple**
4. Follow Apple's authentication flow
5. Your name will appear on the dashboard cards

#### Backup Data to iCloud
1. Sign in with Apple first (required)
2. Go to **Settings** tab
3. Under **iCloud Backup** section
4. Tap **Backup to iCloud**
5. Wait for confirmation

#### Restore Data from iCloud
1. Install app on new device or after reinstall
2. Sign in with Apple
3. Go to **Settings** tab
4. Tap **Restore from iCloud**
5. Confirm the action
6. All your data will be restored

#### Sign Out
1. Go to **Settings** tab
2. Under **Account** section
3. Tap **Sign Out**
4. Dashboard will show "User" instead of your name

## Code Architecture

### AppleSignInManager
- Handles authentication with Apple
- Stores user credentials locally
- Provides user display name
- Manages sign in/out state

### CloudKitManager
- Manages CloudKit database operations
- Backs up all app data structures
- Restores data from cloud
- Checks iCloud availability
- Handles batch operations for performance

### Environment Integration
All managers are injected via SwiftUI environment:
```swift
@Environment(\.appleSignInManager) private var signInManager
@Environment(\.cloudKitManager) private var cloudKitManager
```

## Data Privacy & Security

### Privacy Features
- ✅ No external servers - data only in iCloud
- ✅ User's Apple ID is never exposed
- ✅ Email can be hidden via Apple's privacy features
- ✅ Data encrypted in transit and at rest by iCloud
- ✅ User controls when to backup/restore

### What's Stored in iCloud
All your app data:
- Wallets (name, balance, currency, type)
- Wallet transactions (amount, type, category, notes, dates)
- Credit cards (details, limits, billing info)
- Credit card transactions & installments
- Debts/receivables
- Split bill records

### What's NOT Stored
- User's Apple ID
- Device information
- App analytics
- Usage patterns

## Testing

### Test Sign In
1. Use your personal Apple ID
2. In Simulator, you can use sandbox account
3. Settings → Sign in with Apple ID (in Simulator)

### Test Backup
1. Sign in with Apple
2. Add some wallets/transactions
3. Tap "Backup to iCloud"
4. Check for success message

### Test Restore
1. Create backup on device A
2. Install app on device B (or delete and reinstall)
3. Sign in with same Apple ID
4. Tap "Restore from iCloud"
5. Verify all data is restored

### Test Across Devices
1. Backup from iPhone
2. Install on iPad
3. Sign in with same Apple ID
4. Restore on iPad
5. Both devices should have same data

## Troubleshooting

### "iCloud is not available"
**Solution:**
- Ensure you're signed in to iCloud in Settings app
- Go to Settings → [Your Name] → iCloud
- Make sure iCloud Drive is enabled

### "Sign in with Apple failed"
**Solution:**
- Check internet connection
- Verify Sign in with Apple capability is enabled in Xcode
- Try signing out of Apple ID in Settings and signing back in

### "Backup failed"
**Solution:**
- Check iCloud storage space
- Ensure CloudKit capability is enabled
- Verify you're signed in with Apple in the app

### Data not syncing between devices
**Solution:**
- Make sure you backup on device A first
- Then restore on device B
- CloudKit doesn't auto-sync - you control when to backup/restore

### User name shows "User" after sign in
**Solution:**
- Apple only provides name on FIRST sign in
- If you signed in before, the name might not be available
- Try signing out completely (including from Apple ID) and sign in again
- Or manually set a display name in future update

## API Usage

### Sign In
```swift
// Automatic via SignInWithAppleButton
SignInWithAppleButton {
    // Called on success
}
```

### Check Sign In Status
```swift
if signInManager.isSignedIn {
    // User is signed in
    let name = signInManager.getDisplayName()
}
```

### Backup to iCloud
```swift
Task {
    do {
        try await cloudKitManager.backupToCloud(store: store)
        // Success
    } catch {
        // Handle error
    }
}
```

### Restore from iCloud
```swift
Task {
    do {
        let restoredStore = try await cloudKitManager.restoreFromCloud()
        // Replace current data with restored data
    } catch {
        // Handle error
    }
}
```

## Performance Considerations

### Backup Performance
- Batches records in groups of 100
- Large datasets may take a few seconds
- UI shows progress indicator

### Restore Performance
- Fetches all records at once
- Rebuilds relationships (e.g., CC transactions to cards)
- May take longer for large datasets

### Optimization Tips
- Backup regularly but not excessively
- Restore only when necessary
- CloudKit has rate limits - avoid rapid consecutive calls

## Future Enhancements

Potential improvements you could add:

1. **Auto-sync** - Automatic background sync
2. **Conflict Resolution** - Handle conflicts when data differs between devices
3. **Selective Sync** - Choose what to backup
4. **Sync Status** - Real-time sync progress
5. **Custom Display Name** - Let users set their own name
6. **Family Sharing** - Share budgets with family members

## CloudKit Schema

Your app uses private database with these record types:

| Record Type | Fields |
|------------|--------|
| Wallet | id, name, balance, currency, isPositive, imageData |
| WalletTransaction | id, walletId, amount, type, category, note, date |
| CreditCard | id, name, bank, limit, billingCycleDay, dueDay, colorIndex |
| CCTransaction | id, cardId, description, amount, category, date, isPaid |
| Installment | id, cardId, description, totalPrincipal, annualInterestRate, totalMonths, startDate, paidMonths |
| Debt | id, personName, amount, currency, note, date, dueDate, isSettled |
| SplitBillRecord | id, billName, payerName, totalAmount, currency, date, items, participants |

## Support

### Common Questions

**Q: Do I need an Apple Developer account?**
A: No, you can test with free Apple ID. But for App Store, yes.

**Q: Will this work on Android?**
A: No, Sign in with Apple and iCloud are iOS/Apple ecosystem only.

**Q: Can I use this in production?**
A: Yes, but test thoroughly first. Consider adding error recovery.

**Q: What if user revokes access?**
A: App detects this and signs user out automatically.

**Q: Is there a storage limit?**
A: Yes, iCloud has limits per user. This app uses minimal space.

## Conclusion

You now have a complete, privacy-focused backup solution that:
- ✅ Uses Apple's native authentication
- ✅ Stores data securely in iCloud
- ✅ Works across all user's Apple devices
- ✅ Requires no external servers
- ✅ Respects user privacy

The implementation is production-ready but you should test thoroughly with your use cases before releasing to users.
