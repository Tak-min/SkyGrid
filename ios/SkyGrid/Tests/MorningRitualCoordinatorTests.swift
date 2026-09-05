import Foundation
import Testing
@testable import SkyGrid

@Suite("Morning ritual coordinator")
struct MorningRitualCoordinatorTests {
    @Test("a completed capture clears the current re-alarm loop state")
    @MainActor
    func captureCompletedResetsRealarmState() async {
        let originalAttemptCount = LocalDefaults.morningRealarmAttemptCount
        let originalWakeDayID = LocalDefaults.morningRealarmWakeDayID
        let originalLastCapturedLocalDateID = LocalDefaults.lastCapturedLocalDateID
        let originalOpenCameraAfterMorningAlarm = LocalDefaults.openCameraAfterMorningAlarm
        defer {
            LocalDefaults.morningRealarmAttemptCount = originalAttemptCount
            LocalDefaults.morningRealarmWakeDayID = originalWakeDayID
            LocalDefaults.lastCapturedLocalDateID = originalLastCapturedLocalDateID
            LocalDefaults.openCameraAfterMorningAlarm = originalOpenCameraAfterMorningAlarm
        }
        let localDate = LocalDate(year: 2026, month: 9, day: 5)
        LocalDefaults.morningRealarmAttemptCount = 3
        LocalDefaults.morningRealarmWakeDayID = localDate.docID

        await MorningRitualCoordinator.captureCompleted(localDate: localDate)

        #expect(LocalDefaults.morningRealarmAttemptCount == 0)
        #expect(LocalDefaults.morningRealarmWakeDayID == nil)
    }
}
