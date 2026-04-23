# Category Management Feature

## Overview

Fitur Category Management memungkinkan pengguna untuk mengelola kategori transaksi secara dinamis dengan kemampuan CRUD (Create, Read, Update, Delete) penuh. Kategori disimpan sebagai masterdata dengan data seeding awal dan dapat dikelola melalui menu Settings.

## Komponen Utama

### 1. CategoryManager.swift

**Class: `CategoryManager`**
- Observable class yang mengelola semua operasi kategori
- Menyimpan kategori ke UserDefaults dengan format JSON
- Menyediakan data seeding awal pada first launch

**Model: `ExpenseCategory`**
```swift
struct ExpenseCategory {
    let id: UUID
    var name: String          // Nama kategori
    var icon: String          // SF Symbol icon name
    var type: TransactionType // .inflow atau .outflow
    var isDefault: Bool       // True jika kategori default (tidak bisa dihapus)
    var order: Int            // Urutan tampilan
}
```

**Default Categories:**

**Inflow (Income):**
- Salary (banknote.fill)
- Transfer In (arrow.down.circle.fill)
- Sales (cart.fill)
- Refund (arrow.uturn.backward.circle.fill)
- Gift (gift.fill)
- Other (ellipsis.circle.fill)

**Outflow (Expense):**
- Food (fork.knife)
- Transport (car.fill)
- Shopping (bag.fill)
- Bills (doc.text.fill)
- Entertainment (ticket.fill)
- Health (cross.case.fill)
- Education (book.fill)
- Other (ellipsis.circle.fill)

**Methods:**
- `loadCategories()` - Load dari UserDefaults atau seed default
- `saveCategories()` - Simpan ke UserDefaults
- `addCategory(name:icon:type:)` - Tambah kategori baru
- `updateCategory(_:name:icon:)` - Update kategori existing
- `deleteCategory(_:)` - Hapus kategori (kecuali default)
- `categoriesForType(_:)` - Get kategori berdasarkan type (inflow/outflow)
- `categoryNames(for:)` - Get array nama kategori untuk picker
- `resetToDefaults()` - Reset semua kategori ke default

### 2. CategoryManagementView.swift

**Main View: `CategoryManagementView`**
- UI untuk mengelola kategori di Settings
- Tab selector untuk Inflow/Outflow
- List kategori dengan swipe actions
- Menu untuk add category dan reset to defaults
- Alert confirmation untuk delete dan reset

**Features:**
- ✅ View kategori berdasarkan type (Inflow/Outflow)
- ✅ Add kategori baru dengan custom icon
- ✅ Edit kategori existing
- ✅ Delete kategori custom (default category tidak bisa dihapus)
- ✅ Reset semua kategori ke default
- ✅ Swipe actions (Delete, Edit)
- ✅ Empty state UI

**Sub Views:**
- `CategoryRow` - Row item untuk setiap kategori
- `AddEditCategoryView` - Form untuk add/edit kategori

**AddEditCategoryView Features:**
- Icon preview dengan live update
- Text field untuk nama kategori
- Icon picker dengan 40+ SF Symbols
- Grid layout untuk memilih icon
- Visual indicator untuk selected icon
- Color tint sesuai transaction type

### 3. Integration dengan Views

**AddTransactionView.swift** (Wallet Transactions)
- Menggunakan `@Environment(\.categoryManager)`
- Dynamic category picker dari masterdata
- Categories otomatis update saat type berubah (Inflow/Outflow)

**AddCCTransactionView.swift** (Credit Card Transactions)
- File baru untuk menambah transaksi credit card
- Menggunakan categoryManager untuk kategori outflow
- Konsisten dengan UI AddTransactionView

**SettingView.swift**
- Menu "Manage Categories" di section "System"
- Icon: "tag.fill"
- Opens CategoryManagementView as sheet

### 4. App Setup

**Budget_ExpenseApp.swift**
```swift
@State private var categoryManager = CategoryManager()

var body: some Scene {
    WindowGroup {
        AuthenticationWrapper()
            .environment(\.categoryManager, categoryManager)
    }
}
```

## User Flow

### Mengelola Kategori

1. **Akses Menu:**
   - Buka Settings → System → "Manage Categories"

2. **Add Kategori:**
   - Tap menu (•••) → "Add Category"
   - Pilih nama kategori
   - Pilih icon dari grid (40+ options)
   - Preview langsung terlihat di atas
   - Tap "Add Category" untuk save

