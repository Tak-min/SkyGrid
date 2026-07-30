@preconcurrency import AVFoundation
import CoreImage
import UIKit

/// Real-device camera backend. Camera capture requires a physical device; the
/// simulator correctly reports that no capture device is available.
///
/// Isolation model: `AVCaptureSession` and its inputs/outputs are not `Sendable`, and
/// Apple's own threading contract requires configuring/starting/stopping them off the
/// main thread via a dedicated serial queue — never via actor hops. Those properties
/// are therefore `nonisolated(unsafe)` and confined entirely to `sessionQueue`; only
/// the `AsyncStream` continuations that hand results back to SwiftUI are
/// `@MainActor`-isolated.
final class CameraSessionController: NSObject, CameraSource {
    nonisolated(unsafe) let session = AVCaptureSession()

    private nonisolated(unsafe) let photoOutput = AVCapturePhotoOutput()
    private nonisolated(unsafe) let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.takmin.skygrid.camera.session")

    @MainActor private var continuation: AsyncStream<CIImage>.Continuation?
    @MainActor private var photoCaptureContinuation: CheckedContinuation<UIImage, Error>?

    @MainActor private(set) lazy var previewFrames: AsyncStream<CIImage> = AsyncStream { continuation in
        self.continuation = continuation
    }

    func start() async throws {
        guard await requestCameraAccess() else { throw CameraSourceError.permissionDenied }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [session, photoOutput, videoOutput, weak self] in
                do {
                    try Self.configureSessionIfNeeded(
                        session: session,
                        photoOutput: photoOutput,
                        videoOutput: videoOutput,
                        sampleBufferDelegate: self,
                        sessionQueue: self?.sessionQueue
                    )
                    session.startRunning()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        let session = session
        sessionQueue.async { session.stopRunning() }
        Task { @MainActor in continuation?.finish() }
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in self.photoCaptureContinuation = continuation }
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// Must run on `sessionQueue`, per AVFoundation's own configuration contract —
    /// hence `static`/non-isolated, taking every queue-confined resource as a
    /// parameter rather than touching `self` across an isolation boundary.
    private nonisolated static func configureSessionIfNeeded(
        session: AVCaptureSession,
        photoOutput: AVCapturePhotoOutput,
        videoOutput: AVCaptureVideoDataOutput,
        sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?,
        sessionQueue: DispatchQueue?
    ) throws {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { throw CameraSourceError.configurationFailed }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else { throw CameraSourceError.configurationFailed }
        session.addOutput(photoOutput)

        if let sampleBufferDelegate, let sessionQueue {
            videoOutput.setSampleBufferDelegate(sampleBufferDelegate, queue: sessionQueue)
        }
        guard session.canAddOutput(videoOutput) else { throw CameraSourceError.configurationFailed }
        session.addOutput(videoOutput)
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                photoCaptureContinuation?.resume(throwing: error)
            } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
                photoCaptureContinuation?.resume(returning: image)
            } else {
                photoCaptureContinuation?.resume(throwing: CameraSourceError.configurationFailed)
            }
            photoCaptureContinuation = nil
        }
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        Task { @MainActor [weak self] in self?.continuation?.yield(ciImage) }
    }
}
