import Foundation
import Testing
@testable import SkyGrid

@Suite("PersonalizedMorningPlan")
struct PersonalizedMorningPlanTests {
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
        #expect(plan.headline.contains("year of skies"))
        #expect(plan.recommendation.contains("missed morning"))
        #expect(plan.recommendation.contains("whenever"))
        #expect(plan.privacyNote.contains("decide"))
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

        #expect(plan.proLead.contains("30 days"))
        #expect(plan.privacyNote.contains("private"))
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
