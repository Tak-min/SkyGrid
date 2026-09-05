import Foundation
import UserNotifications

enum MorningReminderFallbackSchedulingInput: Equatable, Sendable {
    case legacy(Int)
    case schedules([MorningAlarmSchedule])
}

enum MorningAlarmKitSchedulingInput: Equatable, Sendable {
    case legacy(Int)
    case schedules([MorningAlarmSchedule])
}

extension Array where Element == MorningAlarmSchedule {
    /// Until schedule editing is exposed, the single wake-time setting remains
    /// authoritative. Disabled schedules retain their stored time so re-enabling
    /// one later does not change it as a side effect of another schedule update.
    func applyingWakeGoalMinutes(_ minutes: Int) -> [MorningAlarmSchedule] {
        map { schedule in
            guard schedule.isEnabled else { return schedule }
            var updated = schedule
            updated.minutesAfterMidnight = minutes
            return updated
        }
    }
}

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

/// A single repeating local-notification occurrence in the reminder fallback.
/// Keeping this value separate from `UNNotificationRequest` makes the reconcile
/// decision deterministic and independently testable.
struct MorningReminderOccurrence: Equatable, Sendable {
    let schedule: MorningAlarmSchedule
    let weekday: Int

    var identifier: String {
        MorningAlarmScheduler.reminderIdentifier(scheduleID: schedule.id, weekday: weekday)
    }
}

/// The parts of a currently pending fallback request that determine whether its
/// identifier still represents the desired weekly notification. A missing time
/// is deliberately treated as stale: a malformed/non-calendar request must not
/// block the correctly configured replacement from being installed.
struct MorningReminderPendingOccurrence: Equatable, Sendable {
    let identifier: String
    let hour: Int?
    let minute: Int?

    func matches(_ occurrence: MorningReminderOccurrence) -> Bool {
        hour == occurrence.schedule.minutesAfterMidnight / 60
            && minute == occurrence.schedule.minutesAfterMidnight % 60
    }
}

struct MorningReminderReconcilePlan: Equatable, Sendable {
    let additions: [MorningReminderOccurrence]
    let cancellations: Set<String>
}

/// The schedule-bearing fields from an AlarmKit alarm. Optional values represent
/// an existing alarm whose schedule is not a weekly wall-clock schedule; it is
/// therefore stale for any matching `MorningAlarmSchedule` identifier.
struct MorningAlarmKitScheduledAlarm: Equatable, Sendable {
    let id: UUID
    let hour: Int?
    let minute: Int?
    let weekdays: Set<Int>?

    func matches(_ schedule: MorningAlarmSchedule) -> Bool {
        hour == schedule.minutesAfterMidnight / 60
            && minute == schedule.minutesAfterMidnight % 60
            && weekdays == schedule.weekdays
    }
}

/// A schedule replacement uses AlarmKit's same-ID replacement behavior, so a
/// changed entry belongs in `additions`, not `cancellations`. Cancellations are
/// strictly alarms whose IDs are no longer desired.
struct MorningAlarmKitReconcilePlan: Equatable, Sendable {
    let additions: [MorningAlarmSchedule]
    let cancellations: Set<UUID>
}

/// Computes the desired AlarmKit schedule set from the caller's already-scoped
/// multi-schedule AlarmKit alarms. Matching IDs are insufficient: an alarm whose
/// wall-clock time or selected weekdays changed must be scheduled again.
func morningAlarmKitReconcilePlan(
    schedules: [MorningAlarmSchedule],
    currentAlarms: [MorningAlarmKitScheduledAlarm]
) -> MorningAlarmKitReconcilePlan {
    let desired = schedules.filter(\.isEnabled)
    let currentByID = Dictionary(
        currentAlarms.map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }
    )
    let desiredIDs = Set(desired.map(\.id))

    return MorningAlarmKitReconcilePlan(
        additions: desired.filter { schedule in
            guard let current = currentByID[schedule.id] else { return true }
            return !current.matches(schedule)
        },
        cancellations: Set(currentAlarms.map(\.id)).subtracting(desiredIDs)
    )
}

