import SwiftUI

/// A buddy's tile shows only their sky color, never the photo itself, until the
/// `BuddyRevealGate` opens (viewer has posted today). Even before reveal, the color
/// alone is visible at reduced opacity — VISION's "the color peeks through first"
/// idea (blueprint §4 Today/BuddyTile).
struct BuddyTile: View {
    let displayName: String
    let hasPostedToday: Bool
    let isRevealed: Bool
    let skyColor: SkyColor?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(tileFill)
                .frame(width: 58, height: 58)
                .overlay(Circle().strokeBorder(SGT.ink.opacity(0.14), lineWidth: 1))
                .scaleEffect(isRevealed && hasPostedToday ? 1 : 0.92)
            Text(caption)
                .font(SGFont.caption(11))
                .foregroundStyle(SGT.ink3)
                .lineLimit(1)
        }
        .animation(reduceMotion ? nil : SGMotion.settle, value: isRevealed)
    }

    private var tileFill: AnyShapeStyle {
        guard hasPostedToday, let skyColor else {
            return AnyShapeStyle(SGT.ghostFaint)
        }
        return isRevealed ? AnyShapeStyle(skyColor.color) : AnyShapeStyle(skyColor.color.opacity(0.35))
    }

    private var caption: String {
        hasPostedToday ? displayName : "\(displayName) · not yet"
    }
}
