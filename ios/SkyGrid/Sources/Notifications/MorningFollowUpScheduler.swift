import Foundation
import UserNotifications

/// A single soft nudge if the morning alarm fired and no post exists ~20 minutes
/// later — deliberately not a repeating notification: a repeating
/// `UNCalendarNotificationTrigger` cannot be cancelled for just one day without
/// killing every future occurrence, which would break "cancel today's nudge
/// because a post was made" without disarming the whole feature. Each day gets
/// its own one-shot, individually addressable request instead.
enum MorningFollowUpScheduler {
    static let identifierPrefix = "com.takmin.skygrid.morning-followup."

    static func identifier(for localDate: LocalDate) -> String {
        identifierPrefix + localDate.docID
    }

    /// A just-completed capture can race a foreground notification delivery.
    /// Suppress only the exact same day's one-shot reminder; other app
    /// notifications must continue to present normally.
    static func shouldSuppressForegroundDelivery(
        identifier: String,
        lastCapturedLocalDateID: String?
    ) -> Bool {
        guard let lastCapturedLocalDateID else { return false }
        return identifier.hasPrefix(identifierPrefix + lastCapturedLocalDateID)
    }

    /// Pure and testable: the (wake day, delivery day, fire-time components)
    /// triples for the next `dayCount` mornings. `fireComponents` carries explicit
    /// year/month/day because — unlike the repeating fallback reminder — each
    /// request must be independently cancellable on the date it will be shown.
    static func plannedFollowUps(
        wakeGoalMinutes: Int,
        startingFrom today: LocalDate,
        dayCount: Int = MorningRitualPolicy.followUpWindowDays
    ) -> [(wakeDay: LocalDate, deliveryDay: LocalDate, fireComponents: DateComponents)] {
        plannedFollowUps(
            wakeGoalMinutes: wakeGoalMinutes,
            schedules: MorningAlarmSchedule.migrate(morningAlarmEnabled: true, wakeGoalMinutes: wakeGoalMinutes),
            startingFrom: today,
            dayCount: dayCount
        )
    }

    /// The schedule-set form filters wake days before computing their one-shot
    /// follow-up. The legacy overload above deliberately supplies one every-day
    /// schedule so existing single-alarm callers retain their current behavior.
    static func plannedFollowUps(
        wakeGoalMinutes: Int,
        schedules: [MorningAlarmSchedule],
        startingFrom today: LocalDate,
        dayCount: Int = MorningRitualPolicy.followUpWindowDays
    ) -> [(wakeDay: LocalDate, deliveryDay: LocalDate, fireComponents: DateComponents)] {
        (0..<dayCount).compactMap { offset in
            let wakeDay = today.adding(days: offset)
            guard let firstWakeMinutes = schedules.firstWakeMinutes(on: wakeDay.weekday) else { return nil }
            let components = fireComponents(wakeGoalMinutes: firstWakeMinutes, wakeDay: wakeDay)
            return (
                wakeDay,
                deliveryDay: deliveryDay(for: components),
                fireComponents: components
            )
        }
    }

    /// Idempotent: clears every pending/delivered follow-up, then re-arms the
    /// window. Safe to call unconditionally on every cold launch and whenever the
    /// wake time changes, mirroring `MorningAlarmScheduler`'s own
    /// cancel-then-reschedule discipline. No-ops silently if notifications were
    /// never authorized — this is a soft nudge, not the primary alarm.
    static func refreshWindow(wakeGoalMinutes: Int, today: LocalDate) async {
        await refreshWindow(
            wakeGoalMinutes: wakeGoalMinutes,
            schedules: MorningAlarmSchedule.migrate(morningAlarmEnabled: true, wakeGoalMinutes: wakeGoalMinutes),
            today: today
        )
    }

    static func refreshWindow(
        wakeGoalMinutes: Int,
        schedules: [MorningAlarmSchedule],
        today: LocalDate
    ) async {
        await cancelAll()
        guard LocalDefaults.morningAlarmEnabled else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let authorized = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        guard authorized else { return }

        for (_, deliveryDay, components) in plannedFollowUps(
            wakeGoalMinutes: wakeGoalMinutes,
            schedules: schedules,
            startingFrom: today
        ) {
            guard deliveryDay.docID != LocalDefaults.lastCapturedLocalDateID else { continue }
            let content = UNMutableNotificationContent()
            content.title = L10n.string("notification.todaysSky")
            content.body = L10n.string("notification.notCapturedYet")
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: identifier(for: deliveryDay),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// Cancels exactly one day's nudge — pending (not yet fired) and delivered
    /// (already sitting in Notification Center), so a capture makes it disappear
    /// either way.
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

    /// `wakeGoalMinutes + followUpDelayMinutes` can cross midnight (e.g. a 23:50
    /// wake time), which is why this returns explicit day-shifted components
    /// rather than assuming the fire day equals the wake day.
    private static func fireComponents(wakeGoalMinutes: Int, wakeDay: LocalDate) -> DateComponents {
        let totalMinutes = wakeGoalMinutes + MorningRitualPolicy.followUpDelayMinutes
        let dayOffset = totalMinutes / (24 * 60)
        let minutesOfDay = totalMinutes % (24 * 60)
        let fireDay = dayOffset > 0 ? wakeDay.adding(days: dayOffset) : wakeDay

        var components = DateComponents()
        components.year = fireDay.year
        components.month = fireDay.month
        components.day = fireDay.day
        components.hour = minutesOfDay / 60
        components.minute = minutesOfDay % 60
        return components
    }

    private static func deliveryDay(for components: DateComponents) -> LocalDate {
        // `fireComponents` always supplies these fields; keeping the conversion
        // beside it makes the notification identifier's date contract explicit.
        LocalDate(year: components.year!, month: components.month!, day: components.day!)
    }
}