/// Computes the desired reminder-fallback set without consulting notification
/// authorization or `UNUserNotificationCenter`. A time mismatch for an otherwise
/// matching identifier is a replacement, not a no-op. `currentPendingOccurrences`
/// is intentionally restricted by the caller to the legacy/multi-schedule namespace.
func morningReminderReconcilePlan(
    schedules: [MorningAlarmSchedule],
    currentPendingOccurrences: [MorningReminderPendingOccurrence]
) -> MorningReminderReconcilePlan {
    let desired = schedules
        .filter(\.isEnabled)
        .flatMap { schedule in
            schedule.weekdays
                .filter { (1...7).contains($0) }
                .sorted()
                .map { MorningReminderOccurrence(schedule: schedule, weekday: $0) }
        }
    let pending = currentPendingOccurrences.filter {
        $0.identifier == MorningAlarmScheduler.notificationIdentifier
            || $0.identifier.hasPrefix(MorningAlarmScheduler.multiScheduleIdentifierPrefix)
    }
    let pendingByIdentifier = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })

    return MorningReminderReconcilePlan(
        additions: desired.filter { occurrence in
            guard let pendingOccurrence = pendingByIdentifier[occurrence.identifier] else { return true }
            return !pendingOccurrence.matches(occurrence)
        },
        cancellations: Set(pending.compactMap { pendingOccurrence in
            guard let desiredOccurrence = desired.first(where: { $0.identifier == pendingOccurrence.identifier }) else {
                return pendingOccurrence.identifier
            }
            return pendingOccurrence.matches(desiredOccurrence) ? nil : pendingOccurrence.identifier
        })
    )
}

/// A failed add must never create a zero-alarm gap by removing an older request
/// in the same reconcile pass. Retaining all stale requests is conservative, and
/// the next successful reconcile removes them. A successful add with the same
/// identifier already replaced its old request, so it must not be removed again.
func morningReminderCancellationsAfterAdding(
    plan: MorningReminderReconcilePlan,
    successfullyAddedIdentifiers: Set<String>
) -> Set<String> {
    let additionIdentifiers = Set(plan.additions.map(\.identifier))
    guard additionIdentifiers.isSubset(of: successfullyAddedIdentifiers) else { return [] }
    return plan.cancellations.subtracting(successfullyAddedIdentifiers)
}

/// One stable, idempotent morning wake schedule. A fixed UUID means updating the
/// selected time replaces the existing AlarmKit schedule instead of accumulating
/// alarms. The notification identifier remains public for NotificationRouter.
enum MorningAlarmScheduler {
    static let notificationIdentifier = "com.takmin.skygrid.morning-reminder"
    /// Reserved namespace for the future multi-schedule reminder fallback requests.
    /// The trailing dot keeps it distinct from the legacy bare identifier above.
    static let multiScheduleIdentifierPrefix = "com.takmin.skygrid.morning-reminder."
    static let alarmIdentifier = UUID(uuidString: "8A9A5E2E-4B4A-4E8B-9382-FA8E3F3EF1CB")!

    static func reminderIdentifier(scheduleID: UUID, weekday: Int) -> String {
        "\(multiScheduleIdentifierPrefix)\(scheduleID.uuidString).\(weekday)"
    }

    static var preferredKind: MorningAlarmKind {
        if #available(iOS 26.0, *), LocalDefaults.morningAlarmBackend != "reminder" { return .systemAlarm }
        return .reminder
    }

