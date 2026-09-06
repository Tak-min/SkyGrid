import Foundation
import Testing
import UIKit
@testable import SkyGrid

@Suite("Display image pipeline")
struct DisplayImagePipelineTests {
    @MainActor private func fixture() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32), format: format).pngData { context in
            UIColor.cyan.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
    }

    @Test func concurrentReadersFetchOnceThenReadMemoryAndDisk() async {
        let remote = SlowImageFetcher(data: await fixture())
        let pipeline = DisplayImagePipeline(remote: remote)
        let path = "pipeline-tests/\(UUID().uuidString).jpg"
        let count = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<10 { group.addTask { await pipeline.image(path: path, size: .thumbnail) != nil } }
            var count = 0
            for await loaded in group { if loaded { count += 1 } }
            return count
        }
        #expect(count == 10)
        #expect(await remote.calls == 1)
        #expect(await pipeline.image(path: path, size: .thumbnail) != nil)
        let reopened = DisplayImagePipeline(remote: remote)
        #expect(await reopened.image(path: path, size: .thumbnail) != nil)
        #expect(await remote.calls == 1)
    }

    @Test func accountInvalidationCannotRepopulateCacheFromLateDownload() async {
        let remote = SlowImageFetcher(data: await fixture())
        let pipeline = DisplayImagePipeline(remote: remote)
        let path = "pipeline-tests/\(UUID().uuidString).jpg"
        let load = Task { await pipeline.image(path: path, size: .thumbnail) }
        // Remote sleep gives invalidation an explicit suspension boundary; this
        // wait has a hard bound so a regression cannot hang the suite.
        for _ in 0..<1000 {
            if await remote.calls > 0 { break }
            await Task.yield()
        }
        await pipeline.invalidate()
        #expect(await load.value == nil)
        #expect(await pipeline.image(path: path, size: .thumbnail) == nil)
        #expect(ImageFileStore.cachedThumbnailData(forRemotePath: path) == nil)
    }
    /// A scrolling grid cancels the `.task` that started a load constantly. Bytes
    /// that were already downloaded and decoded must still reach the cache, or
    /// scrolling back re-downloads and re-decodes every cell it just paid for.
    @Test func cancellingTheStartingCallerStillCachesTheDecodedImage() async {
        let remote = SlowImageFetcher(data: await fixture())
        let pipeline = DisplayImagePipeline(remote: remote)
        let path = "pipeline-tests/\(UUID().uuidString).jpg"

        let starter = Task { await pipeline.image(path: path, size: .thumbnail) }
        for _ in 0..<1000 {
            if await remote.calls > 0 { break }
            await Task.yield()
        }
        starter.cancel()
        _ = await starter.value

        #expect(await pipeline.image(path: path, size: .thumbnail) != nil)
        #expect(await remote.calls == 1)
    }

    @Test func cachedImageNeverReachesTheNetwork() async {
        let remote = SlowImageFetcher(data: await fixture())
        let pipeline = DisplayImagePipeline(remote: remote)
        let path = "pipeline-tests/\(UUID().uuidString).jpg"

        #expect(await pipeline.cachedImage(path: path, size: .thumbnail) == nil)
        #expect(await remote.calls == 0)

        #expect(await pipeline.image(path: path, size: .thumbnail) != nil)
        #expect(await pipeline.cachedImage(path: path, size: .thumbnail) != nil)
        #expect(await remote.calls == 1)
    }

    @Test func cachedImageStopsAtTheRevocationBoundary() async {
        let remote = SlowImageFetcher(data: await fixture())
        let pipeline = DisplayImagePipeline(remote: remote)
        let path = "pipeline-tests/\(UUID().uuidString).jpg"
        #expect(await pipeline.image(path: path, size: .thumbnail) != nil)

        await pipeline.invalidate()
        #expect(await pipeline.cachedImage(path: path, size: .thumbnail) == nil)
    }
}

private actor SlowImageFetcher: ImageFetching {
    let data: Data
    private(set) var calls = 0
    init(data: Data) { self.data = data }
    func fetchImage(path: String) async throws -> Data {
        calls += 1
        // Deliberately returns bytes even after cancellation to model a late SDK
        // callback; the pipeline, not the network, must enforce invalidation.
        try? await Task.sleep(for: .milliseconds(100))
        return data
    }
}
