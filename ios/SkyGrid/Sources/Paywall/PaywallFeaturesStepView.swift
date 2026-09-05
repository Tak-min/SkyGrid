import SwiftUI

/// Step 2 (or step 1 for the automatic reminders, via `showsHeadline`): the
/// archive benefits, still with no price shown.
struct PaywallFeaturesStepView: View {
    let flow: PaywallFlow
    let entryPoint: PaywallEntryPoint
    /// True only when this step is the flow's first (`.ritualMilestone` or
    /// `.firstUnlock`), since those entry points never reach
    /// `PaywallValueStepView` and would otherwise never show
    /// `entryPoint.headline` at all.
    let showsHeadline: Bool
    let onAdvance: () -> Void
    let onContinueWithFree: () -> Void

    var body: some View {
        PaywallStepScaffold(flow: flow, step: .features) {
            if showsHeadline {
                Text(entryPoint.headline)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(SGT.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            benefits
            freeChoice
            RitualGridMark(side: 116)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        } cta: {
            Button(action: onAdvance) {
                Text("See plans and pricing")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkyPrimaryButtonStyle())

            Button("Continue with Free", action: onContinueWithFree)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            let firstArchiveBenefit = entryPoint.firstArchiveBenefit
            PaywallBenefit(
                symbol: "calendar",
                title: firstArchiveBenefit.title,
                detail: firstArchiveBenefit.detail
            )
            PaywallBenefit(
                symbol: "square.grid.3x3",
                title: "Browse a month at a time",
                detail: "See the photos behind every season, not a colour substitute."
            )
            PaywallBenefit(
                symbol: "square.and.arrow.up",
                title: "A full-year share card",
                detail: "Export the complete color record when there is a year to share."
            )
        }
        .padding(SGSpacing.lg)
        .quietCard()
    }

    private var freeChoice: some View {
        HStack(alignment: .top, spacing: SGSpacing.sm) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(SGT.ink2)
            Text("No feature is hidden after purchase: Free remains a complete daily ritual, with the most recent photos always available.")
                .font(SGFont.caption(13))
                .foregroundStyle(SGT.ink2)
        }
        .padding(.horizontal, SGSpacing.sm)
    }
}
