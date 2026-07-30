import Foundation

/// Throttles live camera-preview color sampling to ~4fps. The camera delivers frames
/// at 30-60fps; sampling every one of them for a value the eye can't perceive
/// changing that fast would just waste CPU/battery.
@MainActor
final class LivePreviewSampler {
    private let minimumInterval: TimeInterval
    private var lastSampleTime: Date = .distantPast

    init(samplesPerSecond: Double = 4) {
        self.minimumInterval = 1.0 / samplesPerSecond
    }

    /// `true` if enough time has elapsed since the last accepted sample — callers
    /// should skip color extraction entirely when this returns `false`.
    func shouldSample(now: Date = Date()) -> Bool {
        guard now.timeIntervalSince(lastSampleTime) >= minimumInterval else { return false }
        lastSampleTime = now
        return true
    }
}
