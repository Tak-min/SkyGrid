import CoreImage
import Foundation
import Observation
import UIKit

/// Orchestrates capture → extract sky color → compress → write pending bytes to
/// disk → produce a `PostDraft`. Does NOT write to `PostRepository` or enqueue an
/// upload itself — that hand-off is the caller's job (Task #8/#9's `UploadQueue`),
/// which keeps this view model testable and focused purely on the capture pipeline
/// (blueprint build-order: Camera lands before Persistence/Upload).
@MainActor
@Observable
final class CameraViewModel {
    enum Failure: Equatable {
        case permissionDenied
        case startup
        case capture
        case colorDetection
    }

    enum Phase: Equatable {
        case live
        case reviewing(capturedImage: UIImage, skyColor: SkyColor)
        case failed(Failure)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.live, .live): return true
            case let (.reviewing(li, ls), .reviewing(ri, rs)): return li === ri && ls == rs
            case let (.failed(l), .failed(r)): return l == r
            default: return false
            }
        }
    }

    private(set) var phase: Phase = .live
    private(set) var liveSkyColor: SkyColor?
    /// Only consumed by `CameraView` when there's no real `AVCaptureSession` to bind
    /// a preview layer to (i.e. the Simulator backend) — see `CameraView`.
    private(set) var latestPreviewImage: UIImage?

    private let ownerUid: String
    private let cameraSource: CameraSource
    private let clock: Clock
    private let wakeGoal: WakeGoal
    private let sampler = LivePreviewSampler()
    private var sampleLoopTask: Task<Void, Never>?

    init(ownerUid: String, cameraSource: CameraSource, clock: Clock, wakeGoal: WakeGoal) {
        self.ownerUid = ownerUid
        self.cameraSource = cameraSource
        self.clock = clock
        self.wakeGoal = wakeGoal
    }

    func start() async {
        do {
            try await cameraSource.start()
            phase = .live
            sampleLoopTask = Task { [weak self] in
                guard let self else { return }
                for await frame in self.cameraSource.previewFrames {
                    guard self.sampler.shouldSample() else { continue }
                    self.liveSkyColor = SkyColorExtractor.extract(from: frame)
                    self.latestPreviewImage = UIImage(ciImage: frame)
                }
            }
        } catch CameraSourceError.permissionDenied {
            phase = .failed(.permissionDenied)
        } catch {
            phase = .failed(.startup)
        }
    }

    func stop() {
        sampleLoopTask?.cancel()
        cameraSource.stop()
    }

    func capture() async {
        do {
            let image = try await cameraSource.capturePhoto()
            // A real shutter result is enough for Photo Mission. Darkness or a
            // featureless sky must not make the alarm impossible to complete.
            let skyColor = SkyColorExtractor.extract(from: image)
                ?? liveSkyColor
                ?? SkyColor(uncheckedHex: "#9DB7C5")
            phase = .reviewing(capturedImage: image, skyColor: skyColor)
        } catch {
            phase = .failed(.capture)
        }
    }

    func retake() {
        phase = .live
    }

    /// Recovers from the exact failed operation. A failed camera start must run
    /// `start()` again; merely changing the visible phase would return to a black,
    /// unconfigured preview. Capture/color failures keep the active session and can
    /// return directly to the live viewfinder.
    func retry() async {
        guard case .failed(let failure) = phase else { return }
        switch failure {
        case .permissionDenied, .startup:
            await start()
        case .capture, .colorDetection:
            retake()
        }
    }

    /// Finalizes the reviewed photo: compresses it, persists pending bytes to
    /// `ImageFileStore` (Application Support, never Caches), and returns a
    /// ready-to-enqueue `PostDraft`. Returns `nil` if not currently reviewing a
    /// photo or if compression/writing fails.
    func confirmCapture() -> PostDraft? {
        guard case .reviewing(let image, let skyColor) = phase,
              let (mainData, thumbData) = ImageProcessor.processedPair(from: image)
        else { return nil }

        let now = clock.now
        let localDate = LocalDate(date: now, timeZone: clock.timeZone)
        let imageID = UUID()

        guard let fullURL = try? ImageFileStore.writePendingImage(mainData, filename: "\(imageID.uuidString).jpg"),
              let thumbURL = try? ImageFileStore.writePendingImage(thumbData, filename: "\(imageID.uuidString)_thumb.jpg")
        else { return nil }

        return PostDraft(
            ownerUid: ownerUid,
            localDate: localDate,
            capturedAt: now,
            skyColor: skyColor,
            minutesFromGoal: wakeGoal.minutesFromGoal(capturedAt: now, timeZone: clock.timeZone),
            imageID: imageID,
            localFullImageURL: fullURL,
            localThumbImageURL: thumbURL
        )
    }
}
