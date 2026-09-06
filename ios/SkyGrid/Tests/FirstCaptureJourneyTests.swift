import Foundation
import Testing
@testable import SkyGrid

@Suite("First capture experience measurement")
struct FirstCaptureJourneyTests {
    @Test func resumesAcrossSessionsAndCompletesExactlyOnce() {
        let suite = "FirstCaptureJourneyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let journey = FirstCaptureJourney(defaults: defaults)
        #expect(journey.start(now: Date(timeIntervalSince1970: 100)))
        #expect(!journey.start(now: Date(timeIntervalSince1970: 150)))
        let resumed = FirstCaptureJourney(defaults: defaults)
        #expect(resumed.complete(now: Date(timeIntervalSince1970: 160)) == 60)
        #expect(resumed.complete(now: Date(timeIntervalSince1970: 170)) == nil)
        #expect(!resumed.start())
        resumed.reset()
        #expect(resumed.start())
    }

    @Test func doesNotInventExistingUserOrNegativeDurations() {
        let suite = "FirstCaptureJourneyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let journey = FirstCaptureJourney(defaults: defaults)
        #expect(journey.complete() == nil)
        journey.start(now: Date(timeIntervalSince1970: 100))
        #expect(journey.complete(now: Date(timeIntervalSince1970: 90)) == nil)
        #expect(journey.complete(now: Date(timeIntervalSince1970: 110)) == 10)
    }
}
