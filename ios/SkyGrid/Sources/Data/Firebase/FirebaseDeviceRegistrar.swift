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
    private var pendingWrite: Task<Void, Never>?

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
        await enqueueWrite(uid: uid, token: token, includeToken: true)
    }

    /// Re-persists only the language field for the already-registered token, so a
    /// mid-session in-app language switch reaches server-sent notifications without
    /// waiting for the next token refresh.
    private func persistCurrentLanguage() async {
        guard let uid, let lastToken, !lastToken.isEmpty else { return }
        await enqueueWrite(uid: uid, token: lastToken, includeToken: false)
    }

    private func enqueueWrite(uid: String, token: String, includeToken: Bool) async {
        // A slower old-language write must never finish after a newer selection
        // and put server notifications back into the device's previous language.
        let previous = pendingWrite
        let task = Task {
            await previous?.value
            var fields: [String: Any] = [
                "updatedAt": FieldValue.serverTimestamp(),
                "language": currentLanguageCode(),
            ]
            if includeToken {
                fields["fcmToken"] = token
                fields["platform"] = "ios"
            }
            do {
                try await firestore.collection("users").document(uid).collection("devices")
                    .document(deviceTokenID(for: token)).setDataAsync(fields, merge: true)
            } catch {
                // A failed write is retried on the next token refresh or launch.
                // Notification setup must not block the daily capture flow.
            }
        }
        pendingWrite = task
        await task.value
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
