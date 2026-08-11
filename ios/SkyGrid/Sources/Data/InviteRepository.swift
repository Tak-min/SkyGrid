import Foundation

/// The client's only path to `invites/{code}` and `inviteRateLimits/{uid}` —
/// `firestore.rules` explicit-denies both collections to every client, so every
/// method here is a Cloud Functions callable, never a direct Firestore read/write.
@MainActor
protocol InviteRepository: Sendable {
    /// Returns the caller's live link, minting a new one only when `fresh` is
    /// `true`. The invite screen must always ask with `fresh: false` — minting
    /// unconditionally would silently revoke whichever link the person already
    /// sent (see `createInviteForUser`'s doc comment in `invites.ts`).
    func createInvite(fresh: Bool) async throws -> InviteLink

    /// Reports what a code is without spending it, so the app can say who invited
    /// the caller before acting. Never throws for a code-dependent reason — an
    /// unrecognized or malformed code answers `.unknown`, identical in shape to
    /// every other dead end.
    func previewInvite(code: InviteCode) async throws -> InvitePreview

    /// Spends a code and pairs the two people, atomically, server-side.
    func claimInvite(code: InviteCode) async throws -> InviteClaim

    /// Takes one of the caller's own links out of circulation.
    func revokeInvite(code: InviteCode) async throws -> InviteRevocation
}
