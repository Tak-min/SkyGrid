import AVFoundation
import Foundation
import Testing
@testable import SkyGrid

@MainActor
@Suite("SoundEffectPlayer")
struct SoundEffectPlayerTests {
    @Test("muted playback does not resolve or create a player")
    func muteIsAHardGate() {
        var resolved = false
        var created = false
        var played = false
        let player = SoundEffectPlayer(
            isPlaybackEnabled: { false },
            resourceURL: { _ in resolved = true; return URL(fileURLWithPath: "/sound.caf") },
            makePlayer: { _ in created = true; return dummyPlayer() },
            playPlayer: { _ in played = true }
        )

        #expect(!player.play(.captureSaved))
        #expect(!resolved)
        #expect(!created)
        #expect(!played)
    }

    @Test("missing assets fail quietly")
    func missingAssetFailsQuietly() {
        var created = false
        let player = SoundEffectPlayer(
            isPlaybackEnabled: { true },
            resourceURL: { _ in nil },
            makePlayer: { _ in created = true; return dummyPlayer() },
            playPlayer: { _ in }
        )

        #expect(!player.play(.recoverableError))
        #expect(!created)
    }

    @Test("created players are cached and released")
    func cachesAndReleasesPlayers() {
        var creationCount = 0
        var playCount = 0
        var releaseCount = 0
        let player = SoundEffectPlayer(
            isPlaybackEnabled: { true },
            resourceURL: { _ in URL(fileURLWithPath: "/sound.caf") },
            makePlayer: { _ in creationCount += 1; return dummyPlayer() },
            playPlayer: { _ in playCount += 1 },
            releasePlayer: { _ in releaseCount += 1 }
        )

        #expect(player.play(.captureSaved))
        #expect(player.play(.captureSaved))
        #expect(creationCount == 1)
        #expect(playCount == 2)

        player.releaseResources()
        #expect(releaseCount == 1)
    }

    @Test("sound asset names stay complete and stable")
    func assetNamesStayStable() {
        #expect(AppSoundEffect.allCases.map(\.rawValue) == [
            "capture_saved",
            "mutual_reveal",
            "streak_milestone",
            "recoverable_error",
            "moku_tap",
            "forward_navigation",
            "purchase_confirmed"
        ])
        #expect(AppSoundEffect.fileExtension == "caf")
    }

    @Test("every declared sound is bundled with the app")
    func assetsAreBundled() {
        for effect in AppSoundEffect.allCases {
            #expect(Bundle.main.url(
                forResource: effect.rawValue,
                withExtension: AppSoundEffect.fileExtension
            ) != nil)
        }
    }
}

// MARK: - Test Helpers

/// Create a dummy AVAudioPlayer for testing. Uses a real bundled sound file
/// to satisfy AVAudioPlayer's initialization requirements.
@MainActor
private func dummyPlayer() -> AVAudioPlayer? {
    guard let url = Bundle.main.url(
        forResource: "moku_tap",
        withExtension: "caf"
    ) else { return nil }
    return try? AVAudioPlayer(contentsOf: url)
}

@Suite("RewardSoundPolicy")
struct RewardSoundPolicyTests {
    @Test("an ordinary reward plays once at its peak")
    func ordinaryReward() {
        let effects = RewardBeat.allCases.compactMap {
            RewardSoundPolicy.effect(for: $0, revealedCount: 0, reducedMotion: false)
        }
        #expect(effects == [.captureSaved])
    }

    @Test("a mutual reveal replaces the ordinary capture sound")
    func mutualRevealTakesPriority() {
        let effects = RewardBeat.allCases.compactMap {
            RewardSoundPolicy.effect(for: $0, revealedCount: 2, reducedMotion: false)
        }
        #expect(effects == [.mutualReveal])
    }

    @Test("Reduce Motion still receives one settled-state confirmation")
    func reducedMotionParity() {
        let effects = RewardBeat.allCases.compactMap {
            RewardSoundPolicy.effect(for: $0, revealedCount: 0, reducedMotion: true)
        }
        #expect(effects == [.captureSaved])
    }
}
