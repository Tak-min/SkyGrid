import Foundation
import Observation

@MainActor
@Observable
final class InviteLinkViewModel {
    enum LinkState: Equatable {
        case loading
        case ready(InviteLink)
        case failed(String)
        case revoked
    }

    private(set) var linkState: LinkState = .loading
    private(set) var isRevoking = false

    private let inviteRepository: any InviteRepository
    private let placement: InviteAnalytics.Placement

    init(inviteRepository: any InviteRepository, placement: InviteAnalytics.Placement = .buddiesTab) {
        self.inviteRepository = inviteRepository
        self.placement = placement
    }

    /// Always asks for the caller's existing live link (`fresh: false`) — the invite
    /// screen must never mint unconditionally, or `invitesToRevokeBeforeCreating`
    /// (`invites.ts`) can retire a link the person already sent just because they
    /// reopened this screen. A code that has expired has no live link to reuse, so
    /// the server mints a new one transparently; there is no separate "regenerate"
    /// action to expose for that case.
    func load() async {
        linkState = .loading
        do {
            let link = try await inviteRepository.createInvite(fresh: false)
            // Only a genuinely new mint, not every reuse of an existing link — this
            // screen calls load() on every appearance, and counting each reopen as a
            // "created" event would drown out the signal of how often someone
            // actually mints a fresh invite.
            if !link.isReused {
                InviteAnalytics.record(.linkCreated, placement: placement)
            }
            linkState = .ready(link)
        } catch {
            linkState = .failed(Self.message(for: error))
        }
    }

    /// Explicit "stop sharing this link" — mirrors the Block affordance in
    /// `BuddySafetyView`: a person who sent a code somewhere they regret can take it
    /// out of circulation without waiting for its 7-day expiry.
    func revoke() async {
        guard case .ready(let link) = linkState, !isRevoking else { return }
        isRevoking = true
        defer { isRevoking = false }
        do {
            let revocation = try await inviteRepository.revokeInvite(code: link.code)
            if revocation.isRevoked {
                InviteAnalytics.record(.linkRevoked)
                linkState = .revoked
            }
            // `wasAlreadyClaimed` (revoked == false, claimed == true): the link
            // already found a buddy — nothing to revoke, and the caller will see
            // that reflected the next time this screen loads.
        } catch {
            linkState = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        (error as? RepositoryError)?.errorDescription ?? L10n.string("invite.link.loadError")
    }
}
