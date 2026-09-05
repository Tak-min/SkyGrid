import Testing
@testable import SkyGrid

@Suite("DailyRewardPolicy")
struct DailyRewardPolicyTests {
    private let today = LocalDate(year: 2026, month: 9, day: 6)

    @Test("plays when nothing has played yet")
    func playsWhenNeverPlayed() {
        #expect(DailyRewardPolicy.shouldPlay(for: today, lastPlayedLocalDate: nil))
    }

    @Test("plays on a new calendar day even if yesterday already played")
    func playsOnNewDay() {
        let yesterday = LocalDate(year: 2026, month: 9, day: 5)
        #expect(DailyRewardPolicy.shouldPlay(for: today, lastPlayedLocalDate: yesterday.docID))
    }

    @Test("does not replay for the same day it already played")
    func doesNotReplaySameDay() {
        #expect(!DailyRewardPolicy.shouldPlay(for: today, lastPlayedLocalDate: today.docID))
    }
}
