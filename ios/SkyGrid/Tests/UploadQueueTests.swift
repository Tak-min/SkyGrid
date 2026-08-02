import Testing
import Foundation
@testable import SkyGrid

@Suite("UploadQueue")
struct UploadQueueTests {
    private struct SucceedingImageUploader: ImageUploading {
        func upload(fileURL: URL, to path: String, contentType: String) async throws {}
    }

    private struct AlwaysFailingImageUploader: ImageUploading {
        struct UploadFailed: Error {}

        func upload(fileURL: URL, to path: String, contentType: String) async throws {
            throw UploadFailed()
        }
    }

    private struct PermissionDeniedImageUploader: ImageUploading {
        func upload(fileURL: URL, to path: String, contentType: String) async throws {
            throw RepositoryError.permissionDenied(underlying: "App Check rejected the request.")
        }
    }

    private actor PartialUploadState {
        private(set) var fullUploadCount = 0
        private(set) var thumbUploadCount = 0
        private var uploadedPaths: Set<String> = []

        func upload(path: String) throws {
            if path.hasSuffix("_thumb.jpg") {
                thumbUploadCount += 1
                if thumbUploadCount == 1 { throw AlwaysFailingImageUploader.UploadFailed() }
            } else {
                fullUploadCount += 1
            }
            uploadedPaths.insert(path)
        }

        func imageExists(path: String) -> Bool { uploadedPaths.contains(path) }

        func counts() -> (full: Int, thumb: Int) {
            (fullUploadCount, thumbUploadCount)
        }
    }

    private struct FailsFirstThumbnailUploader: ImageUploading {
        let state: PartialUploadState

        func upload(fileURL: URL, to path: String, contentType: String) async throws {
            try await state.upload(path: path)
        }

        func imageExists(path: String) async -> Bool {
            await state.imageExists(path: path)
        }
    }

    /// Writes real fixture bytes through `ImageFileStore` (the same path production
    /// captures use) rather than pointing at a file that was never created — a
    /// hardcoded `/tmp/skygrid-test-full.jpg` here previously let every test pass
    /// without ever proving the uploader read real bytes from the pending outbox.
    private func makeDraft(dateOffset: Int = 0, ownerUid: String = "test-uid") throws -> PostDraft {
        let date = LocalDate(year: 2026, month: 7, day: 29).adding(days: dateOffset)
        let imageID = UUID()
        let fullURL = try ImageFileStore.writePendingImage(Data("full-\(imageID)".utf8), filename: "\(imageID.uuidString).jpg")
        let thumbURL = try ImageFileStore.writePendingImage(Data("thumb-\(imageID)".utf8), filename: "\(imageID.uuidString)_thumb.jpg")
        return PostDraft(
            ownerUid: ownerUid,
            localDate: date,
            capturedAt: Date(),
            skyColor: SkyColor(uncheckedHex: "#7EA3C8"),
            minutesFromGoal: 5,
            imageID: imageID,
            localFullImageURL: fullURL,
            localThumbImageURL: thumbURL
        )
    }

