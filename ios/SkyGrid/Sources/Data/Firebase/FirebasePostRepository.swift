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

    func observePost(uid: String, localDate: LocalDate) -> AsyncStream<SkyPost?> {
        let document = postDocument(uid: uid, localDate: localDate)
        return AsyncStream { continuation in
            let listener = document.addSnapshotListener { snapshot, error in
                if let error {
                    // The SDK retries and re-invokes this closure once it recovers —
                    // ending the stream on the first error freezes the last yielded
                    // value (which may be an optimistic local write that never
                    // actually reached the server) forever, with no way to notice
                    // the write silently never synced. Yield `nil` instead so a
                    // stale "posted" state can't outlive an unconfirmed write.
                    Self.logger.error("observePost(\(localDate.docID, privacy: .public)) listener error: \(String(describing: error), privacy: .public)")
                    continuation.yield(nil)
                    return
                }
                continuation.yield(snapshot.flatMap(FirebaseDocumentCodec.post(from:)))
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func observePosts(uid: String, from: LocalDate, through: LocalDate) -> AsyncStream<[SkyPost]> {
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
                    continuation.yield([])
                    return
                }
                let posts = snapshot?.documents.compactMap(FirebaseDocumentCodec.post(from:)) ?? []
                continuation.yield(posts)
            }
            continuation.onTermination = { _ in listener.remove() }
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
            let nsError = error as NSError
            Self.logger.error("createPost(\(draft.localDate.docID, privacy: .public)) failed: \(String(describing: error), privacy: .public)")
            // `.setData` (a plain, non-merge set — not a transaction with an
            // `exists: false` precondition) never gets a distinct ALREADY_EXISTS
            // status from Firestore: when the document already exists, the rules
            // engine evaluates the write as an `update`, and this doc's rules
            // deny every update unconditionally, so the SDK surfaces a plain
            // `permission-denied` (code 7) — not code 6, and not a message
            // containing "already exists". The two checks below existed but
            // could never match this repository's actual failure mode, which
            // let a same-day recapture fall through to a generic `.unknown`/
            // `.permissionDenied` error: `PostPublisher` never rolled back the
            // matching `UploadQueue` row (it only does that for
            // `.alreadyPostedToday`), leaving an orphaned image endlessly
            // retrying a Storage upload no post document would ever reference.
            // `create`/`validPostKeys()`/the field-shape checks in
            // firestore.rules are all satisfied by data this app itself
            // constructs, so in practice the only way this document's create
            // gets rules-rejected is that it already exists.
            if nsError.code == 6
                || nsError.localizedDescription.localizedCaseInsensitiveContains("already exists")
                || (nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 7) {
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
