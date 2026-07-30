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
}
