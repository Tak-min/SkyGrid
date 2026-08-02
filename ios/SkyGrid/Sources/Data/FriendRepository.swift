import Foundation

@MainActor
protocol FriendRepository: Sendable {
    /// All *visible* friendships involving `uid` (both pending and accepted) —
    /// callers filter by `status` as needed (buddy list vs. incoming requests). Any
    /// friendship blocked by either member is deliberately excluded here; see
    /// `observeBlockedFriendships` to manage (and undo) blocks.
    func observeFriendships(uid: String) -> AsyncStream<[Friendship]>

    /// Friendships `uid` has blocked, so Settings > Community & Safety can list them
    /// with an unblock action — the only place a block is otherwise reversible from.
    func observeBlockedFriendships(uid: String) -> AsyncStream<[Friendship]>

    func sendRequest(from: String, to: String) async throws
    func acceptRequest(pairId: String, acceptingUid: String) async throws
    func removeFriendship(pairId: String) async throws

    func block(ownerUid: String, blockedUid: String) async throws
    func unblock(ownerUid: String, blockedUid: String) async throws
    func isBlocked(ownerUid: String, otherUid: String) async throws -> Bool
}
