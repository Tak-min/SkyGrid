import Foundation

/// Where captured-but-not-yet-uploaded photo bytes live on disk. Deliberately
/// `Application Support/`, never `Caches/` — the OS can purge `Caches` at any time,
/// which for this app would mean silently losing a morning's only photo before it
/// finishes uploading (blueprint §3.1 / gotcha #5). Remote images are fetched
/// directly through Firebase Storage; this type never pretends local files are an
/// uploaded asset.
enum ImageFileStore {
    private static var pendingDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("SkyGrid/pending", isDirectory: true)
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
}
