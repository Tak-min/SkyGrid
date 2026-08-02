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

    /// `posts/{uid}/{localDate}/{imageUUID}.jpg` — uid- and day-scoped with an
    /// unguessable filename. The day segment lets Storage Rules enforce mutual
    /// reveal before returning a buddy's bytes, rather than relying on UI blur.
    var imagePath: String { "posts/\(ownerUid)/\(localDate.docID)/\(imageID.uuidString).jpg" }
    var thumbPath: String { "posts/\(ownerUid)/\(localDate.docID)/\(imageID.uuidString)_thumb.jpg" }
}
