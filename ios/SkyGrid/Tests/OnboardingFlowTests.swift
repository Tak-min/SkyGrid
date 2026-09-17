import Testing
@testable import SkyGrid

@Suite("Onboarding flow")
@MainActor
struct OnboardingFlowTests {
    @Test("six questions lead to the personalized plan")
    func presentsPlanAfterQuestions() {
        let viewModel = OnboardingViewModel()

        viewModel.advance() // intention
        viewModel.advance() // pace
        viewModel.advance() // frequency
        viewModel.advance() // privacy
        viewModel.advance() // reminder
        viewModel.advance() // wake goal
        viewModel.advance() // plan

        #expect(viewModel.step == .plan)
        viewModel.advance()
        #expect(viewModel.step == .invite)
        viewModel.goBackOneStep()
        #expect(viewModel.step == .plan)
    }

    @Test("first-sky completion persists camera-first paywall ordering")
    func completesIntoFirstCapture() {
        let originalDone = LocalDefaults.onboardingDone
        let originalCamera = LocalDefaults.openCameraAfterOnboarding
        let originalPaywall = LocalDefaults.pendingOnboardingPaywallAfterFirstCapture
        defer {
            LocalDefaults.onboardingDone = originalDone
            LocalDefaults.openCameraAfterOnboarding = originalCamera
            LocalDefaults.pendingOnboardingPaywallAfterFirstCapture = originalPaywall
        }

        LocalDefaults.onboardingDone = false
        LocalDefaults.openCameraAfterOnboarding = false
        LocalDefaults.pendingOnboardingPaywallAfterFirstCapture = false
        let viewModel = OnboardingViewModel()

        viewModel.completeForFirstCapture()

        #expect(LocalDefaults.onboardingDone)
        #expect(LocalDefaults.openCameraAfterOnboarding)
        #expect(LocalDefaults.pendingOnboardingPaywallAfterFirstCapture)
    }
}
