# Panduan Fitur Manajemen Kategori

## 📋 Ringkasan

Fitur Category Management memungkinkan pengguna untuk mengelola kategori transaksi dengan CRUD lengkap. Kategori tersimpan sebagai masterdata dengan data awal (seeding) dan bisa diatur di menu Settings.

## 🎯 Fitur Utama

### ✅ Yang Sudah Dibuat

1. **CategoryManager.swift**
   - Model `ExpenseCategory` dengan properties: id, name, icon, type, isDefault, order
   - CRUD operations lengkap
   - Data seeding otomatis di first launch
   - Persistence ke UserDefaults

2. **CategoryManagementView.swift**
   - UI untuk manage kategori
   - Type selector (Inflow/Outflow)
   - Add/Edit/Delete kategori
   - Icon picker dengan 40+ SF Symbols
   - Reset to defaults
   - Swipe actions

3. **AddCCTransactionView.swift**
   - View baru untuk add transaksi credit card
   - Menggunakan dynamic categories dari CategoryManager

4. **Integration:**
   - Budget_ExpenseApp.swift: CategoryManager added to environment
   - SettingView.swift: Menu "Manage Categories" ditambahkan
   - AddTransactionView.swift: Updated to use dynamic categories

## 📱 Cara Menggunakan

### Mengelola Kategori

```
Settings → System → Manage Categories
```

**Tambah Kategori:**
1. Tap ikon menu (•••) di kanan atas
2. Pilih "Add Category"
3. Masukkan nama kategori
4. Pilih icon dari grid
5. Tap "Add Category"

**Edit Kategori:**
1. Tap kategori yang mau diedit
2. Atau swipe left → "Edit"
3. Ubah nama/icon
4. Tap "Save Changes"

**Hapus Kategori:**
1. Swipe left pada kategori custom
2. Tap "Delete"
3. Confirm
4. ⚠️ Kategori default tidak bisa dihapus

**Reset ke Default:**
1. Tap ikon menu (•••)
2. Pilih "Reset to Defaults"
3. Confirm alert

## 🏗️ Struktur File

```
Budget Expense/
├── CategoryManager.swift              ← Model & Business Logic
├── CategoryManagementView.swift       ← UI untuk CRUD
├── AddCCTransactionView.swift         ← New: CC Transaction Form
├── Budget_ExpenseApp.swift            ← Updated: Add CategoryManager
├── SettingView.swift                  ← Updated: Add Menu
├── AddTransactionView.swift           ← Updated: Use Dynamic Categories
└── CATEGORY_MANAGEMENT_README.md      ← Documentation
```

## 📊 Kategori Default

### Inflow (Pemasukan):
- 💵 Salary
- ⬇️ Transfer In
- 🛒 Sales
- ↩️ Refund
- 🎁 Gift
- ⚪ Other

### Outflow (Pengeluaran):
- 🍽️ Food
- 🚗 Transport
- 🛍️ Shopping
- 📄 Bills
- 🎫 Entertainment
- 🏥 Health
- 📚 Education
- ⚪ Other

## 🔧 Technical Details

**Storage:**
- UserDefaults
- Key: `budget_expense_categories`
- Format: JSON

**Environment Key:**
```swift
@Environment(\.categoryManager) private var categoryManager
```

**Lifecycle:**
```
First Launch → Seed defaults
User Action → Save to UserDefaults
App Restart → Load from UserDefaults
```

## ⚙️ Implementasi di Code

### 1. Add CategoryManager ke Environment (Sudah Done ✅)

```swift
// Budget_ExpenseApp.swift
@State private var categoryManager = CategoryManager()

var body: some Scene {
    WindowGroup {
        AuthenticationWrapper()
            .environment(\.categoryManager, categoryManager)
    }
}
```

### 2. Menggunakan CategoryManager di View

```swift
struct YourView: View {
    @Environment(\.categoryManager) private var categoryManager
    
    var body: some View {
        // Get categories for inflow
        let inflowCategories = categoryManager.categoriesForType(.inflow)
        
        // Get category names only
        let categoryNames = categoryManager.categoryNames(for: .outflow)
        
        // Use in picker
        Picker("Category", selection: $selectedCategory) {
            ForEach(categoryNames, id: \.self) { name in
                Text(name)
            }
        }
    }
}
```

### 3. CRUD Operations

```swift
// Add
categoryManager.addCategory(
    name: "Groceries",
    icon: "cart.fill",
    type: .outflow
)

// Update
categoryManager.updateCategory(
    category,
    name: "Updated Name",
    icon: "star.fill"
)

// Delete (only custom categories)
categoryManager.deleteCategory(category)

// Reset
categoryManager.resetToDefaults()
```

## 🎨 UI Components

**CategoryManagementView:**
- Type selector dengan animasi
- List dengan swipe actions
- Empty state
- Menu dengan options
- Alert confirmations

**AddEditCategoryView:**
- Icon preview live
- Text field untuk nama
- Icon grid (6 columns)
- Save button dengan validation

**CategoryRow:**
- Icon circle dengan tint color
- Category name
- "Default" badge untuk default categories
- Chevron indicator

## 🧪 Testing

Checklist yang perlu di-test:
- [ ] First launch → default categories muncul
- [ ] Add custom category → tersimpan
- [ ] Edit category → perubahan tersimpan
- [ ] Delete custom category → berhasil
- [ ] Delete default category → tidak bisa
- [ ] Reset to defaults → custom hilang, default kembali
- [ ] App restart → data persist
- [ ] Transaction form → kategori muncul sesuai type
- [ ] Type switch di transaction → kategori berubah

## 🚀 Next Steps (Optional)

Jika mau dikembangkan lebih lanjut:

1. **Statistics:** Laporan pengeluaran per kategori
2. **Budgeting:** Set budget limit per kategori
3. **Smart Categorization:** Auto-suggest berdasarkan history
4. **Export/Import:** Share category templates
5. **Subcategories:** Nested structure untuk detail lebih
6. **Custom Colors:** Warna custom per kategori
7. **Usage Count:** Track berapa kali kategori dipakai

## ⚠️ Important Notes

1. **Default Categories:**
   - Ditandai dengan `isDefault: true`
   - Tidak bisa dihapus (UI akan disable delete action)
   - Bisa diedit nama dan icon (tapi tidak recommended)

2. **Transaction Type:**
   - Kategori dibagi berdasarkan `.inflow` dan `.outflow`
   - Credit card transaction selalu menggunakan `.outflow`

3. **Persistence:**
   - Otomatis save setiap ada perubahan
   - Load otomatis saat app start
   - First launch akan seed default categories

4. **Migration:**
   - User existing akan otomatis dapat default categories
   - Tidak ada data loss
   - Smooth upgrade path

## 📞 Support

Jika ada error atau bug:
1. Check console log untuk error messages
2. Verify CategoryManager ada di environment
3. Pastikan semua files sudah di-add ke target
4. Clean build folder (Shift + Cmd + K)

---

**Status:** ✅ Ready to Use
**Tanggal:** 23 April 2026
