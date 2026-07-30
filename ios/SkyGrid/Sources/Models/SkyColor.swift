import SwiftUI

/// A validated `#RRGGBB` sky color, as extracted from a morning photo.
struct SkyColor: Hashable, Sendable {
    let hex: String

    init?(hex: String) {
        guard Self.isValid(hex) else { return nil }
        self.hex = hex
    }

    /// Only for call sites that already hold a value known-valid at compile time
    /// (e.g. mock data, design tokens) — never for parsing untrusted input.
    init(uncheckedHex hex: String) {
        precondition(Self.isValid(hex), "invalid sky color hex: \(hex)")
        self.hex = hex
    }

    private static func isValid(_ hex: String) -> Bool {
        guard hex.count == 7, hex.hasPrefix("#") else { return false }
        return hex.dropFirst().allSatisfy(\.isHexDigit)
    }

    var color: Color {
        let r = UInt8(hex.dropFirst(1).prefix(2), radix: 16) ?? 0
        let g = UInt8(hex.dropFirst(3).prefix(2), radix: 16) ?? 0
        let b = UInt8(hex.dropFirst(5).prefix(2), radix: 16) ?? 0
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    /// Relative luminance (WCAG formula) — used to pick a readable ink color when text
    /// is drawn directly on top of an arbitrary sky color.
    var luminance: Double {
        func channel(_ hexPair: Substring) -> Double {
            let v = Double(UInt8(hexPair, radix: 16) ?? 0) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let r = channel(hex.dropFirst(1).prefix(2))
        let g = channel(hex.dropFirst(3).prefix(2))
        let b = channel(hex.dropFirst(5).prefix(2))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Black or white ink, whichever is legible against this sky color.
    var readableInk: Color {
        luminance > 0.5 ? .black : .white
    }
}
