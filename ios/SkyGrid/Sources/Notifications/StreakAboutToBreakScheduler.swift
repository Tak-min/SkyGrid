import Foundation
import UserNotifications

/// An evening reminder if a user has NOT posted today and has a current streak > 0.
/// The notification warns that their streak will lapse if they don't post before midnight.
/// Fires once per day at 20:00 local time, independently cancellable.
enum StreakAboutToBreakScheduler {
    static let identifierPrefix = "com.takmin.skygrid.streak-about-to-break."

    static func identifier(for localDate: LocalDate) -> String {
        identifierPrefix + localDate.docID
    }

    /// Pure logic: returns true if a reminder should fire for today.
    /// A reminder fires only if the user has NOT posted today AND has a current streak > 0.
    static func shouldRemindToday(
        hasPostedToday: Bool,
        currentStreak: Int
    ) -> Bool {
        !hasPostedToday && currentStreak > 0
    }

    /// Idempotent: cancels all pending/delivered reminders for this user, then re-arms
    /// based on their current streak state. Safe to call unconditionally on app foreground,
    /// mirroring `MorningFollowUpScheduler`'s discipline. No-ops silently if notifications
    /// were never authorized.
    static func refreshReminder(
        hasPostedToday: Bool,
        currentStreak: Int,
        today: LocalDate
    ) async {
        await cancelAll()

        guard shouldRemindToday(hasPostedToday: hasPostedToday, currentStreak: currentStreak) else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let authorized = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        guard authorized else { return }

        var components = DateComponents()
        components.year = today.year
        components.month = today.month
        components.day = today.day
        components.hour = 20
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = L10n.string("notification.streakAboutToBreak.title")
        content.body = L10n.string("notification.streakAboutToBreak.body")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier(for: today),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    /// Pending notification content is snapshotted when scheduled. Keep its
    /// original fire time when the person changes the in-app language.
    static func resyncLocalizedContent() async {
        let center = UNUserNotificationCenter.current()
        for request in await center.pendingNotificationRequests()
            where request.identifier.hasPrefix(identifierPrefix) {
            guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else { continue }
            content.title = L10n.string("notification.streakAboutToBreak.title")
            content.body = L10n.string("notification.streakAboutToBreak.body")
            try? await center.add(UNNotificationRequest(
                identifier: request.identifier,
                content: content,
                trigger: request.trigger
            ))
        }
    }

    /// Cancels exactly one day's reminder — pending and delivered.
    static func cancel(for localDate: LocalDate) {
        let center = UNUserNotificationCenter.current()
        let prefix = identifier(for: localDate)
        Task {
            let pending = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            let delivered = await center.deliveredNotifications()
                .map(\.request.identifier)
                .filter { $0.hasPrefix(prefix) }
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }
    }

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
