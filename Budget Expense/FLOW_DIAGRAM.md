# Authentication Flow Diagram

## Complete Flow Overview

```
App Launch
    ↓
AuthenticationWrapper
    ↓
    ├──→ [No PIN Set?] ────→ PINSetupView
    │                            ↓
    │                        [Create PIN]
    │                            ↓
    │                        [Confirm PIN]
    │                            ↓
    │                        [Save PIN]
    │                            ↓
    │                        [Unlock App] ────┐
    │                                          │
    └──→ [PIN Set?] ──────→ PINEntryView      │
                                ↓              │
                            [Is Face ID       │
                             Enabled?]        │
                                ↓              │
                         ┌──────┴──────┐      │
                         │              │      │
                      [YES]           [NO]     │
                         ↓              ↓      │
                 [Try Face ID]    [Show PIN]  │
                         ↓              ↓      │
                    [Success?]────→[Success?] │
                         │              │      │
                      [YES]           [YES]    │
                         └───────┬──────┘      │
                                 ↓             │
                           [Unlock App] ←──────┘
                                 ↓
                           ContentView
                                 ↓
                              TabView
                                 ↓
                 ┌───────────────┼───────────────┐
                 │               │               │
            Dashboard      Settings          Others
                                 │
                          [Security Section]
                                 ↓
                         ┌───────┴───────┐
                         │               │
                  [Toggle Face ID]  [Reset PIN]
                                         ↓
                                   ResetPINView
                                         ↓
                                 [Verify Old PIN]
                                         ↓
                                  [Enter New PIN]
                                         ↓
                                 [Confirm New PIN]
                                         ↓
                                    [Save PIN]
```

## State Management

### AuthenticationManager States

1. **hasPIN**: `Bool`
   - `false` → First launch, show PINSetupView
   - `true` → PIN exists, show PINEntryView if locked

2. **isAuthenticated**: `Bool`
   - `false` → User needs to authenticate
   - `true` → User is authenticated, can use app

3. **isAppLocked**: `Bool`
   - `false` → App is unlocked, show content
   - `true` → App is locked, show authentication

4. **isFaceIDEnabled**: `Bool`
   - `false` → Face ID disabled, PIN only
   - `true` → Face ID enabled, auto-trigger on lock

### Scene Phase Changes

```
App Active
    ↓
User Backgrounds App
    ↓
[Scene Phase: .background]
    ↓
AuthenticationManager.lockApp()
    ↓
[isAppLocked = true]
    ↓
User Returns to App
    ↓
[Scene Phase: .active]
    ↓
[isAppLocked still true?]
    ↓
Show PINEntryView
    ↓
[Face ID Enabled?]
    ↓
Auto-trigger Face ID
    ↓
[Success?] → Unlock
[Failure?] → Show PIN pad
```

## User Journeys

### Journey 1: First Time User

1. **Install & Launch App**
   ```
   User opens app for first time
   → AuthenticationWrapper detects !hasPIN
   → Shows PINSetupView
   → User enters 123456
   → User confirms 123456
   → PIN saved
   → isAuthenticated = true
   → isAppLocked = false
   → Shows ContentView
   ```

2. **User Closes App**
   ```
   User presses home button
   → Scene phase changes to .background
   → AuthenticationManager.lockApp()
   → isAppLocked = true
   → isAuthenticated = false
   ```

3. **User Reopens App**
   ```
   User taps app icon
   → AuthenticationWrapper detects isAppLocked
   → Shows PINEntryView
   → User enters 123456
   → PIN verified
   → isAuthenticated = true
   → isAppLocked = false
   → Shows ContentView
   ```

### Journey 2: Enable Face ID

1. **Navigate to Settings**
   ```
   User in app → Taps Settings tab
   → Sees Security section
   → Toggle "Use Face ID" ON
   → isFaceIDEnabled saved to UserDefaults
   ```

2. **Next App Lock**
   ```
   User backgrounds app
   → App locks
   → User returns
   → PINEntryView appears
   → onAppear triggers Face ID
   → Face ID prompt shows
   → User authenticates with face
   → Success!
   → App unlocks
   ```

