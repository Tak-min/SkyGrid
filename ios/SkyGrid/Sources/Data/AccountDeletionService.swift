import Foundation
import FirebaseAuth
import FirebaseFunctions

@MainActor
protocol AccountDeleting: Sendable {
    /// Deletes server-side account data, then removes this device's account-scoped
    /// cache. A replacement anonymous identity is only created after onboarding is
    /// explicitly restarted.
    func deleteAccount(uid: String) async throws
}

@MainActor
final class FirebaseAccountDeletionService: AccountDeleting {
    private let functions: Functions
    private let uploadQueue: UploadQueue?

    init(
        functions: Functions = Functions.functions(),
        uploadQueue: UploadQueue? = nil
    ) {
        self.functions = functions
        self.uploadQueue = uploadQueue
    }

    func deleteAccount(uid: String) async throws {
        guard Auth.auth().currentUser?.uid == uid else {
            throw RepositoryError.notAuthenticated
        }

        await uploadQueue?.suspendAccount(uid)
        do {
            // The callable derives the target UID exclusively from the verified
            // Firebase Auth context. No client-supplied UID is sent or trusted.
            // Limited-use App Check tokens are deliberately NOT requested: the App
            // Check debug provider's limited-use exchange is rejected server-side in
            // this project, the SDK then substitutes a placeholder token, and the
            // callable rejects that as an undecodable JWT — making deletion
            // impossible in every build configuration this app can currently test.
            // `consumeAppCheckToken` server-side never actually enforced replay
            // protection either (firebase-functions only records
            // `alreadyConsumed`, it never rejects on it), so nothing is lost by
            // removing it. Replay resistance instead comes from the callable being
            // idempotent and scoped only to the verified caller's own uid.
            _ = try await functions.httpsCallable("deleteAccount").call()
        } catch {
            await uploadQueue?.resumeAccount(uid)
            throw FirebaseRepositoryError.map(error)
        }

        try? Auth.auth().signOut()
        await uploadQueue?.discardAccountData(uid)
        DeviceAccountDataWiper.erase()
    }
}

@MainActor
private enum DeviceAccountDataWiper {
    static func erase() {
        // A system alarm outlives our JSON/SwiftData files, so remove it before
        // deleting the account. Otherwise a deleted account could still ring.
        // The server deletion has already succeeded when this runs. Clearing the
        // alarm flag and the system alarm is synchronous; the remaining
        // ActivityKit cleanup is intentionally best-effort so a system service
        // that never acknowledges its Live Activity teardown cannot trap the
        // person on the deletion progress screen.
        MorningAlarmScheduler.disableForAccountDeletion()

        ImageFileStore.eraseAllAccountImages()

        LocalDefaults.resetAccountScopedValues()
    }
}
