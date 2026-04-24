import SwiftUI

// MARK: - Shared Colors

extension Color {
    static let neonGreen = Color(red: 0.20, green: 0.90, blue: 0.50)
    static let neonRed   = Color(red: 1.00, green: 0.30, blue: 0.30)
    static let appBg     = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let glassText = Color(white: 0.55)
    static let dimText   = Color(white: 0.35)
    
    // MARK: - Hex Initialization & Conversion
    
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    var hex: String {
        let components = UIColor(self).cgColor.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0

        let hexString = String(format: "#%02lX%02lX%02lX",
                               lroundf(Float(r * 255)),
                               lroundf(Float(g * 255)),
                               lroundf(Float(b * 255)))
        return hexString
    }
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
