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
                        Label("Back", systemImage: "chevron.left")
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityHint("Returns to the previous setup step")
                    Spacer()
                }
                .font(SGFont.caption(14))
                .foregroundStyle(SGT.ink2)

                OnboardingProgress(step: 7, total: 9)

                Text("The time your\nmorning begins")
                    .font(SGFont.serifTitle(38))
                    .foregroundStyle(SGT.ink)
                Text("QUESTION 6 OF 6 · A time is enough for now. You can always change it.")
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
                    Label("You chose no reminder. Capture is always ready from Today.", systemImage: "sun.horizon")
                        .font(SGFont.caption())
                        .foregroundStyle(SGT.ink2)
                        .padding(SGSpacing.lg)
                        .quietCard()
                }

                Button(action: advance) {
                    Text("Save time and continue")
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
                Label("Set for every day at this time", systemImage: "checkmark.circle.fill")
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
                    Text("Stop doesn't end your morning.")
                        .font(SGFont.body(14))
                        .fontWeight(.bold)
                        .foregroundStyle(SGT.ink2)
                    Text("If you don't capture the sky, Sky Grid brings the alarm back every 5 minutes, up to 3 times. iPhone always silences the alarm the moment you tap Stop — Sky Grid can only ask again, not keep it sounding.")
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

    private var alarmActionTitle: String {
        if alarmState.isScheduled { return "Update \(alarmState.kind.title)" }
        return reminderPreference == .scheduledAlarm
            ? "Set a Morning Alarm"
            : "Set a Gentle Reminder"
    }

    private var timeString: String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private var alarmMessage: String {
        switch alarmState {
        case .denied:
            return "Permission was not allowed. You can still continue and change this later in Settings."
        case .failed:
            return "It could not be set. You can still continue and try again later in Settings."
        default:
            return "Only choose this if you want Sky Grid to ask for alarm permission now."
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
