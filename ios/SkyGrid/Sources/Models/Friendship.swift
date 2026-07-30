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
    let createdAt: Date

    func otherMember(than uid: String) -> String? {
        members.first { $0 != uid }
    }
}
