import Testing
@testable import SkyGrid

@Suite("PersonalizedMorningPlan")
struct PersonalizedMorningPlanTests {
    @Test("uses the selected intent and local wake time")
    func buildsSeasonalPlan() {
        let profile = PersonalizationProfile(
            intent: .seasonalRecord,
            pace: .flexible,
            privacy: .decideLater
        )

        let plan = PersonalizedMorningPlanBuilder.make(profile: profile, wakeGoalMinutes: 6 * 60 + 45)

        #expect(plan.headline.contains("06:45"))
        #expect(plan.headline.contains("year of skies"))
        #expect(plan.recommendation.contains("missed morning"))
        #expect(plan.privacyNote.contains("decide"))
    }

    @Test("keeps private preference out of the Pro recommendation")
    func keepsPersonalizationBounded() {
        let profile = PersonalizationProfile(
            intent: .moreOutside,
            pace: .gentle,
            privacy: .privateRitual
        )

        let plan = PersonalizedMorningPlanBuilder.make(profile: profile, wakeGoalMinutes: 360)

        #expect(plan.proLead.contains("30 days"))
        #expect(plan.privacyNote.contains("private"))
    }
}
