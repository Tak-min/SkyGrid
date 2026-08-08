import SwiftUI

/// A stable per-person colour, used to give a buddy an avatar disc instead of a bare
/// name row.
///
/// Deliberately derived from the uid alone: it is an *identity* marker, not a claim
/// about that person's activity. The Buddies screen has no legitimate access to a
/// buddy's post before the viewer has captured (`firestore.rules` gates buddy post
/// reads on `hasPostedFor`), so anything status-shaped there would be fabricated.
/// A colour says only "this is Mira", which is true at all times.
///
/// The palette is the same six skies `RitualGridMark` draws, so buddy discs, the
/// onboarding mark, and the grid all read as one system.
enum IdentityColor {
    private static let palette: [Color] = [
        Color(red: 0.78, green: 0.86, blue: 0.89),
        Color(red: 0.92, green: 0.76, blue: 0.61),
        Color(red: 0.64, green: 0.75, blue: 0.78),
        Color(red: 0.82, green: 0.79, blue: 0.68),
        Color(red: 0.49, green: 0.61, blue: 0.70),
        Color(red: 0.89, green: 0.67, blue: 0.58),
    ]

    /// FNV-1a rather than `String.hashValue`: Swift seeds `Hashable` per process, so
    /// `hashValue` would give the same person a different colour on every launch.
    static func forUID(_ uid: String) -> Color {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in uid.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return palette[Int(hash % UInt64(palette.count))]
    }

    /// The initial shown inside the disc. Falls back to nothing rather than to a
    /// placeholder glyph, so an empty display name degrades to a plain colour disc.
    static func initial(for displayName: String) -> String {
        guard let first = displayName.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "" }
        return String(first).uppercased()
    }
}
