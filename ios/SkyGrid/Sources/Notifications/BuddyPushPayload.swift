import Foundation

/// The `data` payload of a buddy-post push notification (`onBuddyPostCreated` /
/// `buddyNotificationStore.ts`'s `sendEachForMulticast` call). Untrusted input —
/// `userInfo` is whatever arrived over APNs — so this only ever returns a value once
/// every field has been positively validated, never a partially-filled guess.
enum BuddyPushPayload: Equatable {
    case buddyPost(posterUid: String, localDate: String)
    case buddyRequestReceived(pairId: String)
    case buddyRequestApproved(pairId: String)
    case inviteClaimed
    case streakBreakReminder(pairId: String)
    case personalStreakBreakReminder(localDate: String)

    private static let buddyPostType = "buddy_post"

    /// `nil` for anything that isn't a recognized SkyGrid buddy-post payload — a
    /// notification this app didn't send, a future payload type this build predates,
    /// or a malformed/incomplete one. Callers must treat `nil` as "not a buddy-post
    /// notification" and fall through to whatever they already do for other
    /// notifications, never as an error to surface.
    static func parse(_ userInfo: [AnyHashable: Any]) -> BuddyPushPayload? {
        guard let type = userInfo["type"] as? String else { return nil }
        switch type {
        case buddyPostType:
            guard let posterUid = userInfo["posterUid"] as? String, !posterUid.isEmpty,
                  let localDate = userInfo["localDate"] as? String, !localDate.isEmpty
            else { return nil }
            return .buddyPost(posterUid: posterUid, localDate: localDate)
        case "buddy_request_received":
            guard let pairId = userInfo["pairId"] as? String, !pairId.isEmpty else { return nil }
            return .buddyRequestReceived(pairId: pairId)
        case "buddy_request_approved":
            guard let pairId = userInfo["pairId"] as? String, !pairId.isEmpty else { return nil }
            return .buddyRequestApproved(pairId: pairId)
        case "invite_claimed":
            return .inviteClaimed
        case "streak_break_reminder":
            guard let pairId = userInfo["pairId"] as? String, !pairId.isEmpty else { return nil }
            return .streakBreakReminder(pairId: pairId)
        case "personal_streak_break_reminder":
            guard let localDate = userInfo["localDate"] as? String, !localDate.isEmpty else { return nil }
            return .personalStreakBreakReminder(localDate: localDate)
        default:
            return nil
        }
    }
}
