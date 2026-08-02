import Foundation

/// Where captured-but-not-yet-uploaded photo bytes live on disk. Deliberately
/// `Application Support/`, never `Caches/` — the OS can purge `Caches` at any time,
/// which for this app would mean silently losing a morning's only photo before it
/// finishes uploading (blueprint §3.1 / gotcha #5). The small thumbnail cache is
/// kept beside the outbox so the archive can show real photos immediately without
/// redownloading a whole year on every launch. Account deletion removes the parent
/// `SkyGrid/` directory, so neither store outlives the account on this device.
enum ImageFileStore {
    private static let thumbnailCacheLimit = 32 * 1024 * 1024
    // Full-resolution captures are compressed to roughly 200-400 KB (blueprint gotcha
    // #4), so this budget holds a couple hundred recently viewed mornings/archive days
    // — a session's worth of Today + Sky Grid detail views — without unbounded growth.
    private static let imageCacheLimit = 64 * 1024 * 1024

    private static var pendingDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("SkyGrid/pending", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static var thumbnailCacheDirectory: URL {
        cacheDirectory(named: "thumb-cache")
    }

    private static var imageCacheDirectory: URL {
        cacheDirectory(named: "image-cache")
    }

    private static func cacheDirectory(named name: String) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("SkyGrid/\(name)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    static func writePendingImage(_ data: Data, filename: String) throws -> URL {
        let url = pendingDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func deletePendingImage(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Resolves a pending image's current on-disk location from its filename alone,
    /// rather than trusting a previously-persisted absolute `URL`. A container's UUID
    /// segment can change across an app container reassignment (e.g. an OS/App Store
    /// update), which would silently strand any `URL` saved before the reassignment —
    /// this always re-derives the path under the *current* container.
    static func pendingImageURL(filename: String) -> URL {
        pendingDirectory.appendingPathComponent(filename)
    }

    /// Deletes any file under the pending outbox directory whose name isn't in
    /// `filenames` — the leftovers of a capture that was superseded (see
    /// `UploadQueue.enqueue`) or otherwise dropped before it could be enqueued.
    static func purgeOrphanedPendingImages(keeping filenames: Set<String>) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: pendingDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in urls where !filenames.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Returns the original local photo while it is still waiting in the outbox.
    /// `PostDraft` deliberately gives the local file and remote path the same final
    /// component, which makes this a safe, short-lived bridge before Storage has the
    /// asset available.
    static func pendingImageData(forRemotePath remotePath: String) -> Data? {
        let filename = URL(fileURLWithPath: remotePath).lastPathComponent
        return try? Data(contentsOf: pendingDirectory.appendingPathComponent(filename))
    }

    static func cachedThumbnailData(forRemotePath remotePath: String) -> Data? {
        cachedData(in: thumbnailCacheDirectory, forRemotePath: remotePath)
    }

    static func cacheThumbnail(_ data: Data, forRemotePath remotePath: String) {
        cache(data, in: thumbnailCacheDirectory, forRemotePath: remotePath, limit: thumbnailCacheLimit)
    }

    /// Full-resolution equivalent of `cachedThumbnailData`/`cacheThumbnail`. Every
    /// remote path is create-only and immutable once uploaded (docID-per-day Storage
    /// rules never allow an overwrite), so caching by `remotePath` alone is always
    /// safe — there is no staleness case to invalidate against.
    static func cachedImageData(forRemotePath remotePath: String) -> Data? {
        cachedData(in: imageCacheDirectory, forRemotePath: remotePath)
    }

    static func cacheImage(_ data: Data, forRemotePath remotePath: String) {
        cache(data, in: imageCacheDirectory, forRemotePath: remotePath, limit: imageCacheLimit)
    }

    private static func cachedData(in directory: URL, forRemotePath remotePath: String) -> Data? {
        try? Data(contentsOf: cacheURL(in: directory, forRemotePath: remotePath))
    }

    private static func cache(_ data: Data, in directory: URL, forRemotePath remotePath: String, limit: Int) {
        try? data.write(to: cacheURL(in: directory, forRemotePath: remotePath), options: .atomic)
        trimCacheIfNeeded(directory: directory, limit: limit)
    }

    private static func cacheURL(in directory: URL, forRemotePath remotePath: String) -> URL {
        let filename = remotePath
            .data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return directory.appendingPathComponent("\(filename).jpg")
    }

    private static func trimCacheIfNeeded(directory: URL, limit: Int) {
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else { return }

        let entries = urls.compactMap { url -> (url: URL, size: Int, modifiedAt: Date)? in
            guard let values = try? url.resourceValues(forKeys: resourceKeys),
                  let size = values.fileSize,
                  let modifiedAt = values.contentModificationDate
            else { return nil }
            return (url, size, modifiedAt)
        }
        var totalSize = entries.reduce(0) { $0 + $1.size }
        guard totalSize > limit else { return }

        for entry in entries.sorted(by: { $0.modifiedAt < $1.modifiedAt }) where totalSize > limit {
            try? FileManager.default.removeItem(at: entry.url)
            totalSize -= entry.size
        }
    }
}
