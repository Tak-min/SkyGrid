import AVFoundation
import SwiftUI

/// Full-screen live viewfinder, one shutter button, and — after capture — exactly
/// two choices ("retake" / "use this"). No gallery picker, no filters, nothing else.
/// Goal: wake-to-posted in ~5 seconds (VISION.md §6).
struct CameraView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: CameraViewModel
    @State private var isConfirming = false
    @State private var isCapturing = false
    @State private var isRecovering = false
    @State private var confirmationError: String?
    private let liveSession: AVCaptureSession
    let onDismiss: () -> Void
    let onConfirmed: (PostDraft) async throws -> Void

    init(
        viewModel: CameraViewModel,
        liveSession: AVCaptureSession,
        onDismiss: @escaping () -> Void,
        onConfirmed: @escaping (PostDraft) async throws -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.liveSession = liveSession
        self.onDismiss = onDismiss
        self.onConfirmed = onConfirmed
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
                .skyAnimation(SGMotion.exchange, value: viewModel.phase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await viewModel.start()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active,
                  case .failed(.permissionDenied) = viewModel.phase
            else { return }
            recoverCamera()
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
                .transition(.opacity)
        case .reviewing(let image, _):
            reviewScreen(image: image)
                .transition(.opacity)
        case .failed(let failure):
            failureScreen(failure: failure)
                .transition(.opacity)
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
                        .skyAnimation(SGMotion.exchange, value: viewModel.liveSkyColor?.hex)
                        .accessibilityLabel("Current sky color")
                    closeButton
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

                CameraReviewActions(
                    isConfirming: isConfirming,
                    onRetake: viewModel.retake,
                    onUse: { confirm(image: image) }
                )
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

            VStack {
                HStack {
                    Spacer()
                    closeButton
                }
                Spacer()
            }
            .padding(.horizontal, SGSpacing.lg)
            .padding(.top, SGSpacing.sm)
        }
    }

    private func failureScreen(failure: CameraViewModel.Failure) -> some View {
        CameraFailureContent(
            failure: failure,
            isRecovering: isRecovering,
            onPrimaryAction: { handleFailureAction(failure) },
            onClose: onDismiss
        )
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.28), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
        }
        .foregroundStyle(.white)
        .accessibilityLabel("Close camera")
        .disabled(isCapturing || isConfirming)
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
            } catch RepositoryError.alreadyPostedToday {
                // A permanent rejection, not a transient one — Firestore's
                // create-only rule means retrying this same draft can never
                // succeed. Say so plainly instead of the generic message, which
                // read as "try again" when trying again cannot help.
                confirmationError = "You've already recorded today's sky."
                isConfirming = false
            } catch {
                confirmationError = "Your post could not be saved."
                isConfirming = false
            }
        }
    }

    private func handleFailureAction(_ failure: CameraViewModel.Failure) {
        if failure == .permissionDenied {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(settingsURL)
        } else {
            recoverCamera()
        }
    }

    private func recoverCamera() {
        guard !isRecovering else { return }
        isRecovering = true
        Task {
            await viewModel.retry()
            isRecovering = false
        }
    }
}

