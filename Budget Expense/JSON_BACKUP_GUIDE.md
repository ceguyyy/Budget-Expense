# JSON Backup & Restore Feature

## Overview
The app now supports complete data backup and restore using JSON files. This allows users to:
- Export all app data to a JSON file
- Save the backup file locally
- Import backup files to restore data
- Transfer data between devices

## Features Implemented

### 1. **Export All Data to JSON**
- Exports complete app state including:
  - All wallets
  - All wallet transactions
  - All credit cards (with transactions and installments)
  - All debts
  - All split bills
- Creates a formatted JSON file with timestamp
- File saved to user-selected location (Files, iCloud Drive, etc.)

### 2. **Import Data from JSON**
- Select any previously exported JSON backup file
- Confirmation dialog before import (prevents accidental data loss)
- Validates JSON structure before import
- Replaces all current data with backup data

### 3. **File Format**
The JSON file includes:
```json
{
  "wallets": [...],
  "walletTransactions": [...],
  "creditCards": [...],
  "debts": [...],
  "splitBills": [...]
}
```

All dates are stored in ISO8601 format for consistency.

## How to Use

### Exporting Data

1. Open **Settings** (gear icon)
2. Scroll to **Data Management** section
3. Tap **"Export All Data to JSON"** (green upload icon)
4. Choose where to save the file:
   - **iCloud Drive** - Access from any device
   - **On My iPhone** - Local storage
   - **Files App** - Any connected cloud service
5. File is named: `BudgetExpense_Backup_MM-DD-YYYY.json`
6. Success message confirms export

### Importing Data

1. Open **Settings** (gear icon)
2. Scroll to **Data Management** section
3. Tap **"Import Data from JSON"** (blue download icon)
4. Select a previously exported JSON file
5. Confirm the import (⚠️ Warning: This replaces ALL current data)
6. Success message confirms import

## Use Cases

### 1. **Regular Backups**
- Export your data weekly/monthly
- Keep backups in iCloud Drive or cloud storage
- Restore if data is lost or corrupted

### 2. **Device Migration**
- Export from old device
- Share file via AirDrop, email, or cloud
- Import on new device

### 3. **Data Archiving**
- Export data before major app updates
- Keep historical snapshots
- Archive old financial records

### 4. **Testing & Development**
- Create test data sets
- Share sample data configurations
- Reset to known state

## Technical Details

### Data Models
All models are `Codable`:
- `Wallet`
- `WalletTransaction`
- `CreditCard` (with nested `CCTransaction` and `Installment`)
- `Debt`
- `SplitBillRecord` (with nested items and participants)

### Encoding Strategy
- **Format**: Pretty-printed JSON with sorted keys
- **Date Format**: ISO8601 (e.g., "2026-04-23T10:30:00Z")
- **Character Encoding**: UTF-8

### Security
- Files are saved with standard iOS security
- No encryption (user can use encrypted cloud storage)
- Secure file access using iOS security-scoped resources

## Comparison with Other Backup Methods

| Feature | JSON Backup | iCloud Sync | CSV Export |
|---------|-------------|-------------|------------|
| Complete data backup | ✅ | ✅ | ❌ |
| Works offline | ✅ | ❌ | ✅ |
| Human-readable | ✅ | ❌ | ✅ |
| Device migration | ✅ | ✅ | ❌ |
| Requires Apple ID | ❌ | ✅ | ❌ |
| Automatic | ❌ | ✅ | ❌ |
| Can restore data | ✅ | ✅ | ❌ |

## Error Handling

The system handles:
- File access errors
- Invalid JSON format
- Missing required fields
- Corrupted data
- Permission issues

All errors show user-friendly messages.

## Best Practices

### For Users
1. **Regular Backups**: Export data weekly
2. **Multiple Locations**: Save to both iCloud and local
3. **Before Updates**: Backup before major app updates
4. **Verify Exports**: Open the JSON file to verify it saved correctly
5. **Test Imports**: Test restore on a backup device first

### For Developers
1. **Version Control**: Consider adding schema version in future
2. **Migration**: Handle old backup formats gracefully
3. **Validation**: Validate all imported data
4. **User Confirmation**: Always confirm destructive operations
5. **Error Messages**: Provide clear, actionable error messages

## Future Enhancements

Potential improvements:
- [ ] Backup encryption
- [ ] Automatic scheduled backups
- [ ] Selective restore (choose what to import)
- [ ] Backup compression
- [ ] Version tracking in JSON
- [ ] Migration helpers for old formats
- [ ] Backup to cloud services (Dropbox, Google Drive)
- [ ] Share backups via QR code

## Troubleshooting

### "Failed to import backup"
- Ensure the file is a valid JSON backup
- Check the file isn't corrupted
- Verify you have the correct file format

### "Cannot access the selected file"
- Grant file access permissions
- Ensure the file still exists
- Try copying file to iCloud Drive first

### "Export successful but can't find file"
- Check the location you selected
- Look in Files app → Browse → Locations
- Check iCloud Drive if selected

## Code Location

- **UI**: `SettingView.swift` - Data Management section
- **Export Function**: `exportToJSON()`
- **Import Function**: `importFromJSON(url:)`
- **Models**: `AppStoreBackup`, `JSONBackupFile`
- **Data Models**: `AppStore.swift` - All Codable models

## Testing Checklist

- [x] Export creates valid JSON file
- [x] Import reads and validates JSON
- [x] Data persists after import
- [x] Error messages display correctly
- [x] Confirmation dialogs work
- [x] File picker shows correct file types
- [x] Cleanup removes temporary files
- [x] Works with iCloud Drive
- [x] Works with local storage
- [x] Works with third-party cloud apps

## Support

For issues:
1. Check console logs for detailed error messages
2. Verify JSON file format
3. Ensure all permissions are granted
4. Try exporting to a different location

---

**Version**: 1.0  
**Last Updated**: April 23, 2026  
**Compatibility**: iOS 17.0+
