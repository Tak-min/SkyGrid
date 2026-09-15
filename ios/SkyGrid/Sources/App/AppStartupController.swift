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
            authenticationError = L10n.string("startup.newAccount.error")
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
            authenticationError = L10n.string("startup.appleSignIn.error")
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

    // Routed through `L10n.string(_:)`: a stored `String?` property (via
    // `LocalizedError`), not a `Text("literal")` call site (see
    // `dev-notes/localization-en-ja-stage2_*.md`). `.firebaseConfigurationMissing`
    // is a dev-machine misconfiguration, not a real end-user path, but is still
    // routed for consistency and to keep the mixed-language scan honest.
    var errorDescription: String? {
        switch self {
        case .firebaseConfigurationMissing:
            L10n.string("error.appStartup.firebaseConfigMissing")
        case .backendUnavailable(let description):
            String(format: L10n.string("error.appStartup.backendUnavailable"), description)
        }
    }
}
