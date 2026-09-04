import Foundation
import UserNotifications

/// Tapping the morning notification goes straight to the camera — never through the
/// home screen or a feed (VISION.md §3, pain point #2: the 30-second window before
/// losing to the snooze). The delegate must be assigned in
/// `application(_:didFinishLaunchingWithOptions:)`, not later via a SwiftUI `.task`,
/// or a cold-start launch from the notification is silently lost — see dev-notes.
@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    private let appRouter: AppRouter

    init(appRouter: AppRouter) {
        self.appRouter = appRouter
    }

    nonisolated static func isMorningNotificationIdentifier(_ identifier: String) -> Bool {
        identifier == MorningAlarmScheduler.notificationIdentifier
            || identifier.hasPrefix(MorningAlarmScheduler.multiScheduleIdentifierPrefix)
            || identifier.hasPrefix(MorningFollowUpScheduler.identifierPrefix)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let isMorningNotification = Self.isMorningNotificationIdentifier(identifier)
        let userInfo = response.notification.request.content.userInfo
        let buddyPost = BuddyPushPayload.parse(userInfo)

        guard isMorningNotification || buddyPost != nil else {
            completionHandler()
            return
        }
        Task { @MainActor [weak self] in
            if isMorningNotification {
                self?.appRouter.pendingRoute = .camera
            }
            if buddyPost != nil {
                self?.appRouter.pendingBuddyRevealRoute = true
                self?.appRouter.buddyRevealRefreshTicks += 1
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if MorningFollowUpScheduler.shouldSuppressForegroundDelivery(
            identifier: notification.request.identifier,
            lastCapturedLocalDateID: LocalDefaults.lastCapturedLocalDateID
        ) {
            // A local post can complete while the one-shot follow-up is being
            // delivered. Avoid a contradictory banner/sound in that narrow race.
            completionHandler([])
            return
        }
        // A buddy-post push that arrives while the app is already foregrounded is not
        // tapped — nobody navigates — but the buddy strip should still catch up, so
        // this bumps the same refresh counter `didReceive` bumps on a tap.
        if BuddyPushPayload.parse(notification.request.content.userInfo) != nil {
            Task { @MainActor [weak self] in
                self?.appRouter.buddyRevealRefreshTicks += 1
            }
        }
        completionHandler([.banner, .sound])
    }
}
