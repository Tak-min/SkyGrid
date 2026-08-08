import Foundation

/// Detects and repairs an orphaned "today" post — a Firestore document that exists
/// but whose referenced image will never reach Storage (see `TodayPostIntegrity`).
/// Detection is read-only and safe to run automatically; `recover(post:)` is
/// destructive (it deletes a Firestore document) and must only be invoked from an
/// explicit, user-confirmed action.
@MainActor
protocol OrphanedPostRecovering: Sendable {
    func evaluate(post: SkyPost, now: Date) async -> TodayPostIntegrity
    func recover(post: SkyPost) async throws
}

enum OrphanedPostRecoveryError: Error, Equatable {
    /// Re-evaluation immediately before deleting found the post is no longer
    /// orphaned (e.g. the upload finished in the background between the banner
    /// rendering and the user's tap). Nothing was deleted.
    case notOrphaned(TodayPostIntegrity)
    /// The document currently on the server no longer matches the post this
    /// recovery was judging (e.g. a second device captured in the meantime).
    /// Nothing was deleted.
    case postChanged
    /// A recovery attempt for this day is already in flight.
    case alreadyRecovering
    /// The post could not be authoritatively re-read before a destructive action.
    case postUnavailable
}

@MainActor
final class OrphanedPostRecovery: OrphanedPostRecovering {
    private let postRepository: any PostRepository
    private let uploadQueue: UploadQueue
    private let imageStore: any ImageUploading
    private let graceInterval: TimeInterval
    private var recoveringDateIDs: Set<String> = []

    init(
        postRepository: any PostRepository,
        uploadQueue: UploadQueue,
        imageStore: any ImageUploading,
        graceInterval: TimeInterval = PostIntegrityPolicy.graceInterval
    ) {
        self.postRepository = postRepository
        self.uploadQueue = uploadQueue
        self.imageStore = imageStore
        self.graceInterval = graceInterval
    }

    func evaluate(post: SkyPost, now: Date) async -> TodayPostIntegrity {
        async let fullPresence = imageStore.imagePresence(path: post.imagePath)
        async let thumbPresence = imageStore.imagePresence(path: post.thumbPath)

        let summaries = (try? await uploadQueue.pendingSummary()) ?? []
        let queueID = PendingUpload.queueID(ownerUid: post.ownerUid, localDateID: post.localDate.docID)
        let row = summaries.first { $0.queueID == queueID }.map {
            PostIntegrityPolicy.QueueRow(
                state: $0.state,
                fullImagePath: $0.fullImagePath,
                hasLocalFullImage: $0.hasLocalFullImage
            )
        }

        return await PostIntegrityPolicy.evaluate(
            fullImage: fullPresence,
            thumbImage: thumbPresence,
            row: row,
            postImagePath: post.imagePath,
            // `capturedAt` is client-set at shutter time; `uploadedAt` is a server
            // timestamp compared against a device clock this codebase has already
            // documented as skew-prone (see `FirebasePostRepository.createPost`).
            postAge: now.timeIntervalSince(post.capturedAt),
            graceInterval: graceInterval
        )
    }

    func recover(post: SkyPost) async throws {
        let dateID = post.localDate.docID
        guard !recoveringDateIDs.contains(dateID) else {
            throw OrphanedPostRecoveryError.alreadyRecovering
        }
        recoveringDateIDs.insert(dateID)
        defer { recoveringDateIDs.remove(dateID) }

        // Re-evaluate immediately before acting: the queue may have drained, or
        // connectivity may have returned, since whatever earlier evaluation caused
        // the caller to offer recovery.
        let verdict = await evaluate(post: post, now: Date())
        guard verdict == .orphaned else {
            throw OrphanedPostRecoveryError.notOrphaned(verdict)
        }

        // Compare-and-delete: confirm the document we're about to destroy still
        // matches the post we judged. Firestore's rules forbid `update` on this
        // document, which rules out a transactional precondition here, so this
        // narrows rather than eliminates the race against a second device capturing
        // for the same account at the same moment.
        let current = await firstValue(from: postRepository.observePost(uid: post.ownerUid, localDate: post.localDate))
        guard case .value(let current?)? = current else {
            throw OrphanedPostRecoveryError.postUnavailable
        }
        guard current.imagePath == post.imagePath else {
            throw OrphanedPostRecoveryError.postChanged
        }

        try await postRepository.deletePost(uid: post.ownerUid, localDate: post.localDate)

        // Best-effort: a failure here leaves a harmless stale row that `enqueue`'s
        // replace-on-recapture branch will overwrite. It must never fail a delete
        // that already succeeded.
        try? await uploadQueue.discardOrphanedRow(queueID: PendingUpload.queueID(ownerUid: post.ownerUid, localDateID: dateID), fullImagePath: post.imagePath)
    }

    private func firstValue<T: Sendable>(from stream: AsyncStream<T>) async -> T? {
        for await value in stream {
            return value
        }
        return nil
    }
}
