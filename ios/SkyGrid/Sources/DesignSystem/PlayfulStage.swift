import SwiftUI

/// Shared material for settled screens. The canvas follows system appearance; Moku
/// and the two brand accents supply character without ambient decoration.
struct PlayfulStageBackdrop: View {
    var accent: Color = SGT.accent

    var body: some View {
        SGT.background
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A compact, decorative companion for non-camera screens. Moku remains hidden
/// from VoiceOver and never conveys private buddy state or replaces navigation.
struct MokuScreenMark: View {
    let state: MokuState
    var side: CGFloat = 62
    var caption: String? = nil

    var body: some View {
        HStack(spacing: SGSpacing.sm) {
            MokuView(state: state, side: side)
            if let caption {
                Text(caption)
                    .font(SGFont.caption(12))
                    .foregroundStyle(SGT.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Raised pixel-edged action material, intentionally unlike the former generic
/// card stack. Use for a meaningful object or action, never just to decorate copy.
struct PlayfulSurfaceModifier: ViewModifier {
    var accent: Color = SGT.accent

    func body(content: Content) -> some View {
        content
            .background(SGT.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(accent.opacity(0.42), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
    }
}

extension View {
    func playfulSurface(accent: Color = SGT.accent) -> some View {
        modifier(PlayfulSurfaceModifier(accent: accent))
    }
}

/// A single screen-entry gesture used by settled screens. It is intentionally
/// modest: Moku supplies character; content should not fly around independently.
struct PlayfulEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: reduceMotion || appeared ? 0 : 14)
            .onAppear {
                if reduceMotion || !MokuMotionPolicy.animationsEnabled {
                    appeared = true
                } else {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    func playfulEntrance() -> some View {
        modifier(PlayfulEntranceModifier())
    }
}
