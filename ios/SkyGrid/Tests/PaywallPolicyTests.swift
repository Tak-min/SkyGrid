import Testing
@testable import SkyGrid

@Suite("ExitOfferPolicy")
struct ExitOfferPolicyTests {
    private let configuration = ExitOfferConfiguration(
        code: "SKYGRID20",
        description: "20% off your first annual term."
    )

    @Test("offers a configured code once from onboarding")
    func offersOnceFromOnboarding() {
        #expect(ExitOfferPolicy.shouldPresent(
            isOnboarding: true,
            hasBeenPresented: false,
            configuration: configuration
        ))
        #expect(!ExitOfferPolicy.shouldPresent(
            isOnboarding: true,
            hasBeenPresented: true,
            configuration: configuration
        ))
    }

    @Test("does not use an exit offer outside onboarding or without configuration")
    func keepsOfferOptionalAndScoped() {
        #expect(!ExitOfferPolicy.shouldPresent(
            isOnboarding: false,
            hasBeenPresented: false,
            configuration: configuration
        ))
        #expect(!ExitOfferPolicy.shouldPresent(
            isOnboarding: true,
            hasBeenPresented: false,
            configuration: nil
        ))
    }
}
