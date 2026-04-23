//
//  OCRDataManager.swift
//  Budget Expense
//
//  Manages OCR result state across the app
//

import SwiftUI
import Combine

@MainActor
@Observable
class OCRDataManager {
    private(set) var pendingOCRResult: OCRResult?
    
    /// Store OCR result for later consumption
    func setPendingResult(_ result: OCRResult) {
        pendingOCRResult = result
        print("📦 OCRDataManager: Stored OCR result")
        print("   - Merchant: \(result.merchant ?? "Unknown")")
        print("   - Amount: \(result.totalAmount ?? 0)")
        print("   - Items: \(result.receiptItems?.count ?? 0)")
    }
    
    /// Retrieve and clear the pending OCR result
    func consumePendingResult() -> OCRResult? {
        guard let result = pendingOCRResult else {
            print("📦 OCRDataManager: No pending result to consume")
            return nil
        }
        
        pendingOCRResult = nil
        print("📦 OCRDataManager: Consumed and cleared OCR result")
        return result
    }
    
    /// Clear pending result without consuming it
    func clearPendingResult() {
        if pendingOCRResult != nil {
            print("📦 OCRDataManager: Cleared pending OCR result")
            pendingOCRResult = nil
        }
    }
    
    /// Check if there's a pending result
    var hasPendingResult: Bool {
        pendingOCRResult != nil
    }
}

// MARK: - Environment Key

private struct OCRDataManagerKey: EnvironmentKey {
    static let defaultValue = OCRDataManager()
}

extension EnvironmentValues {
    var ocrDataManager: OCRDataManager {
        get { self[OCRDataManagerKey.self] }
        set { self[OCRDataManagerKey.self] = newValue }
    }
}
