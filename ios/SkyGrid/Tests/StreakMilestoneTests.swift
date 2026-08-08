import Foundation
import Testing
@testable import SkyGrid

@Suite("StreakMilestone")
struct StreakMilestoneTests {
    @Test("thresholds are the agreed set, strictly increasing")
    func thresholdsAreStrictlyIncreasing() {
        #expect(StreakMilestone.thresholds == [1, 7, 14, 30, 50, 100, 200, 365])
        #expect(zip(StreakMilestone.thresholds, StreakMilestone.thresholds.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("an exact threshold hit produces that milestone")
    func exactHitProducesMilestone() {
        #expect(StreakMilestone.reached(streak: 1, lastCelebrated: 0)?.streak == 1)
        #expect(StreakMilestone.reached(streak: 7, lastCelebrated: 0)?.streak == 7)
        #expect(StreakMilestone.reached(streak: 365, lastCelebrated: 200)?.streak == 365)
    }

    @Test("a streak that is not itself a threshold never celebrates", arguments: [0, 2, 6, 8, 29, 99, 364])
    func nonThresholdNeverCelebrates(streak: Int) {
        #expect(StreakMilestone.reached(streak: streak, lastCelebrated: 0) == nil)
    }

    @Test("a milestone already celebrated does not fire again")
    func highWaterGuardBlocksRepeat() {
        #expect(StreakMilestone.reached(streak: 7, lastCelebrated: 7) == nil)
        #expect(StreakMilestone.reached(streak: 7, lastCelebrated: 14) == nil)
        #expect(StreakMilestone.reached(streak: 1, lastCelebrated: 1) == nil)
    }

    /// A reinstall (or the streak window widening in one jump) can surface a large
    /// streak that never passed through the intermediate thresholds *in this install*.
    /// Nothing may be back-filled — celebrating 100 on a day the user's streak is 130
    /// would print a number that contradicts every other surface.
    @Test("a jump past thresholds does not back-fill the ones it skipped")
    func jumpDoesNotBackFill() {
        #expect(StreakMilestone.reached(streak: 130, lastCelebrated: 0) == nil)
        #expect(StreakMilestone.reached(streak: 201, lastCelebrated: 0) == nil)
    }

    @Test("a negative streak is never a milestone")
    func negativeStreakNeverCelebrates() {
        #expect(StreakMilestone.reached(streak: -1, lastCelebrated: 0) == nil)
    }

    @Test("every threshold carries non-empty copy", arguments: StreakMilestone.thresholds)
    func everyThresholdHasCopy(streak: Int) {
        let milestone = StreakMilestone(streak: streak)
        #expect(!milestone.title.isEmpty)
        #expect(!milestone.headline.isEmpty)
    }

    @Test("the first morning reads differently from every later milestone")
    func firstMorningHasItsOwnCopy() {
        let dayOne = StreakMilestone(streak: 1)
        #expect(dayOne.isFirstMorning)
        for streak in StreakMilestone.thresholds where streak != 1 {
            let later = StreakMilestone(streak: streak)
            #expect(!later.isFirstMorning)
            #expect(later.title != dayOne.title)
            #expect(later.headline != dayOne.headline)
        }
    }
}
