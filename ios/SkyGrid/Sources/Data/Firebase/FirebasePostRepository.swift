@preconcurrency import FirebaseFirestore
import Foundation
import os

@MainActor
final class FirebasePostRepository: PostRepository {
    private static let logger = Logger(subsystem: "com.takmin.skygrid", category: "posts")
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func observePost(uid: String, localDate: LocalDate) -> AsyncStream<PostObservation> {
        let document = postDocument(uid: uid, localDate: localDate)
        return AsyncStream { continuation in
            let listener = document.addSnapshotListener { snapshot, error in
                if let error {
                    // The SDK retries and re-invokes this closure once it recovers.
                    // A failed read must not be represented as an empty day: that
                    // would enable capture after an App Check failure and make the
                    // subsequent rejection look like a duplicate post.
                    Self.logger.error("observePost(\(localDate.docID, privacy: .public)) listener error: \(String(describing: error), privacy: .public)")
                    continuation.yield(.unavailable)
                    return
                }
                continuation.yield(.value(snapshot.flatMap(FirebaseDocumentCodec.post(from:))))
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func observePosts(uid: String, from: LocalDate, through: LocalDate) -> AsyncStream<PostCollectionObservation> {
        let query = firestore.collection("users")
            .document(uid)
            .collection("posts")
            .order(by: FieldPath.documentID())
            .start(at: [from.docID])
            .end(at: [through.docID])

        return AsyncStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    Self.logger.error("observePosts(\(uid, privacy: .public)) listener error: \(String(describing: error), privacy: .public)")
                    continuation.yield(.unavailable)
                    return
                }
                let posts = snapshot?.documents.compactMap(FirebaseDocumentCodec.post(from:)) ?? []
                continuation.yield(.value(posts))
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func fetchPost(uid: String, localDate: LocalDate) async throws -> SkyPost? {
        do {
            let snapshot = try await postDocument(uid: uid, localDate: localDate).getDocument(source: .server)
            return FirebaseDocumentCodec.post(from: snapshot)
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func createPost(_ draft: PostDraft) async throws {
        let document = postDocument(uid: draft.ownerUid, localDate: draft.localDate)
        do {
            // Unlike a Firestore transaction, a normal write is durably queued by
            // the SDK while offline. Rules still permit only a document create, so
            // the `YYYY-MM-DD` document ID remains the one-post-per-day boundary.
            try await document.setDataAsync(FirebaseDocumentCodec.postData(from: draft))
        } catch {
            Self.logger.error("createPost(\(draft.localDate.docID, privacy: .public)) failed: \(String(describing: error), privacy: .public)")
            if FirebasePostWriteFailure.isExplicitDuplicate(error) {
                throw RepositoryError.alreadyPostedToday
            }

            // A create-only Firestore rule reports both a genuine duplicate and
            // App Check/auth/clock failures as `permission-denied`. Only call it
            // a duplicate when a fresh server read confirms the document exists;
            // otherwise preserve the actual failure for a truthful recovery path.
            if FirebasePostWriteFailure.isPermissionDenied(error),
               let existing = try? await document.getDocument(source: .server),
               existing.exists {
                throw RepositoryError.alreadyPostedToday
            }
            throw FirebaseRepositoryError.map(error)
        }
    }

    func deletePost(uid: String, localDate: LocalDate) async throws {
        do {
            try await postDocument(uid: uid, localDate: localDate).deleteAsync()
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    private func postDocument(uid: String, localDate: LocalDate) -> DocumentReference {
        firestore.collection("users").document(uid).collection("posts").document(localDate.docID)
    }
}

/// Pure error predicates used by `createPost`, kept testable without a Firebase
/// project or App Check token.
enum FirebasePostWriteFailure {
    static func isExplicitDuplicate(_ error: Error) -> Bool {
        let nsError = error as NSError
        return (nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 6)
            || nsError.localizedDescription.localizedCaseInsensitiveContains("already exists")
    }

    static func isPermissionDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 7
    }
}
