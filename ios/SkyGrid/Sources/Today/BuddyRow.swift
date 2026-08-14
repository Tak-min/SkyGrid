import SwiftUI

/// Read-cost bounded to 12 buddies shown here (blueprint §4 gotcha #9) — a full
/// buddy list lives elsewhere.
///
/// Each tile's state already encodes the reveal gate (see `BuddyTile`), so this row
/// is purely layout — it no longer needs to know whether the viewer has posted.
struct BuddyRow: View {
    let buddies: [TodayViewModel.BuddyStatus]
    let imageFetching: any ImageFetching

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SGSpacing.lg) {
                ForEach(buddies.prefix(12)) { buddy in
                    BuddyTile(displayName: buddy.displayName, revealState: buddy.revealState, imageFetching: imageFetching)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
