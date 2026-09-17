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

    @Test("paywall and new Today surfaces provide distinct English and Japanese copy")
    func localizedPrioritySurfacesAreComplete() {
        let keys = [
            "paywall.secondChance.headline",
            "paywall.secondChance.status.checking.title",
            "paywall.secondChance.status.offline.detail",
            "paywall.secondChance.renewalNotice",
            "paywall.features.month.title",
            "paywall.features.circle.detail",
            "paywall.features.together.detail",
            "paywall.features.weekly.detail",
            "paywall.features.yearShare.detail",
            "paywall.features.freeDescription",
            "today.walkthrough.morning.title",
            "today.walkthrough.buddy.detail",
            "today.walkthrough.mosaic.title",
            "today.walkthrough.moku.detail",
            "buddy.feed.empty.title",
            "buddy.feed.empty.detail",
            "buddy.feed.compare",
            "buddy.feed.scrollHint",
        ]

        for key in keys {
            let english = L10n.string(key, language: .english)
            let japanese = L10n.string(key, language: .japanese)
            #expect(english != key)
            #expect(japanese != key)
            #expect(english != japanese)
        }
    }
}
