# Architecture Diagram: iCloud & Sign in with Apple

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Budget Expense App                       │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                  Budget_ExpenseApp.swift                    │ │
│  │                                                             │ │
│  │  @State var authManager = AuthenticationManager()          │ │
│  │  @State var appleSignInManager = AppleSignInManager() ← NEW│ │
│  │  @State var cloudKitManager = CloudKitManager() ← NEW      │ │
│  │  @State var categoryManager = CategoryManager()            │ │
│  │                                                             │ │
│  │  All managers injected into SwiftUI Environment            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ DashboardView│  │ SettingView  │  │ContentView   │          │
│  │              │  │              │  │              │          │
│  │ Shows user   │  │ Sign in/out  │  │ Tab Bar      │          │
│  │ name ← NEW   │  │ Sync control │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                  │                                     │
│         └──────────────────┴─────────────────────────────────┐  │
│                                                               │  │
│                        Environment Access                     │  │
│                  @Environment(\.appleSignInManager)           │  │
│                  @Environment(\.cloudKitManager)              │  │
└───────────────────────────────────────────────────────────────┘
                              │
                              │ Uses
                              ↓
        ┌─────────────────────────────────────────────────┐
        │                                                  │
        │          Apple Services (Native)                 │
        │                                                  │
        │  ┌──────────────────┐  ┌────────────────────┐   │
        │  │ AuthenticationKit│  │     CloudKit       │   │
        │  │                  │  │                    │   │
        │  │ • Sign in with   │  │ • Private Database │   │
        │  │   Apple          │  │ • Record Storage   │   │
        │  │ • User Identity  │  │ • Batch Operations │   │
        │  │ • Name/Email     │  │ • Auto Encryption  │   │
        │  └──────────────────┘  └────────────────────┘   │
        │                                                  │
        └──────────────────────────────────────────────────┘
                              │
                              │ Stored in
                              ↓
        ┌─────────────────────────────────────────────────┐
        │                                                  │
        │              User's iCloud Account               │
        │                                                  │
        │  ┌──────────────────┐  ┌────────────────────┐   │
        │  │ Apple ID Profile │  │  iCloud Storage    │   │
        │  │                  │  │                    │   │
        │  │ • Name           │  │ • Wallets          │   │
        │  │ • Email          │  │ • Transactions     │   │
        │  │ • User ID        │  │ • Credit Cards     │   │
        │  │                  │  │ • Debts            │   │
        │  │                  │  │ • Split Bills      │   │
        │  └──────────────────┘  └────────────────────┘   │
        │                                                  │
        └──────────────────────────────────────────────────┘
```

## Data Flow

### Sign In Flow
```
User Taps "Sign in"
       │
       ↓
AppleSignInSheet appears
       │
       ↓
SignInWithAppleButton tapped
       │
       ↓
ASAuthorizationController starts
       │
       ↓
Apple's UI appears (Face ID/password)
       │
       ↓
User authenticates
       │
       ↓
Apple returns credentials
       │
       ↓
AppleSignInManager stores:
  • User ID
  • Display Name
  • Email (if available)
       │
       ↓
Saved to UserDefaults
       │
       ↓
UI updates:
  • Settings shows user info
  • Dashboard shows name
  • iCloud options appear
```

### Backup Flow
```
User taps "Backup to iCloud"
       │
       ↓
Check if signed in ──No──> Show error
       │
      Yes
       ↓
Check iCloud available ──No──> Show error
       │
      Yes
       ↓
CloudKitManager.backupToCloud()
       │
       ↓
For each data type:
  • Wallets
  • Transactions
  • Credit Cards
  • Debts
  • Split Bills
       │
       ↓
Convert to CKRecord
       │
       ↓
Upload in batches (100 at a time)
       │
       ↓
Save to CloudKit Private Database
       │
       ↓
Update last sync timestamp
       │
       ↓
