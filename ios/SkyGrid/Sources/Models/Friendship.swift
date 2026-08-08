import Foundation

enum FriendshipStatus: String, Sendable {
    case pending
    case accepted
}

/// Deterministic, order-independent Firestore document ID for a friendship pair —
/// `friendships/{pairId}`. Sorting the two UIDs is what lets both members compute the
/// same document ID without a lookup, and it's also enforced by Firestore Security
/// Rules on `create` (see blueprint §5.1).
enum PairID {
    static func make(_ a: String, _ b: String) -> String {
        a < b ? "\(a)_\(b)" : "\(b)_\(a)"
    }
}

struct Friendship: Hashable, Sendable {
    let pairId: String
    let members: [String]
    let status: FriendshipStatus
    let requestedBy: String
    /// Immutable handles captured when the request is created. Pending buddies
    /// cannot read each other's full profiles, so these are the only safe way to
    /// present a recognizable invitation instead of a raw Firebase UID.
    let requestedByHandle: Handle?
    let recipientHandle: Handle?
    let createdAt: Date
    let blockedBy: [String]

    init(
        pairId: String,
        members: [String],
        status: FriendshipStatus,
        requestedBy: String,
        requestedByHandle: Handle? = nil,
        recipientHandle: Handle? = nil,
        createdAt: Date,
        blockedBy: [String]
    ) {
        self.pairId = pairId
        self.members = members
        self.status = status
        self.requestedBy = requestedBy
        self.requestedByHandle = requestedByHandle
        self.recipientHandle = recipientHandle
        self.createdAt = createdAt
        self.blockedBy = blockedBy
    }

    func otherMember(than uid: String) -> String? {
        members.first { $0 != uid }
    }

    func handle(for uid: String) -> Handle? {
        uid == requestedBy ? requestedByHandle : recipientHandle
    }
}
