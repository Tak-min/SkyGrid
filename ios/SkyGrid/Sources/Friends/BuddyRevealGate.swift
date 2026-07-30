import Foundation

/// The mutual-blur mechanic (VISION.md §3, pain point #1): a buddy's morning photo
/// stays hidden until the viewer has posted their own — no free-riding by watching
/// without participating.
enum BuddyRevealGate {
    static func isRevealed(viewerHasPostedToday: Bool) -> Bool {
        viewerHasPostedToday
    }
}
