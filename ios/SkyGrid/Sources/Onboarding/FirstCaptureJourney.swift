import Foundation

/// Persistent first-experience stopwatch. Stores no account or preference data;
/// the start event supplies the denominator even when a person never captures.
struct FirstCaptureJourney {
    let defaults: UserDefaults
    private let startKey = "firstCaptureJourney.startedAt"
    private let completeKey = "firstCaptureJourney.completed"

    static let standard = FirstCaptureJourney(defaults: .standard)

    @discardableResult
    func start(now: Date = Date()) -> Bool {
        guard !defaults.bool(forKey: completeKey), defaults.object(forKey: startKey) == nil else { return false }
        defaults.set(now.timeIntervalSince1970, forKey: startKey)
        return true
    }

    /// Wall time includes backgrounding and later sessions. Do not manufacture a
    /// duration for existing users or a clock that moved behind the start time.
    func complete(now: Date = Date()) -> TimeInterval? {
        guard !defaults.bool(forKey: completeKey),
              let start = defaults.object(forKey: startKey) as? Double else { return nil }
        let duration = now.timeIntervalSince1970 - start
        guard duration >= 0 else { return nil }
        defaults.set(true, forKey: completeKey)
        defaults.removeObject(forKey: startKey)
        return duration
    }

    func reset() {
        defaults.removeObject(forKey: startKey)
        defaults.removeObject(forKey: completeKey)
    }
}
