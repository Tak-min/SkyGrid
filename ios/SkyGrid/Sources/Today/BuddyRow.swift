import SwiftUI

/// The strip displays at most `displayLimit` buddies. Status reads are deliberately
/// not truncated here: the server-authoritative buddy circle cap (8) is below this
/// display limit (12), and `RevealSignal` is also the Buddies tab's complete status
/// source.
///
/// Each tile's state already encodes the reveal gate (see `BuddyTile`), so this row
/// is purely layout — it no longer needs to know whether the viewer has posted.
struct BuddyRow: View {
    static let displayLimit = 12

    let buddies: [TodayViewModel.BuddyStatus]
    let today: LocalDate
    let imageFetching: any ImageFetching

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SGSpacing.lg) {
                ForEach(buddies.prefix(Self.displayLimit)) { buddy in
                    BuddyTile(
                        displayName: buddy.displayName,
                        revealState: buddy.revealState,
                        streak: FeatureFlags.buddyStreakVisible
                            ? BuddyStreakDisplayPolicy.display(
                                current: buddy.streakCurrent,
                                lastMutualDate: buddy.streakLastMutualDate,
                                today: today,
                                buddyName: buddy.displayName
                            )
                            : nil,
                        imageFetching: imageFetching
                    )
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
