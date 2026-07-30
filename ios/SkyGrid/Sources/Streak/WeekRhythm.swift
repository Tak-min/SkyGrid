import Foundation

/// The Today screen's primary indicator (VISION.md §3, pain point #3): a rolling
/// 7-day window ending today, described as a plain fact ("4 days posted") rather
/// than a fraction — deliberately not framed as a score.
struct WeekRhythmDay: Sendable, Equatable {
    let date: LocalDate
    let hasPosted: Bool
    let isToday: Bool
}

struct WeekRhythm: Sendable, Equatable {
    /// Oldest to newest, always exactly 7 entries, ending at `today`.
    let days: [WeekRhythmDay]

    var postedCount: Int { days.filter(\.hasPosted).count }
}

enum WeekRhythmCalculator {
    static func summarize(postedDays: [LocalDate], today: LocalDate) -> WeekRhythm {
        let posted = Set(postedDays)
        let days = (0..<7).reversed().map { offset -> WeekRhythmDay in
            let date = today.adding(days: -offset)
            return WeekRhythmDay(date: date, hasPosted: posted.contains(date), isToday: offset == 0)
        }
        return WeekRhythm(days: days)
    }
}
