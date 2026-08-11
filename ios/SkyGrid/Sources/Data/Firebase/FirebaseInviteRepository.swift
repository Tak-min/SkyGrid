@preconcurrency import FirebaseFunctions
import Foundation

@MainActor
final class FirebaseInviteRepository: InviteRepository {
    /// The four invite callables run in Tokyo, beside Firestore, separately from the
    /// three pre-existing functions (`deleteAccount`, `imageDownloadURL`,
    /// the RevenueCat webhook) which stay on the default `us-central1` instance.
    /// Only ever construct this from `ServiceFactory` — the default argument below
    /// calls `Functions.functions(region:)`, which traps if `FirebaseApp` is
    /// unconfigured (the UI-audit harness and unit-test hosts deliberately leave it
    /// that way; give them a stub `InviteRepository` instead of this type).
    static let region = "asia-northeast1"

    private let functions: Functions

    init(functions: Functions = Functions.functions(region: FirebaseInviteRepository.region)) {
        self.functions = functions
    }

    func createInvite(fresh: Bool) async throws -> InviteLink {
        do {
            let result = try await functions.httpsCallable("createInvite").call(["fresh": fresh])
            guard let payload = result.data as? [String: Any],
                  let code = (payload["code"] as? String).flatMap(InviteCode.init(raw:)),
                  let url = (payload["url"] as? String).flatMap(URL.init(string:)),
                  let expiresAt = Self.date(payload["expiresAtMs"]),
                  let reused = payload["reused"] as? Bool
            else { throw RepositoryError.unknown(underlying: "createInvite response was malformed.") }
            return InviteLink(code: code, url: url, expiresAt: expiresAt, isReused: reused)
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func previewInvite(code: InviteCode) async throws -> InvitePreview {
        do {
            let result = try await functions.httpsCallable("previewInvite").call(["code": code.value])
            guard let payload = result.data as? [String: Any],
                  let rawState = payload["state"] as? String
            else { throw RepositoryError.unknown(underlying: "previewInvite response was malformed.") }
            // An unrecognized state (a future server addition this build predates)
            // must not crash a shipped client — fall back to `.unknown`, the same
            // terminal state the server itself uses for a code it can't resolve.
            let state = InvitePreviewState(rawValue: rawState) ?? .unknown
            return InvitePreview(
                state: state,
                creatorHandle: (payload["creatorHandle"] as? String).flatMap(Handle.init(raw:)),
                expiresAt: Self.date(payload["expiresAtMs"])
            )
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func claimInvite(code: InviteCode) async throws -> InviteClaim {
        do {
            let result = try await functions.httpsCallable("claimInviteCode").call(["code": code.value])
            guard let payload = result.data as? [String: Any],
                  let rawOutcome = payload["outcome"] as? String
            else { throw RepositoryError.unknown(underlying: "claimInviteCode response was malformed.") }
            let outcome = InviteClaimOutcome(rawValue: rawOutcome) ?? .unknown
            return InviteClaim(
                outcome: outcome,
                buddyUid: payload["buddyUid"] as? String,
                buddyHandle: (payload["buddyHandle"] as? String).flatMap(Handle.init(raw:)),
                generation: (payload["generation"] as? NSNumber)?.intValue
            )
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    func revokeInvite(code: InviteCode) async throws -> InviteRevocation {
        do {
            let result = try await functions.httpsCallable("revokeInvite").call(["code": code.value])
            guard let payload = result.data as? [String: Any],
                  let revoked = payload["revoked"] as? Bool
            else { throw RepositoryError.unknown(underlying: "revokeInvite response was malformed.") }
            return InviteRevocation(isRevoked: revoked, wasAlreadyClaimed: payload["claimed"] as? Bool ?? false)
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }

    /// Callable payloads decode JS numbers as `NSNumber`, not `Int` — `as? Int`
    /// silently fails on that boxed type and would turn every `expiresAtMs` into a
    /// malformed-response error.
    private static func date(_ raw: Any?) -> Date? {
        guard let millis = (raw as? NSNumber)?.doubleValue else { return nil }
        return Date(timeIntervalSince1970: millis / 1000)
    }
}
