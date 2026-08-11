import Foundation

/// A buddy-invite code: `invites/{code}` in Firestore, reachable by the client only
/// through the four invite callables (`firestore.rules` explicit-denies the collection).
///
/// Every property here is a byte-exact mirror of `ios/functions/src/invites.ts` —
/// `INVITE_ALPHABET`, `INVITE_CODE_LENGTH`, `normalizeInviteCode`, `formatInviteCode`,
/// `INVITE_LINK_BASE`. Preview and claim only agree with each other because both the
/// client and the server normalize the same way; if this drifts from the server file,
/// a code a person can type may preview as valid and fail to claim, or the reverse.
struct InviteCode: Hashable, Sendable, Identifiable {
    /// Crockford Base32 minus `I`, `L`, `O`, `U` — see `invites.ts` for why those four
    /// are dropped (misread as `1`/`1`/`0` by hand, and `U` to keep codes clean).
    static let alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    static let length = 10
    static let linkBase = "https://skygrid.my/i/"

    /// Canonical form: uppercase, unhyphenated, exactly `length` characters, every
    /// character in `alphabet`.
    let value: String

    var id: String { value }

    /// Accepts what a person can plausibly type or paste — case-folded, with the
    /// display hyphen dropped and the three Crockford look-alikes mapped to the digit
    /// they're mistaken for (`O`→`0`, `I`/`L`→`1`). Does **not** trim leading/trailing
    /// whitespace or drop a trailing newline; callers reading from a `TextField` should
    /// trim first. This is deliberate — `normalizeInviteCode` on the server only ever
    /// drops `-`, space, and tab, and a mirror that trims more than the original stops
    /// being one.
    init?(raw: String) {
        var normalized = ""
        for character in raw.uppercased() {
            if character == "-" || character == " " || character == "\t" { continue }
            let mapped: Character
            switch character {
            case "O": mapped = "0"
            case "I", "L": mapped = "1"
            default: mapped = character
            }
            guard Self.alphabet.contains(mapped) else { return nil }
            normalized.append(mapped)
        }
        guard normalized.count == Self.length else { return nil }
        self.value = normalized
    }

    /// Only ever for display, never for storage or lookup — mirrors `formatInviteCode`.
    var formatted: String {
        let half = value.count / 2
        let splitIndex = value.index(value.startIndex, offsetBy: half)
        return "\(value[..<splitIndex])-\(value[splitIndex...])"
    }

    var linkURL: URL {
        // `linkBase` is a fixed, well-formed constant and `value` is already restricted
        // to `alphabet` (alphanumerics only), so this can never fail to parse.
        URL(string: Self.linkBase + value)!
    }
}
