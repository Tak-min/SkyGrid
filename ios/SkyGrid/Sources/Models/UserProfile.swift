import Foundation

/// Domain representation of `users/{uid}`. `isPro` is a display-only mirror — never
/// trusted for entitlement gating (that's always `PurchasesServicing`, see blueprint
/// §2-E) and never trusted by Firestore Security Rules either.
struct UserProfile: Hashable, Sendable {
    let uid: String
    var handle: Handle?
    var displayName: String
    var timezone: String
    var wakeGoalMinutes: Int
    var streakCurrent: Int
    var streakLongest: Int
    var lastPostLocalDate: LocalDate?
    var isPro: Bool
}
