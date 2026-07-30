import Testing
import UIKit
@testable import SkyGrid

/// Fixtures are synthetic two-band images (top 60% "sky" color, bottom 40% "ground"
/// color) under `Resources/Fixtures/` — real sky photos should replace these once
/// available (see dev-notes), but these are enough to verify the extractor samples
/// only the top band and doesn't get pulled toward the ground color.
@Suite("SkyColorExtractor")
struct SkyColorExtractorTests {
    private func loadFixture(_ name: String) throws -> UIImage {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path)
        else {
            Issue.record("Missing fixture: \(name).png")
            throw RepositoryError.notFound
        }
        return image
    }

    @Test("clear sky fixture extracts a blue, not the green ground band")
    func clearSkyExtractsBlueNotGround() throws {
        let image = try loadFixture("clear_sky")
        let extracted = try #require(SkyColorExtractor.extract(from: image))

        // Ground color is #3A5F3A — if the band leaked into the ground, red/blue
        // channels would collapse toward each other and green would dominate.
        let r = UInt8(extracted.hex.dropFirst(1).prefix(2), radix: 16)!
        let g = UInt8(extracted.hex.dropFirst(3).prefix(2), radix: 16)!
        let b = UInt8(extracted.hex.dropFirst(5).prefix(2), radix: 16)!
        #expect(b > g, "expected a blue-dominant sky sample, got \(extracted.hex)")
        #expect(r > 0x30 && r < 0x70, "red channel out of expected sky range: \(extracted.hex)")
    }

    @Test("golden hour fixture extracts amber, not the dark ground band")
    func goldenHourExtractsAmberNotGround() throws {
        let image = try loadFixture("golden_hour")
        let extracted = try #require(SkyColorExtractor.extract(from: image))

        let r = UInt8(extracted.hex.dropFirst(1).prefix(2), radix: 16)!
        let b = UInt8(extracted.hex.dropFirst(5).prefix(2), radix: 16)!
        // Ground is near-black (#2A2A2A); if it leaked in, brightness would collapse
        // well below the amber sky's red channel (~0xE8).
        #expect(r > 0xA0, "expected a bright amber sample, got \(extracted.hex)")
        #expect(r > b, "expected red to dominate blue in a warm sky sample: \(extracted.hex)")
    }
}
