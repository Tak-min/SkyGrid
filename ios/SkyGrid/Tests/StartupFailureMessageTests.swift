import Foundation
import Testing
@testable import SkyGrid

/// Guards the fix for audit finding B2: the startup failure screen used to render
/// `error.localizedDescription` verbatim, putting `"(SkyGrid.RepositoryError error 1.)"`
/// on the very first screen a new user sees.
///
/// These assertions live here rather than in the UI test because `ContentUnavailableView`
/// does not expose its title/description as individually addressable elements, so
/// XCUITest cannot read this copy at all — see `SkyGridUITests`.
@Suite("StartupFailureMessage")
struct StartupFailureMessageTests {
    private let allErrors: [AppStartupError] = [
        .firebaseConfigurationMissing,
        .backendUnavailable("The operation couldn't be completed. (SkyGrid.RepositoryError error 1.)")
    ]

    @Test("no failure ever shows the underlying error's own description")
    func neverLeaksUnderlyingDescription() {
        let underlying = "The operation couldn't be completed. (SkyGrid.RepositoryError error 1.)"
        let message = StartupFailureMessage.make(for: .backendUnavailable(underlying))
        #expect(!message.title.contains(underlying))
        #expect(!message.recovery.contains(underlying))
    }

    @Test("no failure leaks an internal type name or error code shape")
    func neverLeaksInternalIdentifiers() {
        for error in allErrors {
            let message = StartupFailureMessage.make(for: error)
            let shown = message.title + " " + message.recovery
            #expect(!shown.contains("SkyGrid."))
            #expect(!shown.contains("RepositoryError"))
            #expect(!shown.contains("Error Domain"))
            #expect(!shown.lowercased().contains("nserror"))
            #expect(!shown.contains("error 1"))
        }
    }

    @Test("every failure states what happened and what to do about it")
    func everyFailureIsActionable() {
        for error in allErrors {
            let message = StartupFailureMessage.make(for: error)
            #expect(!message.title.isEmpty)
            #expect(!message.recovery.isEmpty)
            #expect(message.title != message.recovery)
        }
    }

    /// The two cases are deliberately worded differently: a missing plist is a build
    /// problem the user cannot retry away, while a backend failure is transient.
    @Test("the two failures are not described interchangeably")
    func failuresAreDistinguishable() {
        let missing = StartupFailureMessage.make(for: .firebaseConfigurationMissing)
        let unavailable = StartupFailureMessage.make(for: .backendUnavailable("x"))
        #expect(missing != unavailable)
    }

    @Test("diagnostic detail is retained for logging even though it is never shown")
    func diagnosticDetailIsRetained() {
        let detail = StartupFailureMessage.diagnosticDetail(for: .backendUnavailable("boom"))
        #expect(detail.contains("boom"))
        let shown = StartupFailureMessage.make(for: .backendUnavailable("boom"))
        #expect(!shown.recovery.contains("boom"))
    }
}
