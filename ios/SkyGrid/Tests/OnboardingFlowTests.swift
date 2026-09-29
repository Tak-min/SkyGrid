import Testing
@testable import SkyGrid

@Suite("Onboarding flow")
@MainActor
struct OnboardingFlowTests {
    @Test("every onboarding step is reversible from language through invite")
    func walksForwardAndBackwardAcrossEveryStep() {
        let viewModel = OnboardingViewModel(step: .language)
        let steps = OnboardingStep.allCases

        #expect(steps.count == 16)
        #expect(viewModel.step == .language)

        for expectedStep in steps.dropFirst() {
            viewModel.advance()
            #expect(viewModel.step == expectedStep)
        }

        for expectedStep in steps.dropLast().reversed() {
            viewModel.goBackOneStep()
            #expect(viewModel.step == expectedStep)
        }
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
