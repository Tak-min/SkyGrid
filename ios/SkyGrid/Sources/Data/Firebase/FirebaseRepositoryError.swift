import Foundation

enum FirebaseRepositoryError {
    static func map(_ error: Error) -> RepositoryError {
        if let repositoryError = error as? RepositoryError {
            return repositoryError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network(underlying: nsError.localizedDescription)
        }
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7: // permission-denied
                return .permissionDenied(underlying: nsError.localizedDescription)
            case 14: // unavailable
                return .network(underlying: nsError.localizedDescription)
            default:
                break
            }
        }
        // Firebase Storage exposes its own error domain. Without this branch an
        // App Check or Storage Rules rejection was reduced to `.unknown`, so the
        // upload queue retried a request that could never succeed and gave the
        // user no actionable state.
        if nsError.domain == "FirebaseStorage.StorageErrorCode" {
            switch nsError.code {
            case -13020, -13021: // unauthenticated, unauthorized
                return .permissionDenied(underlying: nsError.localizedDescription)
            case -13030: // retry-limit-exceeded
                return .network(underlying: nsError.localizedDescription)
            default:
                break
            }
        }
        // Callable Cloud Functions have their own error domain. Without this branch
        // an App Check or auth rejection from a callable (e.g. `deleteAccount`) was
        // reduced to `.unknown`, which the UI shows as a generic "try again" message
        // that can never actually succeed.
        if nsError.domain == "com.firebase.functions" {
            switch nsError.code {
            case 7, 16: // permission-denied, unauthenticated
                return .permissionDenied(underlying: nsError.localizedDescription)
            case 14: // unavailable
                return .network(underlying: nsError.localizedDescription)
            default:
                break
            }
        }
        return .unknown(underlying: nsError.localizedDescription)
    }
}
