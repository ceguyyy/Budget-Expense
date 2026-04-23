import SwiftUI
import UIKit

enum PhotoSource: Identifiable {
    case camera
    case gallery
    
    var id: Int {
        switch self {
        case .camera: return 0
        case .gallery: return 1
        }
    }
}

struct OCRActionView: View {
    @Binding var showSplitBill: Bool
    @Binding var showUniversalAdd: Bool
    @Binding var ocrResult: OCRResult?
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var activeSheet: PhotoSource?
    @State private var showPhotoSourcePicker = false  // ✅ New: Action sheet
    @State private var capturedImage: UIImage?
    
    // New state to track scan completion
    @State private var scanCompleted = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Processing receipt...")
                            .tint(.white)
                            .foregroundStyle(.white)
                    } else if let errorMessage = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.neonRed)
                            
                            Text("Error")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            Text(errorMessage)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Try Again") {
                                self.errorMessage = nil
                                activeSheet = .camera
                            }
                            .buttonStyle(.glassProminent)
                        }
                    } else if scanCompleted, let result = ocrResult {
                        // Show success with action choices
                        VStack(spacing: 24) {
                            // Success header
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.neonGreen)
                                
                                Text("Receipt Scanned Successfully!")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                
                                Text("\(result.merchant ?? "Unknown") - \(result.currency ?? "USD") \(String(format: "%.2f", result.totalAmount ?? 0))")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            
                            // Scanned items preview
                            if let items = result.receiptItems, !items.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Items Found: \(items.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(.glassText)
                                    
                                    ForEach(items.prefix(5)) { item in
                                        HStack {
                                            Text(item.name)
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text("\(result.currency ?? "USD") \(String(format: "%.2f", item.price))")
                                                .font(.caption)
                                                .foregroundStyle(.glassText)
                                        }
                                    }
                                    
                                    if items.count > 5 {
                                        Text("+ \(items.count - 5) more items...")
                                            .font(.caption)
                                            .foregroundStyle(.glassText)
                                    }
                                }
                                .padding()
                                .glassEffect(in: .rect(cornerRadius: 12))
                            }
                            
                            Text("What would you like to do with this receipt?")
                                .font(.subheadline)
                                .foregroundStyle(.glassText)
                                .multilineTextAlignment(.center)
                            
                            // Action buttons
                            VStack(spacing: 12) {
                                Button {
                                    openAddExpense()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add as Expense")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                }
                                .buttonStyle(.glassProminent)
                                
                                Button {
                                    openSplitBill()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.2.fill")
                                        Text("Split Bill")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                }
                                .buttonStyle(.glassProminent)
                                
                                Menu {
                                    Button {
                                        scanCompleted = false
                                        ocrResult = nil
                                        capturedImage = nil
                                        activeSheet = .gallery
                                        
                                    } label: {
                                        Label("Take Photo", systemImage: "camera.fill")
                                    }
                                    
                                    Button {
                                        scanCompleted = false
                                        ocrResult = nil
                                        capturedImage = nil
                                        activeSheet = .gallery
                                    } label: {
                                        Label("Choose from Gallery", systemImage: "photo.on.rectangle")
                                    }
                                } label: {
                                    Text("Scan Another Receipt")
                                        .foregroundStyle(.glassText)
                                        .font(.subheadline)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                        }
                        .padding()
                    } else if let image = capturedImage {
                        VStack(spacing: 16) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                            
                            Button {
                                processImage(image)
                            } label: {
                                HStack(spacing: 10) {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "doc.text.viewfinder")
                                    }
                                    
                                    Text(isLoading ? "Processing..." : "Scan Receipt")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.glassProminent)
                            .disabled(isLoading)
                            .padding(.horizontal, 20)
                            
                            
                            HStack(spacing: 12) {
                                Button {
                                    capturedImage = nil
                                    activeSheet = .camera
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "camera.fill")
                                        Text("Camera")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.glassProminent)
                                
                                
                                Button {
                                    capturedImage = nil
                                    activeSheet = .gallery
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "photo.on.rectangle")
                                        Text("Gallery")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.glassProminent)
                                .glassEffect(.clear)
                                
                            }
                            .padding(.horizontal, 20)
                        }
                    } else {
                        VStack(spacing: 24) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 80))
                                .foregroundStyle(.neonGreen)
                            
                            Text("Scan a Receipt")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            Text("Take a photo or select from your gallery to automatically extract transaction details.")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Button {
                                showPhotoSourcePicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.viewfinder")
                                    Text("Scan Receipt")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                            }
                            .buttonStyle(.glassProminent)
                            .padding(.horizontal, 40)
                           
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("OCR Scanner")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.glassText)
                }
            }
            .fullScreenCover(item: $activeSheet) { source in
                switch source {
                case .camera:
                    CameraView(capturedImage: $capturedImage)
                        .ignoresSafeArea()
                    
                case .gallery:
                    ImagePickerView(capturedImage: $capturedImage)
                        .ignoresSafeArea()
                }
            }
            
           
            
            // ✅ Action sheet to choose Camera or Gallery
            .confirmationDialog("Scan Receipt", isPresented:  $showPhotoSourcePicker, titleVisibility: .visible) {
                
                Button("Take Photo") {
                    #if targetEnvironment(simulator)
                    // Simulator → langsung ke gallery
                    activeSheet = .gallery
                    #else
                    activeSheet = .camera
                    #endif
                }
                
                Button("Choose from Gallery") {
                    activeSheet = .gallery
                }
                
                Button("Cancel", role: .cancel) {}
                
            } message: {
                Text("Select a photo source to scan your receipt")
            }
        }
    }
    
    @Environment(\.dismiss) private var dismiss
    
    private func processImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process image"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let jsonString = try await VertexAIService.scanReceipt(imageData: imageData)
                
                // Print raw response for debugging
                print("📄 Raw OCR response: \(jsonString)")
                
                // Try to extract JSON from the response - handle possible markdown wrapping
                var cleanedString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove markdown code block if present
                if cleanedString.hasPrefix("```json") {
                    cleanedString = String(cleanedString.dropFirst(7))
                    if let endIndex = cleanedString.range(of: "```")?.lowerBound {
                        cleanedString = String(cleanedString[..<endIndex])
                    }
                } else if cleanedString.hasPrefix("```") {
                    cleanedString = String(cleanedString.dropFirst(3))
                    if let endIndex = cleanedString.range(of: "```")?.lowerBound {
                        cleanedString = String(cleanedString[..<endIndex])
                    }
                }
                
                cleanedString = cleanedString.trimmingCharacters(in: .whitespacesAndNewlines)
                
                print("📄 Cleaned JSON: \(cleanedString)")
                
                guard let data = cleanedString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    await MainActor.run {
                        errorMessage = "Failed to parse receipt data: \(cleanedString.prefix(200))"
                        isLoading = false
                    }
                    return
                }
                
                let merchant = json["merchant"] as? String ?? "Unknown Merchant"
                let dateStr = json["date"] as? String ?? ""
                let totalAmount = json["total_amount"] as? Double ?? 0.0
                let currency = json["currency"] as? String ?? "USD"
                
                var items: [ReceiptItem] = []
                if let itemArray = json["items"] as? [[String: Any]] {
                    for item in itemArray {
                        let name = item["name"] as? String ?? ""
                        let price = item["price"] as? Double ?? 0.0
                        items.append(ReceiptItem(name: name, price: price))
                    }
                }
                
                // Parse date string - handle multiple date formats
                var date: Date = Date() // Default to today
                if !dateStr.isEmpty {
                    print("📅 Parsing date string: '\(dateStr)'")
                    
                    // Try simple ISO8601 date format first (yyyy-MM-dd)
                    let simpleISO = ISO8601DateFormatter()
                    simpleISO.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                    if let parsedDate = simpleISO.date(from: dateStr) {
                        date = parsedDate
                        print("📅 ✅ Parsed with ISO8601 (simple): \(date)")
                    } else {
                        // Try ISO8601 with time
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate]
                        if let parsedDate = isoFormatter.date(from: dateStr) {
                            date = parsedDate
                            print("📅 ✅ Parsed with ISO8601 (with time): \(date)")
                        } else {
                            // Try all the date formatters
                            let dateFormatters: [DateFormatter] = [
                                { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }(),
                                { let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd"; return f }(),
                                { let f = DateFormatter(); f.dateFormat = "MM/dd/yyyy"; return f }(),
                                { let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f }(),
                                { let f = DateFormatter(); f.dateFormat = "MMMM d, yyyy"; return f }(),
                                { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f }(),
                                { let f = DateFormatter(); f.dateFormat = "d MMMM yyyy"; return f }(),
                                { let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f }()
                            ]
                            
                            var foundDate = false
                            for formatter in dateFormatters {
                                if let parsedDate = formatter.date(from: dateStr) {
                                    date = parsedDate
                                    print("📅 ✅ Parsed with DateFormatter (\(formatter.dateFormat ?? "unknown")): \(date)")
                                    foundDate = true
                                    break
                                }
                            }
                            
                            if !foundDate {
                                print("📅 ⚠️ Failed to parse date, using today's date")
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    let result = OCRResult(
                        text: "Scanned receipt from \(merchant)",
                        amount: Decimal(totalAmount),
                        date: date,
                        merchant: merchant,
                        items: items.map { $0.name },
                        totalAmount: totalAmount,
                        currency: currency,
                        receiptItems: items
                    )
                    ocrResult = result
                    
                    isLoading = false
                    scanCompleted = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func openAddExpense() {
        print("🔵 OCRActionView: openAddExpense called")
        print("   - ocrResult is: \(ocrResult != nil ? "NOT NIL" : "NIL")")
        if let result = ocrResult {
            print("   - Merchant: \(result.merchant ?? "nil")")
            print("   - Amount: \(result.totalAmount ?? 0)")
            print("   - Date: \(result.date?.description ?? "nil")")
            print("   - Items: \(result.receiptItems?.count ?? 0)")
            
            // ✅ Ensure OCR data is saved to UserDefaults BEFORE dismissing
            if let encoded = try? JSONEncoder().encode(result) {
                UserDefaults.standard.set(encoded, forKey: "pending_ocr_result")
                print("🔵 OCRActionView: ✅ Saved OCR data to UserDefaults before dismiss")
            }
        }
        
        // Dismiss first, then trigger the sheet on next run loop
        dismiss()
        print("🔵 OCRActionView: Called dismiss()")
        
        // Delay setting showUniversalAdd to ensure dismiss completes first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showUniversalAdd = true
            print("🔵 OCRActionView: Set showUniversalAdd = true (delayed)")
        }
    }
    
    private func openSplitBill() {
        print("🟢 OCRActionView: openSplitBill called")
        print("   - ocrResult is: \(ocrResult != nil ? "NOT NIL" : "NIL")")
        if let result = ocrResult {
            print("   - Merchant: \(result.merchant ?? "nil")")
            print("   - Amount: \(result.totalAmount ?? 0)")
            print("   - Items: \(result.receiptItems?.count ?? 0)")
            
            // ✅ Ensure OCR data is saved to UserDefaults BEFORE dismissing
            if let encoded = try? JSONEncoder().encode(result) {
                UserDefaults.standard.set(encoded, forKey: "pending_ocr_result")
                print("🟢 OCRActionView: ✅ Saved OCR data to UserDefaults before dismiss")
            }
        }
        
        // Dismiss first, then trigger the sheet on next run loop
        dismiss()
        print("🟢 OCRActionView: Called dismiss()")
        
        // Delay setting showSplitBill to ensure dismiss completes first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showSplitBill = true
            print("🟢 OCRActionView: Set showSplitBill = true (delayed)")
        }
    }
}

// MARK: - Camera View (SwiftUI wrapper for UIImagePickerController)

struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        
        // Check if camera is available
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            print("⚠️ Camera is not available on this device/simulator")
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            print("📸 Camera: Photo captured")
            
            if let image = info[.originalImage] as? UIImage {
                print("📸 Camera: Successfully captured image of size \(image.size)")
                parent.capturedImage = image
            } else {
                print("⚠️ Camera: Failed to extract image from info dictionary")
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("📸 Camera: User cancelled")
            parent.dismiss()
        }
    }
}

// MARK: - Image Picker View (Gallery)

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        
        // Check if photo library is available
        if !UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            print("⚠️ Photo library is not available on this device")
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            print("📸 Image picker: Image selected")
            
            if let image = info[.originalImage] as? UIImage {
                print("📸 Image picker: Successfully captured image of size \(image.size)")
                parent.capturedImage = image
            } else {
                print("⚠️ Image picker: Failed to extract image from info dictionary")
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("📸 Image picker: User cancelled")
            parent.dismiss()
        }
    }
}

#Preview {
    OCRActionView(
        showSplitBill: .constant(false),
        showUniversalAdd: .constant(false),
        ocrResult: .constant(nil)
    )
}
