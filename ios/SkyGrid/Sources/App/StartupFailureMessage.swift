import Foundation

/// The single place that turns a startup failure into words a person reads.
///
/// This exists because the failure screen used to render `error.localizedDescription`
/// verbatim, and `AppStartupError.backendUnavailable` interpolated the underlying
/// error's description into its own message. The result on the app's very first
/// screen was:
///
///     "Sky Grid could not connect. Check your connection and try again.
///      The operation couldn't be completed. (SkyGrid.RepositoryError error 1.)"
///
/// Routing every failure through this type means no internal error text, domain
/// name, or numeric code can reach the UI, regardless of how deep the throwing call
/// site is. Diagnostic detail is still preserved for the log via
/// `diagnosticDetail` — it is simply never displayed.
struct StartupFailureMessage: Equatable {
    /// One sentence naming what went wrong, in the user's terms.
    let title: String
    /// One sentence telling them what to do, and reassuring them about their data.
    let recovery: String

    static func make(for error: AppStartupError) -> Self {
        switch error {
        case .firebaseConfigurationMissing:
            // Only reachable in a misconfigured development build — a shipped app
            // always bundles its plist — so this one may name the real cause.
            Self(
                title: "Sky Grid isn't configured.",
                recovery: "This build is missing its Firebase configuration file."
            )
        case .backendUnavailable:
            Self(
                title: "Sky Grid couldn't connect.",
                recovery: "Check your connection and try again. Your archive hasn't changed."
            )
        }
    }

    /// Diagnostic text for `Logger` only — never rendered. Kept next to the mapper so
    /// it is obvious that the detail is retained rather than discarded.
    static func diagnosticDetail(for error: AppStartupError) -> String {
        switch error {
        case .firebaseConfigurationMissing:
            "firebaseConfigurationMissing"
        case .backendUnavailable(let underlying):
            "backendUnavailable: \(underlying)"
        }
    }
}
