import Foundation

@MainActor
protocol ContentSafetyRepository: Sendable {
    /// Records a moderation request. A Firebase implementation will persist the
    /// same immutable record to `reports/` for staff triage.
    func submitConcern(reporterUid: String, subjectUid: String) async throws
}
