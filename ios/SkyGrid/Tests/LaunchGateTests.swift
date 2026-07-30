import Testing
@testable import SkyGrid

@Suite("LaunchGate")
struct LaunchGateTests {
    @Test("a handle is not required before the first morning")
    func opensTodayAfterOnboarding() {
        #expect(LaunchGate.destination(onboardingDone: false) == .onboarding)
        #expect(LaunchGate.destination(onboardingDone: true) == .today)
    }
}
