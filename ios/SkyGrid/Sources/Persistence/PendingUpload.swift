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

    init(_ model: PendingUpload) {
        queueID = model.queueID
        ownerUid = model.ownerUid
        localDateID = model.localDateID
        state = model.state
        attemptCount = model.attemptCount
        lastError = model.lastError
    }
}
