# Quick Reference: Sign in with Apple & iCloud Sync

## Access Managers in Your Views

```swift
// In any SwiftUI view
@Environment(\.appleSignInManager) private var signInManager
@Environment(\.cloudKitManager) private var cloudKitManager
@Environment(AppStore.self) private var store
```

## Check if User is Signed In

```swift
if signInManager.isSignedIn {
    // User is signed in
    let name = signInManager.getDisplayName()
    print("Welcome, \(name)!")
} else {
    // User is not signed in
    print("Please sign in")
}
```

## Get User Information

```swift
// Display name (always returns a value, defaults to "User")
let name = signInManager.getDisplayName()

// Email (optional, might be hidden by user)
if let email = signInManager.userEmail {
    print("Email: \(email)")
}

// User ID (Apple's unique identifier)
if let userId = signInManager.userId {
    print("User ID: \(userId)")
}
```

## Backup Data to iCloud

```swift
Task {
    do {
        try await cloudKitManager.backupToCloud(store: store)
        print("✅ Backup successful!")
    } catch {
        print("❌ Backup failed: \(error.localizedDescription)")
    }
}
```

## Restore Data from iCloud

```swift
Task {
    do {
        let restoredStore = try await cloudKitManager.restoreFromCloud()
        
        // Replace current data
        store.wallets = restoredStore.wallets
        store.walletTransactions = restoredStore.walletTransactions
        store.creditCards = restoredStore.creditCards
        store.debts = restoredStore.debts
        store.splitBills = restoredStore.splitBills
        
        print("✅ Restore successful!")
    } catch {
        print("❌ Restore failed: \(error.localizedDescription)")
    }
}
```

## Sign Out User

```swift
signInManager.signOut()
// User is now signed out, dashboard will show "User"
```

## Check iCloud Availability

```swift
if cloudKitManager.isCloudKitAvailable {
    // iCloud is ready to use
    print("iCloud is available")
} else {
    // iCloud is not available
    print("Please sign in to iCloud in Settings")
}
```

## Get Last Sync Date

```swift
if let lastSync = cloudKitManager.lastSyncDate {
    print("Last synced: \(lastSync.formatted())")
} else {
    print("Never synced")
}
```

## Show Sign In Sheet

```swift
struct MyView: View {
    @State private var showSignIn = false
    
    var body: some View {
        Button("Sign In") {
            showSignIn = true
        }
        .sheet(isPresented: $showSignIn) {
            AppleSignInSheet()
        }
    }
}
```

## Custom Sign In Button

```swift
SignInWithAppleButton {
    // Called when sign in succeeds
    print("User signed in!")
}
.frame(height: 50)
```

## Sync Status Indicator

```swift
struct SyncStatusView: View {
    @Environment(\.cloudKitManager) private var cloudKit
    
    var body: some View {
        HStack {
            if cloudKit.isSyncing {
                ProgressView()
                Text("Syncing...")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Up to date")
            }
        }
    }
}
```

## Handle Sync Errors

```swift
Task {
    do {
        try await cloudKitManager.backupToCloud(store: store)
    } catch CloudKitError.notAvailable {
        errorMessage = "Please sign in to iCloud"
    } catch {
        errorMessage = "Sync failed: \(error.localizedDescription)"
    }
}
```

## Display User Name Anywhere

```swift
struct UserGreeting: View {
    @Environment(\.appleSignInManager) private var signInManager
    
    var body: some View {
        Text("Hello, \(signInManager.getDisplayName())!")
            .font(.title)
    }
}
```

## Conditional UI Based on Sign In Status

```swift
struct MyView: View {
    @Environment(\.appleSignInManager) private var signInManager
    
    var body: some View {
        VStack {
            if signInManager.isSignedIn {
                // Signed in view
                Text("Welcome back, \(signInManager.getDisplayName())!")
                Button("Sync Now") {
                    // Sync logic
                }
            } else {
                // Not signed in view
                Text("Sign in to enable cloud sync")
                SignInWithAppleButton {
                    // Success
                }
            }
        }
    }
}
```

## Check Specific Data Availability