Show success message
```

### Restore Flow
```
User taps "Restore from iCloud"
       │
       ↓
Confirm destructive action ──Cancel──> Abort
       │
    Confirm
       ↓
CloudKitManager.restoreFromCloud()
       │
       ↓
Fetch all record types from CloudKit:
  • Query Wallets
  • Query Transactions
  • Query Credit Cards (with nested data)
  • Query Debts
  • Query Split Bills
       │
       ↓
Convert CKRecords back to Swift types
       │
       ↓
Rebuild relationships:
  • CC Transactions → Credit Cards
  • Installments → Credit Cards
  • Transactions → Wallets
       │
       ↓
Replace AppStore data
       │
       ↓
Save to UserDefaults (local persistence)
       │
       ↓
UI automatically updates via @Observable
       │
       ↓
Show success message
```

## Component Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                     AppleSignInManager                       │
│                      @Observable class                       │
├─────────────────────────────────────────────────────────────┤
│ Properties:                                                  │
│   • isSignedIn: Bool                                         │
│   • userDisplayName: String?                                 │
│   • userEmail: String?                                       │
│   • userId: String?                                          │
│                                                              │
│ Methods:                                                     │
│   • handleSignInResult()                                     │
│   • checkCurrentSignInStatus()                               │
│   • signOut()                                                │
│   • getDisplayName() → String                                │
│                                                              │
│ Storage:                                                     │
│   • UserDefaults (local)                                     │
└─────────────────────────────────────────────────────────────┘
                              ↕
                    Used by all views
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                      CloudKitManager                         │
│                      @Observable class                       │
├─────────────────────────────────────────────────────────────┤
│ Properties:                                                  │
│   • isSyncing: Bool                                          │
│   • lastSyncDate: Date?                                      │
│   • isCloudKitAvailable: Bool                                │
│   • syncError: String?                                       │
│                                                              │
│ Methods:                                                     │
│   • backupToCloud(store: AppStore)                           │
│   • restoreFromCloud() → AppStore                            │
│   • checkCloudKitAvailability()                              │
│   • clearCloudData()                                         │
│                                                              │
│ Private Methods:                                             │
│   • backupWallets(), backupTransactions(), etc.              │
│   • fetchWallets(), fetchTransactions(), etc.                │
│   • saveRecords([CKRecord])                                  │
│                                                              │
│ Storage:                                                     │
│   • CloudKit Private Database                                │
│   • UserDefaults (last sync time)                            │
└─────────────────────────────────────────────────────────────┘
```

## UI Components

