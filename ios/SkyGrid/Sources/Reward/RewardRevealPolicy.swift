import Foundation

/// The reward overlay may only speak about a buddy reveal that the existing buddy
/// reader has already observed through Firestore. A same-day check is essential:
/// a cached reading from yesterday is not evidence that anyone is visible for the
/// capture currently being celebrated.
enum RewardRevealPolicy {
    static func verifiedUnlockedCount(for localDate: LocalDate, reading: RevealReading?) -> Int {
        guard reading?.localDate == localDate else { return 0 }
        return reading?.mutuallyUnlockedBuddyCount ?? 0
    }
}
