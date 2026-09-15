import Foundation
import Testing
@testable import SkyGrid

@Suite("PersonalizedMorningPlan")
struct PersonalizedMorningPlanTests {
    // These two tests compare against the same `L10n.string(_:)`-resolved catalog
    // values the implementation itself reads, rather than hardcoded English
    // substrings. `PersonalizedMorningPlanBuilder`'s copy now goes through the
    // stage-2 localization catalog (see `dev-notes/localization-en-ja-stage2_*.md`),
    // so it renders in whichever language the running device/simulator resolves to
    // (`AppLanguage.inferred()`) — a hardcoded-English assertion would fail on any
    // Japanese-locale device or simulator despite correct behavior. Comparing
    // against the same lookup keeps the test's real intent (the correct branch is
    // selected for each profile answer) language-independent.
    @Test("uses the selected intent and local wake time")
    func buildsSeasonalPlan() {
        let profile = PersonalizationProfile(
            intent: .seasonalRecord,
            pace: .flexible,
            frequency: .wheneverItFits,
            privacy: .decideLater
        )

        let plan = PersonalizedMorningPlanBuilder.make(profile: profile, wakeGoalMinutes: 6 * 60 + 45)

        #expect(plan.headline.contains("06:45"))
        #expect(plan.headline == String(format: L10n.string("onboarding.plan.headline.seasonalRecord"), "06:45"))
        #expect(plan.recommendation.contains(L10n.string("onboarding.plan.pace.flexible")))
        #expect(plan.recommendation.contains(L10n.string("onboarding.plan.frequency.wheneverItFits")))
        #expect(plan.privacyNote == L10n.string("onboarding.plan.privacy.decideLater"))
    }

    @Test("keeps private preference out of the Pro recommendation")
    func keepsPersonalizationBounded() {
        let profile = PersonalizationProfile(
            intent: .moreOutside,
            pace: .gentle,
            frequency: .weekdays,
            privacy: .privateRitual
        )

        let plan = PersonalizedMorningPlanBuilder.make(profile: profile, wakeGoalMinutes: 360)

        #expect(plan.proLead == L10n.string("onboarding.plan.proLead.moreOutside"))
        #expect(plan.privacyNote == L10n.string("onboarding.plan.privacy.privateRitual"))
    }

    @Test("keeps older three-answer profiles when new questions are added, leaving the new ones unanswered")
    func decodesLegacyProfile() throws {
        let legacyData = Data(#"{ "intent": "moreOutside", "pace": "structured", "privacy": "shareWithBuddy" }"#.utf8)
        let profile = try JSONDecoder().decode(PersonalizationProfile.self, from: legacyData)

        #expect(profile.intent == .moreOutside)
        #expect(profile.pace == .structured)
        #expect(profile.privacy == .shareWithBuddy)
        // A question that didn't exist yet when this profile was saved is
        // genuinely unanswered — nil, not a silently-assumed default. Same rule
        // as a brand-new onboarding: nothing is ever pre-selected on someone's
        // behalf.
        #expect(profile.frequency == nil)
        #expect(profile.reminder == nil)
    }

    @Test("commercial plans stay limited to the four supported states")
    func exposesFourPlanCatalog() {
        #expect(Set(SubscriptionPlan.allCases.map(\.rawValue)) == Set(["free", "monthly", "annual", "lifetime"]))
    }
}
