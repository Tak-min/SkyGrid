import Foundation
import Testing
@testable import SkyGrid

@MainActor
private final class FakeInviteRepository: InviteRepository {
    var previewResult: Result<InvitePreview, Error> = .failure(RepositoryError.unknown(underlying: "not configured"))
    var claimResult: Result<InviteClaim, Error> = .failure(RepositoryError.unknown(underlying: "not configured"))
    private(set) var claimCallCount = 0

    func createInvite(fresh: Bool) async throws -> InviteLink { fatalError("not used by InviteClaimViewModel") }

    func previewInvite(code: InviteCode) async throws -> InvitePreview {
        try previewResult.get()
    }

    func claimInvite(code: InviteCode) async throws -> InviteClaim {
        claimCallCount += 1
        return try claimResult.get()
    }

    func revokeInvite(code: InviteCode) async throws -> InviteRevocation { fatalError("not used by InviteClaimViewModel") }
}

@MainActor
private func makeViewModel(
    repository: FakeInviteRepository,
    hasHandle: @escaping () -> Bool
) -> InviteClaimViewModel {
    InviteClaimViewModel(
        code: InviteCode(raw: "ABCDEFGH12")!,
        uid: "viewer-uid",
        inviteRepository: repository,
        userRepository: FakeUserRepository(),
        hasHandle: hasHandle
    )
}

@MainActor
private final class FakeUserRepository: UserRepository {
    func observeProfile(uid: String) -> AsyncStream<UserProfileObservation> { AsyncStream { $0.finish() } }
    func createOrUpdateProfile(_ profile: UserProfile) async throws {}
    func claimHandle(_ handle: Handle, for uid: String) async throws {}
    func findUid(forHandle handle: Handle) async throws -> String? { nil }
}

@Suite("InviteClaimViewModel")
struct InviteClaimViewModelTests {
    @Test("loads a preview on demand")
    @MainActor
    func loadsPreview() async {
        let repository = FakeInviteRepository()
        repository.previewResult = .success(InvitePreview(state: .open, creatorHandle: Handle(raw: "morning_owl"), expiresAt: nil))
        let viewModel = makeViewModel(repository: repository, hasHandle: { true })

        await viewModel.loadPreview()

        #expect(viewModel.step == .preview(InvitePreview(state: .open, creatorHandle: Handle(raw: "morning_owl"), expiresAt: nil)))
    }

    @Test("maps a preview failure to a failed step, not a crash")
    @MainActor
    func mapsPreviewFailure() async {
        let repository = FakeInviteRepository()
        repository.previewResult = .failure(RepositoryError.network(underlying: "offline"))
        let viewModel = makeViewModel(repository: repository, hasHandle: { true })

        await viewModel.loadPreview()

        guard case .failed = viewModel.step else {
            Issue.record("expected .failed, got \(viewModel.step)")
            return
        }
    }

    @Test("routes to the handle gate instead of claiming, when the caller has no handle")
    @MainActor
    func routesToHandleGateWithoutHandle() async {
        let repository = FakeInviteRepository()
        let viewModel = makeViewModel(repository: repository, hasHandle: { false })

        viewModel.beginClaim()

        #expect(viewModel.step == .needsHandle)
        #expect(repository.claimCallCount == 0)
    }

    @Test("claims immediately when the caller already has a handle")
    @MainActor
    func claimsImmediatelyWithHandle() async throws {
        let repository = FakeInviteRepository()
        repository.claimResult = .success(InviteClaim(outcome: .paired, buddyUid: "buddy-uid", buddyHandle: Handle(raw: "morning_owl"), generation: 0))
        let viewModel = makeViewModel(repository: repository, hasHandle: { true })

        viewModel.beginClaim()
        // beginClaim() dispatches an unstructured Task; give the run loop a turn.
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.step == .result(.paired))
        #expect(repository.claimCallCount == 1)
    }

    @Test("proceeds to claim once HandleClaimView's completion fires")
    @MainActor
    func claimsAfterHandleClaimed() async throws {
        let repository = FakeInviteRepository()
        repository.claimResult = .success(InviteClaim(outcome: .paired, buddyUid: "buddy-uid", buddyHandle: nil, generation: 0))
        let viewModel = makeViewModel(repository: repository, hasHandle: { false })

        viewModel.beginClaim()
        #expect(viewModel.step == .needsHandle)

        viewModel.handleClaimed(Handle(raw: "new_handle")!)
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.step == .result(.paired))
        #expect(repository.claimCallCount == 1)
    }

    @Test(
        "maps every claim outcome without crashing",
        arguments: [
            InviteClaimOutcome.paired, .alreadyBuddies, .blocked, .expired, .revoked, .claimed, .unknown, .ownInvite
        ]
    )
    @MainActor
    func mapsEveryClaimOutcome(outcome: InviteClaimOutcome) async throws {
        let repository = FakeInviteRepository()
        repository.claimResult = .success(InviteClaim(outcome: outcome, buddyUid: nil, buddyHandle: nil, generation: nil))
        let viewModel = makeViewModel(repository: repository, hasHandle: { true })

        viewModel.beginClaim()
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.step == .result(outcome))
    }
}
