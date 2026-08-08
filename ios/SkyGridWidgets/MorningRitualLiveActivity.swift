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
                .activityBackgroundTint(Self.surface)
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(Self.captureURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Sky Grid", systemImage: "sun.horizon.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Self.sunrise)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("UNTIL")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(captureDeadline(for: context.state), style: .time)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        Text(statusText(for: context.state))
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Label("Open camera", systemImage: "camera.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Self.sunrise)
                    }
                }
            } compactLeading: {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(Self.sunrise)
                    .accessibilityLabel("Sky Grid morning")
            } compactTrailing: {
                Text("Capture")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Self.sunrise)
                    .accessibilityLabel("Open camera")
            } minimal: {
                Image(systemName: "camera.fill")
                    .foregroundStyle(Self.sunrise)
                    .accessibilityLabel("Open Sky Grid camera")
            }
            .keylineTint(Self.sunrise)
            .widgetURL(Self.captureURL)
        }
    }

    private static let captureURL = URL(string: "skygrid://capture")!
    private static let sunrise = Color(red: 0.91, green: 0.58, blue: 0.33)
    private static let surface = Color(red: 0.97, green: 0.96, blue: 0.93)

    private func lockScreen(state: MorningRitualAttributes.ContentState) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's sky")
                    .font(.system(.title3, design: .serif, weight: .medium))
                Text(actionText(for: state))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("AVAILABLE UNTIL")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(captureDeadline(for: state), style: .time)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statusText(for: state)). Open the Sky Grid camera. Available until \(captureDeadline(for: state).formatted(date: .omitted, time: .shortened)).")
    }

    private func captureDeadline(for state: MorningRitualAttributes.ContentState) -> Date {
        state.captureBy ?? state.wokeAt.addingTimeInterval(MorningRitualAttributes.captureWindow)
    }

    private func actionText(for state: MorningRitualAttributes.ContentState) -> String {
        switch state.status {
        case .awaitingCapture: "Tap to open the camera"
        case .captured: "Today's sky is safe"
        case .ended: "The morning window has closed"
        }
    }

    /// No streak counts, no "you're falling behind" — a fact, stated once
    /// (VISION.md §6: "儀式的・寡黙・非評価的。褒めない、煽らない").
    private func statusText(for state: MorningRitualAttributes.ContentState) -> String {
        switch state.status {
        case .awaitingCapture: "Ready for today's sky"
        case .captured: "Captured"
        case .ended: "Morning ritual ended"
        }
    }
}
