import SwiftUI
import UIKit

/// Sky Grid design tokens.
///
/// The settled app follows the system's light or dark appearance while the camera
/// and reward retain their purposeful near-black stage. Neither appearance revives
/// the old warm-paper/editorial UI.
///
/// The day's extracted `SkyColor` remains an additional, secondary accent inside
/// content that legitimately represents a real sky (grid tiles, the live swatch).
/// `SGT.accent`/`accentSecondary` are the two fixed playful accents from
/// `DESIGN.md` (Dawn Spark / Open Sky) used for actions, active states, and Moku.
enum SGT {
    static let background = Color.adaptive(light: "#FFFFFF", dark: "#080A0F")
    static let surface = Color.adaptive(light: "#F2F4F7", dark: "#14171F")
    static let ink = Color.adaptive(light: "#15171C", dark: "#F5F6F8")
    static let ink2 = Color.adaptive(light: "#4D5561", dark: "#B5BAC4")
    static let ink3 = Color.adaptive(light: "#737B87", dark: "#7D8490")
    static let rule = Color.adaptive(light: "#D8DDE4", dark: "#303640")
    static let fill = Color.adaptive(light: "#E7EBF0", dark: "#20242C")

    /// Dawn Spark — the primary playful accent (`DESIGN.md`). Used for the one
    /// dominant action per screen (capture, primary CTA, active tab/selection)
    /// and Moku's spark. Never a substitute for real sky color.
    static let accent = Color(hex: "#FF6846")
    /// Open Sky — secondary active/selected state, used more sparingly than
    /// `accent` so the app keeps one dominant color per screen.
    static let accentSecondary = Color(hex: "#58C7F3")
    static let accentInk = Color(hex: "#111318")

    /// The "quiet grey" a blank Sky Grid cell renders as — for a day with no post.
    static let ghost = Color.adaptive(light: "#D7DCE3", dark: "#282D36")
    static let ghostFaint = Color.adaptive(light: "#E9ECF0", dark: "#171B22")
}

extension Color {
    /// Trusted static color pair used only by design tokens.
    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Trusted-input hex initializer for compile-time-known design tokens only —
    /// never for parsing user-facing sky-color data (that's `SkyColor`).
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: String) {
        let r = UInt8(hex.dropFirst(1).prefix(2), radix: 16) ?? 0
        let g = UInt8(hex.dropFirst(3).prefix(2), radix: 16) ?? 0
        let b = UInt8(hex.dropFirst(5).prefix(2), radix: 16) ?? 0
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}