struct CameraFailureContent: View {
    let failure: CameraViewModel.Failure
    let isRecovering: Bool
    let onPrimaryAction: () -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: SGSpacing.xl) {
                    Image(systemName: failure.symbol)
                        .font(.system(size: 38, weight: .light))
                        .frame(width: 82, height: 82)
                        .background(.white.opacity(0.1), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))

                    VStack(spacing: SGSpacing.sm) {
                        Text(failure.title)
                            .font(SGFont.serifTitle(30))
                        Text(failure.message)
                            .font(SGFont.body(15))
                            .foregroundStyle(.white.opacity(0.74))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: SGSpacing.sm) {
                        Button(action: onPrimaryAction) {
                            Group {
                                if isRecovering {
                                    ProgressView().tint(.black)
                                } else {
                                    Text(failure.actionTitle)
                                }
                            }
                            .font(SGFont.body(16))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isRecovering)

                        Button("Close camera", action: onClose)
                            .font(SGFont.body(15))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 340)
                .padding(.horizontal, SGSpacing.xl)
                .padding(.vertical, SGSpacing.xl)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private extension CameraViewModel.Failure {
    var title: String {
        switch self {
        case .permissionDenied: return "Camera access is off"
        case .startup: return "Camera unavailable"
        case .capture: return "That photo didn't work"
        case .colorDetection: return "We couldn't read the sky"
        }
    }

    var message: String {
        switch self {
        case .permissionDenied:
            return "Allow camera access in Settings to capture your morning sky."
        case .startup:
            return "The camera couldn't get ready. Give it another moment and try again."
        case .capture:
            return "Nothing was saved. Return to the viewfinder and take another photo."
        case .colorDetection:
            return "Try another angle with a little more open sky in the frame."
        }
    }

    var actionTitle: String {
        switch self {
        case .permissionDenied: return "Open Settings"
        case .startup: return "Try camera again"
        case .capture, .colorDetection: return "Back to camera"
        }
    }

    var symbol: String {
        switch self {
        case .permissionDenied: return "camera.badge.ellipsis"
        case .startup: return "camera.aperture"
        case .capture: return "exclamationmark.camera"
        case .colorDetection: return "sun.haze"
        }
    }
}

/// Keeps the two review actions within the review screen's real layout bounds.
///
/// This intentionally uses one action per row. `ViewThatFits` cannot make a
/// reliable horizontal decision here because the review `ZStack` can first
/// propose an unconstrained width and only constrain its child afterwards. That
/// made the two 156pt controls overflow on some camera presentations. A vertical
/// layout has a single, finite width at every Dynamic Type size, while the cap
/// keeps the choices from becoming edge-to-edge pills on larger phones.
struct CameraReviewActions: View {
    private static let maximumWidth: CGFloat = 340

    let isConfirming: Bool
    let onRetake: () -> Void
    let onUse: () -> Void

    var body: some View {
        VStack(spacing: SGSpacing.sm) {
            retakeButton
            useButton
        }
        .frame(maxWidth: Self.maximumWidth)
        .frame(maxWidth: .infinity)
    }

    private var retakeButton: some View {
        Button("Retake", action: onRetake)
            .buttonStyle(CameraChoiceButtonStyle(emphasized: false))
            .disabled(isConfirming)
    }

    private var useButton: some View {
        Button(action: onUse) {
            if isConfirming {
                ProgressView().tint(.black)
            } else {
                Text("Use this one")
            }
        }
        .buttonStyle(CameraChoiceButtonStyle(emphasized: true))
        .disabled(isConfirming)
    }
}

#if DEBUG
/// Credentials-free simulator target for the photo-review layout. It exercises the
/// exact adaptive action component used by CameraView without requiring camera
/// hardware or writing an image to Firebase.
struct CameraReviewAuditView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.34, green: 0.56, blue: 0.72), Color(red: 0.06, green: 0.10, blue: 0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: SGSpacing.md) {
                Text("KEEP THIS SKY")
                    .font(SGFont.caption(13))
                    .foregroundStyle(.white.opacity(0.82))
                CameraReviewActions(
                    isConfirming: false,
                    onRetake: {},
                    onUse: {}
                )
            }
            .padding(.horizontal, SGSpacing.xl)
            .padding(.bottom, 42)
        }
    }
}

/// Simulator-only rendering target for the permission-recovery experience. The
/// button actions stay inert so UI tests never leave the app or change Settings.
struct CameraFailureAuditView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.09, blue: 0.14), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            CameraFailureContent(
                failure: .permissionDenied,
                isRecovering: false,
                onPrimaryAction: {},
                onClose: {}
            )
        }
    }
}
#endif

private struct CameraChoiceButtonStyle: ButtonStyle {
    let emphasized: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SGFont.body(16))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(emphasized ? Color.black : Color.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(emphasized ? Color.white : Color.white.opacity(0.16), in: Capsule())
            .overlay {
                if !emphasized {
                    Capsule().strokeBorder(.white.opacity(0.42), lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
