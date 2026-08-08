import SwiftUI

struct PersonalizedPlanView: View {
    let profile: PersonalizationProfile
    let wakeGoalMinutes: Int
    let onExplorePro: () -> Void
    let onContinueFree: () -> Void
    let onEditAnswers: () -> Void

    private var plan: PersonalizedMorningPlan {
        PersonalizedMorningPlanBuilder.make(profile: profile, wakeGoalMinutes: wakeGoalMinutes)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                HStack {
                    Button(action: onEditAnswers) {
                        Label("Edit answers", systemImage: "chevron.left")
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityHint("Returns to your wake-time answer")
                    Spacer()
                }
                .font(SGFont.caption(14))
                .foregroundStyle(SGT.ink2)

                OnboardingProgress(step: 8, total: 8)

                RitualGridMark(side: 128)
                    .frame(maxWidth: .infinity)

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

                // The personalised prompt describes the same paid archive for
                // everyone; only its relevance copy changes with local answers.
                Button("See my complete archive", action: onExplorePro)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(SkyPrimaryButtonStyle())

                Button("Start with Free", action: onContinueFree)
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
            .padding(.bottom, 32)
        }
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
