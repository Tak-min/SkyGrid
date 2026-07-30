import Foundation

/// Everything known the instant a photo is captured — before any network call. This
/// is what `CameraViewModel` builds and hands to `PostRepository.createPost` /
/// `UploadQueue.enqueue`. Image paths are decided here (client-generated UUID), not
/// assigned later by a server, so the Firestore post document can be written in the
/// same step without waiting on the image upload (blueprint §3.2).
struct PostDraft: Sendable {
    let ownerUid: String
    let localDate: LocalDate
    let capturedAt: Date
    let skyColor: SkyColor
    let minutesFromGoal: Int
    let imageID: UUID
    let localFullImageURL: URL
    let localThumbImageURL: URL

    /// `posts/{uid}/{imageUUID}.jpg` — uid-scoped, unguessable UUID filename.
    /// See blueprint §3.4: this is the MVP's substitute for cross-service Storage
    /// Rules, so the uid segment and the UUID scheme are both load-bearing.
    var imagePath: String { "posts/\(ownerUid)/\(imageID.uuidString).jpg" }
    var thumbPath: String { "posts/\(ownerUid)/\(imageID.uuidString)_thumb.jpg" }
}
