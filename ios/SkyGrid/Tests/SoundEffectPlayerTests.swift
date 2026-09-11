import AudioToolbox
import Foundation
import Testing
@testable import SkyGrid

@MainActor
@Suite("SoundEffectPlayer")
struct SoundEffectPlayerTests {
    @Test("muted playback does not resolve or create a sound")
    func muteIsAHardGate() {
        var resolved = false
        var created = false
        var played: [SystemSoundID] = []
        let player = SoundEffectPlayer(
            isPlaybackEnabled: { false },
            resourceURL: { _ in resolved = true; return URL(fileURLWithPath: "/sound.caf") },
            makeSoundID: { _ in created = true; return 41 },
            playSoundID: { played.append($0) }
        )

        #expect(!player.play(.captureSaved))
        #expect(!resolved)
        #expect(!created)
        #expect(played.isEmpty)
    }

    @Test("missing assets fail quietly")
    func missingAssetFailsQuietly() {
        var created = false
        let player = SoundEffectPlayer(
            isPlaybackEnabled: { true },
            resourceURL: { _ in nil },
            makeSoundID: { _ in created = true; return 42 },
            playSoundID: { _ in }
        )

        #expect(!player.play(.recoverableError))
        #expect(!created)
    }

    @Test("created system sound IDs are cached and released")
    func cachesAndReleasesSoundIDs() {
        var creationCount = 0
        var played: [SystemSoundID] = []
        var disposed: [SystemSoundID] = []
        let player = SoundEffectPlayer(
            isPlaybackEnabled: { true },
            resourceURL: { _ in URL(fileURLWithPath: "/sound.caf") },
            makeSoundID: { _ in creationCount += 1; return 43 },
            playSoundID: { played.append($0) },
            disposeSoundID: { disposed.append($0) }
        )

        #expect(player.play(.captureSaved))
        #expect(player.play(.captureSaved))
        #expect(creationCount == 1)
        #expect(played == [43, 43])

        player.releaseResources()
        #expect(disposed == [43])
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
