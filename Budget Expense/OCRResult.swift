// OCRResult.swift
import Foundation

struct ReceiptItem: Identifiable, Codable {
    let id = UUID()
    let name: String
    let price: Double
    
    init(name: String, price: Double) {
        self.name = name
        self.price = price
    }
}

struct OCRResult: Identifiable, Codable {
    let id = UUID()
    let text: String
    var amount: Decimal?
    var date: Date?
    var merchant: String?
    var items: [String]?
    // OCR receipt scan fields
    var totalAmount: Double?
    var currency: String?
    var receiptItems: [ReceiptItem]?
}
