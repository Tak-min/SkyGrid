import Foundation

/// The Today screen's primary indicator (VISION.md §3, pain point #3): a rolling
/// 7-day window ending today, described as a plain fact ("4 days posted") rather
/// than a fraction — deliberately not framed as a score.
struct WeekRhythmDay: Sendable, Equatable {
    let date: LocalDate
    let hasPosted: Bool
    let isToday: Bool
    /// `nil` when `hasPosted` is `false`, or for a posted day this window's caller
    /// never had a `SkyPost` for (should not happen in practice — `summarize` only
    /// ever receives posts it's about to mark posted — but kept optional rather than
    /// force-unwrapped so a future caller passing a partial post list degrades to
    /// "posted, no thumbnail" instead of crashing).
    let thumbPath: String?
}

struct WeekRhythm: Sendable, Equatable {
    /// Oldest to newest, always exactly 7 entries, ending at `today`.
    let days: [WeekRhythmDay]

    var postedCount: Int { days.filter(\.hasPosted).count }
}

enum WeekRhythmCalculator {
    /// Takes full `SkyPost`s rather than bare dates (2026-08-14, photo-over-color
    /// pivot — see `dev-notes/photo-over-color-conversion_2026-08-14.md`) so each
    /// `WeekRhythmDay` can carry its own `thumbPath` for `WeekRhythmView` to render
    /// the viewer's actual photo instead of a single flat accent colour. This is
    /// always the *viewer's own* week — no buddy privacy gate applies here, unlike
    /// `BuddyTile`.
    static func summarize(posts: [SkyPost], today: LocalDate) -> WeekRhythm {
        let postedByDate = Dictionary(posts.map { ($0.localDate, $0) }, uniquingKeysWith: { _, newest in newest })
        let days = (0..<7).reversed().map { offset -> WeekRhythmDay in
            let date = today.adding(days: -offset)
            let post = postedByDate[date]
            return WeekRhythmDay(date: date, hasPosted: post != nil, isToday: offset == 0, thumbPath: post?.thumbPath)
        }
        return WeekRhythm(days: days)
    }
}
