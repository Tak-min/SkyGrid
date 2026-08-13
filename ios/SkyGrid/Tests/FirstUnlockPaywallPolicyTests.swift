import Foundation
import Testing
@testable import SkyGrid

@Suite("FirstUnlockPaywallPolicy")
struct FirstUnlockPaywallPolicyTests {
    private let today = LocalDate(year: 2025, month: 1, day: 10)

    private func reading(count: Int, acceptedBuddyCount: Int? = 1) -> RevealReading {
        RevealReading(localDate: today, mutuallyUnlockedBuddyCount: count, acceptedBuddyCount: acceptedBuddyCount)
    }

    @Test("does not present without a mutual unlock")
    func requiresMutualUnlock() {
        #expect(!FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            reading: nil,
            completedCaptureCount: 5,
            hasPresentedUnlockPaywall: false
        ))
        #expect(!FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            reading: reading(count: 0),
            completedCaptureCount: 5,
            hasPresentedUnlockPaywall: false
        ))
    }

    @Test("presents the moment a buddy is mutually unlocked, at the very first capture")
    func presentsAtFirstCapture() {
        #expect(FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            reading: reading(count: 1),
            completedCaptureCount: 1,
            hasPresentedUnlockPaywall: false
        ))
    }

    @Test("does not interrupt subscribers but lets unresolved access reach verification")
    func separatesSubscriberFromUnresolvedAccess() {
        #expect(!FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .subscribed,
            reading: reading(count: 1),
            completedCaptureCount: 1,
            hasPresentedUnlockPaywall: false
        ))
        #expect(FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .unknown,
            reading: reading(count: 1),
            completedCaptureCount: 1,
            hasPresentedUnlockPaywall: false
        ))
    }

    @Test("never presents a second time, regardless of how many buddies unlock later")
    func isOneShot() {
        #expect(!FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            reading: reading(count: 3),
            completedCaptureCount: 40,
            hasPresentedUnlockPaywall: true
        ))
    }

    @Test("ignores acceptedBuddyCount entirely — a nil (unresolved) value must not block a real mutual unlock")
    func doesNotReadAcceptedBuddyCount() {
        #expect(FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            reading: reading(count: 1, acceptedBuddyCount: nil),
            completedCaptureCount: 1,
            hasPresentedUnlockPaywall: false
        ))
    }
}
