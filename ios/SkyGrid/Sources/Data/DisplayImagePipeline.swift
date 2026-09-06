import Foundation
import UIKit

/// One instance per account/service graph. Disk reads, decoding and cache trimming
/// run on this actor, never in SwiftUI's main-actor render/update work.
actor DisplayImagePipeline: ImageFetching {
    enum Size: Int, Sendable { case thumbnail = 96, photo = 1440 }
    private let remote: any ImageFetching
    private let memory = NSCache<NSString, UIImage>()
    private var flights: [String: Task<UIImage?, Never>] = [:]
    private var invalidated = false

    /// The app graph injects exactly one pipeline — the instance
    /// `AccountDeletionService` can `invalidate()` — so every production call
    /// returns it and shares its cache and in-flight coalescing.
    ///
    /// A foreign fetcher is only ever an offline stub: the `-SkyGridUIAudit`
    /// harness and SwiftUI previews. Those get a throwaway wrapper, which caches
    /// and coalesces nothing and is never invalidated. Both are correct there
    /// (synthetic bytes, no account to revoke) and neither is reachable from a
    /// shipped build, which is why this stays a wrapper rather than a registry.
    static func resolved(for fetcher: any ImageFetching) -> DisplayImagePipeline {
        fetcher as? DisplayImagePipeline ?? DisplayImagePipeline(remote: fetcher)
    }

    init(remote: any ImageFetching) {
        self.remote = remote
        memory.totalCostLimit = 24 * 1024 * 1024
        memory.countLimit = 400
    }

    func fetchImage(path: String) async throws -> Data {
        guard !invalidated else { throw CancellationError() }
        let data = try await remote.fetchImage(path: path)
        guard !invalidated else { throw CancellationError() }
        return data
    }

    /// `nil` means "nothing to show": no local bytes and no usable remote ones, or
    /// the caller was cancelled, or the account was revoked. Callers cannot tell these
    /// apart, and today none needs to — both call sites (`BuddyTile`,
    /// `GridArchiveViewModel`) re-check `Task.isCancelled` after the await, so a
    /// cancelled `nil` never overwrites what is on screen. Give this a richer result
    /// type the moment a caller actually has to distinguish them; inventing one now
    /// would be a shape with no reader.
    func image(path: String, size: Size) async -> UIImage? {
        guard !invalidated, !Task.isCancelled else { return nil }
        let key = "\(size.rawValue):\(path)"
        if let cached = memory.object(forKey: key as NSString) { return cached }
        let flight = flights[key] ?? {
            let flight = Task { await self.resolve(path: path, size: size, key: key) }
            flights[key] = flight
            return flight
        }()
        let image = await flight.value
        guard !invalidated, !Task.isCancelled else { return nil }
        return image
    }

    /// Local-only lookup: memory, then the outbox and on-disk caches. Never starts a
    /// remote fetch, so a progressive preview cannot turn into an extra download, and
    /// never reads around `invalidate()` the way a direct `ImageFileStore` call would.
    func cachedImage(path: String, size: Size) async -> UIImage? {
        guard !invalidated else { return nil }
        let key = "\(size.rawValue):\(path)"
        if let cached = memory.object(forKey: key as NSString) { return cached }
        // Join an existing flight rather than decoding the same file beside it. This
        // deliberately does not *register* one: a local miss here must not answer a
        // concurrent `image(path:size:)`, which is still entitled to its remote fetch.
        if let flight = flights[key] { return await flight.value }
        guard let image = await Self.decodeLocal(path: path, size: size), !invalidated else { return nil }
        store(image, key: key)
        return image
    }

    /// Call before deleting the account's files: outstanding downloads may finish,
    /// but cannot repopulate either disk or memory after this boundary.
    func invalidate() {
        invalidated = true
        for flight in flights.values { flight.cancel() }
        flights.removeAll()
        memory.removeAllObjects()
    }

    /// Runs inside the coalesced flight, so the caller that happened to start it
    /// has no influence here: caching is gated on `invalidated` alone, never on the
    /// starting caller's cancellation. A scrolling grid cancels those callers
    /// constantly, and gating the cache on them threw away bytes that had already
    /// been downloaded and decoded.
    private func resolve(path: String, size: Size, key: String) async -> UIImage? {
        defer { flights[key] = nil }
        guard !invalidated else { return nil }

        // `decodeLocal` runs detached, so `invalidate()` cancelling this flight does
        // not stop it finishing. Without this re-check a buddy photo decoded across
        // that suspension would be written back into memory after revocation.
        if let image = await Self.decodeLocal(path: path, size: size) {
            // Revoked across the detached decode: give up rather than fall through
            // to the remote fetch. `remote` knows nothing about invalidation, so
            // falling through would put one pointless download against a deleted
            // account's Storage objects.
            guard !invalidated else { return nil }
            store(image, key: key)
            return image
        }
        guard let data = try? await remote.fetchImage(path: path), !invalidated,
              let image = await Self.decode(data, size: size) else { return nil }
        guard !invalidated else { return nil }
        if size == .thumbnail {
            ImageFileStore.cacheThumbnail(data, forRemotePath: path)
        } else {
            ImageFileStore.cacheImage(data, forRemotePath: path)
        }
        store(image, key: key)
        return image
    }

    private func store(_ image: UIImage, key: String) {
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        memory.setObject(image, forKey: key as NSString, cost: cost)
    }

    /// Decoding is deliberately off this actor. A synchronous CGImageSource decode
    /// running on the actor serialises every other call — including calls that only
    /// wanted a memory-cache hit — which is the same head-of-line stall the main
    /// actor had, just moved.
    private static func decode(_ data: Data, size: Size) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            ImageProcessor.displayThumbnail(from: data, maxPixelSize: size.rawValue)
        }.value
    }

    private static func decodeLocal(path: String, size: Size) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let data = ImageFileStore.pendingImageData(forRemotePath: path)
                ?? (size == .thumbnail
                    ? ImageFileStore.cachedThumbnailData(forRemotePath: path)
                    : ImageFileStore.cachedImageData(forRemotePath: path))
            return data.flatMap { ImageProcessor.displayThumbnail(from: $0, maxPixelSize: size.rawValue) }
        }.value
    }
}
