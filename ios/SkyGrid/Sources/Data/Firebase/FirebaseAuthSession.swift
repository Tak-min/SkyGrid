import FirebaseAuth
import Foundation

@MainActor
enum FirebaseAuthSession {
    static func ensureCurrentUser() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }
        do {
            return try await Auth.auth().signInAnonymously().user.uid
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }
}
