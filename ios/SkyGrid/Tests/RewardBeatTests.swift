import Testing
@testable import SkyGrid

@Suite("RewardBeat")
struct RewardBeatTests {
    @Test("beats stay in the contract's causal order")
    func causalOrder() {
        #expect(RewardBeat.allCases == [
            .captureConfirmation,
            .pixelDerivation,
            .mosaicLanding,
            .rewardPeak,
            .settle
        ])
    }

    @Test("offsets are strictly increasing, matching DESIGN.md's beat table")
    func offsetsIncrease() {
        let offsets = RewardBeat.allCases.map(\.startOffset)
        #expect(offsets == offsets.sorted())
        #expect(Set(offsets).count == offsets.count)
    }

    @Test("resolves the current beat at an arbitrary elapsed time")
    func resolvesCurrentBeat() {
        #expect(RewardBeat.current(atElapsed: 0) == .captureConfirmation)
        #expect(RewardBeat.current(atElapsed: 0.1) == .captureConfirmation)
        #expect(RewardBeat.current(atElapsed: 0.18) == .pixelDerivation)
        #expect(RewardBeat.current(atElapsed: 0.6) == .mosaicLanding)
        #expect(RewardBeat.current(atElapsed: 1.0) == .rewardPeak)
        #expect(RewardBeat.current(atElapsed: 1.35) == .settle)
        #expect(RewardBeat.current(atElapsed: 10) == .settle)
    }

    @Test("the normal-path total duration stays inside DESIGN.md's 1.4-1.8s window")
    func totalDurationInWindow() {
        #expect(RewardBeat.totalDuration >= 1.4)
        #expect(RewardBeat.totalDuration <= 1.8)
    }

    @Test("the reduced-motion duration is short, per DESIGN.md's Reduce Motion section")
    func reducedMotionDurationIsShort() {
        #expect(RewardBeat.reducedMotionDuration <= 0.5)
    }
}
