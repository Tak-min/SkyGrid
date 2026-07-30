import Foundation
import UserNotifications

#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import SwiftUI
#endif

/// The platform used for the morning wake experience. AlarmKit is deliberately the
/// primary path: it is a genuine system alarm on iOS 26+, rather than a notification
/// made to look like one. Older OS versions keep a clearly-labelled local reminder.
enum MorningAlarmKind: Equatable, Sendable {
    case systemAlarm
    case reminder

    var title: String {
        switch self {
        case .systemAlarm: return "System Alarm"
        case .reminder: return "Morning Reminder"
        }
    }

    var detail: String {
        switch self {
        case .systemAlarm: return "An iPhone alarm that sounds even when your phone is locked."
        case .reminder: return "On this iOS version, it arrives as a regular notification."
        }
    }
}

/// A UI-ready reflection of the scheduler's *actual* state, not merely a saved
/// toggle. That distinction avoids telling someone an alarm is on after permission
/// was denied in Settings.
enum MorningAlarmState: Equatable, Sendable {
    case off(MorningAlarmKind)
    case needsAuthorization(MorningAlarmKind)
    case denied(MorningAlarmKind)
    case scheduled(MorningAlarmKind)
    case failed(MorningAlarmKind)

    var kind: MorningAlarmKind {
        switch self {
        case .off(let kind), .needsAuthorization(let kind), .denied(let kind), .scheduled(let kind), .failed(let kind):
            return kind
        }
    }

    var isScheduled: Bool {
        if case .scheduled = self { return true }
        return false
    }
}

/// One stable, idempotent morning wake schedule. A fixed UUID means updating the
/// selected time replaces the existing AlarmKit schedule instead of accumulating
/// alarms. The notification identifier remains public for NotificationRouter.
enum MorningAlarmScheduler {
    static let notificationIdentifier = "com.takmin.skygrid.morning-reminder"
    static let alarmIdentifier = UUID(uuidString: "8A9A5E2E-4B4A-4E8B-9382-FA8E3F3EF1CB")!

    static var preferredKind: MorningAlarmKind {
        if #available(iOS 26.0, *), LocalDefaults.morningAlarmBackend != "reminder" { return .systemAlarm }
        return .reminder
    }

