import Foundation

/// Recognizes the public invite link and the secure cross-domain recovery link.
/// Safari deliberately keeps a same-domain link on the web; `open.skygrid.my` gives
/// the fallback page a different associated domain it can hand back to the app without
/// exposing the invite secret through a claimable custom URL scheme.
enum InviteLinkParser {
    static let host = "skygrid.my"
    static let recoveryHost = "open.skygrid.my"
    static let pathPrefix = "/i/"

    /// `https://skygrid.my/i/ABCDE12345`, optionally with a trailing slash, query, or
    /// fragment. Anything else — a foreign host, `http://`, a path outside `/i/*`, a
    /// segment that isn't a valid `InviteCode`, or more than one path segment after
    /// `/i/` — returns `nil` rather than guessing.
    static func code(from url: URL) -> InviteCode? {
        guard url.scheme?.lowercased() == "https",
              let incomingHost = url.host?.lowercased(),
              incomingHost == host || incomingHost == recoveryHost,
              url.pathComponents.count == 3,
              url.pathComponents[0] == "/",
              url.pathComponents[1] == "i"
        else { return nil }
        return InviteCode(raw: url.pathComponents[2])
    }

    /// Recovers a code from the complete share message copied from LINE,
    /// Instagram, or Messages. Those apps commonly put surrounding copy around the
    /// URL/code, so treating the whole clipboard as a raw code cannot work.
    static func code(fromSharedText text: String) -> InviteCode? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = InviteCode(raw: trimmed) { return direct }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            for match in detector.matches(in: trimmed, range: range) {
                if let url = match.url, let code = code(from: url) { return code }
            }
        }

        let separators = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted
        for candidate in trimmed.components(separatedBy: separators) where !candidate.isEmpty {
            if let code = InviteCode(raw: candidate) { return code }
        }
        return nil
    }
}
