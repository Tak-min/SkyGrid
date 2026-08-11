import SwiftUI

/// Step 1: the same value framing the single-screen paywall used to open with,
/// now with no price shown yet. Reached by every entry point except the automatic
/// reminders (`.ritualMilestone`, `.firstUnlock`), which start one step later
/// (see `PaywallFlow.make`).
struct PaywallValueStepView: View {
    let flow: PaywallFlow
    let entryPoint: PaywallEntryPoint
    let onAdvance: () -> Void
    let onContinueWithFree: () -> Void

    var body: some View {
        PaywallStepScaffold(flow: flow, step: .value) {
            hero
        } cta: {
            Button(action: onAdvance) {
                Text("See what Pro opens")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkyPrimaryButtonStyle())

            Button("Continue with Free", action: onContinueWithFree)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            RitualGridMark(side: 108)
                .frame(maxWidth: .infinity)
            Text("SKY GRID PRO")
                .font(SGFont.caption(11))
                .tracking(1.5)
                .foregroundStyle(SGT.ink3)
            Text(entryPoint.headline)
                .font(SGFont.serifTitle(entryPoint.isAutomaticReminder ? 30 : 34))
                .foregroundStyle(SGT.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Keep the newest 30 days free. Upgrade only when you want the long view.")
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
            if let personalizedValueNote = entryPoint.personalizedValueNote {
                Label(personalizedValueNote, systemImage: "sparkles")
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink2)
                    .padding(.top, SGSpacing.xs)
            }
        }
    }
}