```
┌──────────────────────────────────────────────────────────────┐
│                        SettingView                            │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────┐         │
│  │ Account Section                                 │         │
│  │                                                 │         │
│  │ If signed in:                                   │         │
│  │   • User avatar                                 │         │
│  │   • Display name                                │         │
│  │   • Email                                       │         │
│  │   • Sign Out button                             │         │
│  │                                                 │         │
│  │ If NOT signed in:                               │         │
│  │   • "Sign in with Apple" button                 │         │
│  └─────────────────────────────────────────────────┘         │
│                                                               │
│  ┌─────────────────────────────────────────────────┐         │
│  │ iCloud Backup Section (only if signed in)      │         │
│  │                                                 │         │
│  │   • iCloud status indicator                    │         │
│  │   • Last sync time                             │         │
│  │   • "Backup to iCloud" button                  │         │
│  │   • "Restore from iCloud" button               │         │
│  └─────────────────────────────────────────────────┘         │
│                                                               │
│  ┌─────────────────────────────────────────────────┐         │
│  │ Security Section                                │         │
│  │   • Face ID toggle                              │         │
│  │   • Reset PIN                                   │         │
│  └─────────────────────────────────────────────────┘         │
│                                                               │
│  ┌─────────────────────────────────────────────────┐         │
│  │ System Section                                  │         │
│  │   • Currency Rates                              │         │
│  │   • Manage Categories                           │         │
│  └─────────────────────────────────────────────────┘         │
│                                                               │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                      DashboardView                            │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────┐         │
│  │ Balance Cards (swipeable)                       │         │
│  │                                                 │         │
│  │   ┌─────────────────────────────────────────┐   │         │
│  │   │ Total Balance                           │   │         │
│  │   │ Rp 50,000,000                           │   │         │
│  │   │                                         │   │         │
│  │   │ [User Name] ← Shows signed-in name      │   │         │
│  │   │             or "User" if not signed in  │   │         │
│  │   └─────────────────────────────────────────┘   │         │
│  │                                                 │         │
│  └─────────────────────────────────────────────────┘         │
│                                                               │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                    AppleSignInSheet                           │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────┐         │
│  │                 [App Icon]                      │         │
│  │                                                 │         │
│  │           Sign in with Apple                    │         │
│  │                                                 │         │
│  │  Enable iCloud backup and sync across devices  │         │
│  └─────────────────────────────────────────────────┘         │
│                                                               │
│  Benefits:                                                    │
│    ✓ iCloud Backup                                            │
│    ✓ Privacy First                                            │
│    ✓ Cross-Device Sync                                        │
│                                                               │
│  ┌─────────────────────────────────────────────────┐         │
│  │     [Sign in with Apple Button]                 │         │
│  └─────────────────────────────────────────────────┘         │
│                                                               │
│                  Maybe Later                                  │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## CloudKit Record Schema

```
┌──────────────────────────────────────────────────────────────┐
│                    CloudKit Private Database                  │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Record Type: Wallet                                          │
│  ┌────────────────────────────────────────────────┐          │
│  │ Fields:                                        │          │
│  │   • recordName: UUID                           │          │
│  │   • name: String                               │          │
│  │   • balance: Double                            │          │
│  │   • currency: String                           │          │
│  │   • isPositive: Int (1 or 0)                   │          │
│  │   • imageData: Data?                           │          │
│  └────────────────────────────────────────────────┘          │
│                                                               │
│  Record Type: WalletTransaction                               │
│  ┌────────────────────────────────────────────────┐          │
│  │ Fields:                                        │          │
│  │   • recordName: UUID                           │          │
│  │   • walletId: String (UUID)                    │          │
│  │   • amount: Double                             │          │
│  │   • type: String (Inflow/Outflow)              │          │
│  │   • category: String                           │          │
│  │   • note: String                               │          │
│  │   • date: Date                                 │          │
│  └────────────────────────────────────────────────┘          │
│                                                               │
│  Record Type: CreditCard                                      │
│  ┌────────────────────────────────────────────────┐          │
│  │ Fields:                                        │          │
│  │   • recordName: UUID                           │          │
│  │   • name: String                               │          │
│  │   • bank: String                               │          │
│  │   • limit: Double                              │          │
│  │   • billingCycleDay: Int                       │          │
│  │   • dueDay: Int                                │          │
│  │   • colorIndex: Int                            │          │
│  └────────────────────────────────────────────────┘          │
│                                                               │
│  Record Type: CCTransaction                                   │
│  ┌────────────────────────────────────────────────┐          │
│  │ Fields:                                        │          │
│  │   • recordName: UUID                           │          │
│  │   • cardId: String (UUID)                      │          │
│  │   • description: String                        │          │
│  │   • amount: Double                             │          │
│  │   • category: String                           │          │
│  │   • date: Date                                 │          │
│  │   • isPaid: Int (1 or 0)                       │          │
│  └────────────────────────────────────────────────┘          │
│                                                               │
│  Record Type: Installment                                     │
│  ┌────────────────────────────────────────────────┐          │
│  │ Fields:                                        │          │
│  │   • recordName: UUID                           │          │
│  │   • cardId: String (UUID)                      │          │
│  │   • description: String                        │          │
│  │   • totalPrincipal: Double                     │          │
│  │   • annualInterestRate: Double                 │          │
│  │   • totalMonths: Int                           │          │
│  │   • startDate: Date                            │          │
│  │   • paidMonths: Int                            │          │
│  └────────────────────────────────────────────────┘          │
│                                                               │
│  Record Type: Debt                                            │
│  ┌────────────────────────────────────────────────┐          │
│  │ Fields:                                        │          │
│  │   • recordName: UUID                           │          │
│  │   • personName: String                         │          │
│  │   • amount: Double                             │          │
│  │   • currency: String                           │          │
│  │   • note: String                               │          │
│  │   • date: Date                                 │          │
│  │   • dueDate: Date?                             │          │
│  │   • isSettled: Int (1 or 0)                    │          │
│  └────────────────────────────────────────────────┘          │
│                                                               │
│  Record Type: SplitBillRecord                                 │
│  ┌────────────────────────────────────────────────┐          │
│  │ Fields:                                        │          │
│  │   • recordName: UUID                           │          │
│  │   • billName: String                           │          │
│  │   • payerName: String                          │          │
│  │   • totalAmount: Double                        │          │
│  │   • currency: String                           │          │
│  │   • date: Date                                 │          │
│  │   • items: Data (JSON encoded)                 │          │
│  │   • participants: Data (JSON encoded)          │          │
│  └────────────────────────────────────────────────┘          │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## State Management

