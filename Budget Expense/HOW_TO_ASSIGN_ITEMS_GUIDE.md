# Complete Guide: Assigning Items to Participants

## 📋 Full Flow Explained

### Step 1: Scan Receipt with OCR
```
1. Tap FAB button (bottom-right)
2. Select "OCR Expense"
3. Choose "Scan Receipt"
4. Pick "Choose from Gallery" or "Take Photo"
5. Select receipt image
6. Tap "Process Receipt"
7. OCR extracts:
   - Merchant: "Paul Bakery"
   - Items: 6 items (CAPPUCCINO, etc.)
   - Total: Rp 330,330
8. Tap "Split Bill"
```

### Step 2: SplitBill View Opens
```
✅ Items already populated from OCR:
   - CAPPUCCINO (Rp 45,000)
   - HAZELNUT CAPPUCCINO (Rp 50,000)
   - etc... (6 items total)

✅ Mode locked to "Itemized" (can't change)
```

---

## 👥 Step 3: Add Participants

### Option A: Manual Entry
```
1. Tap "Manual" button (top of Participants section)
2. Enter name: "Alice"
3. Tap "Add Participant"
4. Repeat for more people:
   - "Bob"
   - "Charlie"
```

### Option B: From Contacts
```
1. Tap "Contact" button
2. iOS Contacts picker opens
3. Select contacts you want
4. They're added as participants automatically
```

**Note:** You can mix both! Add some manually, some from contacts.

---

## 🎯 Step 4: Assign Items to Participants

This is the KEY step you asked about!

### Method 1: Via Item Row (Inline)

**Currently NOT available** - items show but can't be assigned inline.

### Method 2: Via "Add Item" Sheet (Recommended)

Wait, items from OCR are already added! But they're **NOT ASSIGNED** yet.

**Problem:** OCR items come in **unassigned**. You need to assign them!

---

## 🔧 Solution: Make Items Assignable

Currently, items from OCR are created like this:
```swift
items = receiptItems.map { item in
    SplitItem(
        name: item.name, 
        price: item.price, 
        qty: 1, 
        assigned: []  // ❌ EMPTY! No one assigned
    )
}
```

Users see items but can't assign them because:
1. ✅ Items are editable (tap pencil)
2. ❌ But no "Assign to..." button

---

## ✅ **The Fix: Add Assignment Button to Each Item**

I'll add a button to assign participants to each item.

### New Flow:
```
1. OCR populates 6 items
2. Each item shows:
   - Name, Price, Qty
   - ✏️ Edit button
   - 👥 "Assign People" button ← NEW!
   - 🗑️ Delete button

3. User taps "Assign People" on CAPPUCCINO
4. Sheet opens with participant list:
   ☐ Alice
   ☐ Bob  
   ☐ Charlie

5. User checks:
   ☑️ Alice
   ☑️ Bob

6. Taps "Save"
7. Item now shows:
   "For: Alice, Bob"

8. Repeat for all items
9. Once all items assigned → "Split & Save" enabled
```

---

## 🚀 Implementation

I'll add an "Assign" button to `EditableItemRow`:

```swift
// In EditableItemRow
Button {
    showAssignSheet = true
} label: {
    Image(systemName: "person.2.fill")
        .font(.caption)
        .foregroundStyle(.blue)
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .clipShape(Circle())
}
.sheet(isPresented: $showAssignSheet) {
    AssignParticipantsSheet(
        item: $item,
        participants: participants
    )
}
```

---

## 📱 Expected User Experience

### Current (Broken):
```
1. OCR scans receipt → ✅
2. Items populate → ✅
3. Add participants → ✅
4. Assign items → ❌ CAN'T!
5. Save → ❌ Disabled (items unassigned)
```

### After Fix:
```
1. OCR scans receipt → ✅
2. Items populate → ✅
3. Add participants → ✅
4. For each item, tap 👥 icon → ✅
5. Select who shares that item → ✅
6. Repeat for all items → ✅
7. All assigned → "Split & Save" enabled → ✅
8. Save → Debts created! → ✅
```

---

## 🔑 Key Points

### Why Items Start Unassigned:
- OCR doesn't know WHO ate WHAT
- App can't guess who ordered which item
- User MUST manually assign

### How Assignment Works:
1. Each item has `assigned: Set<UUID>`
2. This stores participant IDs
3. When calculating split:
   - Item cost ÷ number of people assigned
   - Each person pays their share

### Example:
```
CAPPUCCINO (Rp 45,000)
Assigned to: Alice, Bob

Calculation:
- Alice owes: Rp 22,500
- Bob owes: Rp 22,500
```

---

## 📝 Summary

**Your Question:** "gimana assign items ke participants"

**Answer:** 
1. Currently: **Can't!** Items from OCR have no assignment UI
2. Workaround: Delete OCR items, re-add manually via "Add Item"
3. Proper Fix: I'll add "Assign People" button to each item

Let me implement the fix now! 🚀
