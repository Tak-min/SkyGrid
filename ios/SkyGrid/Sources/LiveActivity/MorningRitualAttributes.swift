import ActivityKit
import Foundation

/// Compiled into both the app target (to start/end activities) and the
/// `SkyGridWidgets` extension (to render them) — ActivityKit requires the exact
/// same `ActivityAttributes` type on both sides. Keep this file free of any other
/// app-only dependency.
struct MorningRitualAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        enum Status: String, Codable, Hashable, Sendable {
            case awaitingCapture
            case captured
        }

        var status: Status
        /// The instant the morning alarm alerted. Shown as a bare time — this
        /// app never narrates ("Time to wake up!"), it states a fact.
        var wokeAt: Date
    }

    /// The `LocalDate.docID` ("YYYY-MM-DD") this activity belongs to. Immutable:
    /// an activity is never re-pointed at a different day, only ended and (later)
    /// replaced by a new one.
    let localDateID: String
}
