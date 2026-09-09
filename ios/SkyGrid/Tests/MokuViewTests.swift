import Testing
@testable import SkyGrid

@Suite("MokuView")
struct MokuViewTests {
    @Test("states stay in the causal reward order")
    func statesStayInCausalOrder() {
        #expect(MokuState.allCases == [.waiting, .ready, .bracing, .delight, .settled, .error, .pleading])
    }

    @Test("only successful post-capture states accept sky colors")
    func capturedColorsRequireSuccess() {
        #expect(!MokuState.waiting.mayUseCapturedSkyPalette)
        #expect(!MokuState.ready.mayUseCapturedSkyPalette)
        #expect(!MokuState.bracing.mayUseCapturedSkyPalette)
        #expect(!MokuState.error.mayUseCapturedSkyPalette)
        #expect(!MokuState.pleading.mayUseCapturedSkyPalette)
        #expect(MokuState.delight.mayUseCapturedSkyPalette)
        #expect(MokuState.settled.mayUseCapturedSkyPalette)
    }

    @Test("silhouette is a unique asymmetric 4 by 4 pixel cluster")
    func silhouetteContract() {
        let pixels = MokuView.bodyPixels

        #expect(pixels.count == 13)
        #expect(Set(pixels).count == pixels.count)
        #expect(pixels.allSatisfy { (0..<4).contains($0.column) && (0..<4).contains($0.row) })
        #expect(pixels.contains(MokuPixel(column: 0, row: 3)))
        #expect(!pixels.contains(MokuPixel(column: 3, row: 3)))
    }
}
