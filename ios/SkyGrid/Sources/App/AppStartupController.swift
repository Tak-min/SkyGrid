import Foundation
import Observation

@MainActor
@Observable
final class AppStartupController {
    enum State {
        case idle
        case loading
        case ready(AppServices)
        case deleted
        case failed(AppStartupError)
    }

    private(set) var state: State = .idle

    func start() async {
        if case .loading = state {
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
        await establishSession()
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
