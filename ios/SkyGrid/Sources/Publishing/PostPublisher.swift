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
        do {
            try await postRepository.createPost(draft)
        } catch {
            removeCapturedFiles(for: draft)
            throw error
        }

        do {
            try await uploadQueue.enqueue(draft)
        } catch {
            // Do not leave a successful-looking post whose image can never be
            // retried. This is deliberately best-effort compensation; Firestore
            // remains the durable source for the record while SwiftData owns bytes.
            try? await postRepository.deletePost(uid: draft.ownerUid, localDate: draft.localDate)
            removeCapturedFiles(for: draft)
            throw error
        }
    }

    private func removeCapturedFiles(for draft: PostDraft) {
        ImageFileStore.deletePendingImage(at: draft.localFullImageURL)
        ImageFileStore.deletePendingImage(at: draft.localThumbImageURL)
    }
}
