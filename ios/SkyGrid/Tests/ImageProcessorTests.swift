import ImageIO
import CoreImage
import Testing
import UIKit
@testable import SkyGrid

/// Anchors `Bundle(for:)` to the SkyGridTests bundle, matching the pattern in
/// `SkyColorExtractorTests` — fixtures must load from the test bundle, never
/// `Bundle.main`.
private final class FixtureBundleMarker {}

/// Pixel dimensions read straight from the JPEG's own metadata, not from
/// `UIImage.size` — this is the check that actually catches a render-scale bug,
/// since `UIImage(data:)` always reports scale 1.0 regardless of how many real
/// pixels the renderer that produced the JPEG wrote.
private func pixelSize(of data: Data) -> CGSize? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
          let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
    else { return nil }
    return CGSize(width: width, height: height)
}

/// A flat-color bitmap of an arbitrary size, built at test time rather than added as
/// a fixture file — these tests only care about pixel dimensions, not content.
private func syntheticImage(width: CGFloat, height: CGFloat) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
    return renderer.image { context in
        UIColor.systemBlue.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

@Suite("ImageProcessor")
struct ImageProcessorTests {
    private func loadFixture(_ name: String) throws -> UIImage {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        guard let url = bundle.url(forResource: name, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path)
        else {
            Issue.record("Missing fixture: \(name).jpg")
            throw RepositoryError.notFound
        }
        return image
    }

    @Test("main image is rendered at its point size in pixels, not the device display scale")
    func mainImageRendersAtRequestedPixelSize() throws {
        // Larger than mainLongEdge (1440) on both axes so a resize is guaranteed.
        let oversized = syntheticImage(width: 3000, height: 2000)
        let (mainData, _) = try #require(ImageProcessor.processedPair(from: oversized))

        let size = try #require(pixelSize(of: mainData))
        #expect(max(size.width, size.height) == ImageProcessor.mainLongEdge,
                "expected the long edge to be exactly 1440px, not a display-scale multiple of it: \(size)")
    }

    @Test("thumbnail is a square crop at thumbEdge, regardless of the source's aspect ratio")
    func thumbnailIsSquareAtThumbEdge() throws {
        let landscape = syntheticImage(width: 1600, height: 900)
        let (_, thumbData) = try #require(ImageProcessor.processedPair(from: landscape))

        let size = try #require(pixelSize(of: thumbData))
        #expect(size.width == ImageProcessor.thumbEdge)
        #expect(size.height == ImageProcessor.thumbEdge)
    }

    @Test("thumbnail stays square for a portrait source too")
    func thumbnailIsSquareForPortraitSource() throws {
        let portrait = syntheticImage(width: 900, height: 1600)
        let (_, thumbData) = try #require(ImageProcessor.processedPair(from: portrait))

        let size = try #require(pixelSize(of: thumbData))
        #expect(size.width == ImageProcessor.thumbEdge)
        #expect(size.height == ImageProcessor.thumbEdge)
    }

    @Test("thumbnail from a real photograph is square and never upscaled beyond the source's shorter side")
    func thumbnailFromRealPhotoIsSquare() throws {
        // real_clear_sky.jpg is 1280x841 — already smaller than thumbEdge on neither
        // axis, exercising the ordinary downscale-and-crop path end to end.
        let photo = try loadFixture("real_clear_sky")
        let (_, thumbData) = try #require(ImageProcessor.processedPair(from: photo))

        let size = try #require(pixelSize(of: thumbData))
        #expect(size.width == ImageProcessor.thumbEdge)
        #expect(size.height == ImageProcessor.thumbEdge)
    }

    @Test("archive thumbnails decode to their display-sized bitmap")
    func archiveThumbnailIsDownsampled() throws {
        let source = try loadFixture("real_clear_sky")
        let data = try #require(source.jpegData(compressionQuality: 1))
        let thumbnail = try #require(ImageProcessor.displayThumbnail(from: data, maxPixelSize: 72))

        #expect(max(thumbnail.size.width, thumbnail.size.height) <= 72)
    }
}

@MainActor
private final class RecoverableCameraSource: CameraSource {
    let previewFrames: AsyncStream<CIImage> = AsyncStream { continuation in
        continuation.finish()
    }

    private var startupFailures: [CameraSourceError]
    var shouldFailCapture = false
    private(set) var startCount = 0

    init(startupFailures: [CameraSourceError] = []) {
        self.startupFailures = startupFailures
    }

    func start() async throws {
        startCount += 1
        if !startupFailures.isEmpty {
            throw startupFailures.removeFirst()
        }
    }

    func stop() {}

    func capturePhoto() async throws -> UIImage {
        if shouldFailCapture {
            throw CameraSourceError.configurationFailed
        }
        return syntheticImage(width: 80, height: 80)
    }
}

@Suite("Camera recovery")
@MainActor
struct CameraRecoveryTests {
    private func makeViewModel(source: RecoverableCameraSource) -> CameraViewModel {
        CameraViewModel(
            ownerUid: "camera-recovery-test",
            cameraSource: source,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            wakeGoal: WakeGoal(minutesAfterMidnight: 360)
        )
    }

    @Test("a failed startup retries the camera source instead of only changing the screen")
    func startupFailureRetriesSource() async {
        let source = RecoverableCameraSource(startupFailures: [.configurationFailed])
        let viewModel = makeViewModel(source: source)

        await viewModel.start()
        #expect(viewModel.phase == .failed(.startup))

        await viewModel.retry()
        #expect(source.startCount == 2)
        #expect(viewModel.phase == .live)
    }

    @Test("permission denial is preserved so the UI can route to Settings")
    func permissionDenialIsActionable() async {
        let source = RecoverableCameraSource(startupFailures: [.permissionDenied])
        let viewModel = makeViewModel(source: source)

        await viewModel.start()

        #expect(viewModel.phase == .failed(.permissionDenied))
    }

    @Test("a capture failure returns to the existing live session without restarting it")
    func captureFailureKeepsSession() async {
        let source = RecoverableCameraSource()
        source.shouldFailCapture = true
        let viewModel = makeViewModel(source: source)

        await viewModel.start()
        await viewModel.capture()
        #expect(viewModel.phase == .failed(.capture))

        await viewModel.retry()
        #expect(viewModel.phase == .live)
        #expect(source.startCount == 1)
    }
}
