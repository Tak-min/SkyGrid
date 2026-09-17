import Foundation
import FirebaseFirestore
import os

@MainActor
final class EarlyAdopterGrantRepository {
    private static let logger = Logger(subsystem: "com.takmin.skygrid", category: "early-adopter")
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    /// Reads the early adopter grant document for the current user once.
    /// Returns true if the grant status is "granted", false otherwise (including when not found).
    /// Treats missing documents as "not applicable" rather than an error.
    func checkGrantStatus(uid: String) async -> Bool {
        do {
            let snapshot = try await firestore.collection("earlyAdopterGrants")
                .document(uid)
                .getDocumentAsync()

            guard snapshot.exists,
                  let data = snapshot.data(),
                  let status = data["status"] as? String
            else {
                return false
            }

            return status == "granted"
        } catch {
            Self.logger.error("checkGrantStatus(\(uid, privacy: .public)) failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