```swift
// Check if CloudKit manager is ready
await cloudKitManager.checkCloudKitAvailability()

if cloudKitManager.isCloudKitAvailable {
    // Ready to sync
} else if let error = cloudKitManager.syncError {
    // Show error to user
    print("iCloud error: \(error)")
}
```

## Clear Cloud Data (Advanced)

```swift
// Use with caution - deletes all cloud data
Task {
    do {
        try await cloudKitManager.clearCloudData()
        print("✅ Cloud data cleared")
    } catch {
        print("❌ Failed to clear: \(error)")
    }
}
```

## Example: Auto-Backup on App Background

```swift
struct MyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = AppStore()
    @State private var cloudKit = CloudKitManager()
    @State private var signIn = AppleSignInManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(\.cloudKitManager, cloudKit)
                .environment(\.appleSignInManager, signIn)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background && signIn.isSignedIn {
                // Auto-backup when app goes to background
                Task {
                    try? await cloudKit.backupToCloud(store: store)
                }
            }
        }
    }
}
```

## Example: Sync Indicator in Navigation Bar

```swift
struct DashboardView: View {
    @Environment(\.cloudKitManager) private var cloudKit
    
    var body: some View {
        NavigationStack {
            // Your content
            Text("Dashboard")
            
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if cloudKit.isSyncing {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
        }
    }
}
```

## Example: Smart Sync (Only When Needed)

```swift
func smartSync() async {
    // Only sync if last sync was > 1 hour ago
    let oneHourAgo = Date().addingTimeInterval(-3600)
    
    if let lastSync = cloudKitManager.lastSyncDate,
       lastSync > oneHourAgo {
        print("Recently synced, skipping")
        return
    }
    
    // Perform sync
    try? await cloudKitManager.backupToCloud(store: store)
}
```

## Example: Restore with Progress

```swift
@State private var isRestoring = false
@State private var restoreProgress = 0.0

func restoreWithProgress() async {
    isRestoring = true
    restoreProgress = 0.0
    
    // Simulate progress (in real app, this would track actual restore progress)
    Task {
        for i in 1...5 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            restoreProgress = Double(i) / 5.0
        }
    }
    
    do {
        let restored = try await cloudKitManager.restoreFromCloud()
        store.wallets = restored.wallets
        // ... restore other data
        restoreProgress = 1.0
    } catch {
        print("Error: \(error)")
    }
    
    isRestoring = false
}
```

## Example: Onboarding with Sign In

```swift
struct OnboardingView: View {
    @Environment(\.appleSignInManager) private var signIn
    @State private var showingMain = false
    
    var body: some View {
        if showingMain || signIn.isSignedIn {
            ContentView()
        } else {
            VStack(spacing: 30) {
                Text("Welcome to Budget Expense")
                    .font(.title)
                
                Text("Sign in to get started")
                    .foregroundStyle(.secondary)
                
                SignInWithAppleButton {
                    showingMain = true
                }
                .frame(height: 50)
                .padding()
                
                Button("Skip for now") {
                    showingMain = true
                }
            }
            .padding()
        }
    }
}
```

## Useful Debugging

```swift
// Print all user data
func debugUserInfo() {
    print("=== User Info ===")
    print("Is signed in: \(signInManager.isSignedIn)")
    print("Display name: \(signInManager.getDisplayName())")
    print("Email: \(signInManager.userEmail ?? "nil")")
    print("User ID: \(signInManager.userId ?? "nil")")
    print("================")
}

// Print CloudKit status
func debugCloudKit() {
    print("=== CloudKit Status ===")
    print("Available: \(cloudKitManager.isCloudKitAvailable)")
    print("Syncing: \(cloudKitManager.isSyncing)")
    print("Last sync: \(cloudKitManager.lastSyncDate?.description ?? "Never")")
    print("Error: \(cloudKitManager.syncError ?? "None")")
    print("======================")
}
```

## Tips

1. **Always check `isSignedIn` before syncing**
2. **Use `Task` for async operations**
3. **Handle errors gracefully**
4. **Show loading indicators during sync**
5. **Cache user name to avoid repeated checks**
6. **Test sign out flow thoroughly**
7. **Respect user's choice to not sign in**
8. **Don't force sign in - make it optional**
9. **Clear error messages help users**
10. **Provide manual sync option, don't auto-sync too often**
