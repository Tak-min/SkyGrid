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
                    Label(localized("widget.skyGrid", state: context.state), systemImage: "sun.horizon.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Self.sunrise)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(localized("widget.until", state: context.state))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(captureDeadline(for: context.state), style: .time)
                            .environment(\.locale, locale(for: context.state))
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
                        Label(localized("widget.openCamera", state: context.state), systemImage: "camera.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Self.sunrise)
                    }
                }
            } compactLeading: {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(Self.sunrise)
                    .accessibilityLabel(localized("widget.skyGridMorning", state: context.state))
            } compactTrailing: {
                Text(localized("widget.capture", state: context.state))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Self.sunrise)
                    .accessibilityLabel(localized("widget.openCamera", state: context.state))
            } minimal: {
                Image(systemName: "camera.fill")
                    .foregroundStyle(Self.sunrise)
                    .accessibilityLabel(localized("widget.openSkyGridCamera", state: context.state))
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
                Text(localized("widget.todaysSky", state: state))
                    .font(.system(.title3, design: .serif, weight: .medium))
                Text(actionText(for: state))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(localized("widget.availableUntil", state: state))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(captureDeadline(for: state), style: .time)
                    .environment(\.locale, locale(for: state))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: localized("widget.lockScreenAccessibility", state: state),
            statusText(for: state),
            captureDeadline(for: state).formatted(
                .dateTime.hour().minute().locale(locale(for: state))
            )
        ))
    }

    private func captureDeadline(for state: MorningRitualAttributes.ContentState) -> Date {
        state.captureBy ?? state.wokeAt.addingTimeInterval(MorningRitualAttributes.captureWindow)
    }

    private func actionText(for state: MorningRitualAttributes.ContentState) -> String {
        switch state.status {
        case .awaitingCapture: localized("widget.action.openCamera", state: state)
        case .captured: localized("widget.action.skySafe", state: state)
        case .ended: localized("widget.action.windowClosed", state: state)
        }
    }

    /// No streak counts, no "you're falling behind" — a fact, stated once
    /// (VISION.md §6: "儀式的・寡黙・非評価的。褒めない、煽らない").
    private func statusText(for state: MorningRitualAttributes.ContentState) -> String {
        switch state.status {
        case .awaitingCapture: localized("widget.status.ready", state: state)
        case .captured: localized("widget.status.captured", state: state)
        case .ended: localized("widget.status.ended", state: state)
        }
    }

    private func locale(for state: MorningRitualAttributes.ContentState) -> Locale {
        Locale(identifier: state.languageCode ?? Locale.preferredLanguages.first ?? "en")
    }

    /// A widget runs in another process, so the app's Bundle override cannot
    /// reach it. The activity state carries the selected app language instead.
    private func localized(_ key: String, state: MorningRitualAttributes.ContentState) -> String {
        guard let code = state.languageCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return NSLocalizedString(key, bundle: .main, value: key, comment: "") }
        return NSLocalizedString(key, bundle: bundle, value: key, comment: "")
    }
}
