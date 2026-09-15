@preconcurrency import FirebaseFirestore
import FirebaseMessaging
import Foundation
import CryptoKit

/// Persists the current device's FCM token under the signed-in user. The token is
/// never exposed to other clients; it only gives the server a delivery address for
/// future buddy/reminder notifications. Also persists the in-app selected language
/// so server-sent notifications can be written in the recipient's chosen language.
@MainActor
final class FirebaseDeviceRegistrar {
    private let firestore: Firestore
    private var uid: String?
    private var lastToken: String?
    private var tokenObserver: NSObjectProtocol?
    private var languageObserver: NSObjectProtocol?

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
        languageObserver = NotificationCenter.default.addObserver(
            forName: .skyGridLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.persistCurrentLanguage()
            }
        }
    }

    deinit {
        if let tokenObserver {
            NotificationCenter.default.removeObserver(tokenObserver)
        }
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
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
        lastToken = token
        let tokenID = deviceTokenID(for: token)
        do {
            try await firestore.collection("users").document(uid).collection("devices").document(tokenID)
                .setDataAsync([
                    "fcmToken": token,
                    "updatedAt": FieldValue.serverTimestamp(),
                    "platform": "ios",
                    "language": currentLanguageCode(),
                ], merge: true)
        } catch {
            // Registration is retried on the next FCM token refresh or launch; it
            // must never block camera capture or account startup.
        }
    }

    /// Re-persists only the language field for the already-registered token, so a
    /// mid-session in-app language switch reaches server-sent notifications without
    /// waiting for the next token refresh.
    private func persistCurrentLanguage() async {
        guard let uid, let lastToken, !lastToken.isEmpty else { return }
        let tokenID = deviceTokenID(for: lastToken)
        do {
            try await firestore.collection("users").document(uid).collection("devices").document(tokenID)
                .setDataAsync([
                    "updatedAt": FieldValue.serverTimestamp(),
                    "language": currentLanguageCode(),
                ], merge: true)
        } catch {
            // Same non-blocking discipline as `persist(token:)`: retried on the next
            // token refresh or launch if this write fails.
        }
    }

    private func deviceTokenID(for token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func currentLanguageCode() -> String {
        (LocalDefaults.selectedLanguageCode.flatMap(AppLanguage.init(rawValue:)) ?? AppLanguage.inferred()).rawValue
    }
}

extension Notification.Name {
    static let skyGridFCMTokenDidChange = Notification.Name("SkyGrid.FCMTokenDidChange")
}
