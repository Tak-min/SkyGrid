import SwiftUI

/// The inverse of `SkyPrimaryButtonStyle`, for the one place the app has a dark
/// ground: the milestone moment. Reusing the primary style there would render ink
/// on `SGT.background`, i.e. near-black on near-black.
///
/// **This lives in `Milestone/` rather than `DesignSystem/` on purpose.** It is the
/// only button style that reads `SGExport`, and `SGExport`'s boundary rule limits
/// that palette to export surfaces and this moment. Sitting in the shared design
/// system it was reachable from any screen, so a future `.buttonStyle(...)` on Today
/// or Camera could have pulled the loud palette into the quiet ritual — exactly what
/// the rule exists to prevent. Keeping it here makes the rule greppable again.
struct SkyLoudButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SGFont.body(17).weight(.semibold))
            .foregroundStyle(SGExport.ground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, SGSpacing.lg)
            .background(SGExport.ink, in: Capsule())
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.42)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.985 : 1)
            .animation(reduceMotion ? nil : SGMotion.press, value: configuration.isPressed)
    }
}
