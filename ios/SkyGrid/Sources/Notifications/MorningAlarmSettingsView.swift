import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class MorningAlarmSettingsViewModel {
    private(set) var schedules: [MorningAlarmSchedule] = []
    private(set) var state = MorningAlarmState.off(MorningAlarmScheduler.preferredKind)
    private(set) var liveActivitiesEnabled = MorningRitualActivity.areActivitiesEnabled
    private(set) var isWorking = false
    private(set) var failedScheduleIDs: Set<UUID> = []

    var nextSchedule: MorningAlarmSchedule {
        MorningAlarmSchedule(
            id: UUID(),
            minutesAfterMidnight: LocalDefaults.wakeGoalMinutes,
            weekdays: Set(1...7),
            isEnabled: true
        )
    }

    /// Keep the list stable and chronological. Persisted schedules are edited in
    /// creation order, which made a newly added 07:30 alarm appear above an
    /// existing 06:00 alarm and look as if the wrong row had been updated.
    var displaySchedules: [MorningAlarmSchedule] {
        schedules.sorted { lhs, rhs in
            if lhs.isEnabled != rhs.isEnabled { return lhs.isEnabled && !rhs.isEnabled }
            if lhs.minutesAfterMidnight != rhs.minutesAfterMidnight {
                return lhs.minutesAfterMidnight < rhs.minutesAfterMidnight
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func refresh() async {
        MorningAlarmScheduler.migrateScheduleModelIfNeeded()
        schedules = LocalDefaults.morningAlarmSchedules
        state = await MorningAlarmScheduler.currentState()
        liveActivitiesEnabled = MorningRitualActivity.areActivitiesEnabled
    }

    func save(_ schedule: MorningAlarmSchedule) async {
        var updated = schedules
        if let index = updated.firstIndex(where: { $0.id == schedule.id }) {
            updated[index] = schedule
        } else {
            updated.append(schedule)
        }
        await apply(updated)
    }

    func setEnabled(_ isEnabled: Bool, for schedule: MorningAlarmSchedule) async {
        var updated = schedule
        updated.isEnabled = isEnabled
        await save(updated)
    }

    func delete(_ schedule: MorningAlarmSchedule) async {
        await apply(schedules.filter { $0.id != schedule.id })
    }

    func useReminderFallback() async {
        await apply(schedules, useReminderFallback: true)
    }

    private func apply(
        _ updated: [MorningAlarmSchedule],
        useReminderFallback: Bool = LocalDefaults.morningAlarmBackend == "reminder"
    ) async {
        guard !isWorking else { return }
        isWorking = true
        schedules = updated
        state = await MorningAlarmScheduler.apply(
            schedules: updated,
            useReminderFallback: useReminderFallback
        )
        schedules = LocalDefaults.morningAlarmSchedules
        MorningAlarmAnalytics.recordScheduleChanged(
            schedules: schedules,
            kind: state.kind,
            succeeded: state.isScheduled || !schedules.contains(where: \.isEnabled)
        )
        if case .failed = state {
            let scheduledIDs = await MorningAlarmScheduler.scheduledScheduleIDs(
                in: schedules,
                useReminderFallback: useReminderFallback
            )
            failedScheduleIDs = Set(schedules.filter(\.isEnabled).map(\.id))
                .subtracting(scheduledIDs)
        } else {
            failedScheduleIDs = []
        }
        liveActivitiesEnabled = MorningRitualActivity.areActivitiesEnabled
        isWorking = false
    }
}

/// Edits independent weekly alarms. Each row owns its time and weekdays; saving
/// one row reconciles the complete set so removed days and deleted alarms are
/// cancelled on both AlarmKit and notification-fallback devices.
struct MorningAlarmSettingsView: View {
    @State private var viewModel = MorningAlarmSettingsViewModel()
    @State private var editedSchedule: MorningAlarmSchedule?
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGSpacing.xxl) {
                header
                scheduleList
                stateSection
            }
            .padding(.horizontal, SGSpacing.xl)
            .padding(.vertical, SGSpacing.lg)
        }
        .background(MokuColor.nightStage.ignoresSafeArea())
        .navigationTitle(L10n.string("alarm.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refresh() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.refresh() }
        }
        .sheet(item: $editedSchedule) { schedule in
            MorningAlarmEditor(schedule: schedule) { updated in
                editedSchedule = nil
                Task { await viewModel.save(updated) }
            }
            .presentationDetents([.large])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Text(viewModel.state.kind.title.uppercased())
                .font(SGFont.caption(11))
                .tracking(1.4)
                .foregroundStyle(SGT.ink3)
            Text(headerTitle)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(SGT.ink)
                .contentTransition(.numericText())
            Text(L10n.string("alarm.header.description"))
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, SGSpacing.lg)
    }

    // Routed through `L10n.string(_:)`: this is a stored `String` property, not a
    // `Text("literal")` call site, so automatic String Catalog key matching does
    // not apply (see `dev-notes/localization-en-ja-stage2_*.md`). Japanese has no
    // singular/plural distinction, so only English branches on `enabled.count == 1`.
    private var headerTitle: String {
        let enabled = viewModel.schedules.filter(\.isEnabled)
        guard !enabled.isEmpty else { return L10n.string("alarm.header.noAlarms") }
        let readyKey = enabled.count == 1 ? "alarm.header.readySingular" : "alarm.header.readyPlural"
        let countKey = enabled.count == 1 ? "alarm.header.countSingular" : "alarm.header.countPlural"
        return String(format: L10n.string(viewModel.state.isScheduled ? readyKey : countKey), enabled.count)
    }

    private var scheduleList: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            HStack {
                Text(L10n.string("alarm.schedule.title"))
                    .font(SGFont.caption(11))
                    .tracking(1.3)
                    .foregroundStyle(SGT.ink3)
                Spacer()
                if viewModel.isWorking { ProgressView() }
            }

            ForEach(viewModel.displaySchedules) { schedule in
                alarmRow(schedule)
            }

            Button {
                editedSchedule = viewModel.nextSchedule
            } label: {
                Label("Add another alarm", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkyPrimaryButtonStyle())
            .disabled(viewModel.isWorking)
            .disabled(viewModel.schedules.count >= MorningAlarmScheduler.maximumScheduleCount)
            .accessibilityIdentifier("alarm.add")

            if viewModel.schedules.count >= MorningAlarmScheduler.maximumScheduleCount {
                Text("Five alarms is the safe maximum while keeping room for weekly reminders.")
                    .font(SGFont.caption(12))
                    .foregroundStyle(SGT.ink3)
            }
        }
    }

    private func alarmRow(_ schedule: MorningAlarmSchedule) -> some View {
        HStack(spacing: SGSpacing.md) {
            Button { editedSchedule = schedule } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(timeString(schedule.minutesAfterMidnight))
                        .font(SGFont.numeric(30, weight: .medium))
                        .foregroundStyle(schedule.isEnabled ? SGT.ink : SGT.ink3)
                    Text(weekdaySummary(schedule.weekdays))
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink2)
                    if viewModel.failedScheduleIDs.contains(schedule.id) {
                        Label("Couldn't update this alarm", systemImage: "exclamationmark.circle.fill")
                            .font(SGFont.caption(12))
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle(
                String(format: L10n.string("alarm.enableAccessibility"), timeString(schedule.minutesAfterMidnight)),
                isOn: Binding(
                    get: { schedule.isEnabled },
                    set: { value in Task { await viewModel.setEnabled(value, for: schedule) } }
                )
            )
            .labelsHidden()
            .disabled(viewModel.isWorking)

            Button(role: .destructive) {
                Task { await viewModel.delete(schedule) }
            } label: {
                Image(systemName: "trash")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SGT.ink3)
            .disabled(viewModel.isWorking)
            .accessibilityLabel(String(format: L10n.string("alarm.deleteAlarmAccessibility"), timeString(schedule.minutesAfterMidnight)))
        }
        .padding(SGSpacing.lg)
        .quietCard()
    }

    @ViewBuilder
    private var stateSection: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            switch viewModel.state {
            case .scheduled(let kind):
                Label("All enabled alarms are scheduled", systemImage: "checkmark.circle.fill")
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
                Text(kind.detail)
                    .font(SGFont.caption())
                    .foregroundStyle(SGT.ink3)
                if kind == .systemAlarm {
                    Label("Photo Mission", systemImage: "camera.fill")
                        .font(SGFont.body(14))
                        .foregroundStyle(SGT.ink2)
                    Text("Stopping a ring opens the camera. Until a photo is saved, Sky Grid schedules another system alarm every 5 minutes for up to four hours.")
                        .font(SGFont.caption())
                        .foregroundStyle(SGT.ink3)
                }
                if kind == .systemAlarm && !viewModel.liveActivitiesEnabled {
                    Label("Live Activities are off", systemImage: "rectangle.badge.xmark")
                        .font(SGFont.body(14))
                        .foregroundStyle(SGT.ink2)
                    Button("Open Settings", action: openSystemSettings)
                        .font(SGFont.body(14))
                        .frame(minHeight: 44)
                }
            case .needsAuthorization:
                Text("Add or enable an alarm to request permission at the moment it is needed.")
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
            case .denied(let kind):
                Label("Permission is not allowed", systemImage: "exclamationmark.circle")
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
                Text(L10n.string(kind == .systemAlarm
                     ? "alarm.permission.systemDenied"
                     : "alarm.permission.reminderDenied"))
                    .font(SGFont.caption())
                    .foregroundStyle(SGT.ink3)
                Button("Open Settings", action: openSystemSettings)
                    .buttonStyle(SkySecondaryButtonStyle())
                if kind == .systemAlarm, !viewModel.schedules.isEmpty {
                    Button("Use regular reminders") {
                        Task { await viewModel.useReminderFallback() }
                    }
                    .buttonStyle(SkySecondaryButtonStyle())
                    .disabled(viewModel.isWorking)
                }
            case .off:
                Text(L10n.string(viewModel.schedules.isEmpty
                     ? "alarm.state.addFirst"
                     : viewModel.schedules.contains(where: \.isEnabled)
                        ? "alarm.state.unscheduled"
                        : "alarm.state.enableOne"))
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
            case .failed:
                Text("One or more alarms could not be updated. Your saved schedule is still here; try the change again.")
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
            }
        }
    }

    private func weekdaySummary(_ weekdays: Set<Int>) -> String {
        if weekdays == Set(1...7) { return L10n.string("alarm.repeat.everyDay") }
        if weekdays == Set(2...6) { return L10n.string("alarm.repeat.weekdays") }
        if weekdays == Set([1, 7]) { return L10n.string("alarm.repeat.weekends") }
        var calendar = Calendar.current
        calendar.locale = locale
        let symbols = calendar.veryShortWeekdaySymbols
        return weekdays.sorted().compactMap { day in
            guard symbols.indices.contains(day - 1) else { return nil }
            return symbols[day - 1]
        }.joined(separator: " · ")
    }

    private func timeString(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct MorningAlarmEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var draft: MorningAlarmSchedule
    let onSave: (MorningAlarmSchedule) -> Void

    init(schedule: MorningAlarmSchedule, onSave: @escaping (MorningAlarmSchedule) -> Void) {
        _draft = State(initialValue: schedule)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SGSpacing.xxl) {
                    DatePicker(
                        "Alarm time",
                        selection: Binding(
                            get: { date(for: draft.minutesAfterMidnight) },
                            set: { draft.minutesAfterMidnight = minutes(for: $0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: SGSpacing.md) {
                        Text("REPEAT")
                            .font(SGFont.caption(11))
                            .tracking(1.3)
                            .foregroundStyle(SGT.ink3)
                        HStack(spacing: 6) {
                            ForEach(1...7, id: \.self) { weekday in
                                weekdayButton(weekday)
                            }
                        }
                    }
                }
                .padding(SGSpacing.xl)
            }
            .background(MokuColor.nightStage.ignoresSafeArea())
            .navigationTitle("Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft) }
                        .disabled(draft.weekdays.isEmpty)
                }
            }
        }
    }

    private func weekdayButton(_ weekday: Int) -> some View {
        let selected = draft.weekdays.contains(weekday)
        var calendar = Calendar.current
        calendar.locale = locale
        let symbol = calendar.veryShortWeekdaySymbols[weekday - 1]
        return Button {
            if selected { draft.weekdays.remove(weekday) } else { draft.weekdays.insert(weekday) }
        } label: {
            Text(symbol)
                .font(SGFont.caption(13))
                .foregroundStyle(selected ? SGT.background : SGT.ink2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? SGT.ink : SGT.fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendar.weekdaySymbols[weekday - 1])
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func date(for minutes: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func minutes(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 6) * 60 + (components.minute ?? 0)
    }
}
