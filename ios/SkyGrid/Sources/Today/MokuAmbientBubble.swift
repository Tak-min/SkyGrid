import SwiftUI

struct MokuAmbientBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SGFont.body(14))
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
            .accessibilityLabel("Moku says, \(text)")
            .accessibilityIdentifier("moku.ambientMessage")
            .allowsHitTesting(false)
    }
}

private struct MokuAmbientBubbleModifier: ViewModifier {
    let message: MokuAmbientMessage?
    let anchor: MokuAmbientMessage.Anchor
    let alignment: Alignment
    let offset: CGSize

    func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            if let message, message.anchor == anchor {
                MokuAmbientBubble(text: message.text)
                    .offset(offset)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .center)))
                    .zIndex(2)
            }
        }
    }
}

extension View {
    func mokuAmbientBubble(
        _ message: MokuAmbientMessage?,
        at anchor: MokuAmbientMessage.Anchor,
        alignment: Alignment,
        offset: CGSize = .zero
    ) -> some View {
        modifier(MokuAmbientBubbleModifier(message: message, anchor: anchor, alignment: alignment, offset: offset))
    }
}
