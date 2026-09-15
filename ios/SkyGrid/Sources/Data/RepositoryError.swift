import Foundation

/// Cross-layer error type. Firebase-specific errors are folded into this at the
/// `Data/Firestore/` boundary so nothing above `Data/` ever imports FirebaseFirestore.
///
/// Conforms to `LocalizedError` so that any path which surfaces one of these to a
/// person shows a sentence written for them. Without it, Foundation falls back to
/// the enum's default description and users were shown literal internal text —
/// `"The operation couldn't be completed. (SkyGrid.RepositoryError error 1.)"` was
/// reaching the first screen of the app.
///
/// The `underlying` strings stay on the cases for logging; they are deliberately
/// never interpolated into `errorDescription`.
enum RepositoryError: Error, Sendable, LocalizedError {
    case notFound
    case notAuthenticated
    case handleAlreadyTaken
    case alreadyPostedToday
    /// A locally durable capture is already waiting for its Firestore commit. A
    /// second image must not replace it, or the eventual post could reference a
    /// different photo from the one that reaches Storage.
    case captureAlreadyPending
    case network(underlying: String)
    case permissionDenied(underlying: String)
    /// A server-side precondition wasn't met — e.g. an invite callable's
    /// `failed-precondition` (Cloud Functions error code 9) for a caller with no
    /// handle, or whose account is being deleted. The client-side callers of these
    /// callables are expected to check the same precondition before calling, so
    /// reaching this case is an edge case (a race, or a check that was bypassed),
    /// not the primary way a person learns they need a handle first.
    case actionNotReady(underlying: String)
    /// A rate limit was hit (Cloud Functions error code 8, `resource-exhausted`) —
    /// currently only the invite callables enforce one. Never auto-retry on this;
    /// the caller must wait for a person to try again.
    case rateLimited(underlying: String)
    case unknown(underlying: String)

    // Routed through `L10n.string(_:)`: these are stored `String?` properties
    // (via `LocalizedError`), not `Text("literal")` call sites, so automatic
    // String Catalog key matching does not apply (see
    // `dev-notes/localization-en-ja-stage2_*.md`).
    var errorDescription: String? {
        switch self {
        case .notFound:
            L10n.string("error.repository.notFound")
        case .notAuthenticated:
            L10n.string("error.repository.notAuthenticated")
        case .handleAlreadyTaken:
            L10n.string("error.repository.handleAlreadyTaken")
        case .alreadyPostedToday:
            L10n.string("error.repository.alreadyPostedToday")
        case .captureAlreadyPending:
            L10n.string("error.repository.captureAlreadyPending")
        case .network:
            L10n.string("error.repository.network")
        case .permissionDenied:
            L10n.string("error.repository.permissionDenied")
        case .actionNotReady:
            L10n.string("error.repository.actionNotReady")
        case .rateLimited:
            L10n.string("error.repository.rateLimited")
        case .unknown:
            L10n.string("error.repository.unknown")
        }
    }

    /// The second line of a failure state: what the person can actually do. Kept
    /// separate from `errorDescription` so a call site can show one or both.
    var recoverySuggestion: String? {
        switch self {
        case .notFound, .alreadyPostedToday:
            nil
        case .notAuthenticated:
            L10n.string("error.repository.recovery.notAuthenticated")
        case .handleAlreadyTaken:
            L10n.string("error.repository.recovery.handleAlreadyTaken")
        case .captureAlreadyPending:
            L10n.string("error.repository.recovery.captureAlreadyPending")
        case .network:
            L10n.string("error.repository.recovery.network")
        case .actionNotReady:
            L10n.string("error.repository.recovery.actionNotReady")
        case .rateLimited:
            L10n.string("error.repository.recovery.rateLimited")
        case .permissionDenied, .unknown:
            L10n.string("error.repository.recovery.default")
        }
    }

    /// Internal detail for logs and dev-notes only — never shown to a person.
    var diagnosticDetail: String? {
        switch self {
        case .network(let underlying), .permissionDenied(let underlying), .unknown(let underlying),
             .actionNotReady(let underlying), .rateLimited(let underlying):
            underlying
        case .notFound, .notAuthenticated, .handleAlreadyTaken, .alreadyPostedToday, .captureAlreadyPending:
            nil
        }
    }
}
