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
    private let postRepository: any PostRepository
    private let uploadQueue: UploadQueue

    init(postRepository: any PostRepository, uploadQueue: UploadQueue) {
        self.postRepository = postRepository
        self.uploadQueue = uploadQueue
    }

    func publish(_ draft: PostDraft) async throws {
        // Persist the image outbox before awaiting Firestore. Firestore queues an
        // offline write durably but its completion does not arrive until the
        // server acknowledges it; the previous order could therefore lose the
        // only local record of a photo if the app was terminated offline.
        try await uploadQueue.enqueue(draft)

        do {
            try await postRepository.createPost(draft)
        } catch RepositoryError.alreadyPostedToday {
            // Unlike a transient failure, this is a *permanent* rejection — Firestore's
            // create-only rule means no retry of this draft will ever succeed. Roll
            // back the outbox row so it doesn't upload bytes no post document will
            // ever reference (the accepted capture already owns this queue slot).
            try? await uploadQueue.cancel(
                queueID: PendingUpload.queueID(ownerUid: draft.ownerUid, localDateID: draft.localDate.docID),
                imageID: draft.imageID.uuidString
            )
            throw RepositoryError.alreadyPostedToday
        } catch {
            // Keep the locally durable outbox and its Application Support files.
            // A transient Firestore/App Check failure must never destroy a morning
            // capture. The queue will resume its Storage half once the dependency
            // recovers, while Firestore's own offline persistence retains its write.
            throw error
        }
    }
}
