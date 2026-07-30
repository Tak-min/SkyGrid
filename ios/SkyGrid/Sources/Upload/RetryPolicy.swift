import Foundation

/// Exponential backoff with jitter for failed image uploads:
/// `min(cap, base^attempt) × jitter`, capped at `maxAttempts` before giving up and
/// surfacing a quiet retry affordance to the user (blueprint §5.3) — never silently
/// discarding the photo, since a missed morning's photo can't be recreated.
enum RetryPolicy {
    static let maxAttempts = 8
    static let base: TimeInterval = 2
    static let cap: TimeInterval = 600

    static func delay(forAttempt attempt: Int, jitter: Double = Double.random(in: 0.75...1.25)) -> TimeInterval {
        let raw = min(cap, pow(base, Double(attempt)))
        return raw * jitter
    }
}
