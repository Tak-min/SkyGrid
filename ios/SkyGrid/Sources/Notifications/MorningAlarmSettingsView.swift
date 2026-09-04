import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class MorningAlarmSettingsViewModel {
    var minutes = LocalDefaults.wakeGoalMinutes
    private(set) var state = MorningAlarmState.off(MorningAlarmScheduler.preferredKind)
    private(set) var liveActivitiesEnabled = MorningRitualActivity.areActivitiesEnabled
    private(set) var isWorking = false

    func refresh() async {
        MorningAlarmScheduler.migrateScheduleModelIfNeeded()
        state = await MorningAlarmScheduler.currentState()
        liveActivitiesEnabled = MorningRitualActivity.areActivitiesEnabled
    }

    func enableSystemAlarm() async {
        isWorking = true
        LocalDefaults.wakeGoalMinutes = minutes
        state = await MorningAlarmScheduler.enable(wakeGoalMinutes: minutes)
        isWorking = false
    }

    func enableReminderFallback() async {
        isWorking = true
        LocalDefaults.wakeGoalMinutes = minutes
        state = await MorningAlarmScheduler.enableReminderFallback(wakeGoalMinutes: minutes)
        isWorking = false
    }

    func disable() async {
        isWorking = true
        await MorningAlarmScheduler.disable()
        state = await MorningAlarmScheduler.currentState()
        isWorking = false
    }
}

/// A single-purpose settings screen for the wake flow. This is intentionally not a
/// generic notification preference: it tells the person exactly whether the device
/// has a real AlarmKit alarm or a best-effort notification reminder.
struct MorningAlarmSettingsView: View {
    @State private var viewModel = MorningAlarmSettingsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGSpacing.xxl) {
                alarmReadout
                timeControl
                stateSection
                actionSection
            }
            .padding(.horizontal, SGSpacing.xl)
            .padding(.vertical, SGSpacing.lg)
        }
        .background(SGT.background)
        .navigationTitle("Morning Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refresh() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.refresh() }
        }
    }

    private var alarmReadout: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Text(viewModel.state.kind.title.uppercased())
                .font(SGFont.caption(11))
                .tracking(1.4)
                .foregroundStyle(SGT.ink3)
            Text(timeString(viewModel.minutes))
                .font(SGFont.bigTime(78))
                .foregroundStyle(SGT.ink)
                .contentTransition(.numericText())
            Text(viewModel.state.kind.detail)
                .font(SGFont.caption())
                .foregroundStyle(SGT.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, SGSpacing.lg)
    }

    private var timeControl: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            Text("Time")
                .font(SGFont.serifTitle(23))
                .foregroundStyle(SGT.ink)
            DatePicker(
                "Morning time",
                selection: Binding(
                    get: { date(for: viewModel.minutes) },
                    set: { viewModel.minutes = minutes(for: $0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.vertical, SGSpacing.sm)
            .quietCard()
        }
    }

    @ViewBuilder
    private var stateSection: some View {
        switch viewModel.state {
        case .scheduled:
            VStack(alignment: .leading, spacing: SGSpacing.sm) {
                Label("Set for every day at this time", systemImage: "checkmark.circle.fill")
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
                if viewModel.state.kind == .systemAlarm {
                    if viewModel.liveActivitiesEnabled {
                        Text("After you stop the alarm, a quiet Sky Grid card remains on the Lock Screen and Dynamic Island. Tap it to open the camera.")
                            .font(SGFont.caption())
                            .foregroundStyle(SGT.ink3)
                    } else {
                        Label("Live Activities are off", systemImage: "rectangle.badge.xmark")
                            .font(SGFont.body(14))
                            .foregroundStyle(SGT.ink2)
                        Text("Your alarm still works, but the Lock Screen and Dynamic Island camera shortcut cannot appear.")
                            .font(SGFont.caption())
                            .foregroundStyle(SGT.ink3)
                        Button("Open Settings", action: openSystemSettings)
                            .font(SGFont.body(14))
                            .foregroundStyle(SGT.ink)
                            .frame(minHeight: 44)
                    }
                }
            }
        case .needsAuthorization:
            Label("Permission is needed to turn this on", systemImage: "bell.badge")
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
        case .denied(let kind):
            VStack(alignment: .leading, spacing: SGSpacing.sm) {
                Label("Permission is not allowed", systemImage: "exclamationmark.circle")
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
                Text(kind == .systemAlarm
                     ? "Allow Sky Grid alarms in Settings to use a System Alarm."
                     : "Allow notifications to receive a morning reminder on this device.")
                    .font(SGFont.caption())
                    .foregroundStyle(SGT.ink3)
            }
        case .off:
            Text("Not set yet")
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
        case .failed:
            Text("The alarm could not be updated. Try again.")
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        if viewModel.state.isScheduled {
            Button(role: .destructive) {
                Task { await viewModel.disable() }
            } label: {
                Text("Turn off alarm")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkySecondaryButtonStyle())
            .disabled(viewModel.isWorking)

            Button {
                Task { await viewModel.enableSystemAlarm() }
            } label: {
                Text("Update time")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkyPrimaryButtonStyle())
            .disabled(viewModel.isWorking)
        } else {
            Button {
                Task { await viewModel.enableSystemAlarm() }
            } label: {
                if viewModel.isWorking {
                    ProgressView().tint(SGT.background)
                } else {
                    Text(viewModel.state.kind == .systemAlarm ? "Turn on System Alarm" : "Turn on Morning Reminder")
                }
            }
            .buttonStyle(SkyPrimaryButtonStyle())
            .disabled(viewModel.isWorking)

            if case .denied(.systemAlarm) = viewModel.state {
                Button("Open Settings") {
                    openSystemSettings()
                }
                .buttonStyle(SkySecondaryButtonStyle())

                Button("Use a regular reminder") {
                    Task { await viewModel.enableReminderFallback() }
                }
                .buttonStyle(SkySecondaryButtonStyle())
                .disabled(viewModel.isWorking)
            }
        }
    }

    private func date(for minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private func minutes(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 6) * 60 + (components.minute ?? 0)
    }

    private func timeString(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
