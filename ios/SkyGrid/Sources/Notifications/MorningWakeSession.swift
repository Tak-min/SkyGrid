import Foundation

/// Durable ownership of the capture-required part of a morning alarm. AlarmKit
/// owns the currently sounding alert, so Sky Grid enforces the ritual by arming
/// bounded, genuine one-shot alarms after either alarm action until a local
/// capture commit completes the session.
struct MorningWakeSession: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Equatable, Sendable {
        case awaitingCapture
        case completed
    }

    let wakeDayID: String
    let sourceAlarmID: UUID
    let startedAt: Date
    let deadline: Date
    var phase: Phase
    var pendingRetries: [MorningWakeRetry]

    var pendingRetryAlarmIDs: [UUID] { pendingRetries.map(\.id) }

    func isActive(today: LocalDate, now: Date) -> Bool {
        phase == .awaitingCapture && wakeDayID == today.docID && now < deadline
    }
}

struct MorningWakeRetry: Codable, Equatable, Sendable {
    let id: UUID
    let fireDate: Date
}

func morningWakeRetryDates(
    pending: [MorningWakeRetry],
    consumedAlarmID: UUID?,
    now: Date,
    deadline: Date,
    desiredPendingCount: Int = MorningRealarmPolicy.maximumAttempts
) -> (retained: [MorningWakeRetry], additions: [Date]) {
    let retained = pending
        .filter { $0.id != consumedAlarmID && $0.fireDate > now }
        .sorted { $0.fireDate < $1.fireDate }
    var cursor = max(retained.last?.fireDate ?? now, now)
    var additions: [Date] = []
    while retained.count + additions.count < desiredPendingCount {
        cursor = cursor.addingTimeInterval(MorningRealarmPolicy.interval)
        guard cursor < deadline else { break }
        additions.append(cursor)
    }
    return (retained, additions)
}

enum MorningWakeSessionDecision: Equatable, Sendable {
    case start(deadline: Date)
    case resume(MorningWakeSession)
    case clear(MorningWakeSession?)
}

enum MorningCaptureSessionEndReason: String, Sendable {
    case cameraUnavailable
    case permissionDenied
    case userEndedAfterFailure
}

func morningWakeSessionDecision(
    existing: MorningWakeSession?,
    wakeDay: LocalDate,
    now: Date,
    timeZone: TimeZone,
    hasCaptured: Bool
) -> MorningWakeSessionDecision {
    guard !hasCaptured else { return .clear(existing) }
    if let existing, existing.isActive(today: wakeDay, now: now) {
        return .resume(existing)
    }
    if let existing, existing.wakeDayID == wakeDay.docID {
        return .clear(existing)
    }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: now),
          let dayBoundary = calendar.dateInterval(of: .day, for: nextDay)?.start
    else { return .clear(existing) }
    let deadline = min(now.addingTimeInterval(MorningRitualAttributes.captureWindow), dayBoundary)
    return deadline > now ? .start(deadline: deadline) : .clear(existing)
}
