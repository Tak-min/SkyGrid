import SwiftUI

/// Rendering helpers for showing arbitrary sky colors as UI backgrounds while keeping
/// text legible on top of them (the accent color changes every day, so contrast can't
/// be a fixed design-time choice — see `SkyColor.readableInk`).
extension SkyColor {
    /// A soft vertical gradient from this color toward its own shadow, used behind
    /// the shutter button and Today-screen hero — mirrors the mockup's
    /// `--sky-top`/`--sky-mid`/`--sky-bot` gradient bands.
    var ambientGradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.85), color, color.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
