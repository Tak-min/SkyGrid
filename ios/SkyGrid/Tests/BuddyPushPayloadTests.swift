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

    @Test(
        "returns nil when a required field is missing, empty, or the wrong type",
        arguments: [
            ["type": "buddy_post", "localDate": "2026-08-14"] as [AnyHashable: Any],
            ["type": "buddy_post", "posterUid": "poster-123"] as [AnyHashable: Any],
            ["type": "buddy_post", "posterUid": "", "localDate": "2026-08-14"] as [AnyHashable: Any],
            ["type": "buddy_post", "posterUid": "poster-123", "localDate": ""] as [AnyHashable: Any],
            ["type": "buddy_post", "posterUid": 123, "localDate": "2026-08-14"] as [AnyHashable: Any],
        ]
    )
    func rejectsIncompleteOrMistypedPayload(userInfo: [AnyHashable: Any]) {
        #expect(BuddyPushPayload.parse(userInfo) == nil)
    }

    @Test("returns nil for an empty payload")
    func rejectsEmptyPayload() {
        #expect(BuddyPushPayload.parse([:]) == nil)
    }
}
