import Foundation
import Testing
@testable import SkyGrid

@Suite("BuddyPushPayload")
struct BuddyPushPayloadTests {
    @Test("parses a well-formed buddy-post payload")
    func parsesWellFormedPayload() {
        let userInfo: [AnyHashable: Any] = [
            "type": "buddy_post",
            "posterUid": "poster-123",
            "localDate": "2026-08-14",
        ]

        #expect(BuddyPushPayload.parse(userInfo) == .buddyPost(posterUid: "poster-123", localDate: "2026-08-14"))
    }

    @Test("returns nil for a notification of a different or unrecognized type")
    func rejectsWrongType() {
        let userInfo: [AnyHashable: Any] = [
            "type": "some_other_notification",
            "posterUid": "poster-123",
            "localDate": "2026-08-14",
        ]

        #expect(BuddyPushPayload.parse(userInfo) == nil)
    }

    @Test("returns nil when the type key is missing entirely")
    func rejectsMissingType() {
        let userInfo: [AnyHashable: Any] = ["posterUid": "poster-123", "localDate": "2026-08-14"]

        #expect(BuddyPushPayload.parse(userInfo) == nil)
    }

    @Test("returns nil when a required field is missing, empty, or the wrong type")
    func rejectsIncompleteOrMistypedPayload() {
        let payloads = [
            ["type": "buddy_post", "localDate": "2026-08-14"] as [AnyHashable: Any],
            ["type": "buddy_post", "posterUid": "poster-123"] as [AnyHashable: Any],
            ["type": "buddy_post", "posterUid": "", "localDate": "2026-08-14"] as [AnyHashable: Any],
            ["type": "buddy_post", "posterUid": "poster-123", "localDate": ""] as [AnyHashable: Any],
            ["type": "buddy_post", "posterUid": 123, "localDate": "2026-08-14"] as [AnyHashable: Any],
        ]
        for payload in payloads {
            #expect(BuddyPushPayload.parse(payload) == nil)
        }
    }

    @Test("returns nil for an empty payload")
    func rejectsEmptyPayload() {
        #expect(BuddyPushPayload.parse([:]) == nil)
    }

    @Test("parses request, approval, invite, and streak reminder payloads")
    func parsesOtherNotificationPayloads() {
        #expect(BuddyPushPayload.parse(["type": "buddy_request_received", "pairId": "a_b"]) == .buddyRequestReceived(pairId: "a_b"))
        #expect(BuddyPushPayload.parse(["type": "buddy_request_approved", "pairId": "a_b"]) == .buddyRequestApproved(pairId: "a_b"))
        #expect(BuddyPushPayload.parse(["type": "invite_claimed"]) == .inviteClaimed)
        #expect(BuddyPushPayload.parse(["type": "streak_break_reminder", "pairId": "a_b"]) == .streakBreakReminder(pairId: "a_b"))
        #expect(BuddyPushPayload.parse(["type": "personal_streak_break_reminder", "localDate": "2026-08-14"]) == .personalStreakBreakReminder(localDate: "2026-08-14"))
    }
}
