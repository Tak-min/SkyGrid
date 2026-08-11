import Foundation

/// Recognizes `https://skygrid.my/i/{code}` as an invite link — the only path the
/// Worker's AASA associates with this app (`waitlist/src/aasa.ts` scopes `components`
/// to `/i/*` deliberately, so `/privacy`, `/terms`, and `/support` keep opening in
/// Safari instead of being swallowed by the app).
///
/// Does not recognize `skygrid://capture` — that scheme belongs to the Live Activity,
/// and teaching this parser about it would widen an untrusted-input surface (an
/// attacker-controlled URL string) for no benefit.
enum InviteLinkParser {
    static let host = "skygrid.my"
    static let pathPrefix = "/i/"

    /// `https://skygrid.my/i/ABCDE12345`, optionally with a trailing slash, query, or
    /// fragment. Anything else — a foreign host, `http://`, a path outside `/i/*`, a
    /// segment that isn't a valid `InviteCode`, or more than one path segment after
    /// `/i/` — returns `nil` rather than guessing.
    static func code(from url: URL) -> InviteCode? {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == host,
              url.pathComponents.count == 3,
              url.pathComponents[0] == "/",
              url.pathComponents[1] == "i"
        else { return nil }
        return InviteCode(raw: url.pathComponents[2])
    }
}