### Journey 3: Reset PIN

1. **Initiate Reset**
   ```
   User in Settings
   → Taps "Reset PIN"
   → ResetPINView appears
   → Shows "Enter Current PIN"
   ```

2. **Verification**
   ```
   User enters old PIN: 123456
   → Verified ✓
   → Shows "Enter New PIN"
   → User enters: 654321
   → Shows "Confirm New PIN"
   → User enters: 654321
   → Match ✓
   → New PIN saved
   → View dismisses
   ```

3. **Next Lock**
   ```
   User backgrounds app
   → App locks
   → User returns
   → Enters new PIN: 654321
   → Success!
   → App unlocks
   ```

## Error Handling

### Wrong PIN Entry

```
User enters wrong PIN: 111111
    ↓
authManager.authenticate(with: "111111")
    ↓
verifyPIN("111111") returns false
    ↓
attemptCount += 1
    ↓
Show error: "Incorrect PIN. 4 attempts remaining"
    ↓
Shake animation
    ↓
Clear PIN field
    ↓
User tries again
```

### Mismatched PIN During Setup

```
User creates PIN: 123456
    ↓
User confirms: 123455 (typo!)
    ↓
Comparison: "123456" ≠ "123455"
    ↓
Show alert: "PINs don't match"
    ↓
Reset to start
    ↓
User tries again
```

### Face ID Failure

```
Face ID triggered
    ↓
evaluatePolicy() throws error
    ↓
Catch error
    ↓
Log: "Biometric authentication failed"
    ↓
Show PIN pad
    ↓
User can enter PIN manually
```

## Data Flow

### PIN Storage
```
User creates PIN: "123456"
    ↓
AuthenticationManager.setPIN("123456")
    ↓
UserDefaults.standard.set("123456", forKey: "budget_expense_pin")
    ↓
PIN persisted to disk
```

### PIN Retrieval
```
User enters PIN: "123456"
    ↓
AuthenticationManager.verifyPIN("123456")
    ↓
savedPIN = UserDefaults.standard.string(forKey: "budget_expense_pin")
    ↓
Compare: "123456" == "123456"
    ↓
Return true
    ↓
Unlock app
```

### Face ID Preference
```
User toggles Face ID ON
    ↓
UserDefaults.standard.set(true, forKey: "budget_expense_faceid_enabled")
    ↓
isFaceIDEnabled returns true
    ↓
Next lock: auto-trigger Face ID
```

## Integration Points

### Environment Objects

```swift
// App Level
@State private var authManager = AuthenticationManager()

// View Level  
@Environment(AuthenticationManager.self) private var authManager
```

### Key Methods

```swift
// Create PIN
authManager.setPIN("123456")

// Verify PIN
let isValid = authManager.verifyPIN("123456")

// Authenticate
let success = authManager.authenticate(with: "123456")

// Lock/Unlock
authManager.lockApp()
authManager.unlockApp()

// Biometric
let bioSuccess = await authManager.authenticateWithBiometrics()

// Check states
if authManager.hasPIN { }
if authManager.isAuthenticated { }
if authManager.isAppLocked { }
if authManager.isFaceIDEnabled { }
```

## Testing Scenarios

### Scenario 1: Clean Install
```
1. Delete app
2. Install fresh
3. Launch
4. Should see PIN setup
5. Create PIN
6. Should unlock to dashboard
```

### Scenario 2: Background Lock
```
1. Open app
2. Unlock with PIN
3. Press home button
4. Wait 1 second
5. Return to app
6. Should see PIN entry
```

### Scenario 3: Face ID Flow
```
1. Enable Face ID in Settings
2. Background app
3. Return to app
4. Face ID should auto-trigger
5. Authenticate with face
6. App should unlock
```

### Scenario 4: PIN Reset
```
1. Navigate to Settings
2. Tap Reset PIN
3. Enter current PIN
4. Enter new PIN
5. Confirm new PIN
6. Background app
7. Return and use new PIN
8. Should unlock successfully
```
