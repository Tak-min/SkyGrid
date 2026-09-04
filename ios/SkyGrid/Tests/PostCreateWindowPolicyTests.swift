import Testing
@testable import SkyGrid

/// `PostCreateWindowPolicy` exists to stop `PostStatusBanner` from offering a
/// "Retry now" that can never succeed once `firestore.rules`' `isRecentLocalDate`
/// would already reject the write — see the type's own doc comment (2026-09-04
/// security review, HIGH-2) for the full rationale.
@Suite("PostCreateWindowPolicy")
struct PostCreateWindowPolicyTests {
    private let today = LocalDate(year: 2026, month: 9, day: 4)

    @Test("today's own date is never too old to retry")
    func todayIsNeverTooOld() {
        #expect(!PostCreateWindowPolicy.isTooOldToRetry(localDate: today, today: today))
    }

    @Test("yesterday is not yet too old to retry")
    func yesterdayIsNotTooOld() {
        #expect(!PostCreateWindowPolicy.isTooOldToRetry(localDate: today.adding(days: -1), today: today))
    }

    @Test("the day before yesterday is too old to retry")
    func twoDaysAgoIsTooOld() {
        #expect(PostCreateWindowPolicy.isTooOldToRetry(localDate: today.adding(days: -2), today: today))
    }

    @Test("a week-old capture is too old to retry")
    func aWeekAgoIsTooOld() {
        #expect(PostCreateWindowPolicy.isTooOldToRetry(localDate: today.adding(days: -7), today: today))
    }

    @Test("a future-dated row is never flagged too old (only the past bound is mirrored)")
    func futureDatesAreNeverFlagged() {
        #expect(!PostCreateWindowPolicy.isTooOldToRetry(localDate: today.adding(days: 1), today: today))
        #expect(!PostCreateWindowPolicy.isTooOldToRetry(localDate: today.adding(days: 2), today: today))
    }
}
