import SwiftUI

// MARK: - Shared Colors

extension Color {
    static let neonGreen = Color(red: 0.20, green: 0.90, blue: 0.50)
    static let neonRed   = Color(red: 1.00, green: 0.30, blue: 0.30)
    static let appBg     = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let glassText = Color(white: 0.55)
    static let dimText   = Color(white: 0.35)
}

// SE-0299: allow .glassText / .dimText / .neonGreen / .neonRed / .appBg
// in any ShapeStyle-constrained context (e.g. foregroundStyle)
extension ShapeStyle where Self == Color {
    static var neonGreen: Color { .init(red: 0.20, green: 0.90, blue: 0.50) }
    static var neonRed:   Color { .init(red: 1.00, green: 0.30, blue: 0.30) }
    static var appBg:     Color { .init(red: 0.04, green: 0.04, blue: 0.05) }
    static var glassText: Color { .init(white: 0.55) }
    static var dimText:   Color { .init(white: 0.35) }
}

// MARK: - Shared Formatters

func formatIDR(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle       = .decimal
    f.groupingSeparator = "."
    f.maximumFractionDigits = 0
    return "Rp \(f.string(from: NSNumber(value: value)) ?? "\(Int(value))")"
}

func formatCurrency(_ value: Double, currency: Currency) -> String {
    currency == .idr ? formatIDR(value) : String(format: "$%.2f", value)
}
