import SwiftUI
import UIKit

/// Sky Grid design tokens. Values are pulled verbatim from
/// `design/screens-mockup.html` (the founder-approved visual reference; see
/// VISION.md §6) — do not re-derive these from prose descriptions elsewhere.
///
/// The app itself has no fixed brand color: the day's extracted `SkyColor` is the
/// dynamic accent everywhere. `SGT` only defines the neutral surface/ink tokens that
/// the sky color sits on top of.
enum SGT {
    /// Warm white background (light) / pre-dawn deep navy (dark) — never pure black.
    static let background = adaptive(light: "#FAF7F2", dark: "#12141A")
    static let ink = adaptive(light: "#1A1A18", dark: "#F2F3F5")
    static let ink2 = adaptive(light: "#6E6A62", dark: "#8B919C")
    static let ink3 = adaptive(light: "#A8A399", dark: "#565C68")
    static let rule = adaptive(light: "#E6E0D6", dark: "#21242C")
    static let fill = adaptive(light: "#EFEAE1", dark: "#191C23")

    /// The "quiet grey" a blank Sky Grid cell renders as — for a day with no post.
    static let ghost = adaptive(
        light: Color(hex: "#1A1A18").opacity(0.075),
        dark: Color(hex: "#E4E9F0").opacity(0.24)
    )
    static let ghostFaint = adaptive(
        light: Color(hex: "#1A1A18").opacity(0.032),
        dark: Color(hex: "#E4E9F0").opacity(0.075)
    )

    private static func adaptive(light lightHex: String, dark darkHex: String) -> Color {
        adaptive(light: Color(hex: lightHex), dark: Color(hex: darkHex))
    }

    private static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

private extension Color {
    /// Trusted-input hex initializer for compile-time-known design tokens only —
    /// never for parsing user-facing sky-color data (that's `SkyColor`).
    init(hex: String) {
        let r = UInt8(hex.dropFirst(1).prefix(2), radix: 16) ?? 0
        let g = UInt8(hex.dropFirst(3).prefix(2), radix: 16) ?? 0
        let b = UInt8(hex.dropFirst(5).prefix(2), radix: 16) ?? 0
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