    @Test("enqueue then drain transitions a pending upload to done")
    func enqueueThenDrainSucceeds() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: SucceedingImageUploader())
        try await queue.enqueue(makeDraft())

        // kick() spawns a detached drain task inside the actor; give it a moment.
        try await Task.sleep(nanoseconds: 300_000_000)

        let summary = try await queue.pendingSummary()
        #expect(summary.count == 1)
        #expect(summary.first?.state == .done)
    }

    @Test("a failing uploader retries with an incremented attempt count, never silently drops the record")
    func failingUploadRetriesWithoutDropping() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: AlwaysFailingImageUploader())
        try await queue.enqueue(makeDraft())

        try await Task.sleep(nanoseconds: 300_000_000)

        let summary = try await queue.pendingSummary()
        #expect(summary.count == 1)
        #expect(summary.first?.state == .pendingLocal)
        #expect((summary.first?.attemptCount ?? 0) >= 1)
        #expect(summary.first?.lastError != nil)
    }

    @Test("a permission failure becomes retryable in the UI without background backoff")
    func permissionFailureIsImmediatelyVisibleForManualRetry() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: PermissionDeniedImageUploader())
        try await queue.enqueue(makeDraft())

        try await Task.sleep(nanoseconds: 300_000_000)

        let summary = try await queue.pendingSummary()
        #expect(summary.count == 1)
        #expect(summary.first?.state == .failed)
        #expect(summary.first?.attemptCount == 1)
        #expect(summary.first?.lastError != nil)
    }

    @Test("a retry after the thumbnail fails does not overwrite the full image")
    func partialUploadResumesAtThumbnail() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let state = PartialUploadState()
        let queue = UploadQueue(modelContainer: container, uploader: FailsFirstThumbnailUploader(state: state))
        try await queue.enqueue(makeDraft())
        try await Task.sleep(nanoseconds: 300_000_000)

        let pending = try await queue.pendingSummary()
        let failed = try #require(pending.first)
        #expect(failed.state == .pendingLocal)
        try await queue.retryFailed(queueID: failed.queueID)
        try await Task.sleep(nanoseconds: 300_000_000)

        let completed = try await queue.pendingSummary()
        #expect(completed.first?.state == .done)
        let counts = await state.counts()
        #expect(counts.full == 1)
        #expect(counts.thumb == 2)
    }

    private actor UploadRecorder {
        private(set) var uploadedPaths: [String] = []
        func record(path: String) { uploadedPaths.append(path) }
    }

    private struct RecordingImageUploader: ImageUploading {
        let recorder: UploadRecorder
        func upload(fileURL: URL, to path: String, contentType: String) async throws {
            await recorder.record(path: path)
        }
    }

    @Test("a same-day recapture replaces the queued upload instead of being silently dropped")
    func recaptureReplacesQueuedUpload() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let recorder = UploadRecorder()
        let queue = UploadQueue(modelContainer: container, uploader: RecordingImageUploader(recorder: recorder))

        let first = try makeDraft()
        try await queue.enqueue(first)
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(try await queue.pendingSummary().first?.state == .done)

        // A second capture the same account/day: same queueID, different imageID —
        // exactly the case `enqueue`'s old dedup guard silently dropped once the
        // first row was anything but `.failed`.
        let second = try makeDraft()
        let secondDraft = PostDraft(
            ownerUid: first.ownerUid,
            localDate: first.localDate,
            capturedAt: first.capturedAt,
            skyColor: first.skyColor,
            minutesFromGoal: first.minutesFromGoal,
            imageID: second.imageID,
            localFullImageURL: second.localFullImageURL,
            localThumbImageURL: second.localThumbImageURL
        )
        try await queue.enqueue(secondDraft)
        try await Task.sleep(nanoseconds: 300_000_000)

        let afterSecond = try await queue.pendingSummary()
        #expect(afterSecond.count == 1, "the day keeps exactly one queue row, not two")
        #expect(afterSecond.first?.state == .done)

        let uploaded = await recorder.uploadedPaths
        #expect(uploaded.contains(first.imagePath), "the first capture should have uploaded")
        #expect(uploaded.contains(secondDraft.imagePath), "the replacing capture must also be uploaded, not dropped")
    }

    @Test("a missing local file fails immediately as terminal, without exhausting retries")
    func missingLocalFileFailsImmediately() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: SucceedingImageUploader())
        let draft = try makeDraft()
        // Simulate a stranded reference (e.g. an app-container reassignment) by
        // removing the pending bytes before the queue ever reads them.
        ImageFileStore.deletePendingImage(at: draft.localFullImageURL)

        try await queue.enqueue(draft)
        try await Task.sleep(nanoseconds: 300_000_000)

        let summary = try await queue.pendingSummary()
        #expect(summary.first?.state == .failed)
        #expect(summary.first?.attemptCount == 1, "must fail on the first attempt, not retry a file that will never reappear")
        #expect(summary.first?.lastError?.contains("localFileMissing") == true)
    }

    @Test("cancel removes a still-pending row and its local files")
    func cancelRollsBackAPendingRow() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: AlwaysFailingImageUploader())
        let draft = try makeDraft()
        try await queue.enqueue(draft)
        try await Task.sleep(nanoseconds: 300_000_000)

        let queueID = PendingUpload.queueID(ownerUid: draft.ownerUid, localDateID: draft.localDate.docID)
        try await queue.cancel(queueID: queueID, imageID: draft.imageID.uuidString)

        let summary = try await queue.pendingSummary()
        #expect(summary.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: draft.localFullImageURL.path))
    }

    @Test("cancel is a no-op once the row has already finished uploading")
    func cancelDoesNotUndoACompletedUpload() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: SucceedingImageUploader())
        let draft = try makeDraft()
        try await queue.enqueue(draft)
        try await Task.sleep(nanoseconds: 300_000_000)

        let queueID = PendingUpload.queueID(ownerUid: draft.ownerUid, localDateID: draft.localDate.docID)
        try await queue.cancel(queueID: queueID, imageID: draft.imageID.uuidString)

        let summary = try await queue.pendingSummary()
        #expect(summary.count == 1)
        #expect(summary.first?.state == .done)
    }

    @Test("discardOrphanedRow deletes a failed row with no recoverable local file")
    func discardOrphanedRowDeletesAnUnrecoverableFailedRow() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: AlwaysFailingImageUploader())
        let draft = try makeDraft()
        try await queue.enqueue(draft)
        try await Task.sleep(nanoseconds: 300_000_000)
        // Simulate the local bytes also being unrecoverable, matching the
        // `localFileMissing` orphan path.
        ImageFileStore.deletePendingImage(at: draft.localFullImageURL)

        let queueID = PendingUpload.queueID(ownerUid: draft.ownerUid, localDateID: draft.localDate.docID)
        try await queue.discardOrphanedRow(queueID: queueID, fullImagePath: draft.imagePath)

        let summary = try await queue.pendingSummary()
        #expect(summary.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: draft.localThumbImageURL.path))
    }

    @Test("discardOrphanedRow is a no-op when the row belongs to a different capture")
    func discardOrphanedRowIgnoresAMismatchedImagePath() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: AlwaysFailingImageUploader())
        let draft = try makeDraft()
        try await queue.enqueue(draft)
        try await Task.sleep(nanoseconds: 300_000_000)

        let queueID = PendingUpload.queueID(ownerUid: draft.ownerUid, localDateID: draft.localDate.docID)
        // A different (newer) capture's image path — must never destroy a row that
        // belongs to a capture other than the one being judged orphaned.
        try await queue.discardOrphanedRow(queueID: queueID, fullImagePath: "posts/other/other/other.jpg")

        let summary = try await queue.pendingSummary()
        #expect(summary.count == 1, "a row for a different capture must not be discarded")
    }

    @Test("discardOrphanedRow is a no-op once the row has finished uploading")
    func discardOrphanedRowIgnoresACompletedRow() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: SucceedingImageUploader())
        let draft = try makeDraft()
        try await queue.enqueue(draft)
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(try await queue.pendingSummary().first?.state == .done)

        let queueID = PendingUpload.queueID(ownerUid: draft.ownerUid, localDateID: draft.localDate.docID)
        try await queue.discardOrphanedRow(queueID: queueID, fullImagePath: draft.imagePath)

        let summary = try await queue.pendingSummary()
        #expect(summary.count == 1, "a row that already succeeded must never be discarded")
        #expect(summary.first?.state == .done)
    }

    @Test("upload queue uniqueness is scoped to account and local day")
    func differentAccountsCanQueueTheSameDay() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: AlwaysFailingImageUploader())
        let first = try makeDraft()
        let second = PostDraft(
            ownerUid: "another-account",
            localDate: first.localDate,
            capturedAt: first.capturedAt,
            skyColor: first.skyColor,
            minutesFromGoal: first.minutesFromGoal,
            imageID: UUID(),
            localFullImageURL: first.localFullImageURL,
            localThumbImageURL: first.localThumbImageURL
        )

        try await queue.enqueue(first)
        try await queue.enqueue(second)
        try await Task.sleep(nanoseconds: 300_000_000)

        let summary = try await queue.pendingSummary()
        #expect(summary.count == 2)
        #expect(Set(summary.map(\.queueID)).count == 2)
    }
}
