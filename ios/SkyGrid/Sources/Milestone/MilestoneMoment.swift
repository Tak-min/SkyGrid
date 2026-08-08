import UIKit

/// Everything `MilestoneView` needs, resolved once by the presenter so the view is
/// pure and the audit harness can build one without any repository.
///
/// Identified by the streak because a given threshold can only be presented once —
/// `fullScreenCover(item:)` therefore cannot be re-triggered for the same milestone.
struct MilestoneMoment: Identifiable {
    let milestone: StreakMilestone
    let post: SkyPost
    /// The morning's photo, read from local disk. `nil` is a supported state, not a
    /// failure: `MorningCardExportView` degrades to the extracted sky colour, so the
    /// card stays truthful even when the image is gone.
    let photo: UIImage?
    let handle: Handle?

    var id: Int { milestone.streak }
}
