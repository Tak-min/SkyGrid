import Foundation

/// State of a captured photo's background upload, tracked independently of the
/// Firestore post document (which is written immediately and separately — see
/// `Data/Firestore/FirestorePostRepository`).
enum UploadState: String, Sendable, Codable, Equatable {
    case pendingLocal
    case uploading
    case done
    case failed
}
