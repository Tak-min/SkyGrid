import CoreImage
import UIKit

/// Abstracts the camera hardware so `CameraViewModel`/`CameraView` never touch
/// AVFoundation directly. The app's production composition root always supplies a
/// real `CameraSessionController`; test doubles belong exclusively in test targets.
@MainActor
protocol CameraSource: AnyObject {
    /// Live preview frames, used both for on-screen rendering and live sky-color
    /// sampling (throttled by `LivePreviewSampler`).
    var previewFrames: AsyncStream<CIImage> { get }

    func start() async throws
    func stop()
    func capturePhoto() async throws -> UIImage
}

enum CameraSourceError: Error {
    case permissionDenied
    case configurationFailed
}
