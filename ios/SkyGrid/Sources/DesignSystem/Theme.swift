import SwiftUI
import UIKit

/// Sky Grid design tokens.
///
/// 2026-09-06 owner directive: the calm/quiet "warm paper" theme is retired for
/// every screen, not only the camera. The camera composition (`CameraStage`,
/// `CameraStageColor`) and Moku's reward moment were the part of the playful
/// redesign that actually landed — a near-black stage, high-contrast white
/// controls, and one warm accent — and the owner asked for that exact language
/// (ground, ink, accent, and Moku's presence) to be the app's single visual
/// identity everywhere, not a mode confined to capture. `SGT` is therefore no
/// longer light/dark-adaptive: one dark ground, always, matching
/// `CameraStageColor.background`.
///
/// The day's extracted `SkyColor` remains an additional, secondary accent inside
/// content that legitimately represents a real sky (grid tiles, the live swatch).
/// `SGT.accent`/`accentSecondary` are the two fixed playful accents from
/// `DESIGN.md` (Dawn Spark / Open Sky) used for actions, active states, and Moku.
enum SGT {
    /// The one ground color for every screen — identical to the camera stage's,
    /// so the capture screen no longer looks like a different app.
    static let background = Color(hex: "#080A0F")
    /// A very slightly lifted surface for cards/sheets sitting on `background`,
    /// so content doesn't disappear into pure black.
    static let surface = Color(hex: "#14171F")
    static let ink = Color(hex: "#F5F6F8")
    static let ink2 = Color.white.opacity(0.62)
    static let ink3 = Color.white.opacity(0.42)
    static let rule = Color.white.opacity(0.14)
    static let fill = Color.white.opacity(0.08)

    /// Dawn Spark — the primary playful accent (`DESIGN.md`). Used for the one
    /// dominant action per screen (capture, primary CTA, active tab/selection)
    /// and Moku's spark. Never a substitute for real sky color.
    static let accent = Color(hex: "#FF6846")
    /// Open Sky — secondary active/selected state, used more sparingly than
    /// `accent` so the app keeps one dominant color per screen.
    static let accentSecondary = Color(hex: "#58C7F3")

    /// The "quiet grey" a blank Sky Grid cell renders as — for a day with no post.
    static let ghost = Color.white.opacity(0.10)
    static let ghostFaint = Color.white.opacity(0.05)
}

extension Color {
    /// Trusted-input hex initializer for compile-time-known design tokens only —
    /// never for parsing user-facing sky-color data (that's `SkyColor`).
    init(hex: String) {
        let r = UInt8(hex.dropFirst(1).prefix(2), radix: 16) ?? 0
        let g = UInt8(hex.dropFirst(3).prefix(2), radix: 16) ?? 0
        let b = UInt8(hex.dropFirst(5).prefix(2), radix: 16) ?? 0
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
