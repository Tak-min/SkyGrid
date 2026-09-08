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
        let originalWakeSession = LocalDefaults.morningWakeSession
        defer {
            LocalDefaults.morningRealarmAttemptCount = originalAttemptCount
            LocalDefaults.morningRealarmWakeDayID = originalWakeDayID
            LocalDefaults.lastCapturedLocalDateID = originalLastCapturedLocalDateID
            LocalDefaults.openCameraAfterMorningAlarm = originalOpenCameraAfterMorningAlarm
            LocalDefaults.morningWakeSession = originalWakeSession
        }
        let localDate = LocalDate(year: 2026, month: 9, day: 5)
        LocalDefaults.morningRealarmAttemptCount = 3
        LocalDefaults.morningRealarmWakeDayID = localDate.docID
        LocalDefaults.morningWakeSession = MorningWakeSession(
            wakeDayID: localDate.docID,
            sourceAlarmID: UUID(),
            startedAt: Date(),
            deadline: Date().addingTimeInterval(3_600),
            phase: .awaitingCapture,
            pendingRetries: [MorningWakeRetry(id: UUID(), fireDate: Date().addingTimeInterval(300))]
        )

        await MorningRitualCoordinator.captureCompleted(localDate: localDate)

        #expect(LocalDefaults.morningRealarmAttemptCount == 0)
        #expect(LocalDefaults.morningRealarmWakeDayID == nil)
        #expect(LocalDefaults.morningWakeSession == nil)
    }
}
