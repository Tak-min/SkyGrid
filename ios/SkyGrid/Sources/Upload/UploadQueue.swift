import Foundation
import SwiftData

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
        if try modelContext.fetch(FetchDescriptor<PendingUpload>()).contains(where: { $0.queueID == queueID }) {
            // The durable post repository has already rejected a second post for
            // this day. Treat a replay of the same outbox write as idempotent.
            kick()
            return
        }

        let pending = PendingUpload(draft: draft)
        modelContext.insert(pending)
        try modelContext.save()
        kick()
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
        try modelContext.save()
        kick()
    }

    func pendingSummary() throws -> [PendingUploadSummary] {
        let modelContext = databaseContext()
        return try modelContext.fetch(FetchDescriptor<PendingUpload>()).map(PendingUploadSummary.init)
    }

    private func drain() async {
        let modelContext = databaseContext()
        let doneValue = UploadState.done.rawValue
        while true {
            let now = Date()
            guard let next = try? modelContext.fetch(FetchDescriptor<PendingUpload>())
                .filter({ $0.stateRaw != doneValue && $0.nextAttemptAt <= now })
                .min(by: { $0.nextAttemptAt < $1.nextAttemptAt })
            else { return }
            await upload(next)
        }
    }

    private func upload(_ pending: PendingUpload) async {
        let modelContext = databaseContext()
        pending.stateRaw = UploadState.uploading.rawValue
        try? modelContext.save()

        do {
            try await uploader.upload(fileURL: pending.localFullImageURL, to: pending.fullImagePath, contentType: "image/jpeg")
            try await uploader.upload(fileURL: pending.localThumbImageURL, to: pending.thumbImagePath, contentType: "image/jpeg")
            pending.stateRaw = UploadState.done.rawValue
            pending.lastError = nil
            ImageFileStore.deletePendingImage(at: pending.localFullImageURL)
            ImageFileStore.deletePendingImage(at: pending.localThumbImageURL)
        } catch {
            pending.attemptCount += 1
            pending.lastError = String(describing: error)
            if pending.attemptCount >= RetryPolicy.maxAttempts {
                pending.stateRaw = UploadState.failed.rawValue
            } else {
                pending.stateRaw = UploadState.pendingLocal.rawValue
                pending.nextAttemptAt = Date().addingTimeInterval(RetryPolicy.delay(forAttempt: pending.attemptCount))
            }
        }
        try? modelContext.save()
    }

    /// A failed attempt should retry even if the app remains foregrounded and no
    /// connectivity event arrives. The wake task is deliberately one-shot: after it
    /// fires, `drain()` computes the next earliest due item again.
    private func scheduleNextRetryIfNeeded() {
        let modelContext = databaseContext()
        let doneValue = UploadState.done.rawValue
        guard let next = (try? modelContext.fetch(FetchDescriptor<PendingUpload>()))?
            .filter({ $0.stateRaw != doneValue })
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
