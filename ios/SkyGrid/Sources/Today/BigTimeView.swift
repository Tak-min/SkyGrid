import SwiftUI

/// The Today screen's visual star per VISION.md §6: the number, not the photo.
struct BigTimeView: View {
    let capturedAt: Date?
    let timeZone: TimeZone
    var color: Color = SGT.ink

    var body: some View {
        Text(capturedAt.map(formattedTime) ?? "—:—")
            .font(SGFont.bigTime())
            .foregroundStyle(color)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "H:mm"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
