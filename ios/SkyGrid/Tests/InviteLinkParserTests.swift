import Foundation
import Testing
@testable import SkyGrid

@Suite("InviteLinkParser")
struct InviteLinkParserTests {
    @Test("parses a well-formed invite link")
    func parsesInviteLink() {
        let url = URL(string: "https://skygrid.my/i/ABCDE12345")!
        #expect(InviteLinkParser.code(from: url)?.value == "ABCDE12345")
    }

    @Test(
        "parses regardless of trailing slash, query, or fragment",
        arguments: [
            "https://skygrid.my/i/ABCDE12345/",
            "https://skygrid.my/i/ABCDE12345?utm_source=dm",
            "https://skygrid.my/i/ABCDE12345#top"
        ]
    )
    func parsesWithSuffixes(urlString: String) {
        let url = URL(string: urlString)!
        #expect(InviteLinkParser.code(from: url)?.value == "ABCDE12345")
    }

    @Test("normalizes the path segment the same way InviteCode does")
    func normalizesPathSegment() {
        let url = URL(string: "https://skygrid.my/i/abcde12345")!
        #expect(InviteLinkParser.code(from: url)?.value == "ABCDE12345")
    }

    // The Worker's AASA scopes `components` to `/i/*` only (`waitlist/src/aasa.ts`) so
    // that these keep opening in Safari instead of being swallowed by the app. This
    // parser must independently agree, not just rely on AASA to keep them out.
    @Test(
        "does not treat other skygrid.my pages as invite links",
        arguments: ["https://skygrid.my/privacy", "https://skygrid.my/terms", "https://skygrid.my/support"]
    )
    func rejectsOtherPages(urlString: String) {
        let url = URL(string: urlString)!
        #expect(InviteLinkParser.code(from: url) == nil)
    }

    @Test(
        "rejects malformed or hostile invite-shaped URLs",
        arguments: [
            "https://evil.com/i/ABCDE12345",   // foreign host
            "http://skygrid.my/i/ABCDE12345",  // not https
            "https://skygrid.my/i/",           // no code
            "https://skygrid.my/i",            // no code, no trailing slash
            "https://skygrid.my/i/a/b",         // extra path segment
            "https://skygrid.my/i/short",       // not a valid InviteCode
            "https://skygrid.my/i/%3Cscript%3E"  // injection attempt
        ]
    )
    func rejectsMalformed(urlString: String) {
        let url = URL(string: urlString)!
        #expect(InviteLinkParser.code(from: url) == nil)
    }

    @Test("does not recognize the skygrid:// custom scheme")
    func doesNotRecognizeCustomScheme() {
        let url = URL(string: "skygrid://capture")!
        #expect(InviteLinkParser.code(from: url) == nil)
    }
}
