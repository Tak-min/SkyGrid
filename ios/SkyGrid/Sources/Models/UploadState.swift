import Foundation

/// Durable state for one captured photo. A new capture remains `.stagedPost` until
/// its Firestore document is acknowledged; only then may Storage receive its bytes.
/// The raw values are persisted in SwiftData, so legacy `.pendingLocal` rows remain
/// valid upload-ready rows after this state machine was introduced.
enum UploadState: String, Sendable, Codable, Equatable {
    /// The complete Firestore payload is on-device, but no matching server document
    /// has been confirmed yet. Never eligible for a Storage upload.
    case stagedPost
    case pendingLocal
    case uploading
    case done
    /// The Firestore write was rejected permanently. The local photo is retained so
    /// a later explicit retry never needs the person to recreate their capture.
    case postFailed
    /// Another document already owns this account/day with different image paths.
    /// Keep local bytes for an explicit user decision; never upload them blindly.
    case postConflict
    case failed
}
