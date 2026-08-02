@preconcurrency import FirebaseStorage
import Foundation

struct FirebaseImageStore: ImageFetching, ImageUploading {
    private let storage: Storage

    init(storage: Storage = Storage.storage()) {
        self.storage = storage
    }

    func fetchImage(path: String) async throws -> Data {
        do {
            // Captures are compressed to roughly 200–400 KB before entering the
            // outbox. The cap rejects unexpectedly large or malformed payloads.
            return try await storage.reference(withPath: path).data(maxSize: 5 * 1024 * 1024)
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func upload(fileURL: URL, to path: String, contentType: String) async throws {
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        do {
            _ = try await storage.reference(withPath: path).putFileAsync(from: fileURL, metadata: metadata)
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func imageExists(path: String) async -> Bool {
        (try? await storage.reference(withPath: path).getMetadata()) != nil
    }

    func imagePresence(path: String) async -> RemoteImagePresence {
        do {
            _ = try await storage.reference(withPath: path).getMetadata()
            return .present
        } catch {
            let nsError = error as NSError
            // -13010 is StorageErrorCode.objectNotFound — the one Storage response
            // that positively proves the object was never written, as opposed to a
            // network/App-Check/permission failure that only proves the read failed.
            if nsError.domain == "FirebaseStorage.StorageErrorCode", nsError.code == -13010 {
                return .absent
            }
            return .indeterminate
        }
    }
}
