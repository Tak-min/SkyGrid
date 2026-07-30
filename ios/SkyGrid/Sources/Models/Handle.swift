import Foundation

/// A user's unique, immutable-after-set handle (`handles/{handle} -> {uid}`).
/// MVP deliberately does not support renaming — see blueprint §2-G.
struct Handle: Hashable, Sendable {
    let value: String

    init?(raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard HandleValidator.isValid(normalized) else { return nil }
        self.value = normalized
    }
}

enum HandleValidator {
    private static let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
    private static let lengthRange = 3...20

    static func isValid(_ candidate: String) -> Bool {
        guard lengthRange.contains(candidate.count) else { return false }
        return candidate.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
}
