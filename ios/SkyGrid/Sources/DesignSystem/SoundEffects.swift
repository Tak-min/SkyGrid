import AVFoundation
import Foundation
import UIKit

/// The deliberately small app-wide sound vocabulary. Sound reinforces an already
/// visible, tactile state change; it never carries state by itself.
enum AppSoundEffect: String, CaseIterable {
    case captureSaved = "capture_saved"
    case mutualReveal = "mutual_reveal"
    case streakMilestone = "streak_milestone"
    case recoverableError = "recoverable_error"
    case mokuTap = "moku_tap"
    case forwardNavigation = "forward_navigation"
    case purchaseConfirmed = "purchase_confirmed"

    static let fileExtension = "caf"
}

/// Low-latency playback for short UI sounds. Uses AVAudioPlayer routed through the app's
/// audio session (media-volume-controlled) rather than system sounds. Respects the device's
/// silent setting via the .ambient audio category. All decisions remain injectable so tests
/// never play host audio.
@MainActor
final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()

    private let isPlaybackEnabled: @MainActor () -> Bool
    private let resourceURL: (AppSoundEffect) -> URL?
    private let makePlayer: (URL) -> AVAudioPlayer?
    private let playPlayer: (AVAudioPlayer) -> Void
    private let releasePlayer: (AVAudioPlayer) -> Void
    private var players: [AppSoundEffect: AVAudioPlayer] = [:]

    init(
        isPlaybackEnabled: @escaping @MainActor () -> Bool = {
            LocalDefaults.soundEffectsEnabled
                && UIApplication.shared.applicationState == .active
                && !ProcessInfo.processInfo.arguments.contains("-SkyGridUIAudit")
        },
        resourceURL: @escaping (AppSoundEffect) -> URL? = { effect in
            Bundle.main.url(
                forResource: effect.rawValue,
                withExtension: AppSoundEffect.fileExtension
            )
        },
        makePlayer: @escaping (URL) -> AVAudioPlayer? = { url in
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = 1.0
                player.prepareToPlay()
                return player
            } catch {
                return nil
            }
        },
        playPlayer: @escaping (AVAudioPlayer) -> Void = { player in
            player.currentTime = 0
            player.play()
        },
        releasePlayer: @escaping (AVAudioPlayer) -> Void = { player in
            player.stop()
        }
    ) {
        self.isPlaybackEnabled = isPlaybackEnabled
        self.resourceURL = resourceURL
        self.makePlayer = makePlayer
        self.playPlayer = playPlayer
        self.releasePlayer = releasePlayer
    }

    /// Returns whether playback was accepted. Missing/corrupt resources fail
    /// quietly because the visible UI and VoiceOver announcement remain primary.
    @discardableResult
    func play(_ effect: AppSoundEffect) -> Bool {
        guard isPlaybackEnabled() else { return false }

        if let player = players[effect] {
            playPlayer(player)
            return true
        }

        guard let url = resourceURL(effect),
              let player = makePlayer(url)
        else { return false }

        players[effect] = player
        playPlayer(player)
        return true
    }

    /// Prewarm all sounds at app startup to avoid first-play latency.
    /// Called from AppDelegate.didFinishLaunchingWithOptions.
    func prewarmAllSounds() {
        for effect in AppSoundEffect.allCases {
            // Silently ignore missing/corrupt resources during prewarm;
            // users still get a working app even if a particular sound fails to load.
            if let url = resourceURL(effect), players[effect] == nil {
                if let player = makePlayer(url) {
                    players[effect] = player
                }
            }
        }
    }

    /// Explicit rather than `deinit`: the production singleton lives for the app
    /// process, while tests can deterministically prove cached players are released.
    func releaseResources() {
        players.values.forEach(releasePlayer)
        players.removeAll()
    }
}
