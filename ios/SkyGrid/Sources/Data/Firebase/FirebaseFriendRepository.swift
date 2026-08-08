@preconcurrency import FirebaseFirestore
import Foundation
import os

@MainActor
final class FirebaseFriendRepository: FriendRepository {
    private static let logger = Logger(subsystem: "com.takmin.skygrid", category: "friends")
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
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
        let pairID = PairID.make(from, to)
        let document = firestore.collection("friendships").document(pairID)
        do {
            // Do not transaction-read an absent pair before creating it. Rules
            // intentionally permit reads only to existing members, so that shape
            // is denied before the transaction can ever reach its create. A direct
            // set is create-only in practice: if the deterministic document exists,
            // the strict update rule rejects replacing its immutable fields.
            try await document.setDataAsync([
                "members": [from, to].sorted(),
                "status": FriendshipStatus.pending.rawValue,
                "requestedBy": from,
                "requestedByHandle": requesterHandle.value,
                "recipientHandle": recipientHandle.value,
                "createdAt": FieldValue.serverTimestamp(),
                "blockedBy": [],
            ])
            return .sent
        } catch {
            let originalError = FirebaseRepositoryError.map(error)

            // Duplicate taps, reciprocal requests, accepted connections, and
            // blocks all arrive here because overwriting an existing pair is
            // forbidden. Once it exists, this member may read it and turn that
            // rejection into truthful, actionable UI. If the read also fails
            // (App Check, auth, network, or a genuinely absent target), preserve
            // the original infrastructure error instead of calling it a duplicate.
            if let snapshot = try? await document.getDocumentAsync(),
               snapshot.exists,
               let friendship = FirebaseDocumentCodec.friendship(from: snapshot),
               friendship.members.contains(from), friendship.members.contains(to) {
                if !friendship.blockedBy.isEmpty {
                    return .blocked
                }
                switch friendship.status {
                case .accepted:
                    return .alreadyBuddies
                case .pending where friendship.requestedBy == from:
                    return .alreadyPending
                case .pending:
                    return .incomingRequestExists
                }
            }
            Self.logger.error("sendRequest(\(pairID, privacy: .public)) failed: \(String(describing: error), privacy: .public)")
            throw originalError
        }
    }

    func acceptRequest(pairId: String, acceptingUid: String) async throws {
        let document = firestore.collection("friendships").document(pairId)
        do {
            _ = try await firestore.runTransaction { transaction, errorPointer in
                do {
                    let snapshot = try transaction.getDocument(document)
                    guard let friendship = FirebaseDocumentCodec.friendship(from: snapshot),
                          friendship.status == .pending,
                          friendship.members.contains(acceptingUid),
                          friendship.requestedBy != acceptingUid
                    else {
                        errorPointer?.pointee = NSError(
                            domain: "SkyGrid.Firebase.Friends",
                            code: 403,
                            userInfo: [NSLocalizedDescriptionKey: "This request cannot be accepted."]
                        )
                        return nil
                    }
                    transaction.updateData(["status": FriendshipStatus.accepted.rawValue], forDocument: document)
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
