import FirebaseAnalytics
import FirebaseCore

/// Anonymous configuration telemetry. Times, weekdays, labels, notification IDs,
/// and account identifiers are deliberately excluded; only aggregate counts are
/// needed to learn whether multiple alarms improve the capture path.
enum MorningAlarmAnalytics {
    enum WakeSessionEndReason: String {
        case captured
        case deadline
        case disabled
        case cameraFailure = "camera_failure"
    }

    static func recordScheduleChanged(
        schedules: [MorningAlarmSchedule],
        kind: MorningAlarmKind,
        succeeded: Bool
    ) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent("skygrid_alarm_schedule_changed", parameters: [
            "schedule_count": schedules.count,
            "enabled_count": schedules.filter(\.isEnabled).count,
            "backend": kind == .systemAlarm ? "alarmkit" : "reminder",
            "succeeded": succeeded ? 1 : 0,
            "schema_version": 1,
        ])
    }

    static func recordWakeSessionStarted() {
        recordWakeSessionEvent("skygrid_wake_session_started")
    }

    static func recordRetryHorizonRefilled() {
        recordWakeSessionEvent("skygrid_wake_retry_horizon_refilled")
    }

    static func recordWakeSessionEnded(reason: WakeSessionEndReason) {
        recordWakeSessionEvent("skygrid_wake_session_ended", parameters: ["reason": reason.rawValue])
    }

    private static func recordWakeSessionEvent(
        _ name: String,
        parameters: [String: Any] = [:]
    ) {
        guard FirebaseApp.app() != nil else { return }
        var payload = parameters
        payload["schema_version"] = 1
        Analytics.logEvent(name, parameters: payload)
    }
}
