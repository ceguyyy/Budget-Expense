# PIN Authentication & Face ID Implementation

This implementation adds secure PIN authentication with biometric (Face ID/Touch ID) support to your Budget Expense app.

## Features Implemented

### 1. **First Launch PIN Setup**
- When the app is launched for the first time, users are required to create a 6-digit PIN
- PIN confirmation step to prevent typos
- Visual feedback with animated dots and shake animation on errors

### 2. **PIN Entry on App Launch**
- Whenever the app is opened or returns from background, users must enter their PIN
- Automatic biometric authentication if Face ID/Touch ID is enabled
- Limited attempts with error messaging
- Haptic feedback on number pad

### 3. **Face ID / Touch ID Support**
- Can be enabled/disabled from Settings
- Automatically detects available biometric type (Face ID or Touch ID)
- Falls back to PIN if biometric fails
- Auto-triggers on app launch when enabled

### 4. **Reset PIN from Settings**
- Three-step process:
  1. Verify current PIN
  2. Enter new PIN
  3. Confirm new PIN
- Error handling for incorrect PINs and mismatches

### 5. **Automatic Locking**
- App automatically locks when going to background
- Requires authentication when returning to foreground

## Files Created

1. **AuthenticationManager.swift** - Core authentication logic
   - PIN management (create, verify, reset)
   - Biometric authentication
   - Lock/unlock state management
   - Persistent storage using UserDefaults

2. **PINSetupView.swift** - First-time PIN setup
   - 6-digit PIN creation
   - Confirmation step
   - Visual feedback with animated dots
   - Number pad with haptic feedback

3. **PINEntryView.swift** - PIN entry for unlocking
   - 6-digit PIN input
   - Biometric authentication option
   - Attempt tracking
   - Auto-trigger Face ID on appear

4. **ResetPINView.swift** - PIN reset from Settings
   - Three-step verification process
   - Current PIN verification
   - New PIN creation and confirmation

5. **AuthenticationWrapper.swift** - Main authentication flow
   - Handles first launch vs. locked state
   - Scene phase monitoring
   - Auto-lock on background

## Updated Files

1. **Budget_ExpenseApp.swift**
   - Added AuthenticationManager initialization
   - Uses AuthenticationWrapper instead of ContentView directly

2. **ContentView.swift**
   - Added AuthenticationManager environment

3. **SettingView.swift**
   - Added Security section
   - Face ID/Touch ID toggle
   - Reset PIN button

## Usage

### For First-Time Users
1. Launch app
2. Create 6-digit PIN
3. Confirm PIN
4. App unlocks automatically

### For Returning Users
1. App shows PIN entry screen
2. If Face ID enabled, automatically prompts for biometric
3. Can enter PIN manually if biometric fails
4. App unlocks after successful authentication

### Enabling Face ID
1. Go to Settings tab
2. Toggle "Use Face ID" (or "Use Touch ID")
3. Next time app locks, biometric will auto-trigger

### Resetting PIN
1. Go to Settings tab
2. Tap "Reset PIN"
3. Enter current PIN
4. Enter new 6-digit PIN
5. Confirm new PIN

## Security Features

- PIN stored securely in UserDefaults (consider using Keychain for production)
- Biometric authentication uses LocalAuthentication framework
- App automatically locks when backgrounded
- Attempt tracking prevents brute force
- Shake animation provides clear error feedback
- Face ID permission requested only when needed

## Important Notes

### For Production
Consider upgrading PIN storage from UserDefaults to Keychain for enhanced security:

```swift
// Use KeychainAccess or similar library
import KeychainAccess

private let keychain = Keychain(service: "com.yourapp.budgetexpense")

func setPIN(_ pin: String) {
    try? keychain.set(pin, key: pinKey)
}

func verifyPIN(_ pin: String) -> Bool {
    guard let savedPIN = try? keychain.get(pinKey) else { return false }
    return pin == savedPIN
}
```

### Info.plist Requirements
Add Face ID usage description to Info.plist:

```xml
<key>NSFaceIDUsageDescription</key>
<string>We need Face ID to securely unlock your Budget Expense app</string>
```

## Testing

1. **First Launch**: Delete app and reinstall to test PIN setup flow
2. **Face ID**: Enable in Settings, background app, return to test auto-trigger
3. **Reset PIN**: Try resetting with correct and incorrect old PINs
4. **Wrong PIN**: Enter wrong PIN multiple times to test error states
5. **Background Lock**: Background app and return to verify auto-lock

## Customization

### Change PIN Length
In `PINSetupView.swift`, `PINEntryView.swift`, and `ResetPINView.swift`:
```swift
private let pinLength = 6  // Change to 4 for shorter PIN
```

### Attempt Limits
In `PINEntryView.swift`:
```swift
private let maxAttempts = 5  // Adjust as needed
```

### Auto-Lock Behavior
In `AuthenticationWrapper.swift`, modify `handleScenePhaseChange()` to customize when app locks.

## Color Scheme

The implementation uses your app's existing color scheme:
- `.appBg` - Background color
- `.neonGreen` - Primary accent color
- `.neonRed` - Error color
- `.glassText` - Text styling

Make sure these are defined in your color assets or extensions.
