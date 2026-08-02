import ActivityKit
import WidgetKit
import SwiftUI

/// Deliberately plain system fonts/colors rather than the app's `DesignSystem`
/// tokens — this file compiles into a second target, and `Theme.swift`'s dynamic
/// `UIColor { traits in … }` providers were not confirmed self-contained enough
/// to share without risking a confusing cross-module build failure for a card
/// this small. Revisit only if the widget's look needs to diverge further from
/// the system defaults.
struct MorningRitualLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MorningRitualAttributes.self) { context in
            lockScreen(state: context.state)
                .activityBackgroundTint(Color(white: 0.98))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sun.horizon")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.wokeAt, style: .time)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(statusText(for: context.state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "sun.horizon")
            } compactTrailing: {
                Text(context.state.wokeAt, style: .time)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "sun.horizon")
            }
        }
    }

    private func lockScreen(state: MorningRitualAttributes.ContentState) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's sky")
                    .font(.system(.title3, design: .serif))
                Text(statusText(for: state))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(state.wokeAt, style: .time)
                .font(.system(.body, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    /// No streak counts, no "you're falling behind" — a fact, stated once
    /// (VISION.md §6: "儀式的・寡黙・非評価的。褒めない、煽らない").
    private func statusText(for state: MorningRitualAttributes.ContentState) -> String {
        switch state.status {
        case .awaitingCapture: "Not captured yet"
        case .captured: "Captured"
        }
    }
}
