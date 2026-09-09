import Foundation
import Testing
@testable import SkyGrid

@Suite("Second-chance paywall policy")
struct SecondChancePaywallPolicyTests {
    @Test("only the first onboarding paywall can attempt the offer")
    func onboardingOneShot() {
        let onboarding = PaywallEntryPoint.onboarding(
            profile: PersonalizationProfile(),
            wakeGoalMinutes: 360
        )
        #expect(SecondChancePaywallPolicy.shouldAttempt(
            entryPoint: onboarding,
            hasPresentedForAccount: false
        ))
        #expect(!SecondChancePaywallPolicy.shouldAttempt(
            entryPoint: onboarding,
            hasPresentedForAccount: true
        ))
    }

    @Test(
        "manual and later automatic paywalls never attempt the offer",
        arguments: [
            PaywallEntryPoint.home,
            .archive,
            .settings,
            .ritualMilestone(captureCount: 10),
            .firstUnlock,
            .soloMorning(captureCount: 3),
        ]
    )
    func otherEntryPointsAreExcluded(_ entryPoint: PaywallEntryPoint) {
        #expect(!SecondChancePaywallPolicy.shouldAttempt(
            entryPoint: entryPoint,
            hasPresentedForAccount: false
        ))
    }

    @Test("the connectivity threshold remains the decided seven seconds")
    func connectivityThreshold() {
        #expect(SecondChancePaywallPolicy.connectionTimeout == .seconds(7))
    }
}
