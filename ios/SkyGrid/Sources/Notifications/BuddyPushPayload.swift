import Foundation

/// The `data` payload of a buddy-post push notification (`onBuddyPostCreated` /
/// `buddyNotificationStore.ts`'s `sendEachForMulticast` call). Untrusted input —
/// `userInfo` is whatever arrived over APNs — so this only ever returns a value once
/// every field has been positively validated, never a partially-filled guess.
enum BuddyPushPayload: Equatable {
    case buddyPost(posterUid: String, localDate: String)

    private static let buddyPostType = "buddy_post"

    /// `nil` for anything that isn't a recognized SkyGrid buddy-post payload — a
    /// notification this app didn't send, a future payload type this build predates,
    /// or a malformed/incomplete one. Callers must treat `nil` as "not a buddy-post
    /// notification" and fall through to whatever they already do for other
    /// notifications, never as an error to surface.
    static func parse(_ userInfo: [AnyHashable: Any]) -> BuddyPushPayload? {
        guard let type = userInfo["type"] as? String, type == buddyPostType,
              let posterUid = userInfo["posterUid"] as? String, !posterUid.isEmpty,
              let localDate = userInfo["localDate"] as? String, !localDate.isEmpty
        else { return nil }
        return .buddyPost(posterUid: posterUid, localDate: localDate)
    }
}
