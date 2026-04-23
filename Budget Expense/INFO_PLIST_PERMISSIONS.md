# Info.plist Permission Keys - Complete Guide

## ⚠️ WAJIB DITAMBAHKAN KE INFO.PLIST

Tanpa keys ini, aplikasi akan **CRASH** saat request permission!

---

## Cara Menambahkan di Xcode

### Option 1: Via Xcode UI (RECOMMENDED)

1. **Buka project** di Xcode
2. **Select app target** di navigator kiri
3. Klik tab **"Info"**
4. Klik tombol **"+"** untuk add key
5. **Copy-paste nama key** dari list dibawah
6. **Paste value/description** yang sesuai

---

### Option 2: Edit Info.plist Langsung (Advanced)

1. **Right-click** `Info.plist` file
2. Pilih **"Open As"** → **"Source Code"**
3. **Paste semua XML** di bawah ini **INSIDE** tag `<dict>...</dict>`

```xml
<!-- Photo Library Permission -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Kami butuh akses ke galeri foto Anda untuk scan struk belanja menggunakan OCR</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Kami butuh akses untuk menyimpan foto struk ke galeri Anda</string>

<!-- Camera Permission -->
<key>NSCameraUsageDescription</key>
<string>Kami butuh akses kamera untuk foto struk belanja secara langsung</string>

<!-- Contacts Permission -->
<key>NSContactsUsageDescription</key>
<string>Kami butuh akses kontak untuk split bill dengan teman Anda</string>

<!-- Face ID / Touch ID Permission -->
<key>NSFaceIDUsageDescription</key>
<string>Kami menggunakan Face ID untuk mengamankan data keuangan Anda</string>
```

---

## Daftar Lengkap Keys (Copy-Paste Friendly)

### 1. Photo Library (Read & Write)

**Key**: `NSPhotoLibraryUsageDescription`  
**Value**: `Kami butuh akses ke galeri foto Anda untuk scan struk belanja menggunakan OCR`

**Key**: `NSPhotoLibraryAddUsageDescription`  
**Value**: `Kami butuh akses untuk menyimpan foto struk ke galeri Anda`

---

### 2. Camera

**Key**: `NSCameraUsageDescription`  
**Value**: `Kami butuh akses kamera untuk foto struk belanja secara langsung`

---

### 3. Contacts

**Key**: `NSContactsUsageDescription`  
**Value**: `Kami butuh akses kontak untuk split bill dengan teman Anda`

---

### 4. Face ID / Touch ID

**Key**: `NSFaceIDUsageDescription`  
**Value**: `Kami menggunakan Face ID untuk mengamankan data keuangan Anda`

---

## Verifikasi Sudah Benar

Setelah ditambahkan, Info.plist Anda harus terlihat seperti ini di Xcode:

```
Information Property List
  ├─ Privacy - Photo Library Usage Description
  │    "Kami butuh akses ke galeri foto..."
  ├─ Privacy - Photo Library Additions Usage Description
  │    "Kami butuh akses untuk menyimpan foto..."
  ├─ Privacy - Camera Usage Description
  │    "Kami butuh akses kamera..."
  ├─ Privacy - Contacts Usage Description
  │    "Kami butuh akses kontak..."
  └─ Privacy - Face ID Usage Description
       "Kami menggunakan Face ID..."
```

---

## Troubleshooting

### ❌ App Crash saat Request Permission

**Solusi**: Double-check semua keys sudah ada di Info.plist

### ❌ Permission Dialog Tidak Muncul

**Solusi**: 
1. Clean build folder (Cmd+Shift+K)
2. Delete app dari device/simulator
3. Rebuild & run

### ❌ Simulator: "This app does not have permission to access camera"

**Ini normal!** Simulator tidak punya kamera fisik. Test di **real device**.

---

## Testing Checklist

- [ ] Photo Library permission dialog muncul ✅
- [ ] Camera permission dialog muncul (device only) ✅
- [ ] Contacts permission dialog muncul ✅
- [ ] Face ID prompt muncul (device with Face ID) ✅
- [ ] App tidak crash saat request permission ✅

---

Generated: April 24, 2026
