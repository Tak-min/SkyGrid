import Foundation

/// Read-side: downloading/displaying already-uploaded images (with caching).
/// Split from `ImageUploading` because the two have very different failure modes and
/// backends (Firestore-backed metadata vs. Storage-backed bytes) — see blueprint §Data/.
protocol ImageFetching: Sendable {
    func fetchImage(path: String) async throws -> Data
}

/// Write-side: uploading a locally-captured image to remote storage. Consumed by
/// `UploadQueue`, not by views directly.
protocol ImageUploading: Sendable {
    func upload(fileURL: URL, to path: String, contentType: String) async throws
    /// Used only by the durable outbox to resume a partially completed capture.
    /// A `false` result also covers an indeterminate read; the following upload will
    /// surface the underlying error and enter normal retry handling.
    func imageExists(path: String) async -> Bool
    /// Distinguishes "the object is definitively not there" from "we could not find
    /// out" (offline, App Check rejected, transient error). `imageExists` collapses
    /// both into `false`, which is safe for deciding whether to *resume* an upload
    /// but must never be used to authorize *deleting* a post document — an
    /// indeterminate read must never be mistaken for proof of absence.
    func imagePresence(path: String) async -> RemoteImagePresence
}

extension ImageUploading {
    func imageExists(path: String) async -> Bool { false }
    /// Fail-safe default: a conformer that cannot positively distinguish absence
    /// from failure must never report `.absent`.
    func imagePresence(path: String) async -> RemoteImagePresence {
        await imageExists(path: path) ? .present : .indeterminate
    }
}

/// Tri-state result of probing whether a remote image object exists. Unlike a plain
/// `Bool`, this makes "we don't know" a distinct, non-actionable state — see
/// `ImageUploading.imagePresence(path:)`.
enum RemoteImagePresence: Sendable, Equatable {
    case present
    case absent
    case indeterminate
}
