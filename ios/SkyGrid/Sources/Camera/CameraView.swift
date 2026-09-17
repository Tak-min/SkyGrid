import AVFoundation
import SwiftUI

/// Inset live viewfinder, one shutter button, and — after capture — exactly
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
    let requiresCaptureToDismiss: Bool
    let onDismiss: () -> Void
    let onEndRequiredCapture: () async -> Void
    let onConfirmed: (PostDraft) async throws -> Void

    init(
        viewModel: CameraViewModel,
        liveSession: AVCaptureSession,
        requiresCaptureToDismiss: Bool = false,
        onDismiss: @escaping () -> Void,
        onEndRequiredCapture: @escaping () async -> Void = {},
        onConfirmed: @escaping (PostDraft) async throws -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.liveSession = liveSession
        self.requiresCaptureToDismiss = requiresCaptureToDismiss
        self.onDismiss = onDismiss
        self.onEndRequiredCapture = onEndRequiredCapture
        self.onConfirmed = onConfirmed
    }

    var body: some View {
        ZStack {
            CameraStageColor.background.ignoresSafeArea()
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
        .onChange(of: viewModel.phase) { _, phase in
            guard case .failed(let failure) = phase,
                  failure != .permissionDenied
            else { return }
            SoundEffectPlayer.shared.play(.recoverableError)
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
        CameraStage {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SKY GRID")
                        .font(SGFont.caption(12))
                        .tracking(1.8)
                    Text(requiresCaptureToDismiss ? L10n.string("camera.photoMissionAllCaps") : L10n.string("THIS MORNING"))
                        .font(SGFont.caption(11))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .foregroundStyle(.white)
                Spacer()
                // The live screen's only Moku is the expressive one in
                // `CameraCaptureControls`, which reacts to `isCapturing`. A second
                // static mark here made the capture screen show two companions.
                if !requiresCaptureToDismiss { closeButton }
            }
        } viewfinder: {
            CameraPreviewView(session: liveSession)
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.12), .clear, .black.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        } controls: {
            CameraCaptureControls(
                liveColor: viewModel.liveSkyColor,
                isCapturing: isCapturing,
                onCapture: capture
            )
        }
    }

    private func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        Task {
            await viewModel.capture()
            isCapturing = false
        }
    }

    private func reviewScreen(image: UIImage) -> some View {
        CameraStage {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SKY GRID")
                        .font(SGFont.caption(12))
                        .tracking(1.8)
                    Text("CAPTURED")
                        .font(SGFont.caption(11))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .foregroundStyle(.white)
                Spacer()
                if !requiresCaptureToDismiss { closeButton }
            }
        } viewfinder: {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } controls: {
            VStack(spacing: SGSpacing.md) {
                Text("KEEP THIS SKY")
                    .font(SGFont.caption(12))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.72))

                CameraReviewActions(
                    isConfirming: isConfirming,
                    onRetake: viewModel.retake,
                    onUse: { confirm(image: image) }
                )

                if let confirmationError {
                    Text(confirmationError)
                        .font(SGFont.caption())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func failureScreen(failure: CameraViewModel.Failure) -> some View {
        CameraFailureContent(
            failure: failure,
            isRecovering: isRecovering,
            onPrimaryAction: { handleFailureAction(failure) },
            closeTitle: requiresCaptureToDismiss ? "End today's wake-up" : "Close camera",
            onClose: {
                guard requiresCaptureToDismiss else {
                    onDismiss()
                    return
                }
                Task {
                    await onEndRequiredCapture()
                    onDismiss()
                }
            }
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
            confirmationError = L10n.string("camera.confirmationError.saveFailed")
            SoundEffectPlayer.shared.play(.recoverableError)
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
                SoundEffectPlayer.shared.play(.recoverableError)
                isConfirming = false
            } catch {
                confirmationError = L10n.string("camera.confirmationError.postFailed")
                SoundEffectPlayer.shared.play(.recoverableError)
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
    var closeTitle = "Close camera"
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: SGSpacing.xxl) {
                    Spacer()
                        .frame(height: SGSpacing.lg)

                    MokuView(state: .error, side: 120)

                    VStack(spacing: SGSpacing.md) {
                        Text(failure.title)
                            .font(SGFont.display(48, weight: .black))
                            .tracking(-0.5)
                        Text(failure.message)
                            .font(SGFont.body(16))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    VStack(spacing: SGSpacing.md) {
                        Button(action: onPrimaryAction) {
                            Group {
                                if isRecovering {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(failure.actionTitle)
                                }
                            }
                            .font(SGFont.body(16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(SGT.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isRecovering)

                        Button(closeTitle, action: onClose)
                            .font(SGFont.body(15))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }

                    Spacer()
                        .frame(height: SGSpacing.lg)
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
    // Routed through `L10n.string(_:)`: `Text(failure.title/.message/.actionTitle)`
    // consumes these as stored `String` properties, not `Text("literal")` call
    // sites, so automatic String Catalog key matching does not apply here (see
    // `dev-notes/localization-en-ja-stage2_*.md`).
    var title: String {
        switch self {
        case .permissionDenied: return L10n.string("camera.failure.permissionDenied.title")
        case .startup: return L10n.string("camera.failure.startup.title")
        case .capture: return L10n.string("camera.failure.capture.title")
        case .colorDetection: return L10n.string("camera.failure.colorDetection.title")
        }
    }

    var message: String {
        switch self {
        case .permissionDenied:
            return L10n.string("camera.failure.permissionDenied.message")
        case .startup:
            return L10n.string("camera.failure.startup.message")
        case .capture:
            return L10n.string("camera.failure.capture.message")
        case .colorDetection:
            return L10n.string("camera.failure.colorDetection.message")
        }
    }

    var actionTitle: String {
        switch self {
        case .permissionDenied: return L10n.string("camera.failure.permissionDenied.action")
        case .startup: return L10n.string("camera.failure.startup.action")
        case .capture, .colorDetection: return L10n.string("camera.failure.backToCamera.action")
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
        CameraStage {
            CameraAuditHeader()
        } viewfinder: {
            if let photo = storePhoto {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
            LinearGradient(
                colors: [
                    Color(red: 0.34, green: 0.56, blue: 0.72),
                    Color(red: 0.76, green: 0.65, blue: 0.56),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            }
        } controls: {
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
        }
    }

    private var storePhoto: UIImage? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-SkyGridStorePhotoDirectory"),
              arguments.indices.contains(index + 1) else { return nil }
        let url = URL(fileURLWithPath: arguments[index + 1]).appendingPathComponent("real_sunset_sky.jpg")
        return UIImage(contentsOfFile: url.path)
    }
}

/// Simulator-only fixture for the approved live composition. It renders the real
/// stage, Moku, swatch, and shutter around a clearly synthetic sky field without
/// constructing camera hardware.
struct CameraLiveAuditView: View {
    private let fixtureColor = SkyColor(uncheckedHex: "#72BCE4")

    var body: some View {
        CameraStage {
            CameraAuditHeader()
        } viewfinder: {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.24, green: 0.58, blue: 0.83),
                        Color(red: 0.91, green: 0.67, blue: 0.5),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 86, height: 86)
                    .blur(radius: 12)
                    .offset(x: 92, y: -96)
            }
        } controls: {
            CameraCaptureControls(
                liveColor: fixtureColor,
                isCapturing: false,
                onCapture: {}
            )
        }
    }
}

private struct CameraAuditHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SKY GRID")
                    .font(SGFont.caption(12))
                    .tracking(1.8)
                Text("THIS MORNING")
                    .font(SGFont.caption(11))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .foregroundStyle(.white)
            Spacer()
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.1), in: Circle())
                .accessibilityLabel("Close camera")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SGFont.body(16))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(emphasized ? SGT.accent : Color.white.opacity(0.16), in: Capsule())
            .overlay {
                if !emphasized {
                    Capsule().strokeBorder(.white.opacity(0.42), lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
