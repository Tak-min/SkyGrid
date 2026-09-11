import Foundation

/// What `previewInvite` may report about a code, mirroring `InvitePreviewState` in
/// `ios/functions/src/invites.ts`. `ownInvite` and `claimedByYou` only exist for the
/// caller who created or already claimed the code — nobody else can ever see them,
/// so they leak nothing.
enum InvitePreviewState: String, Sendable {
    case open
    case ownInvite
    case claimedByYou
    case expired
    case claimed
    case revoked
    case unknown
}

/// Mirrors `ClaimOutcome` in `invites.ts`. `blocked` must never be shown alongside who
/// the blocker is — the UI copy for this case should name neither party.
enum InviteClaimOutcome: String, Sendable {
    case paired
    case alreadyBuddies
    case blocked
    case expired
    case revoked
    case claimed
    case unknown
    case ownInvite
    /// The claimant already has the maximum number of accepted buddies. This is
    /// distinct from `.unknown`: the invite remains valid and can be retried after
    /// a slot is freed.
    case circleFull
    /// The inviter's circle is full. Do not expose their identity beyond the link
    /// the claimant intentionally opened.
    case buddyCircleFull
}

/// The caller's own invite link, from `createInvite`.
struct InviteLink: Equatable, Sendable {
    let code: InviteCode
    let url: URL
    let expiresAt: Date
    /// `true` when this is the caller's existing live link, not a freshly minted one.
    /// `createInvite` only mints when the caller passes `fresh: true` — opening the
    /// invite screen must always ask with `fresh: false`, or repeatedly opening it
    /// silently revokes whichever link was already sent (see `createInviteForUser`'s
    /// doc comment and `invitesToRevokeBeforeCreating`).
    let isReused: Bool
}

/// What `previewInvite` returned for a code, before it is spent.
struct InvitePreview: Equatable, Sendable {
    let state: InvitePreviewState
    let creatorHandle: Handle?
    let expiresAt: Date?
}

/// What `claimInviteCode` returned after attempting to spend a code.
struct InviteClaim: Equatable, Sendable {
    let outcome: InviteClaimOutcome
    let buddyUid: String?
    let buddyHandle: Handle?
    /// `0` or `1` — the friendship's generation as `inviteGeneration` computed it
    /// server-side. Not currently consumed by the client; carried through in case a
    /// future screen needs to distinguish a first buddy from a replacement one.
    let generation: Int?
    /// Present only when the caller's own Circle refused the claim. Older Functions
    /// omit both fields, so the client must treat absence as "do not upsell."
    let circleLimit: Int?
    let canUpgradeCircle: Bool

    init(
        outcome: InviteClaimOutcome,
        buddyUid: String?,
        buddyHandle: Handle?,
        generation: Int?,
        circleLimit: Int? = nil,
        canUpgradeCircle: Bool = false
    ) {
        self.outcome = outcome
        self.buddyUid = buddyUid
        self.buddyHandle = buddyHandle
        self.generation = generation
        self.circleLimit = circleLimit
        self.canUpgradeCircle = canUpgradeCircle
    }
}

/// What `revokeInvite` returned.
struct InviteRevocation: Equatable, Sendable {
    let isRevoked: Bool
    /// `true` when the code had already been claimed and therefore could not be
    /// revoked — distinct from `isRevoked == false` meaning "not your code" or
    /// "no such code", both of which `revokeInvite` also answers with `revoked: false`
    /// to avoid giving a caller an oracle for which is true.
    let wasAlreadyClaimed: Bool
}
