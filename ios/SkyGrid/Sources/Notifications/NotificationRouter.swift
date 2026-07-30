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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.notification.request.identifier == MorningAlarmScheduler.notificationIdentifier else {
            completionHandler()
            return
        }
        Task { @MainActor [weak self] in
            self?.appRouter.pendingRoute = .camera
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
