# FAQ: iCloud Backup & Sign in with Apple

## General Questions

### Q: Do I need to sign in with Apple to use the app?
**A:** No, sign in is completely optional! The app works perfectly fine without signing in. All your data is stored locally. Sign in is only required if you want to backup to iCloud or sync across devices.

### Q: What happens to my data if I don't sign in?
**A:** Your data stays on your device, saved in UserDefaults (iOS's local storage). It will persist even after closing the app, but won't be backed up to iCloud.

### Q: Can I use the app offline?
**A:** Yes! The app works fully offline. Sign in and sync require internet, but all core features work without internet.

### Q: Will my data be shared with anyone?
**A:** No. Your data is private and never shared. It's either stored locally on your device or in your personal iCloud account. No third parties have access.

---

## Sign in with Apple

### Q: What information does Apple provide to the app?
**A:** On first sign in, Apple provides:
- User ID (encrypted token)
- Full Name (if you allow it)
- Email (real or private relay email if you choose)

On subsequent sign-ins, Apple only confirms your identity.

### Q: Can I hide my email?
**A:** Yes! When signing in, Apple gives you the option to:
- Share your real email
- Use "Hide My Email" (Apple creates a private relay email)

### Q: What if I don't want to share my name?
**A:** Your name is requested but not required. The app will work fine and show "User" on the dashboard instead of your name.

### Q: How do I sign out?
**A:** Go to Settings tab → Account section → Tap "Sign Out"

### Q: What happens when I sign out?
**A:**
- Your local data remains intact
- Dashboard shows "User" instead of your name
- iCloud sync options disappear
- You can sign back in anytime

### Q: Can I delete my Sign in with Apple data?
**A:** Yes, go to your Apple ID settings in iOS Settings app → Password & Security → Apps Using Apple ID → Budget Expense → Stop Using Apple ID

---

## iCloud Backup

### Q: What data is backed up to iCloud?
**A:** Everything you create in the app:
- All wallets and their balances
- All transactions (wallet and credit card)
- All credit cards and installments
- All debts/receivables
- All split bill records

### Q: What is NOT backed up?
**A:**
- Your PIN code
- App settings (like Face ID preference)
- Category customizations
- Display preferences

### Q: How much iCloud storage does this use?
**A:** Very little! For most users:
- Small usage (< 100 transactions): ~50 KB
- Medium usage (100-500 transactions): ~200-500 KB
- Heavy usage (1000+ transactions): ~1-2 MB

This is minimal compared to photos/videos.

### Q: Do I need an iCloud+ subscription?
**A:** No! The free iCloud tier (5 GB) is more than enough for this app's data.

### Q: Can I backup without signing in?
**A:** No, iCloud backup requires Sign in with Apple. But you can use local export to CSV without signing in.

### Q: Is backup automatic?
**A:** No, you control when to backup. Go to Settings → iCloud Backup → Tap "Backup to iCloud". This gives you full control.

### Q: Can I make it auto-backup?
**A:** Not in the current version, but you can modify the code to add auto-backup on app close (see QUICK_REFERENCE.md for example code).

### Q: How do I know when I last backed up?
**A:** Settings → iCloud Backup section shows "Last Backup: X minutes/hours/days ago"

---

## Restore & Sync

### Q: How do I restore my data on a new device?
**A:**
1. Install the app on new device
2. Sign in with the same Apple ID
3. Go to Settings → iCloud Backup
4. Tap "Restore from iCloud"
5. Confirm the action
6. Wait for completion

### Q: Will restore delete my current data?
**A:** Yes! Restore replaces all local data with cloud data. That's why there's a confirmation dialog.

### Q: Can I merge cloud and local data?
**A:** Not automatically. The restore operation completely replaces local data. You'd need to backup first if you want to preserve local data.

### Q: What if I have data on two devices?
**A:** You need to choose which device's data to keep:
1. Backup from Device A
2. Restore on Device B (this erases Device B's local data)
3. Or vice versa

The app doesn't auto-sync or merge - you have full control.

### Q: Does it sync automatically between devices?
**A:** No, sync is manual. You backup from one device and restore on another when you want.

### Q: Why isn't it auto-syncing?
**A:** Manual sync gives you control and privacy. You decide when and what to sync. Auto-sync can also drain battery and data.

### Q: Can I add auto-sync?
**A:** Yes, the code is designed to support it. Check QUICK_REFERENCE.md for an example of auto-backup on app background.

---

## Troubleshooting

### Q: "iCloud is not available" error
**A:** This means:
- You're not signed in to iCloud on your device
- iCloud Drive is disabled
- Internet connection is down

**Fix:**
1. Open iOS Settings
2. Tap your name at top
3. Tap iCloud
4. Enable iCloud Drive
5. Restart app

### Q: Sign in with Apple fails
**A:** Possible causes:
- No internet connection
- Apple's servers are down (rare)
- Sign in with Apple capability not enabled in Xcode
- Bundle ID mismatch

**Fix:**
1. Check internet
2. Verify Xcode capabilities are set
3. Try again later
4. Restart device

### Q: Backup fails with "rate limit" error
**A:** CloudKit has rate limits to prevent abuse.

**Fix:**
- Wait a few minutes and try again
- Don't backup too frequently (once per session is enough)
- For very large datasets, the app batches uploads automatically

### Q: My name shows "User" after signing in
**A:** Apple only provides your name on the FIRST sign in. If you signed in before, the name might not be available.

**Fix:**
- Sign out from the app
- Go to iOS Settings → Apple ID → Password & Security → Apps Using Apple ID
- Remove Budget Expense
- Sign in again in the app

### Q: Restore seems stuck
**A:** Restore can take time for large datasets.

**What to do:**
- Wait patiently (can take 30-60 seconds for large datasets)
- Check internet connection
- If truly stuck (> 2 minutes), force close and try again

### Q: Data is different after restore
**A:** Make sure you:
- Backed up from the correct device
- Used the same Apple ID on both devices
- Didn't backup after making changes

### Q: Lost all my data after restore!
**A:** Restore replaces local data with cloud data. If cloud was empty or old, you'd lose recent local data.

**Prevention:**
- Always backup before restore
- Verify last backup time before restoring
- Consider exporting to CSV periodically as extra backup

---

## Privacy & Security

### Q: Can Apple see my financial data?
**A:** No. Data is encrypted in CloudKit. Apple can't read it, only you can access it with your Apple ID.

### Q: Is my data encrypted?
**A:** Yes, on multiple levels:
- Encrypted in transit (HTTPS)
- Encrypted at rest in iCloud
- iOS encrypts UserDefaults on device

### Q: What if I lose my phone?
**A:** If you backed up to iCloud:
- Get a new device
- Sign in with your Apple ID
- Install the app
- Restore from iCloud
- All your data is back!

Without iCloud backup, local data is lost if device is lost.

### Q: Can someone access my data if they steal my phone?
**A:** Not easily. Your data is protected by:
- iOS device passcode
- App PIN code
- Face ID/Touch ID (if enabled)
- iOS encryption

### Q: What if I forget my PIN?
**A:** The PIN is for app lock only. If you forget it, you'd need to reinstall the app. If you have iCloud backup, you can restore your data after reinstall.

### Q: Can I use this for sensitive financial data?
**A:** Yes, but remember:
- It's a personal finance tracker, not a bank
- No regulatory compliance certifications
- Privacy and security are good but not bank-level
- Use at your own discretion

---

## Technical Questions

### Q: What iOS version is required?
**A:** iOS 17.0 or later (because the code uses latest SwiftUI features and Swift Observation framework)

### Q: Does this work on iPad?
**A:** Yes! It's universal and works on iPhone, iPad, and can even work on Mac with Catalyst (though not tested).

### Q: Does this work on Android?
**A:** No. Sign in with Apple and iCloud are Apple ecosystem exclusive.

### Q: Can I self-host the backend?
**A:** There is no backend! Everything uses Apple's services. That's the beauty of this implementation - no servers to maintain.

### Q: What if CloudKit goes down?
**A:** Rare, but possible. Your local data is unaffected. Sync just won't work until CloudKit is back.

### Q: What are CloudKit rate limits?
**A:** Apple doesn't publish exact numbers, but generally:
- Plenty for normal use
- The app batches operations (100 records at a time)
- Avoid syncing more than once per minute

### Q: Can I customize what gets synced?
**A:** Currently, it's all or nothing. But you can modify `CloudKitManager.swift` to add selective sync.

### Q: How do I clear all cloud data?
**A:** Use the `clearCloudData()` method in CloudKitManager (not currently in UI). This deletes all cloud records.

**Warning:** This is permanent and cannot be undone!

---

## Development Questions

### Q: Do I need an Apple Developer account?
**A:** 
- For testing: No, free Apple ID works
- For App Store: Yes, $99/year required

### Q: Can I test in Simulator?
**A:** Yes! Just sign in to iCloud in Simulator's Settings app first.

### Q: Where is the data stored in CloudKit?
**A:** In the private database of the default CloudKit container for your app's bundle ID.

### Q: How do I view CloudKit data?
**A:** Use CloudKit Dashboard:
1. Go to developer.apple.com
2. CloudKit Console
3. Select your container
4. Browse records

### Q: Can I modify the code?
**A:** Yes! All code is yours to modify. The implementation is modular and well-commented.

### Q: Where do I add new fields to sync?
**A:** In `CloudKitManager.swift`:
1. Add field to record in `backupXXX()` method
2. Add field retrieval in corresponding `fetchXXX()` method

### Q: How do I add a new data type to sync?
**A:**
1. Add record type constant in CloudKitManager
2. Create `backup<Type>()` method
3. Create `fetch<Type>()` method
4. Call both in `backupToCloud()` and `restoreFromCloud()`

---

## Best Practices

### Q: How often should I backup?
**A:** 
- After major changes (adding many transactions, new credit card, etc.)
- Before deleting the app
- Before upgrading iOS
- Once a week if you use the app daily

### Q: Should I use iCloud backup or CSV export?
**A:**
- iCloud: Best for regular backups and multi-device sync
- CSV: Best for permanent records, data analysis, migration

Use both! They serve different purposes.

### Q: What if I want to switch to a new Apple ID?
**A:**
1. Backup with old Apple ID
2. Export to CSV (as extra safety)
3. Sign out from app
4. Sign in with new Apple ID
5. Manually backup again with new Apple ID

Note: Old Apple ID's cloud data stays separate.

### Q: Can I share my data with family?
**A:** Not directly through this app. You could:
- Export to CSV and share the file
- Manually enter data on another device
- (Future feature: Family sharing could be added)

---

## Comparison with Alternatives

### Q: Why not use Firebase or other cloud services?
**A:**
- Privacy: Your data stays in Apple ecosystem
- No third-party servers
- No tracking or analytics by default
- Free (no server costs)
- Better integration with iOS

### Q: Why not use Core Data + CloudKit sync?
**A:**
- Simpler to implement
- More control over what syncs
- Core Data CloudKit sync is complex
- This approach is more explicit

### Q: Why manual sync instead of automatic?
**A:**
- User control and privacy
- Saves battery and data
- Prevents sync conflicts
- User knows exactly when data is uploaded

---

## Future Enhancements

### Q: Will you add auto-sync?
**A:** You can add it yourself using the example in QUICK_REFERENCE.md. It's intentionally manual for user control.

### Q: Will you add conflict resolution?
**A:** Not in current version. Conflict resolution is complex. For personal use, last-write-wins (current behavior) is usually fine.

### Q: Can I sync with web version?
**A:** No web version exists, and CloudKit web access is complex. This is designed for native iOS only.

### Q: Can I sync with family members?
**A:** Not currently. Each Apple ID has its own private data. Shared data would require CloudKit shared database (more complex).

---

## Support

### Q: Something isn't working, where do I get help?
**A:** Check:
1. This FAQ
2. TROUBLESHOOTING section in IMPLEMENTATION_GUIDE.md
3. Code comments in the source files
4. Apple's documentation for Sign in with Apple and CloudKit

### Q: Can I contribute improvements?
**A:** This is your codebase! Modify, improve, and customize as you wish.

### Q: Where do I report bugs?
**A:** This is a custom implementation for your personal use. Debug using:
- Xcode debugger
- Print statements
- CloudKit Dashboard
- Apple's developer forums

---

## Quick Tips

✅ **DO:**
- Backup before major changes
- Test restore on a secondary device first
- Keep PIN code safe
- Export to CSV periodically
- Sign in with your main Apple ID

❌ **DON'T:**
- Sync too frequently (respect rate limits)
- Share your Apple ID
- Restore without verifying last backup time
- Assume auto-sync is enabled
- Delete app without backup if you care about data

---

Need more help? Check the other documentation files:
- `IMPLEMENTATION_SUMMARY.md` - Overview
- `ICLOUD_SIGNIN_IMPLEMENTATION_GUIDE.md` - Detailed guide
- `SETUP_CHECKLIST.md` - Setup steps
- `QUICK_REFERENCE.md` - Code examples
- `ARCHITECTURE_DIAGRAM.md` - System design
