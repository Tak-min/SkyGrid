import SwiftUI

struct WakeGoalPickerView: View {
    @Binding var minutes: Int
    let onNext: () -> Void

    @State private var alarmState = MorningAlarmState.off(MorningAlarmScheduler.preferredKind)
    @State private var isScheduling = false

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.xl) {
            OnboardingProgress(step: 3, total: 4)

            Spacer(minLength: 16)
            Text("The time your\nmorning begins")
                .font(SGFont.serifTitle(38))
                .foregroundStyle(SGT.ink)
            Text("A time is enough for now. The alarm is optional.")
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

            Spacer(minLength: 4)
            Button(action: advance) {
                Text("Save time and continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkyPrimaryButtonStyle())
            .disabled(isScheduling)
        }
        .padding(SGSpacing.xl)
    }

    private var alarmActionTitle: String {
        if alarmState.isScheduled { return "Update \(alarmState.kind.title)" }
        return alarmState.kind == .systemAlarm ? "Set a System Alarm" : "Set a Morning Reminder"
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
