import SwiftUI

/// The horizontally scrolling strip displays every buddy status supplied by
/// `RevealSignal`, which is also the Buddies tab's complete status source. This UI
/// does not mirror or expose the server's abuse-prevention limit for Pro Circles.
///
/// Each tile's state already encodes the reveal gate (see `BuddyTile`), so this row
/// is purely layout — it no longer needs to know whether the viewer has posted.
/// Revealed skies use a photo-first card rather than a tiny avatar: the buddy is a
/// core product action, not metadata below the morning record.
struct BuddyRow: View {
    let buddies: [TodayViewModel.BuddyStatus]
    let today: LocalDate
    let imageFetching: any ImageFetching
    let onSelect: (TodayViewModel.BuddyStatus) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SGSpacing.lg) {
                ForEach(buddies) { buddy in
                    if buddy.post != nil {
                        Button { onSelect(buddy) } label: { tile(for: buddy) }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the buddy sky feed")
                    } else {
                        tile(for: buddy)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func tile(for buddy: TodayViewModel.BuddyStatus) -> some View {
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
            imageFetching: imageFetching,
            style: .featured
        )
    }
}
