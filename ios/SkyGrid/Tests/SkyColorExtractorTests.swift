import Testing
import UIKit
@testable import SkyGrid

/// Anchors `Bundle(for:)` to the SkyGridTests bundle. Fixtures live under
/// `SkyGrid/Tests/Fixtures/` as test-target-only resources (see project.yml) — they
/// must never be loaded via `Bundle.main`, which would require bundling them into
/// the shipping app (an earlier version of this file did exactly that by mistake).
private final class FixtureBundleMarker {}

/// `clear_sky.png` / `golden_hour.png` are original synthetic two-band images (top
/// 60% "sky" color, bottom 40% "ground" color) — enough to verify the extractor
/// samples only the top band. The `real_*.jpg` fixtures are actual photographs
/// (Wikimedia Commons, see ATTRIBUTION.md) covering lighting conditions the
/// synthetic fixtures can't: JPEG noise, gradients, and foreground silhouettes
/// intruding into the sky band.
@Suite("SkyColorExtractor")
struct SkyColorExtractorTests {
    private func loadFixture(_ name: String, extension ext: String = "png") throws -> UIImage {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        guard let url = bundle.url(forResource: name, withExtension: ext),
              let image = UIImage(contentsOfFile: url.path)
        else {
            Issue.record("Missing fixture: \(name).\(ext)")
            throw RepositoryError.notFound
        }
        return image
    }

    private func channels(_ hex: String) -> (r: UInt8, g: UInt8, b: UInt8) {
        (
            UInt8(hex.dropFirst(1).prefix(2), radix: 16)!,
            UInt8(hex.dropFirst(3).prefix(2), radix: 16)!,
            UInt8(hex.dropFirst(5).prefix(2), radix: 16)!
        )
    }

    @Test("clear sky fixture extracts a blue, not the green ground band")
    func clearSkyExtractsBlueNotGround() throws {
        let image = try loadFixture("clear_sky")
        let extracted = try #require(SkyColorExtractor.extract(from: image))

        // Ground color is #3A5F3A — if the band leaked into the ground, red/blue
        // channels would collapse toward each other and green would dominate.
        let (r, g, b) = channels(extracted.hex)
        #expect(b > g, "expected a blue-dominant sky sample, got \(extracted.hex)")
        #expect(r > 0x30 && r < 0x70, "red channel out of expected sky range: \(extracted.hex)")
    }

    @Test("golden hour fixture extracts amber, not the dark ground band")
    func goldenHourExtractsAmberNotGround() throws {
        let image = try loadFixture("golden_hour")
        let extracted = try #require(SkyColorExtractor.extract(from: image))

        let (r, _, b) = channels(extracted.hex)
        // Ground is near-black (#2A2A2A); if it leaked in, brightness would collapse
        // well below the amber sky's red channel (~0xE8).
        #expect(r > 0xA0, "expected a bright amber sample, got \(extracted.hex)")
        #expect(r > b, "expected red to dominate blue in a warm sky sample: \(extracted.hex)")
    }

    // MARK: - Real photographs (VISION.md §8: synthetic fixtures alone weren't enough
    // to catch color-management issues that only show up on real JPEG gradients/noise)

    @Test("clear blue sky photo extracts a saturated blue, matching an independent Pillow cross-check")
    func realClearSkyExtractsSaturatedBlue() throws {
        let image = try loadFixture("real_clear_sky", extension: "jpg")
        let extracted = try #require(SkyColorExtractor.extract(from: image))

        // Independently computed (Python/Pillow, plain arithmetic mean of the top
        // 55% band) as a cross-check oracle: #326FB5 (50, 112, 182). Tolerance
        // accounts for CoreImage's CIAreaAverage vs. Pillow's decoder/averaging
        // not being bit-identical.
        let (r, g, b) = channels(extracted.hex)
        #expect(b > g && g > r, "expected blue > green > red for a clear sky, got \(extracted.hex)")
        #expect((30...80).contains(Int(r)), "red channel drifted from Pillow cross-check: \(extracted.hex)")
        #expect((150...220).contains(Int(b)), "blue channel drifted from Pillow cross-check: \(extracted.hex)")
    }

    @Test("overcast sky photo extracts a low-saturation gray, not a hue-dominant color")
    func realOvercastSkyExtractsGray() throws {
        let image = try loadFixture("real_overcast_sky", extension: "jpg")
        let extracted = try #require(SkyColorExtractor.extract(from: image))

        // Cross-check: #81888C (130, 136, 141) — channels close together (low
        // saturation), unlike the vivid clear/sunset fixtures.
        let (r, g, b) = channels(extracted.hex)
        let spread = Int(max(r, g, b)) - Int(min(r, g, b))
        #expect(spread < 40, "expected low channel spread (gray, overcast), got \(extracted.hex) spread=\(spread)")
        #expect((90...180).contains(Int(g)), "brightness drifted from Pillow cross-check: \(extracted.hex)")
    }

    @Test("sunset-over-water sky photo extracts a muted blue-violet, distinct from the clear sky fixture")
    func realSunsetSkyExtractsMutedBlueViolet() throws {
        let image = try loadFixture("real_sunset_sky", extension: "jpg")
        let extracted = try #require(SkyColorExtractor.extract(from: image))

        // Cross-check: #4F69A6 (79, 105, 166) — the top 55% band is still the
        // blue/violet upper sky, not yet the fiery orange horizon lower in frame.
        let (r, g, b) = channels(extracted.hex)
        #expect(b > g && b > r, "expected blue to dominate the upper band, got \(extracted.hex)")
        #expect((50...110).contains(Int(r)), "red channel drifted from Pillow cross-check: \(extracted.hex)")
    }

    @Test("dramatic sky photo with a foreground tree silhouette extracts a dark warm tone, not black")
    func realDramaticSkyExtractsDarkWarmTone() throws {
        let image = try loadFixture("real_dramatic_sky", extension: "jpg")
        let extracted = try #require(SkyColorExtractor.extract(from: image))

        // Cross-check: #694054 (105, 64, 85) — a bare tree silhouette intrudes into
        // the sky band from one edge; this asserts it darkens/mutes the average
        // without a small foreground object swamping the whole reading toward black.
        let (r, g, _) = channels(extracted.hex)
        #expect(r > g, "expected red to dominate green in a warm/fire-toned sky, got \(extracted.hex)")
        #expect((60...160).contains(Int(r)), "red channel drifted from Pillow cross-check: \(extracted.hex)")
    }
}
