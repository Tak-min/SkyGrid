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
    /// The lighter end of the card's ground gradient. A flat fill made the 1080×1920
    /// canvas read as an empty rectangle that content had been placed on; a shallow
    /// top-leading-to-bottom-trailing ramp gives it a light direction, which is the
    /// cheapest way to make a dark card look composed rather than unfinished.
    static let groundTop = Color(fixedHex: "#111A28")
    static let ink = Color.white
    static let ink2 = Color.white.opacity(0.62)

    /// Secondary text on the export cards. A fixed blue-grey rather than translucent
    /// white (`ink2`), because these now sit on `surface`/`surfaceRaised` panels as
    /// well as on the ground, and a translucent ink changes value with whatever is
    /// behind it — the panels made the same label render as two different greys.
    static let inkMuted = Color(fixedHex: "#A7B0BC")

    /// Panels. `surface` is the recessed field the photo mosaic sits in; the mosaic
    /// needs a bounded edge or a sparse year reads as tiles scattered on nothing.
    /// `surfaceRaised` is the footer ticket, which has to sit *above* the ground.
    static let surface = Color(fixedHex: "#111823")
    static let surfaceRaised = Color(fixedHex: "#182231")

    /// The 2px edge on every panel and photo tile. At story-tray scale this is what
    /// keeps adjacent sky photos from bleeding into one another.
    static let hairline = Color(fixedHex: "#2A3748")

    /// Un-captured days in the year map. Dim enough to read as an unfilled slot, lit
    /// enough that the 31×12 calendar shape survives as a field of dots.
    static let guide = Color(fixedHex: "#39485B")

    /// The ground both cards are drawn on. Shared rather than declared per card, so
    /// the year card and the morning card cannot drift apart — a viewer who sees one
    /// of each from two different people has to recognise them as the same app.
    static let groundGradient = LinearGradient(
        colors: [groundTop, ground],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The canonical listing link. Points straight at the App Store rather than the
    /// marketing site — a share card's job is a one-hop install, not a second
    /// landing page. Shared by every export surface so the cards can never drift.
    ///
    /// The cards stopped *drawing* this as a QR on 2026-08-11 (see
    /// `Grid/AppStoreIdentityExportView.swift` for why a QR cannot work on a Story).
    /// It is kept because it is still the one true listing URL for any surface that
    /// needs to hand someone the app — share text, the invite web page, or an
    /// on-screen code meant to be scanned by a *second* device, in person.
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
