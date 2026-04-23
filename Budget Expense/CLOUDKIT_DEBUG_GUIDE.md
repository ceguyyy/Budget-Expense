# CloudKit Debug Guide

## EXC_BREAKPOINT Crash Fix

The `EXC_BREAKPOINT` error you're experiencing is typically caused by:
1. Force-unwrapping nil optionals
2. Precondition failures
3. CloudKit authentication issues
4. Invalid data types when storing/fetching from CloudKit

## Changes Made

### 1. Added Proper Initialization
- Added loading of `lastSyncDate` from UserDefaults in `init()`
- This prevents crashes when the manager tries to display the last sync date

### 2. Enhanced Error Handling
- Added comprehensive error messages for different CloudKit account statuses
- Added `@MainActor` annotations to ensure UI updates happen on the main thread
- Added detailed logging throughout the backup/restore process

### 3. Better Logging
All CloudKit operations now log their progress:
- 🔄 Starting operations
- ✅ Successful completions
- ❌ Failures with error details
- 📦 Batch processing progress

### 4. Safer Record Saving
- Added better error handling in `saveRecords()`
- Logs batch processing progress
- Handles partial failures gracefully

## Debugging Steps

### 1. Check Console Logs
When the app crashes, check the Xcode console for:
```
🔄 Starting backup to iCloud...
💼 Backing up X wallets...
```

This will tell you exactly where the crash occurs.

### 2. Common Crash Points

#### CloudKit Not Available
If you see:
```
❌ CloudKit availability check failed
```
**Solution**: Make sure you're signed into iCloud on the simulator/device.

#### Account Status Issues
If the crash happens during initialization:
- Check Settings > [Your Name] > iCloud
- Ensure iCloud Drive is enabled
- Sign out and back in if needed

#### Data Type Mismatches
If crashes occur during save/fetch:
- Check that all custom types conform to `Codable`
- Verify CloudKit field types match your Swift types

### 3. Enable CloudKit Logging

Add this to your scheme's environment variables:
```
-com.apple.coredata.cloudkit.verbose 1
```

### 4. Test with Empty Data First
Before backing up all your data:
1. Create a new wallet
2. Try backing up just that one item
3. Check if it succeeds
4. Gradually add more data

## CloudKit Requirements Checklist

- [ ] Signed into iCloud on device/simulator
- [ ] iCloud capability enabled in project settings
- [ ] CloudKit container configured in project
- [ ] Internet connection available
- [ ] iCloud Drive enabled in device settings

## Capability Setup

Make sure your project has:

1. **Signing & Capabilities**
   - iCloud capability added
   - CloudKit checked
   - Container selected or created

2. **Info.plist**
   - No special entries needed for CloudKit

3. **Entitlements**
   - Should be auto-generated when you add iCloud capability

## Common Issues and Solutions

### Issue: "iCloud is not available"
**Solutions:**
- Sign into iCloud in iOS Settings
- Enable iCloud Drive
- Check internet connection

### Issue: Crash on first launch
**Solutions:**
- The `checkCloudKitAvailability()` runs async in init
- Make sure UI doesn't access `isCloudKitAvailable` before it's set
- Added MainActor annotations to fix this

### Issue: "No iCloud account found"
**Solutions:**
- Sign into iCloud on the device
- For simulator: Xcode > Settings > Accounts > Add Apple ID

### Issue: Records not syncing
**Solutions:**
- Check CloudKit Dashboard (developer.apple.com)
- Verify record types match your code
- Clear cloud data and retry

## Testing CloudKit

### 1. Development vs Production
- Development: Use during development/testing
- Production: Use for App Store builds
- Switch in Signing & Capabilities

### 2. CloudKit Dashboard
Access at: developer.apple.com/icloud/dashboard
- View all records
- Delete test data
- Check schema

### 3. Testing Steps
1. Fresh install
2. Create some data
3. Tap "Backup to iCloud"
4. Check console for success
5. Delete app
6. Reinstall
7. Tap "Restore from iCloud"
8. Verify data appears

## Error Messages

The enhanced error handling now provides specific messages:

| Status | Message |
|--------|---------|
| noAccount | No iCloud account found |
| restricted | iCloud is restricted on this device |
| couldNotDetermine | Could not determine iCloud status |
| temporarilyUnavailable | iCloud is temporarily unavailable |

## Next Steps

1. **Run the app** and check the console
2. **Look for the last log** before the crash
3. **Take a screenshot** of the error
4. **Share the console output** for more specific help

The enhanced logging will tell you exactly where the crash occurs, making it much easier to fix!
