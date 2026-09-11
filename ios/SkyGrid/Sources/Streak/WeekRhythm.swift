import Foundation

/// The Today screen's primary indicator (VISION.md §3, pain point #3): a rolling
/// 7-day window ending today, described as a plain fact ("4 days posted") rather
/// than a fraction — deliberately not framed as a score.
struct WeekRhythmDay: Sendable, Equatable {
    let date: LocalDate
    let hasPosted: Bool
    let isToday: Bool
    /// The post that made this day count. Keeping the source object on the rolling
    /// week lets the Pro recap reuse this calculator's exact date boundary instead
    /// of rebuilding a subtly different "last seven" query in the UI.
    let post: SkyPost?
    /// `nil` when `hasPosted` is `false`, or for a posted day this window's caller
    /// never had a `SkyPost` for (should not happen in practice — `summarize` only
    /// ever receives posts it's about to mark posted — but kept optional rather than
    /// force-unwrapped so a future caller passing a partial post list degrades to
    /// "posted, no thumbnail" instead of crashing).
    var thumbPath: String? { post?.thumbPath }
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
            return WeekRhythmDay(date: date, hasPosted: post != nil, isToday: offset == 0, post: post)
        }
        return WeekRhythm(days: days)
    }
}

enum WeeklyRecapPolicy {
    /// A recap is earned only when every day in the calculator's rolling seven-day
    /// window has a post. This deliberately means seven calendar mornings ending
    /// today, not seven non-contiguous posts selected by a second history query.
    static func isReady(_ rhythm: WeekRhythm) -> Bool {
        rhythm.days.count == 7 && rhythm.postedCount == 7
    }

    static func canOpen(_ rhythm: WeekRhythm, isPro: Bool) -> Bool {
        isPro && isReady(rhythm)
    }
}
