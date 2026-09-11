import AudioToolbox
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

/// Low-latency playback for short UI sounds. The system-sound path respects the
/// device's silent setting, and IDs are cached after first use to avoid decoding on
/// each reward. All decisions remain injectable so tests never play host audio.
@MainActor
final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()

    private let isPlaybackEnabled: @MainActor () -> Bool
    private let resourceURL: (AppSoundEffect) -> URL?
    private let makeSoundID: (URL) -> SystemSoundID?
    private let playSoundID: (SystemSoundID) -> Void
    private let disposeSoundID: (SystemSoundID) -> Void
    private var soundIDs: [AppSoundEffect: SystemSoundID] = [:]

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
        makeSoundID: @escaping (URL) -> SystemSoundID? = { url in
            var soundID: SystemSoundID = 0
            let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
            return status == kAudioServicesNoError ? soundID : nil
        },
        playSoundID: @escaping (SystemSoundID) -> Void = { soundID in
            AudioServicesPlaySystemSound(soundID)
        },
        disposeSoundID: @escaping (SystemSoundID) -> Void = { soundID in
            AudioServicesDisposeSystemSoundID(soundID)
        }
    ) {
        self.isPlaybackEnabled = isPlaybackEnabled
        self.resourceURL = resourceURL
        self.makeSoundID = makeSoundID
        self.playSoundID = playSoundID
        self.disposeSoundID = disposeSoundID
    }

    /// Returns whether playback was accepted. Missing/corrupt resources fail
    /// quietly because the visible UI and VoiceOver announcement remain primary.
    @discardableResult
    func play(_ effect: AppSoundEffect) -> Bool {
        guard isPlaybackEnabled() else { return false }

        if let soundID = soundIDs[effect] {
            playSoundID(soundID)
            return true
        }

        guard let url = resourceURL(effect),
              let soundID = makeSoundID(url)
        else { return false }

        soundIDs[effect] = soundID
        playSoundID(soundID)
        return true
    }

    /// Explicit rather than `deinit`: the production singleton lives for the app
    /// process, while tests can deterministically prove cached IDs are disposed.
    func releaseResources() {
        soundIDs.values.forEach(disposeSoundID)
        soundIDs.removeAll()
    }
}
