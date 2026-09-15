import Foundation
import UserNotifications

/// Fires a local notification once the rolling 7-day weekly recap becomes ready
/// (all 7 days posted). Fires immediately when the condition is first met,
/// then cancels itself to avoid repeat firings for the same recap window.
enum WeeklyRecapReadyScheduler {
    static let identifierPrefix = "com.takmin.skygrid.weekly-recap-ready."

    /// Identifier is keyed by the recap's end date (the current day when all 7 are posted).
    static func identifier(for localDate: LocalDate) -> String {
        identifierPrefix + localDate.docID
    }

    /// Returns true if the recap is newly ready. A recap is ready when all 7 days
    /// have been posted. We consider it "newly" ready if there's no pending notification
    /// for this recap window yet.
    static func isRecapNewlyReady(_ rhythm: WeekRhythm) -> Bool {
        WeeklyRecapPolicy.isReady(rhythm)
    }

    /// Fires an immediate notification (or near-immediate, within a second) to notify
    /// the user that their weekly recap is ready to view. Safe to call even if already
    /// fired — uses an idempotent check to avoid stacking duplicates.
    static func notifyRecapReady(
        endDate: LocalDate
    ) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let authorized = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        guard authorized else { return }

        // Check if we've already fired for this recap window to avoid duplicates.
        let pendingRequests = await center.pendingNotificationRequests()
        let id = identifier(for: endDate)
        if pendingRequests.contains(where: { $0.identifier == id }) {
            return
        }

        let delivered = await center.deliveredNotifications()
        if delivered.contains(where: { $0.request.identifier == id }) {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = L10n.string("notification.weeklyRecapReady.title")
        content.body = L10n.string("notification.weeklyRecapReady.body")
        content.sound = .default

        // Fire immediately (next runloop).
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
    }

    /// Cancels the notification for a specific recap window.
    static func cancel(for localDate: LocalDate) {
        let center = UNUserNotificationCenter.current()
        let id = identifier(for: localDate)
        Task {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            center.removeDeliveredNotifications(withIdentifiers: [id])
        }
    }

    /// Cancels all weekly recap notifications.
    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pendingIDs = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)

        let deliveredIDs = await center.deliveredNotifications()
            .map(\.request.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
    }
}