```
User Sign In State Changes:

┌─────────────┐
│ Not Signed  │
│     In      │
└──────┬──────┘
       │
       │ User signs in
       ↓
┌─────────────┐
│  Signed In  │ ← AppleSignInManager.isSignedIn = true
└──────┬──────┘
       │
       │ Triggers UI update via @Observable
       ↓
┌─────────────────────────────────────────────┐
│ UI Updates Automatically:                   │
│                                             │
│ • DashboardView shows user name             │
│ • SettingView shows user profile            │
│ • iCloud options become available           │
│ • Environment propagates to all child views │
└─────────────────────────────────────────────┘


Sync State Changes:

┌─────────────┐
│    Idle     │
└──────┬──────┘
       │
       │ User taps "Backup"
       ↓
┌─────────────┐
│   Syncing   │ ← CloudKitManager.isSyncing = true
└──────┬──────┘
       │
       │ Upload completes
       ↓
┌─────────────┐
│  Complete   │ ← CloudKitManager.isSyncing = false
│             │   CloudKitManager.lastSyncDate = now
└─────────────┘
```

## Security & Privacy Architecture

```
                    User's Device
┌─────────────────────────────────────────────┐
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │         Budget Expense App              │ │
│  │                                         │ │
│  │  Local Storage (UserDefaults):         │ │
│  │  • User ID (token)                     │ │
│  │  • Display name                        │ │
│  │  • Email                               │ │
│  │  • App data (encrypted by iOS)         │ │
│  └────────────────────────────────────────┘ │
│                                              │
└──────────────┬───────────────────────────────┘
               │
               │ HTTPS + End-to-End Encryption
               ↓
┌─────────────────────────────────────────────┐
│          Apple's Servers                     │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │  Apple ID Authentication               │ │
│  │  • Validates identity                  │ │
│  │  • Never shares password               │ │
│  │  • Returns encrypted token             │ │
│  └────────────────────────────────────────┘ │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │  CloudKit Private Database             │ │
│  │  • Encrypted at rest                   │ │
│  │  • Encrypted in transit                │ │
│  │  • Only accessible by user             │ │
│  │  • Synced across user's devices        │ │
│  └────────────────────────────────────────┘ │
│                                              │
└──────────────────────────────────────────────┘

Privacy Guarantees:
✓ No data sent to third parties
✓ No analytics collected
✓ No tracking
✓ User controls all data
✓ Can delete anytime
✓ Encrypted by Apple
```

This architecture provides a complete, secure, and privacy-focused solution for cloud backup and authentication!
