import Foundation
import Testing
@testable import SkyGrid

@Suite("PaywallFlow")
struct PaywallFlowTests {
    @Test(
        "every entry point except the automatic reminders gets the full three-step flow",
        arguments: [
            PaywallEntryPoint.onboarding(profile: PersonalizationProfile(), wakeGoalMinutes: 360),
            .home,
            .archive,
            .settings,
            // Unlike `.ritualMilestone`/`.firstUnlock`, `.soloMorning` gets the full
            // flow: nothing has demonstrated the product's value to a solo person
            // yet, so the value step still earns its place.
            .soloMorning(captureCount: 3)
        ]
    )
    func fullFlowForActiveEntryPoints(entryPoint: PaywallEntryPoint) {
        let flow = PaywallFlow.make(for: entryPoint)
        #expect(flow.steps == [.value, .features, .plan])
    }

    @Test(
        "the automatic capture-driven reminders skip the value step",
        arguments: [PaywallEntryPoint.ritualMilestone(captureCount: 10), .firstUnlock]
    )
    func shortenedFlowForAutomaticReminder(entryPoint: PaywallEntryPoint) {
        let flow = PaywallFlow.make(for: entryPoint)
        #expect(flow.steps == [.features, .plan])
    }

    @Test("every flow ends with .plan")
    func alwaysEndsWithPlan() {
        for entryPoint: PaywallEntryPoint in [
            .onboarding(profile: PersonalizationProfile(), wakeGoalMinutes: 360),
            .home, .archive, .settings, .ritualMilestone(captureCount: 3)
        ] {
            #expect(PaywallFlow.make(for: entryPoint).isFinal(.plan))
        }
    }

    @Test("first reflects the flow's leading step")
    func firstMatchesLeadingStep() {
        #expect(PaywallFlow.make(for: .home).first == .value)
        #expect(PaywallFlow.make(for: .ritualMilestone(captureCount: 3)).first == .features)
    }

    @Test("next walks forward and stops after the final step")
    func nextAdvancesThenStops() {
        let flow = PaywallFlow.make(for: .home)
        #expect(flow.next(after: .value) == .features)
        #expect(flow.next(after: .features) == .plan)
        #expect(flow.next(after: .plan) == nil)
    }

    @Test("previous walks backward and stops before the first step")
    func previousRewindsThenStops() {
        let flow = PaywallFlow.make(for: .home)
        #expect(flow.previous(before: .plan) == .features)
        #expect(flow.previous(before: .features) == .value)
        #expect(flow.previous(before: .value) == nil)
    }

    @Test("index reports each step's position")
    func indexReflectsPosition() {
        let flow = PaywallFlow.make(for: .home)
        #expect(flow.index(of: .value) == 0)
        #expect(flow.index(of: .features) == 1)
        #expect(flow.index(of: .plan) == 2)
    }
}
