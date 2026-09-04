import Foundation

/// A listener failure is distinct from a confirmed empty buddy list. This lets
/// views retain the last successful relationships instead of making them vanish.
enum FriendshipCollectionObservation: Sendable {
    case value([Friendship])
    case unavailable
}

/// Blocks remain recoverable only while this collection can be inspected from
/// Settings, so a failed read must not look like a confirmed empty block list.
enum BlockedFriendshipCollectionObservation: Sendable {
    case value([Friendship])
    case unavailable
}

enum FriendRequestResult: Sendable, Equatable {
    case sent
    case alreadyPending
    case incomingRequestExists
    case alreadyBuddies
    case blocked
}

enum FriendRequestAcceptanceResult: Sendable, Equatable {
    case accepted
    case alreadyAccepted
    case circleFull
    case buddyCircleFull
    case invalidRequest
}

@MainActor
protocol FriendRepository: Sendable {
    /// All *visible* friendships involving `uid` (both pending and accepted) —
    /// callers filter by `status` as needed (buddy list vs. incoming requests). Any
    /// friendship blocked by either member is deliberately excluded here; see
    /// `observeBlockedFriendships` to manage (and undo) blocks.
    func observeFriendships(uid: String) -> AsyncStream<FriendshipCollectionObservation>

    /// Friendships `uid` has blocked, so Settings > Community & Safety can list them
    /// with an unblock action — the only place a block is otherwise reversible from.
    func observeBlockedFriendships(uid: String) -> AsyncStream<BlockedFriendshipCollectionObservation>

    func sendRequest(
        from: String,
        to: String,
        requesterHandle: Handle,
        recipientHandle: Handle
    ) async throws -> FriendRequestResult
    func acceptRequest(pairId: String, acceptingUid: String) async throws -> FriendRequestAcceptanceResult
    func removeFriendship(pairId: String) async throws

    func block(ownerUid: String, blockedUid: String) async throws
    func unblock(ownerUid: String, blockedUid: String) async throws
    func isBlocked(ownerUid: String, otherUid: String) async throws -> Bool
}
