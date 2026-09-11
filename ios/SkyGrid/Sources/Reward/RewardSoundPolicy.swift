/// Keeps the daily reward to one sound. A verified mutual reveal is the rarer,
/// more meaningful result and therefore replaces (rather than stacks on) the
/// ordinary saved-capture sound.
enum RewardSoundPolicy {
    static func effect(
        for beat: RewardBeat,
        revealedCount: Int,
        reducedMotion: Bool
    ) -> AppSoundEffect? {
        if revealedCount > 0 {
            return beat == .settle ? .mutualReveal : nil
        }

        if reducedMotion {
            return beat == .settle ? .captureSaved : nil
        }

        return beat == .rewardPeak ? .captureSaved : nil
    }
}
