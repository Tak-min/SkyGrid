import AVFoundation
import SwiftUI

/// Full-screen live viewfinder, one shutter button, and — after capture — exactly
/// two choices ("retake" / "use this"). No gallery picker, no filters, nothing else.
/// Goal: wake-to-posted in ~5 seconds (VISION.md §6).
struct CameraView: View {
    @State private var viewModel: CameraViewModel
    @State private var isConfirming = false
    @State private var isCapturing = false
    @State private var confirmationError: String?
    private let liveSession: AVCaptureSession
    let onConfirmed: (PostDraft) async throws -> Void

    init(
        viewModel: CameraViewModel,
        liveSession: AVCaptureSession,
        onConfirmed: @escaping (PostDraft) async throws -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.liveSession = liveSession
        self.onConfirmed = onConfirmed
    }

    var body: some View {
        ZStack {
            content
        }
        .background(.black)
        .task {
            await viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .live:
            liveViewfinder
        case .reviewing(let image, _):
            reviewScreen(image: image)
        case .failed(let message):
            failureScreen(message: message)
        }
    }

    private var liveViewfinder: some View {
        ZStack {
            CameraPreviewView(session: liveSession)
                .ignoresSafeArea()

            LinearGradient(colors: [.black.opacity(0.44), .clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SKY GRID")
                            .font(SGFont.caption(12))
                            .tracking(1.8)
                        Text("THIS MORNING")
                            .font(SGFont.caption(12))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
                    Spacer()
                    Circle()
                        .fill((viewModel.liveSkyColor?.color ?? Color.white).opacity(0.88))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                        .accessibilityLabel("Current sky color")
                }
                .padding(.horizontal, SGSpacing.xl)
                .padding(.top, 14)
                Spacer()
                VStack(spacing: SGSpacing.md) {
                    Text("ONE SKY")
                        .font(SGFont.caption(13))
                        .foregroundStyle(.white.opacity(0.82))
                    ShutterButton(liveColor: viewModel.liveSkyColor, isWorking: isCapturing) {
                        guard !isCapturing else { return }
                        isCapturing = true
                        Task {
                            await viewModel.capture()
                            isCapturing = false
                        }
                    }
                }
                .padding(.bottom, 42)
            }
        }
    }

    private func reviewScreen(image: UIImage) -> some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: SGSpacing.md) {
                Text("KEEP THIS SKY")
                    .font(SGFont.caption(13))
                    .foregroundStyle(.white.opacity(0.82))

                HStack(spacing: SGSpacing.sm) {
                    Button("Retake") { viewModel.retake() }
                        .buttonStyle(CameraChoiceButtonStyle(emphasized: false))
                        .disabled(isConfirming)

                    Button {
                        confirm(image: image)
                    } label: {
                        if isConfirming {
                            ProgressView().tint(.black)
                        } else {
                            Text("Use this one")
                        }
                    }
                    .buttonStyle(CameraChoiceButtonStyle(emphasized: true))
                    .disabled(isConfirming)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, SGSpacing.xl)
            .padding(.bottom, confirmationError == nil ? 42 : 72)

            if let confirmationError {
                Text(confirmationError)
                    .font(SGFont.caption())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
            }
        }
    }

    private func failureScreen(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 52, weight: .ultraLight))
            Text(message)
                .font(SGFont.body())
            Button("Try again") { viewModel.retake() }
                .buttonStyle(SkySecondaryButtonStyle())
        }
        .foregroundStyle(.white)
    }

    private func confirm(image: UIImage) {
        guard !isConfirming else { return }
        guard let draft = viewModel.confirmCapture() else {
            confirmationError = "Your photo could not be saved."
            return
        }

        confirmationError = nil
        isConfirming = true
        Task {
            do {
                try await onConfirmed(draft)
                Haptics.postCompleted()
            } catch {
                confirmationError = "Your post could not be saved."
                isConfirming = false
            }
        }
    }
}

private struct CameraChoiceButtonStyle: ButtonStyle {
    let emphasized: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SGFont.body(16))
            .foregroundStyle(emphasized ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(emphasized ? Color.white : Color.white.opacity(0.16), in: Capsule())
            .overlay {
                if !emphasized {
                    Capsule().strokeBorder(.white.opacity(0.42), lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
