# Info.plist Required Permissions

Add these keys to your `Info.plist` file for the app to work properly.

## Required Permission Keys (3 Total)

### 1. Photo Library Access
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Duit Gw Woi needs access to your photo library to scan receipts and extract transaction details automatically.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save scanned receipt images to your photo library for record keeping.</string>
```

### 2. Camera Access
```xml
<key>NSCameraUsageDescription</key>
<string>Duit Gw Woi needs camera access to take photos of receipts for automatic transaction entry.</string>
```

### 3. Face ID / Touch ID (Biometric Authentication)
```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to securely access your financial data and protect your privacy.</string>
```

---

## How to Add in Xcode

### Option 1: Using Xcode UI (Recommended)

1. Open your project in Xcode
2. Select your target (e.g., "Budget Expense")
3. Go to **Info** tab
4. Click **+** button to add new entries
5. Add each key with its corresponding value:
   - `Privacy - Photo Library Usage Description`
   - `Privacy - Photo Library Additions Usage Description`
   - `Privacy - Camera Usage Description`
   - `Privacy - Face ID Usage Description`

### Option 2: Edit Info.plist as Source Code

1. Right-click `Info.plist` in Xcode
2. Choose **Open As** → **Source Code**
3. Paste the XML entries above inside the main `<dict>` tag

---

## Complete Info.plist Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Your existing keys -->
    
    <!-- Photo Library -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Duit Gw Woi needs access to your photo library to scan receipts and extract transaction details automatically.</string>
    
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>Save scanned receipt images to your photo library for record keeping.</string>
    
    <!-- Camera -->
    <key>NSCameraUsageDescription</key>
    <string>Duit Gw Woi needs camera access to take photos of receipts for automatic transaction entry.</string>
    
    <!-- Face ID / Touch ID -->
    <key>NSFaceIDUsageDescription</key>
    <string>Use Face ID to securely access your financial data and protect your privacy.</string>
    
    <!-- Optional: User Tracking -->
    <key>NSUserTrackingUsageDescription</key>
    <string>This allows us to provide better personalized features and improve the app experience.</string>
</dict>
</plist>
```

---

## Testing Permissions

### First Launch Flow:
1. App opens
2. Onboarding screen appears (swipeable cards)
3. User swipes through permission explanations
4. On last screen, "Grant Permissions" button
5. iOS shows permission dialogs one by one
6. User grants/denies each permission
7. App continues to main screen

### Permission States:
- ✅ **Authorized**: Full access granted
- 📸 **Limited**: Partial access (for photos)
- ❌ **Denied**: Access denied - show settings button
- ⏳ **Not Determined**: Not asked yet

### Reset Permissions for Testing:
1. Settings → General → Reset → Reset Location & Privacy
2. Or: Delete app and reinstall
3. Permissions will be asked again on first launch

---

## Important Notes

⚠️ **Without these keys**, the app will crash immediately when trying to access:
- Photo library
- Camera
- Face ID

✅ **Best Practice**: Always explain WHY you need each permission in simple, user-friendly language

🔒 **Privacy**: Users can always change permissions later in Settings → Your App

---

Generated: April 24, 2026
