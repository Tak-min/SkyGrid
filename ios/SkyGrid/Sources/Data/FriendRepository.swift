import Foundation

@MainActor
protocol FriendRepository: Sendable {
    /// All friendships involving `uid` (both pending and accepted) — callers filter
    /// by `status` as needed (buddy list vs. incoming requests).
    func observeFriendships(uid: String) -> AsyncStream<[Friendship]>

    func sendRequest(from: String, to: String) async throws
    func acceptRequest(pairId: String, acceptingUid: String) async throws
    func removeFriendship(pairId: String) async throws

    func block(ownerUid: String, blockedUid: String) async throws
    func unblock(ownerUid: String, blockedUid: String) async throws
    func isBlocked(ownerUid: String, otherUid: String) async throws -> Bool
}
