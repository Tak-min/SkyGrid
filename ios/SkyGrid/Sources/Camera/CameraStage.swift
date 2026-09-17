import SwiftUI

/// Geometry shared by the real camera and its deterministic audit fixture. The
/// viewfinder is intentionally inset: a camera preview that reaches the screen
/// edges violates the owner-approved composition even if its contents still crop.
enum CameraStageLayout {
    static let horizontalInset: CGFloat = 20
    static let maximumViewfinderWidth: CGFloat = 430
    static let viewfinderHeightToWidth: CGFloat = 1.18
    static let maximumSafeHeightFraction: CGFloat = 0.54
    static let viewfinderCornerRadius: CGFloat = 32

    static func viewfinderSize(
        in container: CGSize,
        safeVerticalInsets: CGFloat
    ) -> CGSize {
        let width = max(
            0,
            min(maximumViewfinderWidth, container.width - horizontalInset * 2)
        )
        let safeHeight = max(0, container.height - safeVerticalInsets)
        let height = max(
            0,
            min(width * viewfinderHeightToWidth, safeHeight * maximumSafeHeightFraction)
        )
        return CGSize(width: width, height: height)
    }
}

/// The black physical stage around SkyGrid's camera window. Generic slots keep
/// live, review, and debug-audit surfaces on exactly the same geometry without
/// coupling this component to camera hardware or persistence.
struct CameraStage<Header: View, Viewfinder: View, Controls: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let viewfinder: () -> Viewfinder
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        GeometryReader { proxy in
            let viewfinderSize = CameraStageLayout.viewfinderSize(
                in: proxy.size,
                safeVerticalInsets: proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            )

            VStack(spacing: 0) {
                header()
                    .frame(height: 52)
                    .frame(maxWidth: CameraStageLayout.maximumViewfinderWidth)

                Spacer().frame(height: 12)

                viewfinder()
                    .frame(width: viewfinderSize.width, height: viewfinderSize.height)
                    .clipped()
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: CameraStageLayout.viewfinderCornerRadius,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: CameraStageLayout.viewfinderCornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }
                    .accessibilityIdentifier("camera.viewfinder")

                Spacer(minLength: 14)

                controls()
                    .frame(maxWidth: CameraStageLayout.maximumViewfinderWidth)
            }
            .padding(.horizontal, CameraStageLayout.horizontalInset)
            .padding(.top, max(proxy.safeAreaInsets.top, 8))
            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(CameraStageColor.background.ignoresSafeArea())
    }
}

/// Bottom camera controls preserve a truly centered shutter. Moku and the live
/// sky swatch balance the edges but remain smaller than the capture action.
struct CameraCaptureControls: View {
    let liveColor: SkyColor?
    let isCapturing: Bool
    let onCapture: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ShutterButton(
                    liveColor: liveColor,
                    isWorking: isCapturing,
                    action: onCapture
                )
                .accessibilityIdentifier("camera.shutter")

                HStack {
                    MokuView(state: isCapturing ? .bracing : .ready, side: 64)
                    Spacer()
                    liveSkySwatch
                }
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, minHeight: 90)

            Text("ONE SKY · THIS MORNING")
                .font(SGFont.caption(11))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var liveSkySwatch: some View {
        VStack(spacing: 5) {
            Circle()
                .fill(liveColor?.color ?? Color.white.opacity(0.34))
                .frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(.white.opacity(0.52), lineWidth: 1))
                .skyAnimation(SGMotion.exchange, value: liveColor?.hex)
            Text("LIVE")
                .font(SGFont.caption(9))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(width: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("Current sky color"))
    }
}

enum CameraStageColor {
    /// Capture remains a physical near-black viewfinder in both system appearances.
    static let background = Color(hex: "#080A0F")
}
