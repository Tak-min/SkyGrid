import Testing
import Foundation
@testable import SkyGrid

@Suite("OrphanedPostRecovery")
@MainActor
struct OrphanedPostRecoveryTests {
    private struct SucceedingImageUploader: ImageUploading {
        func upload(fileURL: URL, to path: String, contentType: String) async throws {}
    }

    /// Reports a fixed presence for every path — enough to drive
    /// `PostIntegrityPolicy` without touching real Storage.
    private struct FixedPresenceImageUploader: ImageUploading {
        let presence: RemoteImagePresence
        func upload(fileURL: URL, to path: String, contentType: String) async throws {}
        func imagePresence(path: String) async -> RemoteImagePresence { presence }
    }

    /// A `PostRepository` fake whose `observePost` always yields `currentPost` (the
    /// server's current view, independent of the `post` the recovery call was given —
    /// this is what lets tests exercise the compare-and-delete guard), and which
    /// records every `deletePost` invocation.
    @MainActor
    private final class RecordingPostRepository: PostRepository {
        var currentPost: SkyPost?
        private(set) var deleteCallCount = 0
        private(set) var deletedDates: [LocalDate] = []

        init(currentPost: SkyPost?) {
            self.currentPost = currentPost
        }

        func observePost(uid: String, localDate: LocalDate) -> AsyncStream<SkyPost?> {
            let value = currentPost
            return AsyncStream { continuation in
                continuation.yield(value)
                continuation.finish()
            }
        }

        func observePosts(uid: String, from: LocalDate, through: LocalDate) -> AsyncStream<[SkyPost]> {
            AsyncStream { continuation in
                continuation.yield([])
                continuation.finish()
            }
        }

        func createPost(_ draft: PostDraft) async throws {}

        func deletePost(uid: String, localDate: LocalDate) async throws {
            deleteCallCount += 1
            deletedDates.append(localDate)
            currentPost = nil
        }
    }

    private func makePost(imagePath: String = "posts/uid/2026-08-02/image.jpg", capturedAt: Date = Date().addingTimeInterval(-300)) -> SkyPost {
        SkyPost(
            ownerUid: "uid",
            localDate: LocalDate(year: 2026, month: 8, day: 2),
            capturedAt: capturedAt,
            uploadedAt: capturedAt,
            imagePath: imagePath,
            thumbPath: imagePath.replacingOccurrences(of: ".jpg", with: "_thumb.jpg"),
            skyColor: SkyColor(uncheckedHex: "#7EA3C8"),
            minutesFromGoal: 0,
            reactions: [:]
        )
    }

    @Test("evaluate never reports orphaned when Storage still holds the image")
    func evaluateNeverOrphansAnIntactPost() async throws {
        let post = makePost()
        let repository = RecordingPostRepository(currentPost: post)
        let queue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: SucceedingImageUploader())
        let recovery = OrphanedPostRecovery(postRepository: repository, uploadQueue: queue, imageStore: FixedPresenceImageUploader(presence: .present))