    @MainActor
    static func migrateScheduleModelIfNeeded() {
        guard LocalDefaults.morningAlarmScheduleModelVersion == 0 else { return }
        LocalDefaults.morningAlarmSchedules = MorningAlarmSchedule.migrate(
            morningAlarmEnabled: LocalDefaults.morningAlarmEnabled,
            wakeGoalMinutes: LocalDefaults.wakeGoalMinutes
        )
        LocalDefaults.morningAlarmScheduleModelVersion = 1
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
        let normalizedMinutes = normalizeWakeGoalMinutes(wakeGoalMinutes)
        let state: MorningAlarmState
        if #available(iOS 26.0, *) {
            LocalDefaults.morningAlarmBackend = "automatic"
            switch alarmKitSchedulingInput(wakeGoalMinutes: normalizedMinutes) {
            case .legacy(let minutes):
                state = await scheduleAlarmKit(minutes: minutes)
                await refreshMorningRitualFollowUps(minutes: minutes)
            case .schedules(let schedules):
                state = await scheduleAlarmKit(schedules: schedules)
                await refreshMorningRitualFollowUps(minutes: normalizedMinutes, schedules: schedules)
            }
        } else {
            state = await scheduleReminder(minutes: normalizedMinutes)
            await refreshMorningRitualFollowUps(minutes: normalizedMinutes)
        }
        return state
    }

    /// An explicit escape hatch for an iOS 26 user who declined AlarmKit. This is
    /// never selected automatically: a regular notification is not an equivalent
    /// substitute for a system alarm.
    static func enableReminderFallback(wakeGoalMinutes: Int) async -> MorningAlarmState {
        LocalDefaults.morningAlarmBackend = "reminder"
        let normalizedMinutes = normalizeWakeGoalMinutes(wakeGoalMinutes)
        return await scheduleReminderFallback(wakeGoalMinutes: normalizedMinutes)
    }

    static func disable() async {
        disableImmediately()
        await finishDisabling()
    }

    /// Clears the state that controls the next morning immediately, without
    /// waiting on the system-owned ActivityKit shutdown acknowledgement. This is
    /// used while deleting an account: a stalled Dynamic Island teardown must
    /// never keep the person on a destructive-action spinner after the server
    /// has already confirmed deletion.
    static func disableForAccountDeletion() {
        disableImmediately()
        Task {
            await finishDisabling()
        }
    }

    private static func disableImmediately() {
        if #available(iOS 26.0, *) {
            try? AlarmManager.shared.cancel(id: alarmIdentifier)
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        LocalDefaults.morningAlarmEnabled = false
        LocalDefaults.morningAlarmBackend = "automatic"
    }

    private static func finishDisabling() async {
        await MorningFollowUpScheduler.cancelAll()
        await MorningRitualActivity.end(status: .ended)
    }

    /// The follow-up nudge and the alarm share one wake time; this keeps them in
    /// lockstep every time the alarm (re)schedules, mirroring the AlarmKit
    /// cancel-then-reschedule idempotency already used for the alarm itself.
    private static func refreshMorningRitualFollowUps(minutes: Int) async {
        let today = LocalDate(date: Date(), timeZone: .current)
        await MorningFollowUpScheduler.refreshWindow(wakeGoalMinutes: minutes, today: today)
    }

    private static func refreshMorningRitualFollowUps(
        minutes: Int,
        schedules: [MorningAlarmSchedule]
    ) async {
        let today = LocalDate(date: Date(), timeZone: .current)
        await MorningFollowUpScheduler.refreshWindow(
            wakeGoalMinutes: minutes,
            schedules: schedules,
            today: today
        )
    }

    /// Uses schedule-set reconciliation once migration has persisted schedules.
    /// An empty store keeps the direct pre-migration caller behavior unchanged.
    static func reminderFallbackSchedulingInput(wakeGoalMinutes: Int) -> MorningReminderFallbackSchedulingInput {
        guard let schedules = persistedSchedulesApplyingWakeGoalMinutes(wakeGoalMinutes) else {
            return .legacy(wakeGoalMinutes)
        }
        return .schedules(schedules)
    }

    /// Uses AlarmKit schedule-set reconciliation once migration has persisted schedules.
    /// An empty store keeps the direct pre-migration caller behavior unchanged.
    static func alarmKitSchedulingInput(wakeGoalMinutes: Int) -> MorningAlarmKitSchedulingInput {
        guard let schedules = persistedSchedulesApplyingWakeGoalMinutes(wakeGoalMinutes) else {
            return .legacy(wakeGoalMinutes)
        }
        return .schedules(schedules)
    }

    /// Applies the settings wake time to a persisted schedule set before either
    /// backend reconciles it. `nil` deliberately preserves the legacy empty-store
    /// path for callers that still schedule one all-days wake alarm directly.
    private static func persistedSchedulesApplyingWakeGoalMinutes(
        _ wakeGoalMinutes: Int
    ) -> [MorningAlarmSchedule]? {
        let schedules = LocalDefaults.morningAlarmSchedules
        guard !schedules.isEmpty else { return nil }

        let updatedSchedules = schedules.applyingWakeGoalMinutes(wakeGoalMinutes)
        LocalDefaults.morningAlarmSchedules = updatedSchedules
        return updatedSchedules
    }

    private static func scheduleReminderFallback(wakeGoalMinutes: Int) async -> MorningAlarmState {
        switch reminderFallbackSchedulingInput(wakeGoalMinutes: wakeGoalMinutes) {
        case .legacy(let minutes):
            let state = await scheduleReminder(minutes: minutes)
            await refreshMorningRitualFollowUps(minutes: minutes)
            return state
        case .schedules(let schedules):
            let state = await scheduleReminders(schedules: schedules)
            await refreshMorningRitualFollowUps(minutes: wakeGoalMinutes, schedules: schedules)
            return state
        }
    }

    /// Re-issues `AlarmManager.shared.schedule(id:configuration:)` for the current
    /// wake time on every launch, while an alarm is enabled. AlarmKit persists a
    /// schedule's bound `secondaryIntent` at the moment `schedule` is called; a later
    /// app update (a new build of `OpenMorningCameraIntent`, a changed alert layout)
    /// does **not** retroactively refresh an alarm that was already scheduled by an
    /// older binary. Without this, the on-device alarm can keep firing correctly
    /// (that part is OS-owned) while its secondary button silently references stale
    /// intent behavior from whatever build was running the last time someone opened
    /// Settings and touched the toggle. `enable`/`enableReminderFallback` are already
    /// idempotent (cancel-then-reschedule under one fixed identifier), so calling this
    /// unconditionally on every cold launch is safe and does not re-prompt for
    /// authorization once it has already been granted.
    static func resyncIfNeeded() async {
        await migrateScheduleModelIfNeeded()
        guard LocalDefaults.morningAlarmEnabled else { return }
        let minutes = LocalDefaults.wakeGoalMinutes
        if LocalDefaults.morningAlarmBackend == "reminder" {
            let normalizedMinutes = normalizeWakeGoalMinutes(minutes)
            _ = await scheduleReminderFallback(wakeGoalMinutes: normalizedMinutes)
        } else {
            _ = await enable(wakeGoalMinutes: minutes)
        }
        // enable/enableReminderFallback already refresh the follow-up window as
        // part of scheduling, which is what keeps it rolling forward on every
        // cold launch.
    }

    private static func normalizeWakeGoalMinutes(_ minutes: Int) -> Int {
        min(max(minutes, 0), 23 * 60 + 59)
    }

    /// Reconciles the pre-AlarmKit fallback as one weekly local notification per
    /// enabled schedule weekday. This is deliberately additive beside the legacy
    /// single-value entry points until their callers migrate to schedule sets.
    static func scheduleReminders(schedules: [MorningAlarmSchedule]) async -> MorningAlarmState {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        let pendingOccurrences: [MorningReminderPendingOccurrence] = requests.compactMap { request -> MorningReminderPendingOccurrence? in
            guard request.identifier == notificationIdentifier
                    || request.identifier.hasPrefix(multiScheduleIdentifierPrefix)
            else { return nil }
            let trigger = request.trigger as? UNCalendarNotificationTrigger
            return MorningReminderPendingOccurrence(
                identifier: request.identifier,
                hour: trigger?.dateComponents.hour,
                minute: trigger?.dateComponents.minute
            )
        }
        let plan = morningReminderReconcilePlan(
            schedules: schedules,
            currentPendingOccurrences: pendingOccurrences
        )

        guard schedules.contains(where: \.isEnabled) else {
            center.removePendingNotificationRequests(withIdentifiers: Array(plan.cancellations))
            LocalDefaults.morningAlarmEnabled = false
            return .off(.reminder)
        }

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

        guard !plan.additions.isEmpty || !plan.cancellations.isEmpty else {
            return .scheduled(.reminder)
        }

        var addedIdentifiers = Set<String>()
        var didFail = false
        for occurrence in plan.additions {
            let content = reminderContent()
            var components = DateComponents()
            components.weekday = occurrence.weekday
            components.hour = occurrence.schedule.minutesAfterMidnight / 60
            components.minute = occurrence.schedule.minutesAfterMidnight % 60
            let request = UNNotificationRequest(
                identifier: occurrence.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            do {
                try await center.add(request)
                addedIdentifiers.insert(occurrence.identifier)
            } catch {
                didFail = true
            }
        }

        let cancellations = morningReminderCancellationsAfterAdding(
            plan: plan,
            successfullyAddedIdentifiers: addedIdentifiers
        )
        center.removePendingNotificationRequests(withIdentifiers: Array(cancellations))

        if didFail { return .failed(.reminder) }
        LocalDefaults.morningAlarmEnabled = true
        return .scheduled(.reminder)
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
            return requests.contains(where: {
                $0.identifier == notificationIdentifier
                    || $0.identifier.hasPrefix(multiScheduleIdentifierPrefix)
            })
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
        let content = reminderContent()

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

    private static func reminderContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Capture the sky"
        content.body = ""
        content.sound = .default
        content.categoryIdentifier = notificationIdentifier
        return content
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private extension MorningAlarmScheduler {
    static func scheduleAlarmKit(schedules: [MorningAlarmSchedule]) async -> MorningAlarmState {
        let manager = AlarmManager.shared
        let currentAlarms: [MorningAlarmKitScheduledAlarm]
        do {
            // AlarmKit exposes only this app's alarms. At this incremental stage,
            // that is the multi-schedule space (including the legacy fixed UUID
            // reused by migration); future re-alarm IDs will be excluded here.
            currentAlarms = try manager.alarms.map(alarmKitScheduledAlarm(from:))
        } catch {
            return .failed(.systemAlarm)
        }
        let plan = morningAlarmKitReconcilePlan(
            schedules: schedules,
            currentAlarms: currentAlarms
        )

        guard schedules.contains(where: \.isEnabled) else {
            var didFail = false
            for id in plan.cancellations {
                do {
                    try manager.cancel(id: id)
                } catch {
                    didFail = true
                }
            }
            guard !didFail else { return .failed(.systemAlarm) }
            LocalDefaults.morningAlarmEnabled = false
            return .off(.systemAlarm)
        }

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

        // Keep the soft follow-up permission request aligned with the existing
        // single-alarm path. Its result never changes whether a system alarm arms.
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])

        var didFail = false
        for schedule in plan.additions {
            do {
                _ = try await manager.schedule(
                    id: schedule.id,
                    configuration: alarmKitConfiguration(schedule: schedule)
                )
            } catch {
                didFail = true
            }
        }

        // Schedule first so a successful replacement is never followed by a
        // cancellation of the same ID; replacements are absent from this set.
        for id in plan.cancellations {
            do {
                try manager.cancel(id: id)
            } catch {
                didFail = true
            }
        }

        guard !didFail else { return .failed(.systemAlarm) }
        LocalDefaults.morningAlarmEnabled = true
        return .scheduled(.systemAlarm)
    }

    static func alarmKitScheduledAlarm(from alarm: Alarm) -> MorningAlarmKitScheduledAlarm {
        guard case .relative(let relative) = alarm.schedule,
              case .weekly(let repeatingWeekdays) = relative.repeats
        else {
            return MorningAlarmKitScheduledAlarm(id: alarm.id, hour: nil, minute: nil, weekdays: nil)
        }
        return MorningAlarmKitScheduledAlarm(
            id: alarm.id,
            hour: relative.time.hour,
            minute: relative.time.minute,
            weekdays: Set(repeatingWeekdays.compactMap(morningAlarmWeekday))
        )
    }

    static func alarmKitConfiguration(
        schedule entry: MorningAlarmSchedule
    ) -> AlarmManager.AlarmConfiguration<SkyGridAlarmMetadata> {
        let alert = makeAlertPresentation()
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: SkyGridAlarmMetadata(),
            tintColor: Color(red: 0.48, green: 0.65, blue: 0.78)
        )
        let schedule = Alarm.Schedule.relative(
            .init(
                time: .init(
                    hour: entry.minutesAfterMidnight / 60,
                    minute: entry.minutesAfterMidnight % 60
                ),
                repeats: .weekly(entry.weekdays.sorted().compactMap(morningAlarmWeekday))
            )
        )
        return .alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: MorningAlarmStoppedIntent(),
            secondaryIntent: OpenMorningCameraIntent(),
            sound: .default
        )
    }

    static func morningAlarmWeekday(_ weekday: Int) -> Locale.Weekday? {
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }

    static func morningAlarmWeekday(_ weekday: Locale.Weekday) -> Int? {
        switch weekday {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        @unknown default: return nil
        }
    }

    static func alarmKitState() async -> MorningAlarmState {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .notDetermined:
            return .needsAuthorization(.systemAlarm)
        case .denied:
            return .denied(.systemAlarm)
        case .authorized:
            let schedules = LocalDefaults.morningAlarmSchedules
            let enabledIDs = Set(schedules.filter(\.isEnabled).map(\.id))
            let requiredIDs = schedules.isEmpty ? Set([alarmIdentifier]) : enabledIDs
            guard !requiredIDs.isEmpty else { return .off(.systemAlarm) }
            let scheduledIDs = try? Set(manager.alarms.map(\.id))
            return scheduledIDs?.isSuperset(of: requiredIDs) == true
                ? .scheduled(.systemAlarm)
                : .off(.systemAlarm)
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

        // AlarmKit authorization alone does not grant UNUserNotificationCenter
        // authorization, which the follow-up nudge needs. Asking here piggybacks
        // on the one moment someone has already deliberately turned on the
        // morning wake flow, rather than a separate, unexplained prompt later. A
        // denial here only loses the soft nudge — the alarm itself is unaffected.
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])

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
            stopIntent: MorningAlarmStoppedIntent(),
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
struct SkyGridAlarmMetadata: AlarmMetadata {}

