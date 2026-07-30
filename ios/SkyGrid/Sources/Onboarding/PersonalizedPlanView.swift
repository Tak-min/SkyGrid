import SwiftUI

struct PersonalizedPlanView: View {
    let profile: PersonalizationProfile
    let wakeGoalMinutes: Int
    let onExplorePro: () -> Void
    let onContinueFree: () -> Void

    private var plan: PersonalizedMorningPlan {
        PersonalizedMorningPlanBuilder.make(profile: profile, wakeGoalMinutes: wakeGoalMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.xl) {
            OnboardingProgress(step: 4, total: 4)

            Spacer(minLength: 14)

            RitualGridMark()
                .frame(maxWidth: .infinity)
                .frame(height: 150)

            VStack(alignment: .leading, spacing: SGSpacing.md) {
                Text("YOUR MORNING PLAN")
                    .font(SGFont.caption(11))
                    .tracking(1.5)
                    .foregroundStyle(SGT.ink3)
                Text(plan.headline)
                    .font(SGFont.serifTitle(36))
                    .foregroundStyle(SGT.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(plan.recommendation)
                    .font(SGFont.body(16))
                    .foregroundStyle(SGT.ink2)
            }

            VStack(alignment: .leading, spacing: SGSpacing.md) {
                Label(plan.privacyNote, systemImage: "lock")
                    .font(SGFont.caption(14))
                    .foregroundStyle(SGT.ink2)
                Label("Camera access is only requested when you choose Capture.", systemImage: "camera")
                    .font(SGFont.caption(14))
                    .foregroundStyle(SGT.ink2)
            }
            .padding(SGSpacing.lg)
            .quietCard()

            Spacer(minLength: 0)

            Button("Start with Free", action: onContinueFree)
                .frame(maxWidth: .infinity)
                .buttonStyle(SkyPrimaryButtonStyle())

            Button("Explore Pro", action: onExplorePro)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)

            Text("Free includes daily capture, your weekly rhythm, 30 days of archive, and standard sharing.")
                .font(SGFont.caption(12))
                .foregroundStyle(SGT.ink3)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(SGSpacing.xl)
    }
}

struct OnboardingProgress: View {
    let step: Int
    let total: Int

    var body: some View {
        HStack {
            Text("SKY GRID")
                .font(SGFont.caption(12))
                .tracking(2)
                .foregroundStyle(SGT.ink3)
            Spacer()
            Text(String(format: "%02d / %02d", step, total))
                .font(SGFont.numeric(12))
                .foregroundStyle(SGT.ink3)
        }
        .padding(.top, SGSpacing.lg)

        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(SGT.rule)
                Capsule()
                    .fill(SGT.ink.opacity(0.55))
                    .frame(width: proxy.size.width * CGFloat(step) / CGFloat(total))
            }
        }
        .frame(height: 2)
    }
}
