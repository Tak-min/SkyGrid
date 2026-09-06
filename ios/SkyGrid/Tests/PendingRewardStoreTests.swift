import Foundation
import Testing
@testable import SkyGrid

@Suite("Pending reward store")
struct PendingRewardStoreTests {
    private func store() -> PendingRewardStore {
        let defaults = UserDefaults(suiteName: "pending-reward-tests-\(UUID().uuidString)")!
        return PendingRewardStore(defaults: defaults)
    }

    private let today = LocalDate(year: 2026, month: 9, day: 6)
    private let record = PendingRewardRecord(
        localDate: LocalDate(year: 2026, month: 9, day: 6),
        skyColor: SkyColor(uncheckedHex: "#8FB6D8"),
        thumbPath: "posts/uid/2026-09-06/abc_thumb.jpg"
    )

    @Test func survivesTheProcessAndRoundTrips() {
        let store = store()
        store.save(record)
        #expect(store.load(today: today) == record)
    }

    /// The reward answers for the capture that just happened. A celebration arriving
    /// the next morning reads as a bug, not a reward.
    @Test func aRecordFromAnEarlierMorningNeverResurfaces() {
        let store = store()
        store.save(record)
        #expect(store.load(today: LocalDate(year: 2026, month: 9, day: 7)) == nil)
    }

    @Test func clearingLeavesNothingToRestore() {
        let store = store()
        store.save(record)
        store.clear()
        #expect(store.load(today: today) == nil)
    }

    @Test func aPartiallyWrittenRecordIsNotHalfRestored() {
        let defaults = UserDefaults(suiteName: "pending-reward-tests-\(UUID().uuidString)")!
        defaults.set(today.docID, forKey: "pendingReward.localDate")
        #expect(PendingRewardStore(defaults: defaults).load(today: today) == nil)
    }

    @Test func aCorruptSkyColourIsRejectedRatherThanForced() {
        let defaults = UserDefaults(suiteName: "pending-reward-tests-\(UUID().uuidString)")!
        defaults.set(today.docID, forKey: "pendingReward.localDate")
        defaults.set("not-a-hex", forKey: "pendingReward.skyColorHex")
        defaults.set("posts/uid/2026-09-06/abc_thumb.jpg", forKey: "pendingReward.thumbPath")
        #expect(PendingRewardStore(defaults: defaults).load(today: today) == nil)
    }
}