/// AlarmKit invokes this after the person dismisses their morning alarm. Opening
/// the app is intentional here: the only next step is the one-tap camera ritual.
///
/// Deliberately not `private`: App Intents are looked up by the system via their
/// mangled type name, and `private`/`fileprivate` types carry an extra file-scoped
/// discriminator in that mangled name that plain `internal` types don't — one less
/// variable in how AlarmKit resolves this type across app rebuilds.
@available(iOS 26.0, *)
struct OpenMorningCameraIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Sky Grid"
    // `openAppWhenRun` was deprecated in iOS 26.0 in favor of `supportedModes`;
    // `.foreground(.immediate)` is Apple's documented replacement for "always
    // bring the app forward when this intent runs."
    static var supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult {
        // This ends AlarmKit's own alerting UI (sound and Island presentation).
        // It intentionally does not cancel the repeating schedule; that remains
        // armed for tomorrow. The separate Live Activity is reconciled/ended once
        // the capture is confirmed.
        try? AlarmManager.shared.stop(id: MorningAlarmScheduler.alarmIdentifier)
        LocalDefaults.openCameraAfterMorningAlarm = true
        return .result()
    }
}

/// AlarmKit runs this in the app's process when the alarm's Stop button is
/// tapped — `AlarmManager` has already silenced the alarm itself by the time this
/// runs (that part is system-owned and cannot be gated on app logic; see the
/// morning-ritual dev-note for the confirmed platform constraint). This exists
/// only to start the "sky not captured yet" Live Activity for the person who just
/// dismissed the alarm without opening the camera.
///
/// Deliberately not `private`: see the comment on `OpenMorningCameraIntent` above
/// — App Intents are looked up by mangled type name, and a file-scoped access
/// modifier changes that name across rebuilds.
@available(iOS 26.0, *)
struct MorningAlarmStoppedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Sky Grid morning alarm stopped"
    static var isDiscoverable: Bool { false }
    // No `supportedModes` override: the default is background execution. This
    // must NOT bring the app forward — the person chose not to open it.

    func perform() async throws -> some IntentResult {
        let today = LocalDate(date: Date(), timeZone: .current)
        let hasPostToday = LocalDefaults.lastCapturedLocalDateID == today.docID
        await MorningRitualCoordinator.reconcile(
            today: today,
            hasPostToday: hasPostToday,
            now: Date(),
            timeZone: .current
        )
        return .result()
    }
}
#endif
