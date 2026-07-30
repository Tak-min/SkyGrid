import Foundation

/// A deliberately small audit record for a post-concern report. The reporting
/// user never has to label another person as fraudulent; moderation can make that
/// determination later.
struct ContentReport: Hashable, Sendable {
    let id: UUID
    let reporterUid: String
    let subjectUid: String
    let createdAt: Date
    let status: Status

    enum Status: String, Sendable {
        case received
    }
}