    static func currentState() async -> MorningAlarmState {
        if #available(iOS 26.0, *), preferredKind == .systemAlarm {
            return await alarmKitState()
        }
        return await reminderState()
    }

    /// Requests only the authorization relevant to the current OS and schedules
    /// one all-days wake alarm at the supplied local wall-clock time.
    static func enable(wakeGoalMinutes: Int) async -> MorningAlarmState {
        let normalizedMinutes = min(max(wakeGoalMinutes, 0), 23 * 60 + 59)
        if #available(iOS 26.0, *) {
            LocalDefaults.morningAlarmBackend = "automatic"
            return await scheduleAlarmKit(minutes: normalizedMinutes)
        }
        return await scheduleReminder(minutes: normalizedMinutes)
    }

    /// An explicit escape hatch for an iOS 26 user who declined AlarmKit. This is
    /// never selected automatically: a regular notification is not an equivalent
    /// substitute for a system alarm.
    static func enableReminderFallback(wakeGoalMinutes: Int) async -> MorningAlarmState {
        LocalDefaults.morningAlarmBackend = "reminder"
        return await scheduleReminder(minutes: min(max(wakeGoalMinutes, 0), 23 * 60 + 59))
    }

    static func disable() async {
        if #available(iOS 26.0, *) {
            try? AlarmManager.shared.cancel(id: alarmIdentifier)
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        LocalDefaults.morningAlarmEnabled = false
        LocalDefaults.morningAlarmBackend = "automatic"
    }

    private static func reminderState() async -> MorningAlarmState {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .needsAuthorization(.reminder)
        case .denied:
            return .denied(.reminder)
        case .authorized, .provisional, .ephemeral:
            let requests = await center.pendingNotificationRequests()
            return requests.contains(where: { $0.identifier == notificationIdentifier })
                ? .scheduled(.reminder)
                : .off(.reminder)
        @unknown default:
            return .failed(.reminder)
        }
    }

    private static func scheduleReminder(minutes: Int) async -> MorningAlarmState {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let authorization: UNAuthorizationStatus
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                authorization = granted ? .authorized : .denied
            } catch {
                return .failed(.reminder)
            }
        default:
            authorization = settings.authorizationStatus
        }

        guard authorization != .denied else { return .denied(.reminder) }
        guard authorization == .authorized || authorization == .provisional || authorization == .ephemeral else {
            return .failed(.reminder)
        }

        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "Capture the sky"
        content.body = ""
        content.sound = .default
        content.categoryIdentifier = notificationIdentifier

        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        do {
            try await center.add(request)
            LocalDefaults.morningAlarmEnabled = true
            return .scheduled(.reminder)
        } catch {
            return .failed(.reminder)
        }
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private extension MorningAlarmScheduler {
    static func alarmKitState() async -> MorningAlarmState {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .notDetermined:
            return .needsAuthorization(.systemAlarm)
        case .denied:
            return .denied(.systemAlarm)
        case .authorized:
            let hasMorningAlarm = (try? manager.alarms.contains(where: { $0.id == alarmIdentifier })) ?? false
            return hasMorningAlarm ? .scheduled(.systemAlarm) : .off(.systemAlarm)
        @unknown default:
            return .failed(.systemAlarm)
        }
    }

    static func scheduleAlarmKit(minutes: Int) async -> MorningAlarmState {
        let manager = AlarmManager.shared
        let authorization: AlarmManager.AuthorizationState
        switch manager.authorizationState {
        case .notDetermined:
            do {
                authorization = try await manager.requestAuthorization()
            } catch {
                return .failed(.systemAlarm)
            }
        default:
            authorization = manager.authorizationState
        }

        guard authorization == .authorized else {
            return authorization == .denied ? .denied(.systemAlarm) : .failed(.systemAlarm)
        }

        // Never leave a fallback notification behind after upgrading to the real
        // system alarm; duplicate morning prompts are worse than a failed update.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        try? manager.cancel(id: alarmIdentifier)

        let alert = makeAlertPresentation()
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: SkyGridAlarmMetadata(),
            tintColor: Color(red: 0.48, green: 0.65, blue: 0.78)
        )
        let schedule = Alarm.Schedule.relative(
            .init(
                time: .init(hour: minutes / 60, minute: minutes % 60),
                repeats: .weekly([.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
            )
        )
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            secondaryIntent: OpenMorningCameraIntent(),
            sound: .default
        )

        do {
            _ = try await manager.schedule(id: alarmIdentifier, configuration: configuration)
            LocalDefaults.morningAlarmEnabled = true
            return .scheduled(.systemAlarm)
        } catch {
            return .failed(.systemAlarm)
        }
    }

    static func makeAlertPresentation() -> AlarmPresentation.Alert {
        let cameraButton = AlarmButton(text: "Capture the sky", textColor: .white, systemImageName: "camera")
        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(
                title: "Capture the sky",
                secondaryButton: cameraButton,
                secondaryButtonBehavior: .custom
            )
        }
        return AlarmPresentation.Alert(
            title: "Capture the sky",
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: cameraButton,
            secondaryButtonBehavior: .custom
        )
    }
}

@available(iOS 26.0, *)
private struct SkyGridAlarmMetadata: AlarmMetadata {}

/// AlarmKit invokes this after the person dismisses their morning alarm. Opening
/// the app is intentional here: the only next step is the one-tap camera ritual.
@available(iOS 26.0, *)
private struct OpenMorningCameraIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Sky Grid"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        LocalDefaults.openCameraAfterMorningAlarm = true
        return .result()
    }
}
#endif
