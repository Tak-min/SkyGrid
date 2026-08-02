import Foundation
import SwiftData

/// SwiftData record tracking one photo's background upload. Deliberately holds only
/// upload-plumbing state — never a mirror of post content — see blueprint §3.1:
/// Firestore itself (with offline persistence) is the single source of truth for the
/// post document; this model exists purely so image bytes can retry independently.
@Model
final class PendingUpload {
    /// The actual uniqueness boundary is an account *and* its local calendar day.
    /// A bare date collides as soon as someone signs out and starts another account
    /// on the same device.
    @Attribute(.unique) var queueID: String
    var localDateID: String
    var imageID: String
    var ownerUid: String
    var fullImagePath: String
    var thumbImagePath: String
    var localFullImageURL: URL
    var localThumbImageURL: URL
    var stateRaw: String
    var attemptCount: Int
    var nextAttemptAt: Date
    var lastError: String?
    var createdAt: Date

    var state: UploadState {
        get { UploadState(rawValue: stateRaw) ?? .pendingLocal }
        set { stateRaw = newValue.rawValue }
    }

    init(draft: PostDraft, createdAt: Date = Date()) {
        self.queueID = Self.queueID(ownerUid: draft.ownerUid, localDateID: draft.localDate.docID)
        self.localDateID = draft.localDate.docID
        self.imageID = draft.imageID.uuidString
        self.ownerUid = draft.ownerUid
        self.fullImagePath = draft.imagePath
        self.thumbImagePath = draft.thumbPath
        self.localFullImageURL = draft.localFullImageURL
        self.localThumbImageURL = draft.localThumbImageURL
        self.stateRaw = UploadState.pendingLocal.rawValue
        self.attemptCount = 0
        self.nextAttemptAt = createdAt
        self.lastError = nil
        self.createdAt = createdAt
    }

    static func queueID(ownerUid: String, localDateID: String) -> String {
        "\(ownerUid):\(localDateID)"
    }
}

/// Sendable snapshot of a `PendingUpload` for crossing the `UploadQueue` actor
/// boundary — the `@Model` instance itself must never leave the actor.
struct PendingUploadSummary: Sendable, Equatable {
    let queueID: String
    let ownerUid: String
    let localDateID: String
    let state: UploadState
    let attemptCount: Int
    let lastError: String?
    let fullImagePath: String
    let thumbImagePath: String
    /// Whether a retry could still put bytes in Storage. Keyed on the *full* image
    /// only: `UploadQueue.uploadIfNeeded` attempts the full image before the
    /// thumbnail and throws `localFileMissing` immediately, so a missing full image
    /// means no retry can ever land either object.
    let hasLocalFullImage: Bool

    init(_ model: PendingUpload) {
        queueID = model.queueID
        ownerUid = model.ownerUid
        localDateID = model.localDateID
        state = model.state
        attemptCount = model.attemptCount
        lastError = model.lastError
        fullImagePath = model.fullImagePath
        thumbImagePath = model.thumbImagePath
        // Re-resolve from the filename alone, never the stored absolute URL — a
        // container's UUID segment can change across an app container reassignment
        // (see `UploadQueue.pendingImageURL`), which would silently strand a
        // previously-persisted `URL`.
        hasLocalFullImage = FileManager.default.fileExists(
            atPath: ImageFileStore.pendingImageURL(filename: model.localFullImageURL.lastPathComponent).path
        )
    }
}
