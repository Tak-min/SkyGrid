import Testing
@testable import SkyGrid

@Suite("NotificationRouter")
struct NotificationRouterTests {
    @Test("routes future multi-schedule reminder identifiers to the morning flow")
    func recognizesMultiScheduleReminderIdentifier() {
        let identifier = MorningAlarmScheduler.multiScheduleIdentifierPrefix + "some-uuid.mon"

        #expect(NotificationRouter.isMorningNotificationIdentifier(identifier))
    }

    @Test("continues routing the legacy bare morning reminder identifier")
    func recognizesLegacyMorningReminderIdentifier() {
        #expect(NotificationRouter.isMorningNotificationIdentifier(MorningAlarmScheduler.notificationIdentifier))
    }

    @Test("does not route unrelated notification identifiers to the morning flow")
    func rejectsUnrelatedIdentifier() {
        #expect(!NotificationRouter.isMorningNotificationIdentifier("com.takmin.skygrid.unrelated"))
    }

    @Test("continues routing the one-shot follow-up reminder identifier")
    func recognizesFollowUpIdentifier() {
        let identifier = MorningFollowUpScheduler.identifierPrefix + "2026-09-05"

        #expect(NotificationRouter.isMorningNotificationIdentifier(identifier))
    }
}
