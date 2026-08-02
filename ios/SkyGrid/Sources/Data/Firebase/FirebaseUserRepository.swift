@preconcurrency import FirebaseFirestore
import Foundation
import os

@MainActor
final class FirebaseUserRepository: UserRepository {
    private static let logger = Logger(subsystem: "com.takmin.skygrid", category: "users")
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func observeProfile(uid: String) -> AsyncStream<UserProfile?> {
        let document = firestore.collection("users").document(uid)
        return AsyncStream { continuation in
            let listener = document.addSnapshotListener { snapshot, error in
                if let error {
                    // Keep the last known profile state while Firestore retries.
                    // Yielding nil here would turn a failed read into "no handle",
                    // incorrectly presenting the claim form while every save is
                    // still being rejected by the backend.
                    Self.logger.error("observeProfile(\(uid, privacy: .public)) listener error: \(String(describing: error), privacy: .public)")
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
                    if handleSnapshot.exists,
                       handleSnapshot.data()?["uid"] as? String != uid {
                        errorPointer?.pointee = Self.domainError(code: 409, message: "That handle is already claimed.")
                        return nil
                    }

                    let profileSnapshot = try transaction.getDocument(profileDocument)
                    let existingHandle = profileSnapshot.data()?["handle"]
                    if let existingHandle,
                       (existingHandle as? String) != handle.value {
                        errorPointer?.pointee = Self.domainError(code: 409, message: "Handles cannot be changed.")
                        return nil
                    }

                    if !handleSnapshot.exists {
                        transaction.setData([
                            "uid": uid,
                            "createdAt": FieldValue.serverTimestamp(),
                        ], forDocument: handleDocument)
                    }

                    if profileSnapshot.exists {
                        if existingHandle == nil {
                            // Profiles can predate a handle (for example, after a
                            // future settings/profile write). Claiming the optional
                            // handle must not rewrite any profile or server-owned
                            // fields. If it is already ours, this transaction is an
                            // intentional no-op so a retry succeeds.
                            transaction.updateData(["handle": handle.value], forDocument: profileDocument)
                        }
                    } else {
                        transaction.setData([
                            "handle": handle.value,
                            "displayName": "Sky Grid member",
                            "timezone": TimeZone.current.identifier,
                            "wakeGoalMinutes": LocalDefaults.wakeGoalMinutes,
                            "streakCurrent": 0,
                            "streakLongest": 0,
                            "isPro": false,
                            "createdAt": FieldValue.serverTimestamp(),
                        ], forDocument: profileDocument)
                    }
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
            Self.logger.error("claimHandle failed: \(String(describing: error), privacy: .public)")
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
