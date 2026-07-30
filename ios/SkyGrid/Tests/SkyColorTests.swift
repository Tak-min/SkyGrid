import Testing
import SwiftUI
@testable import SkyGrid

@Suite("SkyColor")
struct SkyColorTests {
    @Test("accepts well-formed hex")
    func acceptsValidHex() {
        #expect(SkyColor(hex: "#7EA3C8") != nil)
    }

    @Test("rejects malformed hex", arguments: ["7EA3C8", "#7EA3C", "#GGGGGG", "", "#7EA3C88"])
    func rejectsInvalidHex(_ candidate: String) {
        #expect(SkyColor(hex: candidate) == nil)
    }

    @Test("picks readable ink by luminance")
    func readableInkContrastsWithBrightness() {
        let brightSky = SkyColor(uncheckedHex: "#F5F5F5")
        let darkSky = SkyColor(uncheckedHex: "#12141A")
        #expect(brightSky.readableInk == .black)
        #expect(darkSky.readableInk == .white)
    }
}