3. **Edit Kategori:**
   - Tap kategori atau swipe left → "Edit"
   - Ubah nama atau icon
   - Tap "Save Changes"

4. **Delete Kategori:**
   - Swipe left pada kategori custom
   - Tap "Delete"
   - Confirm deletion
   - **Note:** Default categories tidak bisa dihapus

5. **Reset ke Default:**
   - Tap menu (•••) → "Reset to Defaults"
   - Confirm alert
   - Semua custom categories dihapus
   - Default categories di-restore

### Menggunakan Kategori di Transaksi

1. **Wallet Transaction:**
   - Add Transaction → pilih type (Inflow/Outflow)
   - Category picker otomatis menampilkan kategori sesuai type
   - Select category dari menu

2. **Credit Card Transaction:**
   - Add Transaction dari Credit Card detail
   - Category picker menampilkan kategori Outflow
   - Select category dari menu

## Data Persistence

**Storage:** UserDefaults
**Key:** `budget_expense_categories`
**Format:** JSON (Array of ExpenseCategory)

**Lifecycle:**
1. First Launch → Seed default categories
2. User Operations → Save to UserDefaults
3. App Restart → Load from UserDefaults
4. Reset → Clear & re-seed defaults

## Design Highlights

### UI/UX Features
- 🎨 Glass morphism design consistent dengan app theme
- 🎯 Type selector dengan visual feedback (neonGreen/neonRed)
- 🖼️ Icon preview dengan live update
- 📱 Responsive grid layout untuk icon picker
- ⚡ Smooth animations (spring duration: 0.2)
- 🔒 Protected default categories (cannot delete)
- 🎭 Empty state dengan helpful message

### Color Scheme
- Inflow: `.neonGreen`
- Outflow: `.neonRed`
- Background: `.appBg` / `Color(white: 0.12)`
- Text: `.white` / `.glassText`

### Icons
- 40+ curated SF Symbols
- Categories: General, Shopping, Transport, Food, Health, Entertainment, Finance, Education, Nature

## Future Enhancements

### Possible Improvements:
1. **Category Statistics**
   - Show spending per category
   - Chart visualization
   - Top categories

2. **Category Icons**
   - Custom color per category
   - Upload custom images
   - Emoji support

3. **Category Budget**
   - Set budget limit per category
   - Alert when approaching limit
   - Monthly budget tracking

4. **Smart Categories**
   - Auto-suggest category based on note
   - ML-based categorization
   - Recent/frequent categories

5. **Import/Export**
   - Export categories to JSON
   - Import from file
   - Share category templates

6. **Subcategories**
   - Nested category structure
   - Parent-child relationships
   - Hierarchical budget tracking

## Migration Notes

### Breaking Changes:
- Hardcoded category arrays dihapus dari AddTransactionView
- Category sekarang dynamic dari CategoryManager
- Perlu menambahkan CategoryManager ke environment di root app

### Backwards Compatibility:
- ✅ Existing users akan auto-seed default categories pada first launch setelah update
- ✅ Tidak ada data loss
- ✅ Smooth migration path

## Testing Checklist

- [ ] First launch seeds default categories
- [ ] Add custom category (Inflow)
- [ ] Add custom category (Outflow)
- [ ] Edit category name
- [ ] Edit category icon
- [ ] Delete custom category
- [ ] Cannot delete default category
- [ ] Reset to defaults removes custom categories
- [ ] Categories persist after app restart
- [ ] Transaction view shows correct categories
- [ ] Category picker updates when type changes
- [ ] Icon grid scrollable dan responsive
- [ ] Empty state displays correctly
- [ ] Swipe actions work properly
- [ ] Context menu works on category rows
- [ ] Alerts show proper messages

## Code Quality

- ✅ SwiftUI best practices
- ✅ MVVM architecture
- ✅ Observable pattern untuk state management
- ✅ Environment values untuk dependency injection
- ✅ Codable untuk persistence
- ✅ Type safety dengan enums
- ✅ View modifiers untuk reusability
- ✅ Accessibility support (VoiceOver ready)
- ✅ Dark mode compatible
- ✅ No force unwraps
- ✅ Proper error handling

---

**Created:** April 23, 2026
**Version:** 1.0
**Status:** ✅ Implemented
