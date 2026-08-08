import SwiftUI

/// Design tokens for artifacts that leave the app — share cards and the milestone
/// moment. Deliberately a *separate* namespace from `SGT`, because they encode the
/// opposite intent.
///
/// `SGT` is the quiet ritual surface: warm, low-contrast, appropriate for a
/// half-awake 6am capture. `SGExport` is the loud surface: a fixed dark ground so
/// the user's own sky colours are the only chroma, and so the card survives being
/// rendered ~120px wide in an Instagram/TikTok Story tray.
///
/// **Boundary rule:** `SGExport` may only be referenced from `Grid/*ExportView.swift`,
/// `Grid/ShareCardRenderer.swift`, and `Milestone/*`. It must never reach the
/// Today/Camera/Grid screens — that is what keeps the ritual calm while the artifact
/// is loud.
///
/// Check it (from `ios/SkyGrid`; comment-only mentions are excluded):
///
///     grep -rn 'SGExport\.' Sources/ | grep -v ': *//'
///
/// Anything outside those three locations is a violation. `SkyLoudButtonStyle` lives
/// in `Milestone/` rather than `DesignSystem/` for exactly this reason — a shared
/// button style reading these tokens was reachable from every screen, which is the
/// door this rule exists to keep shut.
///
/// Every value here is **non-adaptive** on purpose. `SGT`'s tokens resolve through
/// `Color(UIColor { traits in ... })` (`Theme.swift`), and `ImageRenderer` resolves
/// such colours against an unpinned trait environment — which made the exported
/// card's ground depend on the exporting device's appearance rather than being a
/// fixed brand artifact.
enum SGExport {
    /// Pre-dawn near-black. Blue-tinted rather than pure black, matching the rule
    /// that a dark surface should read as a chosen colour, not an absent one.
    static let ground = Color(fixedHex: "#0B0E14")
    static let ink = Color.white
    static let ink2 = Color.white.opacity(0.62)
    static let ink3 = Color.white.opacity(0.34)

    /// Grid cells inside an export. `SGT.ghost`/`SGT.fill` are tuned for the warm
    /// in-app background and turn to mud on the dark ground.
    ///
    /// Raised 0.06 → 0.09 on 2026-08-08: at 0.06 the un-posted cells all but vanished
    /// once the card was scaled to a story-tray thumbnail, so the mosaic lost the
    /// grid it is supposed to read as and became a few floating colour marks. The
    /// empty cells have to stay legible enough to be the *shape* the posted days sit
    /// in, while still clearly receding behind them.
    static let cellEmpty = Color.white.opacity(0.09)
    static let cellPostedNoThumb = Color.white.opacity(0.14)

    /// The link a QR scan or a typed URL both land on. Points straight at the App
    /// Store listing rather than the marketing site — a share card's job is a
    /// one-hop install, not a second landing page. Shared by every export surface
    /// so the two cards can never drift apart.
    static let downloadURLString = "https://apps.apple.com/us/app/sky-grid-morning-wake/id6796222704"
}

extension Color {
    /// Trusted-input hex initializer for compile-time-known export tokens only —
    /// never for parsing user-facing sky-color data (that's `SkyColor`).
    init(fixedHex hex: String) {
        let r = UInt8(hex.dropFirst(1).prefix(2), radix: 16) ?? 0
        let g = UInt8(hex.dropFirst(3).prefix(2), radix: 16) ?? 0
        let b = UInt8(hex.dropFirst(5).prefix(2), radix: 16) ?? 0
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
