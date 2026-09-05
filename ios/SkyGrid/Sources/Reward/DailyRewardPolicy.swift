import Foundation

/// Bounds the daily reward to "at most once for that successful post"
/// (DESIGN.md's daily reward motion contract). Pure so the one-per-day guarantee is
/// testable without a simulator — mirrors `PostCaptureMomentPolicy`'s pure-decide
/// shape and `RootView.recordCompletedCapture`'s same-day guard.
enum DailyRewardPolicy {
    /// `lastPlayedLocalDate` is a `LocalDate.docID` string, mirroring
    /// `LocalDefaults.lastCompletedCaptureLocalDate`'s same-day comparison — a plain
    /// `String?` rather than `LocalDate?` so the persisted value round-trips through
    /// `UserDefaults` without its own decoding step.
    static func shouldPlay(for localDate: LocalDate, lastPlayedLocalDate: String?) -> Bool {
        lastPlayedLocalDate != localDate.docID
    }
}
