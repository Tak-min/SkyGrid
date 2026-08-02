import Foundation
import Testing
@testable import SkyGrid

@Suite("AutomaticPaywallPresentationPolicy")
struct AutomaticPaywallPresentationPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let firstCaptureDay = LocalDate(year: 2025, month: 1, day: 10)

    @Test("waits for three completed captures before the first reminder")
    func waitsForRitualValue() {
        #expect(!AutomaticPaywallPresentationPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            completedCaptureCount: 2,
            lastPromptedCaptureCount: nil,
            lastPromptedLocalDate: nil,
            captureLocalDate: firstCaptureDay,
            snoozedUntil: nil,
            now: now
        ))
        #expect(AutomaticPaywallPresentationPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            completedCaptureCount: 3,
            lastPromptedCaptureCount: nil,
            lastPromptedLocalDate: nil,
            captureLocalDate: firstCaptureDay,
            snoozedUntil: nil,
            now: now
        ))
    }

    @Test("does not interrupt subscribers but lets unresolved access reach verification")
    func separatesSubscriberFromUnresolvedAccess() {
        #expect(!AutomaticPaywallPresentationPolicy.shouldPresent(
            entitlementStatus: .subscribed,
            completedCaptureCount: 3,
            lastPromptedCaptureCount: nil,
            lastPromptedLocalDate: nil,
            captureLocalDate: firstCaptureDay,
            snoozedUntil: nil,
            now: now
        ))
        #expect(AutomaticPaywallPresentationPolicy.shouldPresent(
            entitlementStatus: .unknown,
            completedCaptureCount: 3,
            lastPromptedCaptureCount: nil,
            lastPromptedLocalDate: nil,
            captureLocalDate: firstCaptureDay,
            snoozedUntil: nil,
            now: now
        ))
    }

    @Test("uses three captures or three local calendar days between reminders")
    func enforcesCaptureOrCalendarCadence() {
        #expect(!AutomaticPaywallPresentationPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            completedCaptureCount: 5,
            lastPromptedCaptureCount: 3,
            lastPromptedLocalDate: firstCaptureDay,
            captureLocalDate: firstCaptureDay.adding(days: 2),
            snoozedUntil: nil,
            now: now
        ))
        #expect(AutomaticPaywallPresentationPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            completedCaptureCount: 6,
            lastPromptedCaptureCount: 3,
            lastPromptedLocalDate: firstCaptureDay,
            captureLocalDate: firstCaptureDay.adding(days: 2),
            snoozedUntil: nil,
            now: now
        ))
        #expect(AutomaticPaywallPresentationPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            completedCaptureCount: 4,
            lastPromptedCaptureCount: 3,
            lastPromptedLocalDate: firstCaptureDay,
            captureLocalDate: firstCaptureDay.adding(days: 3),
            snoozedUntil: nil,
            now: now
        ))
    }

    @Test("snoozes automatic reminders for fourteen days after two dismissals")
    func appliesFourteenDaySnooze() {
        let snooze = AutomaticPaywallPresentationPolicy.snoozeUntil(
            afterConsecutiveDismissals: 2,
            now: now
        )
        #expect(snooze == now.addingTimeInterval(14 * 24 * 60 * 60))
        #expect(!AutomaticPaywallPresentationPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            completedCaptureCount: 6,
            lastPromptedCaptureCount: 3,
            lastPromptedLocalDate: firstCaptureDay,
            captureLocalDate: firstCaptureDay.adding(days: 3),
            snoozedUntil: snooze,
            now: now
        ))
    }
}
