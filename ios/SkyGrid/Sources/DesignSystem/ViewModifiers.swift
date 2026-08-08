import SwiftUI

/// The one shared "quiet card" surface used everywhere a grouped panel is needed
/// (buddy rows, settings sections, the week-rhythm strip). Centralized so hairline
/// stroke opacity / corner radius never drifts between screens — see this machine's
/// iOS UI Design Quality rule against copy-pasted glass/card styling.
struct QuietCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(SGT.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(SGT.rule, lineWidth: 1)
            )
    }
}

extension View {
    func quietCard() -> some View {
        modifier(QuietCardModifier())
    }
}

/// Routes every motion call site through one place so Reduce Motion is honored
/// consistently instead of being re-checked (or forgotten) at each usage.
struct SkyAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    func skyAnimation<Value: Equatable>(_ animation: Animation?, value: Value) -> some View {
        modifier(SkyAnimationModifier(animation: animation, value: value))
    }
}

/// Large, full-width actions are reserved for an irreversible step in the morning
/// flow (open camera / enable alarm / confirm photo). Keeping the style centralized
/// also keeps hit areas at or above Apple's 44pt minimum.
struct SkyPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SGFont.body(16))
            // A disabled primary action is styled as an *unfilled* control rather
            // than a faded solid one. Fading the filled ink capsule to 42% produced
            // mid-grey-on-warm-fill, which reads as "already tapped" or "broken"
            // instead of "you haven't filled this in yet" (seen on Add Buddy's
            // "Send request" before a handle is entered).
            .foregroundStyle(isEnabled ? SGT.background : SGT.ink3)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, SGSpacing.lg)
            .background(isEnabled ? SGT.ink : SGT.fill, in: Capsule())
            .overlay {
                if !isEnabled {
                    Capsule().strokeBorder(SGT.rule, lineWidth: 1)
                }
            }
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity)
            .opacity(isEnabled && configuration.isPressed ? 0.72 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SkySecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SGFont.body(16))
            .foregroundStyle(SGT.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, SGSpacing.lg)
            .background(SGT.fill, in: Capsule())
            .overlay(Capsule().strokeBorder(SGT.rule, lineWidth: 1))
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity)
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.42)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
