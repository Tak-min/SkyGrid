import SwiftUI

/// A bounded seven-day rhythm. The marks are evidence, not a streak meter: an empty
/// day remains an equally calm part of the week.
struct WeekRhythmView: View {
    let rhythm: WeekRhythm
    var accent: SkyColor = SkyColor(uncheckedHex: "#9DB7C5")
    var body: some View {
        HStack(spacing: 7) {
            ForEach(rhythm.days, id: \.date) { day in
                VStack(spacing: SGSpacing.sm) {
                    Text(weekdayLabel(for: day.date))
                        .font(SGFont.fixedCaption(10))
                        .foregroundStyle(day.isToday ? SGT.ink : SGT.ink3)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(day.hasPosted ? accent.color : SGT.ghostFaint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .overlay {
                            if day.isToday {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(SGT.ink.opacity(0.44), lineWidth: 1)
                            }
                        }
                }
            }
        }
        .padding(SGSpacing.md)
        .quietCard()
        // Firestore can deliver the week's initial values after this card first
        // appears. Animating that listener update made the entire "THIS WEEK"
        // row look like it was popping in from another tab; render the settled
        // state directly instead.
    }

    private func weekdayLabel(for day: LocalDate) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        guard let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}
