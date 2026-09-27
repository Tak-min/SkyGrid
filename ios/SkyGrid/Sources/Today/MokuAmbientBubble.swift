import SwiftUI

struct MokuAmbientBubble: View {
    let text: String
    /// Caps Dynamic Type growth for callers that overlay this bubble on top of
    /// other content (the Today card) at a fixed position — an uncapped font
    /// there grows tall enough to cover the content behind it. Pass `nil` (the
    /// default) for callers that instead let the bubble flow in normal layout,
    /// where uncapped growth is safe because it just pushes siblings aside.
    var maximumFontScale: CGFloat? = nil

    var body: some View {
        Text(text)
            .font(SGFont.body(14, maximumScale: maximumFontScale))
            .foregroundStyle(SGT.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SGSpacing.md)
            .padding(.vertical, SGSpacing.sm)
            .frame(maxWidth: 230, alignment: .leading)
            .background(SGT.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SGT.ink.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: SGT.ink.opacity(0.12), radius: 12, y: 5)
            .accessibilityLabel(String(format: L10n.string("moku.saysAccessibility"), text))
            .accessibilityIdentifier("moku.ambientMessage")
            .allowsHitTesting(false)
    }
}
