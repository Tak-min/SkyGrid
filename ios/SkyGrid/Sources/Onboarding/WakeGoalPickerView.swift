import SwiftUI

struct WakeGoalPickerView: View {
    @Binding var minutes: Int
    let reminderPreference: ReminderPreference
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var alarmState = MorningAlarmState.off(MorningAlarmScheduler.preferredKind)
    @State private var isScheduling = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                HStack {
                    Button(action: onBack) {
                        Label(L10n.string("Back"), systemImage: "chevron.left")
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityHint(L10n.string("Returns to the previous setup step"))
                    Spacer()
                }
                .font(SGFont.caption(14))
                .foregroundStyle(SGT.ink2)

                OnboardingProgress(step: 8, total: 10)

                Text("The time your\nmorning begins")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(SGT.ink)
                Text(L10n.string("onboarding.wakeGoal.instructionLabel"))
                    .font(SGFont.body(16))
                    .foregroundStyle(SGT.ink2)
                Text(timeString)
                    .font(SGFont.bigTime(76))
                    .foregroundStyle(SGT.ink)
                    .contentTransition(.numericText())
                DatePicker(
                    "Wake time",
                    selection: Binding(
                        get: { date(for: minutes) },
                        set: { minutes = minutes(for: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
                .quietCard()

                if reminderPreference != .noReminder {
                    reminderControls
                } else {
                    Label(L10n.string("onboarding.wakeGoal.noReminderLabel"), systemImage: "sun.horizon")
                        .font(SGFont.caption())
                        .foregroundStyle(SGT.ink2)
                        .padding(SGSpacing.lg)
                        .quietCard()
                }

                Button(action: advance) {
                    Text(L10n.string("Save time and continue"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SkyPrimaryButtonStyle())
                .disabled(isScheduling)
            }
            .padding(SGSpacing.xl)
            .padding(.bottom, 32)
        }
    }

    private var reminderControls: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            if alarmState.isScheduled {
                Label(L10n.string("onboarding.wakeGoal.alarmScheduled"), systemImage: "checkmark.circle.fill")
                    .font(SGFont.caption())
                    .foregroundStyle(SGT.ink2)
            } else {
                Text(alarmMessage)
                    .font(SGFont.caption())
                    .foregroundStyle(SGT.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if reminderPreference == .scheduledAlarm {
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text(alarmState.kind == .systemAlarm ? L10n.string("onboarding.wakeGoal.photoMissionActive") : L10n.string("onboarding.wakeGoal.reminderFallback"))
                        .font(SGFont.body(14))
                        .fontWeight(.bold)
                        .foregroundStyle(SGT.ink2)
                    Text(photoMissionDetail)
                        .font(SGFont.caption())
                        .foregroundStyle(SGT.ink3)
                }
            }

            Button(action: scheduleAlarm) {
                if isScheduling {
                    ProgressView().tint(SGT.ink)
                } else {
                    Text(alarmActionTitle)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(SkySecondaryButtonStyle())
            .disabled(isScheduling)
        }
    }

    // Routed through `L10n.string(_:)`: these stored `String` properties are
    // consumed via `Text(...)`, not `Text("literal")` call sites, so automatic
    // String Catalog key matching does not apply (see
    // `dev-notes/localization-en-ja-stage2_*.md`).
    private var photoMissionDetail: String {
        if alarmState.kind == .systemAlarm {
            return L10n.string("onboarding.wakeGoal.photoMissionDetail.systemAlarm")
        }
        return L10n.string("onboarding.wakeGoal.photoMissionDetail.reminder")
    }

    private var alarmActionTitle: String {
        if alarmState.isScheduled {
            return String(format: L10n.string("onboarding.wakeGoal.updateAlarmAction"), alarmState.kind.title)
        }
        return reminderPreference == .scheduledAlarm
            ? L10n.string("onboarding.wakeGoal.setMorningAlarmAction")
            : L10n.string("onboarding.wakeGoal.setGentleReminderAction")
    }

    private var timeString: String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private var alarmMessage: String {
        switch alarmState {
        case .denied:
            return L10n.string("onboarding.wakeGoal.alarmMessage.denied")
        case .failed:
            return L10n.string("onboarding.wakeGoal.alarmMessage.failed")
        default:
            return L10n.string("onboarding.wakeGoal.alarmMessage.default")
        }
    }

    private func scheduleAlarm() {
        isScheduling = true
        Task {
            LocalDefaults.wakeGoalMinutes = minutes
            alarmState = await MorningAlarmScheduler.enable(wakeGoalMinutes: minutes)
            isScheduling = false
        }
    }

    private func advance() {
        LocalDefaults.wakeGoalMinutes = minutes
        onNext()
    }

    private func date(for minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private func minutes(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 6) * 60 + (components.minute ?? 0)
    }
}
