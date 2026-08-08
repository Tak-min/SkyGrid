import AuthenticationServices
import Foundation
import Observation

@MainActor
@Observable
final class AppStartupController {
    enum State {
        case idle
        case loading
        case authenticationRequired
        case ready(AppServices)
        case deleted
        case failed(AppStartupError)
    }

    private(set) var state: State = .idle
    private(set) var authenticationError: String?

    func start() async {
        if case .loading = state {
            return
        }
        guard FirebaseAuthSession.isConfigured else {
            state = .failed(.firebaseConfigurationMissing)
            return
        }
        guard FirebaseAuthSession.hasCurrentUser else {
            authenticationError = nil
            state = .authenticationRequired
            return
        }
        await establishSession()
    }

    func restartAfterAccountDeletion() async {
        // Account deletion intentionally leaves the app unsigned-out and dormant.
        // A new anonymous identity is only created from the explicit Start fresh
        // action, never as a side effect of deletion.
        state = .deleted
    }

    func startNewAnonymousSession() async {
        authenticationError = nil
        guard FirebaseAuthSession.isConfigured else {
            state = .failed(.firebaseConfigurationMissing)
            return
        }
        state = .loading
        do {
            _ = try await FirebaseAuthSession.startFreshAnonymousUser()
            await establishSession()
        } catch {
            state = .authenticationRequired
            authenticationError = "新しいアカウントを準備できませんでした。通信を確認して、もう一度お試しください。"
        }
    }

    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential,
        rawNonce: String
    ) async {
        authenticationError = nil
        state = .loading
        do {
            _ = try await FirebaseAuthSession.signInWithApple(credential: credential, rawNonce: rawNonce)
            await establishSession()
        } catch let error as AppleAccountLinkError {
            state = .authenticationRequired
            guard error != .cancelled else { return }
            authenticationError = error.localizedDescription
        } catch {
            state = .authenticationRequired
            authenticationError = "Apple へのサインインを完了できませんでした。もう一度お試しください。"
        }
    }

    func appleAuthorizationFailed(_ error: Error) {
        state = .authenticationRequired
        let linkError = AppleAccountLinkError.map(error)
        guard linkError != .cancelled else { return }
        authenticationError = linkError.localizedDescription
    }

    private func establishSession() async {
        state = .loading
        do {
            state = .ready(try await ServiceFactory.makeAppServices())
        } catch let error as AppStartupError {
            state = .failed(error)
        } catch {
            state = .failed(.backendUnavailable(error.localizedDescription))
        }
    }
}

enum AppStartupError: Error, Equatable, LocalizedError {
    case firebaseConfigurationMissing
    case backendUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .firebaseConfigurationMissing:
            "Firebase configuration is missing. Add the GoogleService-Info.plist for com.takmin.skygrid before running Sky Grid."
        case .backendUnavailable(let description):
            "Sky Grid could not connect. Check your connection and try again. \(description)"
        }
    }
}
