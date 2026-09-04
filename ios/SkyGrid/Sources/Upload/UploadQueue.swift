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
    /// Production injects the Firestore repository so a staged row can resume its
    /// document create after a process death. `nil` preserves the old upload-only
    /// behavior for isolated legacy tests and UI audit data.
    private let postRepository: (any PostRepository)?
    private var drainTask: Task<Void, Never>?
    private var retryWakeTask: Task<Void, Never>?
    /// Account deletion temporarily fences a UID before the server-side callable
    /// runs. A queued retry must not recreate Storage bytes while that callable is
    /// deleting the same account.
    private var suspendedOwnerUIDs: Set<String> = []

    init(
        modelContainer: ModelContainer,
        uploader: any ImageUploading,
        postRepository: (any PostRepository)? = nil
    ) {
        self.modelContainer = modelContainer
        self.uploader = uploader
        self.postRepository = postRepository
    }

    /// Persists the full post payload before beginning network work. It returns as
    /// soon as the device owns a recoverable copy; Firestore/Storage then progress
    /// through the durable state machine without keeping the camera open offline.
    func enqueue(_ draft: PostDraft) async throws {
        guard !suspendedOwnerUIDs.contains(draft.ownerUid) else {
            throw RepositoryError.notAuthenticated
        }
        let modelContext = databaseContext()
        let queueID = PendingUpload.queueID(ownerUid: draft.ownerUid, localDateID: draft.localDate.docID)
        if let existing = try modelContext.fetch(FetchDescriptor<PendingUpload>()).first(where: { $0.queueID == queueID }) {
            guard existing.imageID != draft.imageID.uuidString else {
                // The exact same capture was handed to us again (e.g. a relaunch
                // replays an in-flight publish) — resume rather than duplicate it.
                kick()
                return
            }
            // Replacing a durable row while its Firestore create or Storage upload
            // is in flight can make the eventual document point at a different
            // image. Preserve the original capture and let the UI explain that it
            // is still being resolved instead of silently discarding either photo.
            throw RepositoryError.captureAlreadyPending
        }

        let pending = PendingUpload(draft: draft)
        modelContext.insert(pending)
        try modelContext.save()
        kick()
        Task { @MainActor in
            BackgroundUploadScheduler.schedule()
        }
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
        try discardRow(queueID: queueID, fullImagePath: fullImagePath)
    }

    /// Clears a row whose `localDate` has aged past what `firestore.rules`'
    /// `isRecentLocalDate` will still accept (see `PostCreateWindowPolicy`) —
    /// called from `TodayViewModel` once the UI has told the person their photo
    /// can no longer be sent, distinct in *reason* from `discardOrphanedRow`
    /// (server-confirmed-orphaned) even though both end a row the same way: the
    /// local bytes are retained nowhere else, so this is explicit-user-action
    /// only, never automatic. Same guards as `discardOrphanedRow` — a no-op if a
    /// newer capture has replaced this row, or if it already reached
    /// `.uploading`/`.done` between the UI decision and this call.
    func discardStaleUpload(queueID: String, fullImagePath: String) throws {
        try discardRow(queueID: queueID, fullImagePath: fullImagePath)
    }

    private func discardRow(queueID: String, fullImagePath: String) throws {
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

    /// Used by iOS's finite `BGProcessingTask` window. Unlike `kick()`, this
    /// waits for the current drain so the system receives a truthful completion
    /// signal when the background execution window ends.
    func processScheduledWork() async {
        kick()
        if let drainTask {
            await drainTask.value
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
        switch pending.state {
        case .stagedPost, .postFailed:
            pending.stateRaw = UploadState.stagedPost.rawValue
        case .pendingLocal, .failed:
            pending.stateRaw = UploadState.pendingLocal.rawValue
        case .uploading, .done, .postConflict:
            return
        }
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

    /// Stops an account's in-flight retry cycle without discarding its only local
    /// capture yet. If the deletion callable fails, `resumeAccount` makes the
    /// exact durable row eligible to continue again.
    func suspendAccount(_ ownerUid: String) {
        suspendedOwnerUIDs.insert(ownerUid)
        drainTask?.cancel()
        retryWakeTask?.cancel()
        retryWakeTask = nil
    }

    func resumeAccount(_ ownerUid: String) {
        suspendedOwnerUIDs.remove(ownerUid)
        kick()
    }

    /// Called only after the deletion callable confirms the account is gone. The
    /// SwiftData container remains open; unlinking `default.store` while its
    /// context is alive corrupts SQLite and can crash the app. Deleting rows
    /// through the owning context clears the outbox safely instead.
    func discardAccountData(_ ownerUid: String) {
        suspendedOwnerUIDs.insert(ownerUid)
        drainTask?.cancel()
        retryWakeTask?.cancel()
        retryWakeTask = nil

        let modelContext = databaseContext()
        let rows = (try? modelContext.fetch(FetchDescriptor<PendingUpload>())) ?? []
        for row in rows where row.ownerUid == ownerUid {
            ImageFileStore.deletePendingImage(at: row.localFullImageURL)
            ImageFileStore.deletePendingImage(at: row.localThumbImageURL)
            modelContext.delete(row)
        }
        try? modelContext.save()
    }

    private func drain() async {
        purgeOrphanedPendingFiles()
        let modelContext = databaseContext()
        let terminalStates: Set<String> = [
            UploadState.done.rawValue,
            UploadState.failed.rawValue,
            UploadState.postFailed.rawValue,
            UploadState.postConflict.rawValue,
        ]
        while true {
            let now = Date()
            guard let next = try? modelContext.fetch(FetchDescriptor<PendingUpload>())
                .filter({
                    !terminalStates.contains($0.stateRaw)
                        && !suspendedOwnerUIDs.contains($0.ownerUid)
                        && $0.nextAttemptAt <= now
                })
                .min(by: { $0.nextAttemptAt < $1.nextAttemptAt })
            else { return }
            switch next.state {
            case .stagedPost:
                await commitPost(next)
            case .pendingLocal, .uploading:
                await upload(next)
            case .done, .postFailed, .postConflict, .failed:
                return
            }
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

    /// Performs the Firestore half before a row becomes eligible for Storage. A
    /// crash at any await point leaves enough data in `PendingUpload` to resume the
    /// same create, rather than uploading bytes that no post can reference.
    private func commitPost(_ pending: PendingUpload) async {
        let job = UploadJob(pending)
        guard job.state == .stagedPost, !suspendedOwnerUIDs.contains(job.ownerUid) else { return }

        guard let postRepository else {
            // Isolated legacy tests have no Firestore backend. Production always
            // injects one; keeping this branch preserves those upload-only tests.
            markUploadReady(job)
            return
        }
        guard let draft = pending.postDraft() else {
            markPostFailure(job, error: UploadQueueError.postPayloadMissing)
            return
        }

        do {
            try await postRepository.createPost(draft)
            markUploadReady(job)
        } catch RepositoryError.alreadyPostedToday {
            await reconcileDuplicate(job, using: postRepository)
        } catch {
            markPostFailure(job, error: error)
        }
    }

    /// A duplicate can be the same write whose server acknowledgement raced a
    /// process termination. Compare both immutable paths before deciding whether to
    /// activate the upload or retain it as a conflict for the person to resolve.
    private func reconcileDuplicate(_ job: UploadJob, using repository: any PostRepository) async {
        do {
            guard let localDate = LocalDate(docID: job.localDateID) else {
                markPostFailure(job, error: UploadQueueError.postPayloadMissing)
                return
            }
            guard let existing = try await repository.fetchPost(uid: job.ownerUid, localDate: localDate) else {
                markPostFailure(job, error: RepositoryError.network(underlying: "The post could not be verified."))
                return
            }
            guard existing.imagePath == job.fullImagePath, existing.thumbPath == job.thumbImagePath else {
                markPostConflict(job)
                return
            }
            markUploadReady(job)
        } catch {
            markPostFailure(job, error: error)
        }
    }

    private func markUploadReady(_ job: UploadJob) {
        guard let pending = matching(job, expectedState: .stagedPost) else { return }
        pending.stateRaw = UploadState.pendingLocal.rawValue
        pending.attemptCount = 0
        pending.nextAttemptAt = Date()
        pending.lastError = nil
        try? databaseContext().save()
    }

    private func markPostConflict(_ job: UploadJob) {
        guard let pending = matching(job, expectedState: .stagedPost) else { return }
        pending.stateRaw = UploadState.postConflict.rawValue
        pending.lastError = "Another photo already owns this day."
        try? databaseContext().save()
    }

    private func markPostFailure(_ job: UploadJob, error: Error) {
        guard let pending = matching(job, expectedState: .stagedPost) else { return }
        pending.attemptCount += 1
        pending.lastError = String(describing: error)
        Self.logger.error("Post commit attempt \(pending.attemptCount, privacy: .public) for \(pending.queueID, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        if Self.isTerminal(error) || pending.attemptCount >= RetryPolicy.maxAttempts {
            pending.stateRaw = UploadState.postFailed.rawValue
        } else {
            pending.stateRaw = UploadState.stagedPost.rawValue
            pending.nextAttemptAt = Date().addingTimeInterval(RetryPolicy.delay(forAttempt: pending.attemptCount))
        }
        try? databaseContext().save()
    }

    private func upload(_ pending: PendingUpload) async {
        // SwiftData models are mutable reference objects. Take an immutable copy
        // before any await, then conditionally apply the outcome to the same image
        // only. This prevents an old task from completing over a newer capture.
        let job = UploadJob(pending)
        guard !suspendedOwnerUIDs.contains(job.ownerUid),
              (job.state == .pendingLocal || job.state == .uploading),
              let current = matching(job) else { return }
        current.stateRaw = UploadState.uploading.rawValue
        try? databaseContext().save()

        let fullImageURL = ImageFileStore.pendingImageURL(filename: job.fullFilename)
        let thumbImageURL = ImageFileStore.pendingImageURL(filename: job.thumbFilename)

        do {
            // Storage Rules permit a create but not an overwrite. Checking each
            // immutable path lets a restarted queue resume after full succeeded and
            // thumb failed without changing the remote object name.
            try await uploadIfNeeded(remotePath: job.fullImagePath, localURL: fullImageURL)
            try await uploadIfNeeded(remotePath: job.thumbImagePath, localURL: thumbImageURL)
            guard let current = matching(job, expectedState: .uploading) else { return }
            // Both remote objects have acknowledged creation. Promote the exact
            // bytes locally before removing the outbox files, so a new Today card
            // reads the same capture immediately instead of downloading it again.
            ImageFileStore.promotePendingImage(at: fullImageURL, forRemotePath: job.fullImagePath)
            ImageFileStore.promotePendingThumbnail(at: thumbImageURL, forRemotePath: job.thumbImagePath)
            current.stateRaw = UploadState.done.rawValue
            current.lastError = nil
            try? databaseContext().save()
            ImageFileStore.deletePendingImage(at: fullImageURL)
            ImageFileStore.deletePendingImage(at: thumbImageURL)
        } catch {
            guard let current = matching(job, expectedState: .uploading) else { return }
            current.attemptCount += 1
            current.lastError = String(describing: error)
            Self.logger.error("Upload attempt \(current.attemptCount, privacy: .public) for \(current.queueID, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            // Authentication, App Check and Storage Rules failures are not
            // transient. Keep the local JPEGs and expose Retry now immediately
            // instead of spending several exponential-backoff attempts on an
            // operation that cannot recover by itself.
            if Self.isTerminal(error) || current.attemptCount >= RetryPolicy.maxAttempts {
                current.stateRaw = UploadState.failed.rawValue
            } else {
                current.stateRaw = UploadState.pendingLocal.rawValue
                current.nextAttemptAt = Date().addingTimeInterval(RetryPolicy.delay(forAttempt: current.attemptCount))
            }
            try? databaseContext().save()
        }
    }

    private func matching(_ job: UploadJob, expectedState: UploadState? = nil) -> PendingUpload? {
        guard let pending = try? databaseContext().fetch(FetchDescriptor<PendingUpload>())
            .first(where: { $0.queueID == job.queueID && $0.imageID == job.imageID })
        else { return nil }
        guard expectedState == nil || pending.state == expectedState else { return nil }
        return pending
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
        let terminalStates: Set<String> = [
            UploadState.done.rawValue,
            UploadState.failed.rawValue,
            UploadState.postFailed.rawValue,
            UploadState.postConflict.rawValue,
        ]
        guard let next = (try? modelContext.fetch(FetchDescriptor<PendingUpload>()))?
            .filter({ !terminalStates.contains($0.stateRaw) && !suspendedOwnerUIDs.contains($0.ownerUid) })
            .min(by: { $0.nextAttemptAt < $1.nextAttemptAt }),
              next.nextAttemptAt > Date()
        else { return }

        let wait = next.nextAttemptAt.timeIntervalSinceNow
        Task { @MainActor in
            BackgroundUploadScheduler.schedule(earliestBeginDate: next.nextAttemptAt)
        }
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

/// An immutable projection of the SwiftData model, safe to retain across Firebase
/// and Storage awaits. Applying any result requires `queueID + imageID` to still
/// match the current row.
private struct UploadJob: Sendable {
    let queueID: String
    let imageID: String
    let ownerUid: String
    let localDateID: String
    let fullImagePath: String
    let thumbImagePath: String
    let fullFilename: String
    let thumbFilename: String
    let state: UploadState

    init(_ pending: PendingUpload) {
        queueID = pending.queueID
        imageID = pending.imageID
        ownerUid = pending.ownerUid
        localDateID = pending.localDateID
        fullImagePath = pending.fullImagePath
        thumbImagePath = pending.thumbImagePath
        fullFilename = pending.localFullImageURL.lastPathComponent
        thumbFilename = pending.localThumbImageURL.lastPathComponent
        state = pending.state
    }
}

private enum UploadQueueError: Error {
    case localFileMissing
    case postPayloadMissing
}
