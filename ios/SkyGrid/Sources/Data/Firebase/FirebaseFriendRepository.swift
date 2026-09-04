@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseFunctions
import Foundation
import os

@MainActor
final class FirebaseFriendRepository: FriendRepository {
    private static let logger = Logger(subsystem: "com.takmin.skygrid", category: "friends")
    private let firestore: Firestore
    private let functions: Functions

    init(
        firestore: Firestore = Firestore.firestore(),
        functions: Functions = Functions.functions(region: FirebaseInviteRepository.region)
    ) {
        self.firestore = firestore
        self.functions = functions
    }

    func observeFriendships(uid: String) -> AsyncStream<FriendshipCollectionObservation> {
        let query = firestore.collection("friendships").whereField("members", arrayContains: uid)
        return AsyncStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    // See FirebasePostRepository.observePost: ending the stream on
                    // the first error would freeze buddy state forever instead of
                    // letting the SDK's automatic retry recover it.
                    Self.logger.error("observeFriendships(\(uid, privacy: .public)) listener error: \(String(describing: error), privacy: .public)")
                    continuation.yield(.unavailable)
                    return
                }
                let friendships = (snapshot?.documents ?? [])
                    .filter { (($0.data()["blockedBy"] as? [String]) ?? []).isEmpty }
                    .compactMap(FirebaseDocumentCodec.friendship(from:))
                    .sorted { $0.createdAt > $1.createdAt }
                continuation.yield(.value(friendships))
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func observeBlockedFriendships(uid: String) -> AsyncStream<BlockedFriendshipCollectionObservation> {
        // Same query as `observeFriendships` (Firestore only allows one
        // array-contains clause per query, and Security Rules can only prove a
        // `list` query safe when it is constrained by the exact field the rule
        // inspects — `members`, not `blockedBy`). The `blockedBy` filter therefore
        // has to happen client-side rather than as a second query clause.
        let query = firestore.collection("friendships").whereField("members", arrayContains: uid)
        return AsyncStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    Self.logger.error("observeBlockedFriendships(\(uid, privacy: .public)) listener error: \(String(describing: error), privacy: .public)")
                    continuation.yield(.unavailable)
                    return
                }
                let blocked = (snapshot?.documents ?? [])
                    .compactMap(FirebaseDocumentCodec.friendship(from:))
                    .filter { $0.blockedBy.contains(uid) }
                    .sorted { $0.createdAt > $1.createdAt }
                continuation.yield(.value(blocked))
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func sendRequest(
        from: String,
        to: String,
        requesterHandle: Handle,
        recipientHandle: Handle
    ) async throws -> FriendRequestResult {
        guard from != to else { throw RepositoryError.unknown(underlying: "You cannot add yourself as a buddy.") }
        do {
            // The protocol retains `from`/`to` for local repositories and test
            // doubles, but this Firebase path deliberately trusts neither. The
            // callable derives identities from Auth plus server-owned handle docs.
            _ = requesterHandle
            let result = try await functions.httpsCallable("requestBuddy").call([
                "recipientHandle": recipientHandle.value,
            ])
            guard let payload = result.data as? [String: Any],
                  let rawOutcome = payload["outcome"] as? String
            else { throw RepositoryError.unknown(underlying: "requestBuddy response was malformed.") }
            switch rawOutcome {
            case "sent": return .sent
            case "alreadyPending": return .alreadyPending
            case "incomingRequestExists": return .incomingRequestExists
            case "alreadyBuddies": return .alreadyBuddies
            case "blocked": return .blocked
            case "unknownHandle", "ownHandle":
                throw RepositoryError.unknown(underlying: "The buddy handle is no longer available.")
            default:
                throw RepositoryError.unknown(underlying: "requestBuddy returned an unknown outcome.")
            }
        } catch {
            Self.logger.error("sendRequest callable failed: \(String(describing: error), privacy: .public)")
            throw FirebaseRepositoryError.map(error)
        }
    }

    func acceptRequest(pairId: String, acceptingUid: String) async throws -> FriendRequestAcceptanceResult {
        do {
            _ = acceptingUid
            let result = try await functions.httpsCallable("acceptBuddy").call(["pairId": pairId])
            guard let payload = result.data as? [String: Any],
                  let rawOutcome = payload["outcome"] as? String
            else { throw RepositoryError.unknown(underlying: "acceptBuddy response was malformed.") }
            switch rawOutcome {
            case "accepted": return .accepted
            case "alreadyAccepted": return .alreadyAccepted
            case "circleFull": return .circleFull
            case "buddyCircleFull": return .buddyCircleFull
            case "invalidRequest": return .invalidRequest
            default: throw RepositoryError.unknown(underlying: "acceptBuddy returned an unknown outcome.")
            }
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func removeFriendship(pairId: String) async throws {
        do {
            try await firestore.collection("friendships").document(pairId).deleteAsync()
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func block(ownerUid: String, blockedUid: String) async throws {
        guard ownerUid != blockedUid else { return }
        let document = firestore.collection("friendships").document(PairID.make(ownerUid, blockedUid))
        do {
            _ = try await firestore.runTransaction { transaction, errorPointer in
                do {
                    guard try transaction.getDocument(document).exists else { return nil }
                    transaction.updateData(["blockedBy": FieldValue.arrayUnion([ownerUid])], forDocument: document)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func unblock(ownerUid: String, blockedUid: String) async throws {
        let document = firestore.collection("friendships").document(PairID.make(ownerUid, blockedUid))
        do {
            _ = try await firestore.runTransaction { transaction, errorPointer in
                do {
                    guard try transaction.getDocument(document).exists else { return nil }
                    transaction.updateData(["blockedBy": FieldValue.arrayRemove([ownerUid])], forDocument: document)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func isBlocked(ownerUid: String, otherUid: String) async throws -> Bool {
        do {
            let snapshot = try await firestore.collection("friendships").document(PairID.make(ownerUid, otherUid))
                .getDocumentAsync()
            return ((snapshot.data()?["blockedBy"] as? [String]) ?? []).contains(ownerUid)
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }
}
