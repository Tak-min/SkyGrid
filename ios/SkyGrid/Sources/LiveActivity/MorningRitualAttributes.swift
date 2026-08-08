import ActivityKit
import Foundation

/// Compiled into both the app target (to start/end activities) and the
/// `SkyGridWidgets` extension (to render them) — ActivityKit requires the exact
/// same `ActivityAttributes` type on both sides. Keep this file free of any other
/// app-only dependency.
struct MorningRitualAttributes: ActivityAttributes {
    /// Shared by the app and widget targets so lifecycle policy and the displayed
    /// deadline cannot drift apart.
    static let captureWindow: TimeInterval = 4 * 60 * 60

    struct ContentState: Codable, Hashable, Sendable {
        enum Status: String, Codable, Hashable, Sendable {
            case awaitingCapture
            case captured
            case ended
        }

        var status: Status
        /// The instant the morning alarm alerted. Shown as a bare time — this
        /// app never narrates ("Time to wake up!"), it states a fact.
        var wokeAt: Date
        /// Optional for decoding activities started by an older app build.
        var captureBy: Date? = nil
    }

    /// The `LocalDate.docID` ("YYYY-MM-DD") this activity belongs to. Immutable:
    /// an activity is never re-pointed at a different day, only ended and (later)
    /// replaced by a new one.
    let localDateID: String
}
