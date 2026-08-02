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

    init(functions: Functions = Functions.functions()) {
        self.functions = functions
    }

    func deleteAccount(uid: String) async throws {
        guard Auth.auth().currentUser?.uid == uid else {
            throw RepositoryError.notAuthenticated
        }

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
            throw FirebaseRepositoryError.map(error)
        }

        try? Auth.auth().signOut()
        await DeviceAccountDataWiper.erase()
    }
}

@MainActor
private enum DeviceAccountDataWiper {
    static func erase() async {
        // A system alarm outlives our JSON/SwiftData files, so remove it before
        // deleting the account. Otherwise a deleted account could still ring.
        await MorningAlarmScheduler.disable()

        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let skyGridDirectory = appSupport.appendingPathComponent("SkyGrid", isDirectory: true)
        if fileManager.fileExists(atPath: skyGridDirectory.path) {
            try? fileManager.removeItem(at: skyGridDirectory)
        }

        // The default SwiftData store lives beside Application Support. Remove only
        // its documented basename and sidecars, never the entire shared directory.
        for filename in ["default.store", "default.store-shm", "default.store-wal"] {
            let url = appSupport.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
            }
        }

        LocalDefaults.resetAccountScopedValues()
    }
}
