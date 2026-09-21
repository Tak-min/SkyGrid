import SwiftUI
import UIKit

/// A bounded seven-day rhythm. The marks are evidence, not a streak meter: an empty
/// day remains an equally calm part of the week.
///
/// **Design history (updated 2026-08-14):** each posted day used to show one flat
/// accent colour — not even that day's own extracted sky colour, just a single fixed
/// colour reused across every posted cell. The product owner's photo-over-color
/// reversal (`dev-notes/photo-over-color-conversion_2026-08-14.md`) replaced that
/// with each day's actual photo. This is always the viewer's own week, so unlike
/// `BuddyTile` there is no mutual-reveal gate to respect — a posted day's photo is
/// simply fetched and shown.
struct WeekRhythmView: View {
    @Environment(\.locale) private var locale
    let rhythm: WeekRhythm
    let imageFetching: any ImageFetching
    var accent: SkyColor = SkyColor(uncheckedHex: "#9DB7C5")
    @State private var thumbnails: [String: UIImage] = [:]

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
                            if let thumbPath = day.thumbPath, let thumbnail = thumbnails[thumbPath] {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 42)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
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
        .task(id: thumbPathsToLoad) { await loadMissingThumbnails() }
    }

    /// The set of paths this render needs but doesn't have yet, joined into one
    /// string so `.task(id:)` only restarts when the actual set of pending fetches
    /// changes — not on every unrelated `rhythm` re-render (e.g. `isToday` shifting
    /// at midnight doesn't change which photos are missing).
    private var thumbPathsToLoad: String {
        rhythm.days
            .compactMap(\.thumbPath)
            .filter { thumbnails[$0] == nil }
            .sorted()
            .joined(separator: ",")
    }

    private func loadMissingThumbnails() async {
        let missing = rhythm.days.compactMap(\.thumbPath).filter { thumbnails[$0] == nil }
        guard !missing.isEmpty else { return }
        for path in missing {
            guard let thumbnail = await ThumbnailLoader.loadThumbnail(forRemotePath: path, imageFetching: imageFetching) else { continue }
            thumbnails[path] = thumbnail
        }
    }

    private func weekdayLabel(for day: LocalDate) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        guard let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}
