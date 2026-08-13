import Foundation
import Testing
@testable import SkyGrid

@Suite("SoloMorningPaywallPolicy")
struct SoloMorningPaywallPolicyTests {
    private let today = LocalDate(year: 2025, month: 1, day: 10)

    private func reading(accepted: Int?, unlocked: Int = 0, on date: LocalDate? = nil) -> RevealReading {
        RevealReading(
            localDate: date ?? today,
            mutuallyUnlockedBuddyCount: unlocked,
            acceptedBuddyCount: accepted
        )
    }

    private func evaluate(
        entitlementStatus: EntitlementStatus = .notSubscribed,
        reading: RevealReading?,
        completedCaptureCount: Int = 1,
        captureLocalDate: LocalDate? = nil,
        lastPromptedCaptureCount: Int? = nil,
        lastPromptedLocalDate: LocalDate? = nil,
        snoozedUntil: Date? = nil,
        now: Date = Date(timeIntervalSince1970: 0)
    ) -> SoloMorningPaywallPolicy.Verdict {
        SoloMorningPaywallPolicy.evaluate(
            entitlementStatus: entitlementStatus,
            reading: reading,
            completedCaptureCount: completedCaptureCount,
            captureLocalDate: captureLocalDate ?? today,
            lastPromptedCaptureCount: lastPromptedCaptureCount,
            lastPromptedLocalDate: lastPromptedLocalDate,
            snoozedUntil: snoozedUntil,
            now: now
        )
    }

    @Test("does not assume solo when the friendship snapshot hasn't landed yet")
    func unresolvedFriendshipsIsUndetermined() {
        #expect(evaluate(reading: nil) == .undetermined)
        #expect(evaluate(reading: reading(accepted: nil)) == .undetermined)
    }

    @Test("treats a reading for a different day as undetermined")
    func staleReadingIsUndetermined() {
        let yesterday = LocalDate(year: 2025, month: 1, day: 9)
        #expect(evaluate(reading: reading(accepted: 0, on: yesterday)) == .undetermined)
    }

    @Test("never presents for someone who already has a buddy, even before mutual unlock")
    func pairedUserIsNotEligible() {
        #expect(evaluate(reading: reading(accepted: 1, unlocked: 0)) == .notEligible)
    }

    @Test("presents on the first capture for a confirmed-solo user")
    func presentsAtFirstCapture() {
        #expect(evaluate(reading: reading(accepted: 0), completedCaptureCount: 1) == .present)
    }

    @Test("does not present before any capture is completed")
    func requiresAtLeastOneCapture() {
        #expect(evaluate(reading: reading(accepted: 0), completedCaptureCount: 0) == .notEligible)
    }

    @Test("does not interrupt subscribers but lets unresolved access reach verification")
    func separatesSubscriberFromUnresolvedAccess() {
        #expect(evaluate(entitlementStatus: .subscribed, reading: reading(accepted: 0)) == .notEligible)
        #expect(evaluate(entitlementStatus: .unknown, reading: reading(accepted: 0)) == .present)
    }

    @Test("withholds a re-prompt before either cadence threshold is reached")
    func withholdsBeforeCadence() {
        let day = LocalDate(year: 2025, month: 1, day: 11) // +1 day, +1 capture since prompt
        #expect(evaluate(
            reading: reading(accepted: 0, on: day),
            completedCaptureCount: 5,
            captureLocalDate: day,
            lastPromptedCaptureCount: 4,
            lastPromptedLocalDate: LocalDate(year: 2025, month: 1, day: 10)
        ) == .notEligible)
    }

    @Test("re-prompts once the capture-count cadence is reached, even if the day count is not")
    func repromptsOnCaptureCadence() {
        let day = LocalDate(year: 2025, month: 1, day: 11) // +1 day only
        #expect(evaluate(
            reading: reading(accepted: 0, on: day),
            completedCaptureCount: 6, // +2 captures since prompt (>= 2)
            captureLocalDate: day,
            lastPromptedCaptureCount: 4,
            lastPromptedLocalDate: LocalDate(year: 2025, month: 1, day: 10)
        ) == .present)
    }

    @Test("re-prompts once the day cadence is reached, even if the capture count is not")
    func reptromptsOnDayCadence() {
        let day = LocalDate(year: 2025, month: 1, day: 12) // +2 days
        #expect(evaluate(
            reading: reading(accepted: 0, on: day),
            completedCaptureCount: 5, // +1 capture only since prompt
            captureLocalDate: day,
            lastPromptedCaptureCount: 4,
            lastPromptedLocalDate: LocalDate(year: 2025, month: 1, day: 10)
        ) == .present)
    }

    @Test("withholds while a snooze is in effect, then resumes once it lapses")
    func respectsSnooze() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(evaluate(
            reading: reading(accepted: 0),
            snoozedUntil: now.addingTimeInterval(1),
            now: now
        ) == .notEligible)
        #expect(evaluate(
            reading: reading(accepted: 0),
            snoozedUntil: now,
            now: now
        ) == .present)
    }

    @Test("snooze escalates from none, to a short snooze, to a longer one")
    func snoozeEscalates() {
        let now = Date(timeIntervalSince1970: 0)
        #expect(SoloMorningPaywallPolicy.snoozeUntil(afterConsecutiveDismissals: 1, now: now) == nil)
        #expect(SoloMorningPaywallPolicy.snoozeUntil(afterConsecutiveDismissals: 2, now: now) == now.addingTimeInterval(SoloMorningPaywallPolicy.snoozeInterval))
        #expect(SoloMorningPaywallPolicy.snoozeUntil(afterConsecutiveDismissals: 3, now: now) == now.addingTimeInterval(SoloMorningPaywallPolicy.snoozeInterval))
        #expect(SoloMorningPaywallPolicy.snoozeUntil(afterConsecutiveDismissals: 4, now: now) == now.addingTimeInterval(SoloMorningPaywallPolicy.longSnoozeInterval))
        #expect(SoloMorningPaywallPolicy.snoozeUntil(afterConsecutiveDismissals: 5, now: now) == now.addingTimeInterval(SoloMorningPaywallPolicy.longSnoozeInterval))
    }
}
