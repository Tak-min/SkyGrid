import Foundation

/// Commits the two durable parts of a capture as one user-visible action. A capture
/// is never reported as complete until both the local post and its upload outbox row
/// have been written. The two stores cannot share a database transaction, so this
/// service performs the small, explicit compensation needed by the independent
/// Firestore and SwiftData stores.
@MainActor
protocol PostPublishing: Sendable {
    func publish(_ draft: PostDraft) async throws
}

@MainActor
final class PostPublisher: PostPublishing {
    private let uploadQueue: UploadQueue

    init(uploadQueue: UploadQueue) {
        self.uploadQueue = uploadQueue
    }

    func publish(_ draft: PostDraft) async throws {
        // `enqueue` persists both JPEG locations and the Firestore payload before
        // networking. Its state machine commits Firestore first and only then makes
        // the row eligible for Storage, so an offline capture can close promptly
        // without ever uploading orphaned bytes.
        try await uploadQueue.enqueue(draft)
    }
}
