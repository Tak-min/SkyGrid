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
}
