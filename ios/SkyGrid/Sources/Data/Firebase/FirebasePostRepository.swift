@preconcurrency import FirebaseFirestore
import Foundation

@MainActor
final class FirebasePostRepository: PostRepository {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func observePost(uid: String, localDate: LocalDate) -> AsyncStream<SkyPost?> {
        let document = postDocument(uid: uid, localDate: localDate)
        return AsyncStream { continuation in
            let listener = document.addSnapshotListener { snapshot, error in
                guard error == nil else {
                    continuation.finish()
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
                guard error == nil else {
                    continuation.finish()
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
            if nsError.code == 6 || nsError.localizedDescription.localizedCaseInsensitiveContains("already exists") {
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
