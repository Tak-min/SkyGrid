import SwiftUI

/// A short, post-settlement reflection of the already-authorized buddy tiles. It
/// deliberately reuses `BuddyTile`, whose photo rendering is gated on `.posted`,
/// rather than fetching paths or deciding visibility inside the reward sequence.
struct RewardBuddyRevealStrip: View {
    let statuses: [TodayViewModel.BuddyStatus]
    let localDate: LocalDate
    let imageFetching: any ImageFetching

    private var revealed: [TodayViewModel.BuddyStatus] {
        statuses.filter { if case .posted = $0.revealState { true } else { false } }
    }

    var body: some View {
        if !revealed.isEmpty {
            HStack(spacing: SGSpacing.md) {
                ForEach(revealed.prefix(3), id: \.uid) { status in
                    BuddyTile(
                        displayName: status.displayName,
                        revealState: status.revealState,
                        streak: BuddyStreakDisplayPolicy.display(
                            current: status.streakCurrent,
                            lastMutualDate: status.streakLastMutualDate,
                            today: localDate,
                            buddyName: status.displayName
                        ),
                        imageFetching: imageFetching
                    )
                }
            }
            .transition(.opacity)
        }
    }
}
