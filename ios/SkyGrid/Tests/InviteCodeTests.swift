import Testing
@testable import SkyGrid

@Suite("InviteCode")
struct InviteCodeTests {
    // Ported from `ios/functions/test/invites.test.js` ("normalizes what a person can
    // plausibly type") so the client and server never silently diverge on what counts
    // as a valid code.
    @Test(
        "normalizes what a person can plausibly type",
        arguments: [
            ("abcde12345", "ABCDE12345"),
            ("ABCDE-12345", "ABCDE12345"),
            ("  ABCDE 12345 ", "ABCDE12345"),
            ("ABCDEO1234", "ABCDE01234"),  // O -> 0
            ("ABCDEI2345", "ABCDE12345"),  // I -> 1
            ("ABCDEl2345", "ABCDE12345")   // l -> L -> 1
        ]
    )
    func normalizesInput(raw: String, expected: String) {
        #expect(InviteCode(raw: raw)?.value == expected)
    }

    // Ported from the same file's "rejects anything that cannot be a code instead of
    // guessing".
    @Test(
        "rejects anything that cannot be a code",
        arguments: [
            "ABCDE1234",    // too short
            "ABCDE123456",  // too long
            "ABCDE1234!",   // punctuation
            "ABCDU12345",   // U is not in the alphabet
            ""
        ]
    )
    func rejectsInvalid(raw: String) {
        #expect(InviteCode(raw: raw) == nil)
    }

    @Test("does not trim a trailing newline, unlike a pasted TextField value")
    func doesNotTrimNewline() {
        // normalizeInviteCode only drops '-', space, and tab — a mirror that trims more
        // than that stops being one. Callers reading from a TextField must trim first.
        #expect(InviteCode(raw: "ABCDE12345\n") == nil)
    }

    @Test("formats for display only, and the display form normalizes back")
    func formatsForDisplay() {
        let code = InviteCode(raw: "ABCDE12345")
        #expect(code?.formatted == "ABCDE-12345")
        #expect(InviteCode(raw: code!.formatted)?.value == "ABCDE12345")
    }

    @Test("builds the canonical link URL")
    func buildsLinkURL() {
        let code = InviteCode(raw: "ABCDE12345")
        #expect(code?.linkURL.absoluteString == "https://skygrid.my/i/ABCDE12345")
    }
}
