import Foundation
import SwiftData
import os

/// Serial, idempotent background upload queue for pending photo images. Firestore's
/// own offline persistence already durably handles the *post document* — this queue
/// handles ONLY the image bytes (blueprint §3.1/§5.3). Deliberately single-file-at-a-
/// time: a user posts at most one photo per morning, so parallelism would only add
/// complexity for no real throughput benefit.
///
/// Implemented as a plain custom actor rather than via the `@ModelActor` macro, so it
/// can take an injected `ImageUploading` alongside its `ModelContainer` — the macro's
/// synthesized initializer doesn't accommodate extra dependencies. All `ModelContext`
/// access stays confined to this actor's isolation domain, which is what SwiftData
/// requires for thread safety regardless of which mechanism sets the context up.
actor UploadQueue {
    private static let logger = Logger(subsystem: "com.takmin.skygrid", category: "upload")
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext?
    private let uploader: any ImageUploading
    private var drainTask: Task<Void, Never>?
    private var retryWakeTask: Task<Void, Never>?

    init(modelContainer: ModelContainer, uploader: any ImageUploading) {
        self.modelContainer = modelContainer
        self.uploader = uploader
    }

    func enqueue(_ draft: PostDraft) throws {
        let modelContext = databaseContext()
        let queueID = PendingUpload.queueID(ownerUid: draft.ownerUid, localDateID: draft.localDate.docID)
        if let existing = try modelContext.fetch(FetchDescriptor<PendingUpload>()).first(where: { $0.queueID == queueID }) {
            guard existing.imageID != draft.imageID.uuidString else {
                // The exact same capture was handed to us again (e.g. a relaunch
                // replays an in-flight publish) — idempotent no-op.
                kick()
                return
            }
            // A *different* photo for the same day. `PostPublisher.publish` always
            // calls `enqueue` before `createPost`, so whichever capture reaches here
            // last is also the one Firestore's create-only rule will accept — this
            // row must track that same capture regardless of what the previous one's
            // state was (previously this only reactivated a `.failed` row, silently
            // dropping a same-day recapture whenever the prior row was still
            // `.pendingLocal`/`.uploading`/`.done`, which let a post document and its
            // queued upload point at two different images).
            ImageFileStore.deletePendingImage(at: existing.localFullImageURL)
            ImageFileStore.deletePendingImage(at: existing.localThumbImageURL)
            existing.imageID = draft.imageID.uuidString
            existing.fullImagePath = draft.imagePath
            existing.thumbImagePath = draft.thumbPath
            existing.localFullImageURL = draft.localFullImageURL
            existing.localThumbImageURL = draft.localThumbImageURL
            existing.stateRaw = UploadState.pendingLocal.rawValue
            existing.attemptCount = 0
            existing.nextAttemptAt = Date()
            existing.lastError = nil
            try modelContext.save()
            kick()
            return
        }

        let pending = PendingUpload(draft: draft)
        modelContext.insert(pending)
        try modelContext.save()
        kick()
    }

    /// Rolls back a row when its matching Firestore write is *known* to have been
    /// permanently rejected (`RepositoryError.alreadyPostedToday`), not merely
    /// delayed — called from `PostPublisher` so a capture that lost the create-only
    /// race never proceeds to upload bytes nobody's post document will reference.
    /// A no-op if another capture has since replaced this row (see `enqueue`) or if
    /// it already finished uploading.
    func cancel(queueID: String, imageID: String) throws {
        let modelContext = databaseContext()
        guard let existing = try modelContext.fetch(FetchDescriptor<PendingUpload>()).first(where: { $0.queueID == queueID }),
              existing.imageID == imageID,
              existing.state != .done
        else { return }
        ImageFileStore.deletePendingImage(at: existing.localFullImageURL)
        ImageFileStore.deletePendingImage(at: existing.localThumbImageURL)
        modelContext.delete(existing)
        try modelContext.save()
    }

    /// Clears the row left behind by a post document that has just been confirmed
    /// orphaned (Storage never received its bytes and never will) and deleted —
    /// called from `OrphanedPostRecovery`, distinct from `cancel(queueID:imageID:)`
    /// which rolls back a row whose *own* create lost the one-post-per-day race.
    /// A no-op if a newer capture has since replaced this row (`fullImagePath`
    /// mismatch — never destroy someone else's in-flight upload) or if it has
    /// already reached `.uploading`/`.done` between evaluation and this call.
    func discardOrphanedRow(queueID: String, fullImagePath: String) throws {
        let modelContext = databaseContext()
        guard let existing = try modelContext.fetch(FetchDescriptor<PendingUpload>()).first(where: { $0.queueID == queueID }),
              existing.fullImagePath == fullImagePath,
              existing.state != .uploading && existing.state != .done
        else { return }
        ImageFileStore.deletePendingImage(at: existing.localFullImageURL)
        ImageFileStore.deletePendingImage(at: existing.localThumbImageURL)
        modelContext.delete(existing)
        try modelContext.save()
    }

    /// Idempotent: calling this while a drain is already running is a no-op — the
    /// in-flight drain picks up anything new on its next pass. Mirrors V-Mate's
    /// `RevenueCatManager.syncIdentity()` / `identitySyncTask` guard pattern.
    func kick() {
        guard drainTask == nil else { return }
        retryWakeTask?.cancel()
        retryWakeTask = nil
        drainTask = Task { [weak self] in
            await self?.drain()
            await self?.finishDrain()
        }
    }

    private func finishDrain() {
        drainTask = nil
        scheduleNextRetryIfNeeded()
    }

    func retryFailed(queueID: String) throws {
        let modelContext = databaseContext()
        guard let pending = try modelContext.fetch(FetchDescriptor<PendingUpload>()).first(where: { $0.queueID == queueID }) else {
            return
        }
        pending.stateRaw = UploadState.pendingLocal.rawValue
        pending.nextAttemptAt = Date()
        pending.attemptCount = 0
        pending.lastError = nil
        try modelContext.save()
        kick()
    }

    func pendingSummary() throws -> [PendingUploadSummary] {
        let modelContext = databaseContext()
        return try modelContext.fetch(FetchDescriptor<PendingUpload>()).map(PendingUploadSummary.init)
    }

    private func drain() async {
        purgeOrphanedPendingFiles()
        let modelContext = databaseContext()
        let terminalStates: Set<String> = [UploadState.done.rawValue, UploadState.failed.rawValue]
        while true {
            let now = Date()
            guard let next = try? modelContext.fetch(FetchDescriptor<PendingUpload>())
                .filter({ !terminalStates.contains($0.stateRaw) && $0.nextAttemptAt <= now })
                .min(by: { $0.nextAttemptAt < $1.nextAttemptAt })
            else { return }
            await upload(next)
        }
    }

    /// Deletes any pending-outbox file no row currently references — the leftovers
    /// of a capture `enqueue` superseded before it could upload. Runs once per drain
    /// cycle rather than per-enqueue; a directory listing is cheap at this app's
    /// scale (at most a handful of pending files at any time).
    private func purgeOrphanedPendingFiles() {
        let modelContext = databaseContext()
        guard let rows = try? modelContext.fetch(FetchDescriptor<PendingUpload>()) else { return }
        var keep: Set<String> = []
        for row in rows {
            keep.insert(row.localFullImageURL.lastPathComponent)
            keep.insert(row.localThumbImageURL.lastPathComponent)
        }
        ImageFileStore.purgeOrphanedPendingImages(keeping: keep)
    }

    private func upload(_ pending: PendingUpload) async {
        let modelContext = databaseContext()
        pending.stateRaw = UploadState.uploading.rawValue
        try? modelContext.save()

        // Re-resolve both paths from their filename under the *current* app
        // container rather than trusting the persisted absolute `URL` — see
        // `ImageFileStore.pendingImageURL`.
        let fullImageURL = ImageFileStore.pendingImageURL(filename: pending.localFullImageURL.lastPathComponent)
        let thumbImageURL = ImageFileStore.pendingImageURL(filename: pending.localThumbImageURL.lastPathComponent)

        do {
            // Storage Rules permit a create but not an overwrite. Checking each
            // immutable path lets a restarted queue resume after full succeeded and
            // thumb failed, without changing the persisted SwiftData schema.
            try await uploadIfNeeded(remotePath: pending.fullImagePath, localURL: fullImageURL)
            try await uploadIfNeeded(remotePath: pending.thumbImagePath, localURL: thumbImageURL)
            pending.stateRaw = UploadState.done.rawValue
            pending.lastError = nil
            ImageFileStore.deletePendingImage(at: fullImageURL)
            ImageFileStore.deletePendingImage(at: thumbImageURL)
        } catch {
            pending.attemptCount += 1
            pending.lastError = String(describing: error)
            Self.logger.error("Upload attempt \(pending.attemptCount, privacy: .public) for \(pending.queueID, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            // Authentication, App Check and Storage Rules failures are not
            // transient. Keep the local JPEGs and expose Retry now immediately
            // instead of spending several exponential-backoff attempts on an
            // operation that cannot recover by itself.
            if Self.isTerminal(error) || pending.attemptCount >= RetryPolicy.maxAttempts {
                pending.stateRaw = UploadState.failed.rawValue
            } else {
                pending.stateRaw = UploadState.pendingLocal.rawValue
                pending.nextAttemptAt = Date().addingTimeInterval(RetryPolicy.delay(forAttempt: pending.attemptCount))
            }
        }
        try? modelContext.save()
    }

    private func uploadIfNeeded(remotePath: String, localURL: URL) async throws {
        guard !(await uploader.imageExists(path: remotePath)) else { return }
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw UploadQueueError.localFileMissing
        }
        try await uploader.upload(fileURL: localURL, to: remotePath, contentType: "image/jpeg")
    }

    private static func isTerminal(_ error: Error) -> Bool {
        switch error {
        case RepositoryError.notAuthenticated, RepositoryError.permissionDenied:
            return true
        case UploadQueueError.localFileMissing:
            return true
        default:
            return false
        }
    }

    /// A failed attempt should retry even if the app remains foregrounded and no
    /// connectivity event arrives. The wake task is deliberately one-shot: after it
    /// fires, `drain()` computes the next earliest due item again.
    private func scheduleNextRetryIfNeeded() {
        let modelContext = databaseContext()
        let terminalStates: Set<String> = [UploadState.done.rawValue, UploadState.failed.rawValue]
        guard let next = (try? modelContext.fetch(FetchDescriptor<PendingUpload>()))?
            .filter({ !terminalStates.contains($0.stateRaw) })
            .min(by: { $0.nextAttemptAt < $1.nextAttemptAt }),
              next.nextAttemptAt > Date()
        else { return }

        let wait = next.nextAttemptAt.timeIntervalSinceNow
        retryWakeTask = Task { [weak self] in
            guard wait > 0 else {
                await self?.kick()
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.kick()
        }
    }

    /// Actor initializers run on the caller's executor. Constructing `ModelContext`
    /// there binds it to the main queue and later produces a SwiftData concurrency
    /// warning. Delaying construction until this actor handles its first message
    /// binds the context to the queue that owns every subsequent access.
    private func databaseContext() -> ModelContext {
        if let modelContext { return modelContext }
        let context = ModelContext(modelContainer)
        modelContext = context
        return context
    }
}

private enum UploadQueueError: Error {
    case localFileMissing
}
