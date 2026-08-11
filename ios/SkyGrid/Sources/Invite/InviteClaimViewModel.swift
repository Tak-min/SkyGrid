import Foundation
import Observation

@MainActor
@Observable
final class InviteClaimViewModel {
    enum Step: Equatable {
        case loadingPreview
        case preview(InvitePreview)
        /// Reached only after tapping "Become buddies" with no local handle. Distinct
        /// from `.preview` so `InviteClaimView` can swap in `HandleClaimView` without
        /// losing the code this claim is for.
        case needsHandle
        case claiming
        case result(InviteClaimOutcome)
        case failed(String)
    }

    private(set) var step: Step = .loadingPreview

    let code: InviteCode
    let uid: String
    let userRepository: any UserRepository
    private let inviteRepository: any InviteRepository
    /// Defaults to the same cheap, locally cached read `RootView` already trusts for
    /// `milestoneMoment`'s handle display. Injectable so tests can drive both branches
    /// of `beginClaim()` without touching the real `UserDefaults` singleton.
    private let hasHandle: () -> Bool

    init(
        code: InviteCode,
        uid: String,
        inviteRepository: any InviteRepository,
        userRepository: any UserRepository,
        hasHandle: @escaping () -> Bool = { LocalDefaults.handle != nil }
    ) {
        self.code = code
        self.uid = uid
        self.inviteRepository = inviteRepository
        self.userRepository = userRepository
        self.hasHandle = hasHandle
    }

    /// Never requires a handle — `previewInviteCode` only validates the *creator's*
    /// handle, not the caller's (see `ios/functions/src/inviteStore.ts`). Showing who
    /// invited the caller must work before they have committed to anything.
    func loadPreview() async {
        step = .loadingPreview
        do {
            let preview = try await inviteRepository.previewInvite(code: code)
            step = .preview(preview)
        } catch {
            step = .failed(Self.message(for: error))
        }
    }

    /// Called when the person taps "Become buddies." `claimInviteCode` hard-fails
    /// server-side (`failed-precondition`) for a caller with no handle — pre-empting
    /// that client-side keeps the server error genuinely exceptional rather than the
    /// primary way someone learns they need a handle first.
    func beginClaim() {
        guard hasHandle() else {
            step = .needsHandle
            return
        }
        Task { await claim() }
    }

    /// `HandleClaimView`'s completion — proceed straight to the claim this sheet
    /// exists for, rather than leaving the person to tap "Become buddies" a second
    /// time.
    func handleClaimed(_ handle: Handle) {
        Task { await claim() }
    }

    private func claim() async {
        step = .claiming
        do {
            let result = try await inviteRepository.claimInvite(code: code)
            step = .result(result.outcome)
        } catch {
            step = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        (error as? RepositoryError)?.errorDescription ?? "Something went wrong. Try this link again in a moment."
    }
}
