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
    /// JSON payload required to reconstruct a `PostDraft` after process death. It
    /// is optional solely for rows created by older builds, which were already
    /// ready to upload and therefore never need a Firestore retry.
    var postPayloadData: Data?
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
        self.postPayloadData = try? JSONEncoder().encode(PostPayload(draft: draft))
        self.stateRaw = UploadState.stagedPost.rawValue
        self.attemptCount = 0
        self.nextAttemptAt = createdAt
        self.lastError = nil
        self.createdAt = createdAt
    }

    static func queueID(ownerUid: String, localDateID: String) -> String {
        "\(ownerUid):\(localDateID)"
    }

    func postDraft() -> PostDraft? {
        guard let postPayloadData,
              let payload = try? JSONDecoder().decode(PostPayload.self, from: postPayloadData),
              payload.ownerUid == ownerUid,
              payload.localDateID == localDateID,
              payload.imageID == imageID,
              let localDate = LocalDate(docID: payload.localDateID),
              let imageID = UUID(uuidString: payload.imageID),
              let skyColor = SkyColor(hex: payload.skyColorHex)
        else { return nil }

        return PostDraft(
            ownerUid: payload.ownerUid,
            localDate: localDate,
            capturedAt: payload.capturedAt,
            skyColor: skyColor,
            minutesFromGoal: payload.minutesFromGoal,
            imageID: imageID,
            localFullImageURL: ImageFileStore.pendingImageURL(filename: localFullImageURL.lastPathComponent),
            localThumbImageURL: ImageFileStore.pendingImageURL(filename: localThumbImageURL.lastPathComponent)
        )
    }
}

/// Codable rather than a SwiftData relationship so one outbox row and one payload
/// remain portable through a lightweight schema migration.
private struct PostPayload: Codable {
    let ownerUid: String
    let localDateID: String
    let capturedAt: Date
    let skyColorHex: String
    let minutesFromGoal: Int
    let imageID: String

    init(draft: PostDraft) {
        ownerUid = draft.ownerUid
        localDateID = draft.localDate.docID
        capturedAt = draft.capturedAt
        skyColorHex = draft.skyColor.hex
        minutesFromGoal = draft.minutesFromGoal
        imageID = draft.imageID.uuidString
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
