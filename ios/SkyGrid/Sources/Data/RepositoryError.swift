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

    var errorDescription: String? {
        switch self {
        case .notFound:
            "That record could not be found."
        case .notAuthenticated:
            "You're signed out. Sign in again to continue."
        case .handleAlreadyTaken:
            "That handle is already taken. Try another one."
        case .alreadyPostedToday:
            "You've already kept a sky this morning."
        case .captureAlreadyPending:
            "This morning's photo is still being saved. Give it a moment."
        case .network:
            "Sky Grid couldn't reach the network."
        case .permissionDenied:
            "Sky Grid doesn't have permission to do that right now."
        case .actionNotReady:
            "That's not possible right now."
        case .rateLimited:
            "Too many tries."
        case .unknown:
            "Something went wrong on Sky Grid's side."
        }
    }

    /// The second line of a failure state: what the person can actually do. Kept
    /// separate from `errorDescription` so a call site can show one or both.
    var recoverySuggestion: String? {
        switch self {
        case .notFound, .alreadyPostedToday:
            nil
        case .notAuthenticated:
            "Your archive is safe and will come back with your account."
        case .handleAlreadyTaken:
            "Handles are unique, so this one belongs to someone else."
        case .captureAlreadyPending:
            "It will finish on its own — you don't need to retake it."
        case .network:
            "Check your connection and try again. Nothing in your archive has changed."
        case .actionNotReady:
            "Nothing has changed — try again in a moment."
        case .rateLimited:
            "Give it a few minutes and try again."
        case .permissionDenied, .unknown:
            "Nothing in your archive has changed. Try again in a moment."
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