        let verdict = await recovery.evaluate(post: post, now: Date())
        #expect(verdict == .intact)
    }

    @Test("recover refuses to delete when Storage read is indeterminate (App Check / offline regression guard)")
    func recoverRefusesWhenIndeterminate() async throws {
        let post = makePost()
        let repository = RecordingPostRepository(currentPost: post)
        let queue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: SucceedingImageUploader())
        let recovery = OrphanedPostRecovery(postRepository: repository, uploadQueue: queue, imageStore: FixedPresenceImageUploader(presence: .indeterminate))

        await #expect(throws: OrphanedPostRecoveryError.notOrphaned(.undetermined)) {
            try await recovery.recover(post: post)
        }
        #expect(repository.deleteCallCount == 0)
    }

    @Test("recover deletes and clears the queue row when no local row exists at all (loss scenario b)")
    func recoverHandlesMissingQueueRow() async throws {
        let post = makePost()
        let repository = RecordingPostRepository(currentPost: post)
        let queue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: SucceedingImageUploader())
        let recovery = OrphanedPostRecovery(postRepository: repository, uploadQueue: queue, imageStore: FixedPresenceImageUploader(presence: .absent))

        try await recovery.recover(post: post)

        #expect(repository.deleteCallCount == 1)
        #expect(repository.deletedDates == [post.localDate])
    }

    @Test("recover deletes and discards a failed row with no recoverable local file (loss scenario a)")
    func recoverHandlesFailedRowWithNoLocalFile() async throws {
        let post = makePost()

        let imageID = UUID()
        let fullURL = try ImageFileStore.writePendingImage(Data("full".utf8), filename: "\(imageID.uuidString).jpg")
        let thumbURL = try ImageFileStore.writePendingImage(Data("thumb".utf8), filename: "\(imageID.uuidString)_thumb.jpg")
        let draft = PostDraft(
            ownerUid: post.ownerUid,
            localDate: post.localDate,
            capturedAt: post.capturedAt,
            skyColor: post.skyColor,
            minutesFromGoal: post.minutesFromGoal,
            imageID: imageID,
            localFullImageURL: fullURL,
            localThumbImageURL: thumbURL
        )
        // A terminal (permission-denied) failure drives the row straight to
        // `.failed` after one attempt — see `UploadQueue.isTerminal` — then the
        // local file is removed to reproduce the unrecoverable case
        // (`hasLocalFullImage == false`).
        struct FailingUploader: ImageUploading {
            func upload(fileURL: URL, to path: String, contentType: String) async throws {
                throw RepositoryError.permissionDenied(underlying: "App Check rejected the request.")
            }
        }
        let failingQueue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: FailingUploader())
        try await failingQueue.enqueue(draft)
        try await Task.sleep(nanoseconds: 300_000_000)
        ImageFileStore.deletePendingImage(at: fullURL)

        let unrecoverablePost = makePost(imagePath: draft.imagePath, capturedAt: post.capturedAt)
        let unrecoverableRepository = RecordingPostRepository(currentPost: unrecoverablePost)
        let recovery = OrphanedPostRecovery(postRepository: unrecoverableRepository, uploadQueue: failingQueue, imageStore: FixedPresenceImageUploader(presence: .absent))

        try await recovery.recover(post: unrecoverablePost)

        #expect(unrecoverableRepository.deleteCallCount == 1)
        let remaining = try await failingQueue.pendingSummary()
        #expect(remaining.isEmpty, "the failed row must be discarded once the post it belonged to is deleted")
    }

    @Test("recover throws postChanged and deletes nothing when the server doc no longer matches")
    func recoverRefusesWhenServerDocChanged() async throws {
        let judgedPost = makePost(imagePath: "posts/uid/2026-08-02/old.jpg")
        let currentPost = makePost(imagePath: "posts/uid/2026-08-02/new.jpg")
        let repository = RecordingPostRepository(currentPost: currentPost)
        let queue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: SucceedingImageUploader())
        let recovery = OrphanedPostRecovery(postRepository: repository, uploadQueue: queue, imageStore: FixedPresenceImageUploader(presence: .absent))

        await #expect(throws: OrphanedPostRecoveryError.postChanged) {
            try await recovery.recover(post: judgedPost)
        }
        #expect(repository.deleteCallCount == 0)
    }

    @Test("two concurrent recover calls for the same day produce exactly one delete")
    func concurrentRecoverCallsAreSerialized() async throws {
        let post = makePost()
        let repository = RecordingPostRepository(currentPost: post)
        let queue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: SucceedingImageUploader())
        let recovery = OrphanedPostRecovery(postRepository: repository, uploadQueue: queue, imageStore: FixedPresenceImageUploader(presence: .absent))

        async let first: () = recovery.recover(post: post)
        async let second: () = recovery.recover(post: post)
        _ = try? await first
        _ = try? await second

        #expect(repository.deleteCallCount == 1)
    }
}
