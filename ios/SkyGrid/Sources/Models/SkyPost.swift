import Foundation

/// Domain representation of `users/{uid}/posts/{localDate}`. Immutable — a post is
/// never edited after creation (Firestore Security Rules only allow `create` and a
/// narrow `reactions`-only `update`; see blueprint §5.1).
struct SkyPost: Hashable, Sendable {
    let ownerUid: String
    let localDate: LocalDate
    let capturedAt: Date
    let uploadedAt: Date
    let imagePath: String
    let thumbPath: String
    let skyColor: SkyColor
    let minutesFromGoal: Int
    /// uid -> emoji. Phase 3 feature (blueprint §2-A); modeled now so the type is
    /// stable, but no UI writes to it yet.
    let reactions: [String: String]

    var minutesFromGoalDescription: String {
        minutesFromGoal <= 0 ? "\(-minutesFromGoal) min early" : "\(minutesFromGoal) min late"
    }
}
