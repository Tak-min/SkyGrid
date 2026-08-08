@preconcurrency import FirebaseStorage
@preconcurrency import FirebaseFunctions
import Foundation

struct FirebaseImageStore: ImageFetching, ImageUploading {
    private let storage: Storage
    private let functions: Functions

    init(storage: Storage = Storage.storage(), functions: Functions = Functions.functions()) {
        self.storage = storage
        self.functions = functions
    }

    func fetchImage(path: String) async throws -> Data {
        do {
            // Shared bytes are authorized and delivered by the callable's
            // server-side friendship predicate. Direct Storage reads remain
            // owner-only so a production Storage Rules cross-service lookup
            // cannot turn a valid buddy photo into a false permission denial.
            let result = try await functions.httpsCallable("imageDownloadURL").call(["path": path])
            guard let payload = result.data as? [String: Any],
                  let base64 = payload["base64"] as? String,
                  let imageData = Data(base64Encoded: base64)
            else { throw RepositoryError.unknown(underlying: "Image response was malformed.") }
            return imageData
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
