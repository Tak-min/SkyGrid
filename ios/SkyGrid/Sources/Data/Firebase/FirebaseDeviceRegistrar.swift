@preconcurrency import FirebaseFirestore
import FirebaseMessaging
import Foundation
import CryptoKit

/// Persists the current device's FCM token under the signed-in user. The token is
/// never exposed to other clients; it only gives the server a delivery address for
/// future buddy/reminder notifications.
@MainActor
final class FirebaseDeviceRegistrar {
    private let firestore: Firestore
    private var uid: String?
    private var tokenObserver: NSObjectProtocol?

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
        tokenObserver = NotificationCenter.default.addObserver(
            forName: .skyGridFCMTokenDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.userInfo?["token"] as? String else { return }
            Task { @MainActor in
                await self?.persist(token: token)
            }
        }
    }

    deinit {
        if let tokenObserver {
            NotificationCenter.default.removeObserver(tokenObserver)
        }
    }

    func start(for uid: String) {
        self.uid = uid
        Messaging.messaging().token { [weak self] token, _ in
            guard let token else { return }
            Task { @MainActor in
                await self?.persist(token: token)
            }
        }
    }

    private func persist(token: String) async {
        guard let uid, !token.isEmpty else { return }
        let tokenID = SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
        do {
            try await firestore.collection("users").document(uid).collection("devices").document(tokenID)
                .setDataAsync([
                    "fcmToken": token,
                    "updatedAt": FieldValue.serverTimestamp(),
                    "platform": "ios",
                ], merge: true)
        } catch {
            // Registration is retried on the next FCM token refresh or launch; it
            // must never block camera capture or account startup.
        }
    }
}

extension Notification.Name {
    static let skyGridFCMTokenDidChange = Notification.Name("SkyGrid.FCMTokenDidChange")
}
