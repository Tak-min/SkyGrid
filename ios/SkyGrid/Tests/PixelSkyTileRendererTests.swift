import Testing
import UIKit
@testable import SkyGrid

@Suite("PixelSkyTileRenderer")
struct PixelSkyTileRendererTests {
    @Test("derives a fixed 24 by 24 tile from an actual thumbnail")
    func derivesFixedResolutionTile() {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 40, y: 0, width: 40, height: 40))
        }

        let tile = PixelSkyTileRenderer.makeTile(from: source.jpegData(compressionQuality: 1))

        #expect(tile?.size == CGSize(width: 24, height: 24))
    }

    @Test("does not fabricate a tile when image bytes are absent")
    func missingImageStaysAbsent() {
        #expect(PixelSkyTileRenderer.makeTile(from: nil) == nil)
        #expect(PixelSkyTileRenderer.makeTile(from: Data("not an image".utf8)) == nil)
    }
}
