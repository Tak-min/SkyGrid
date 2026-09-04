import Testing
@testable import SkyGrid

@Suite("Onboarding flow")
@MainActor
struct OnboardingFlowTests {
    @Test("keeps personalized plan inputs and presents the optional invite last")
    func presentsInviteAfterPlan() {
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
}
