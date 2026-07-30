import SwiftUI

/// Read-cost bounded to 12 buddies shown here (blueprint §4 gotcha #9) — a full
/// buddy list lives elsewhere.
struct BuddyRow: View {
    let buddies: [TodayViewModel.BuddyStatus]
    let viewerHasPostedToday: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SGSpacing.lg) {
                ForEach(buddies.prefix(12)) { buddy in
                    BuddyTile(
                        displayName: buddy.displayName,
                        hasPostedToday: buddy.hasPostedToday,
                        isRevealed: BuddyRevealGate.isRevealed(viewerHasPostedToday: viewerHasPostedToday),
                        skyColor: buddy.post?.skyColor
                    )
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
