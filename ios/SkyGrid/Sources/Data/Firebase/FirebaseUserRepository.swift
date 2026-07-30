@preconcurrency import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseUserRepository: UserRepository {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func observeProfile(uid: String) -> AsyncStream<UserProfile?> {
        let document = firestore.collection("users").document(uid)
        return AsyncStream { continuation in
            let listener = document.addSnapshotListener { snapshot, error in
                guard error == nil else {
                    continuation.finish()
                    return
                }
                continuation.yield(snapshot.flatMap(FirebaseDocumentCodec.profile(from:)))
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func createOrUpdateProfile(_ profile: UserProfile) async throws {
        do {
            // Handles are immutable and can only be changed through claimHandle.
            // Ordinary profile updates must never overwrite that mapping.
            try await firestore.collection("users")
                .document(profile.uid)
                .setDataAsync(FirebaseDocumentCodec.mutableProfileData(from: profile), merge: true)
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func claimHandle(_ handle: Handle, for uid: String) async throws {
        let handleDocument = firestore.collection("handles").document(handle.value)
        let profileDocument = firestore.collection("users").document(uid)

        do {
            _ = try await firestore.runTransaction { transaction, errorPointer in
                do {
                    let handleSnapshot = try transaction.getDocument(handleDocument)
                    if let owner = handleSnapshot.data()?["uid"] as? String, owner != uid {
                        errorPointer?.pointee = Self.domainError(code: 409, message: "That handle is already claimed.")
                        return nil
                    }

                    let profileSnapshot = try transaction.getDocument(profileDocument)
                    if let existing = profileSnapshot.data()?["handle"] as? String, existing != handle.value {
                        errorPointer?.pointee = Self.domainError(code: 409, message: "Handles cannot be changed.")
                        return nil
                    }

                    transaction.setData([
                        "uid": uid,
                        "createdAt": FieldValue.serverTimestamp(),
                    ], forDocument: handleDocument, merge: true)
                    transaction.setData([
                        "handle": handle.value,
                        "displayName": profileSnapshot.data()?["displayName"] as? String ?? "Sky Grid member",
                        "timezone": profileSnapshot.data()?["timezone"] as? String ?? TimeZone.current.identifier,
                        "wakeGoalMinutes": profileSnapshot.data()?["wakeGoalMinutes"] as? Int ?? LocalDefaults.wakeGoalMinutes,
                        "streakCurrent": profileSnapshot.data()?["streakCurrent"] as? Int ?? 0,
                        "streakLongest": profileSnapshot.data()?["streakLongest"] as? Int ?? 0,
                        "isPro": profileSnapshot.data()?["isPro"] as? Bool ?? false,
                        "createdAt": FieldValue.serverTimestamp(),
                    ], forDocument: profileDocument, merge: true)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == Self.errorDomain, nsError.code == 409 {
                throw RepositoryError.handleAlreadyTaken
            }
            throw FirebaseRepositoryError.map(error)
        }
    }

    func findUid(forHandle handle: Handle) async throws -> String? {
        do {
            let snapshot = try await firestore.collection("handles").document(handle.value).getDocumentAsync()
            return snapshot.data()?["uid"] as? String
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    private static let errorDomain = "SkyGrid.Firebase.User"

    private static func domainError(code: Int, message: String) -> NSError {
        NSError(domain: errorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
