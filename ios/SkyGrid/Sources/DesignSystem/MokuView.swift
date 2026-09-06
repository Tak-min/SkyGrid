import SwiftUI

/// The truthful visual states Moku can represent. Success colors are deliberately
/// unavailable before `delight`: callers must not make a bracing or error pose look
/// like a completed capture.
enum MokuState: String, CaseIterable, Identifiable {
    case waiting
    case ready
    case bracing
    case delight
    case settled
    case error

    var id: Self { self }

    var mayUseCapturedSkyPalette: Bool {
        self == .delight || self == .settled
    }
}

struct MokuPixel: Hashable {
    let column: Int
    let row: Int
}

/// SkyGrid's original tile spirit, drawn entirely with native SwiftUI shapes.
///
/// Moku is decorative feedback, never a control or a source of product truth. The
/// caller supplies sampled sky colors only after a saved capture succeeds. Without
/// that palette, even a success pose falls back to Moku's neutral material rather
/// than inventing a sky.
struct MokuView: View {
    let state: MokuState
    let side: CGFloat
    let capturedSkyPalette: [Color]
    /// A user tap requests a playful jump without changing the capture state.
    var interaction: Int
    var leapsOnArrival: Bool
    var interactionFeedback: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var motionTrigger = 0
    @State private var isLeap = false
    @State private var hasEntered = false
    @State private var lastPlayedInteraction = 0

    init(
        state: MokuState,
        side: CGFloat = 112,
        capturedSkyPalette: [Color] = [],
        interaction: Int = 0,
        leapsOnArrival: Bool = false,
        interactionFeedback: Bool = true
    ) {
        self.state = state
        self.side = side
        self.capturedSkyPalette = capturedSkyPalette
        self.interaction = interaction
        self.leapsOnArrival = leapsOnArrival
        self.interactionFeedback = interactionFeedback
    }

    var body: some View {
        Group {
            if motionAllowed {
                Color.clear
                    .frame(width: side, height: side)
                    .keyframeAnimator(initialValue: MokuMotionValues(), trigger: motionTrigger) { _, motion in
                        artwork(motion: motion)
                    } keyframes: { _ in
                        // Anticipation → airborne stretch → contact squash → rest.
                        // Every track terminates; no ambient timer or whole-screen bob.
                        KeyframeTrack(\.lift) {
                            CubicKeyframe(0.035, duration: 0.16)
                            CubicKeyframe(isLeap ? -0.34 : -0.035, duration: 0.24)
                            CubicKeyframe(0.018, duration: 0.28)
                            SpringKeyframe(0, duration: 0.4, spring: .snappy)
                        }
                        KeyframeTrack(\.scaleX) {
                            CubicKeyframe(isLeap ? 1.13 : 1.015, duration: 0.16)
                            CubicKeyframe(isLeap ? 0.88 : 1, duration: 0.18)
                            CubicKeyframe(1, duration: 0.25)
                            CubicKeyframe(isLeap ? 1.16 : 1.015, duration: 0.09)
                            SpringKeyframe(1, duration: 0.4, spring: .snappy)
                        }
                        KeyframeTrack(\.scaleY) {
                            CubicKeyframe(isLeap ? 0.83 : 0.985, duration: 0.16)
                            CubicKeyframe(isLeap ? 1.16 : 1, duration: 0.18)
                            CubicKeyframe(1, duration: 0.25)
                            CubicKeyframe(isLeap ? 0.82 : 0.985, duration: 0.09)
                            SpringKeyframe(1, duration: 0.4, spring: .snappy)
                        }
                        KeyframeTrack(\.turn) {
                            CubicKeyframe(-5, duration: 0.16)
                            CubicKeyframe(isLeap ? 10 : 3, duration: 0.24)
                            CubicKeyframe(-3, duration: 0.28)
                            SpringKeyframe(0, duration: 0.4, spring: .snappy)
                        }
                        KeyframeTrack(\.wave) {
                            CubicKeyframe(-20, duration: 0.16)
                            CubicKeyframe(65, duration: 0.2)
                            CubicKeyframe(25, duration: 0.14)
                            CubicKeyframe(70, duration: 0.14)
                            CubicKeyframe(20, duration: 0.14)
                            CubicKeyframe(0, duration: 0.3)
                        }
                        KeyframeTrack(\.blink) {
                            LinearKeyframe(1, duration: 0.08)
                            LinearKeyframe(0.12, duration: 0.08)
                            LinearKeyframe(1, duration: 0.1)
                            LinearKeyframe(1, duration: 0.7)
                            LinearKeyframe(0.12, duration: 0.08)
                            LinearKeyframe(1, duration: 0.1)
                        }
                        KeyframeTrack(\.gaze) {
                            CubicKeyframe(-0.1, duration: 0.16)
                            CubicKeyframe(0.12, duration: 0.3)
                            CubicKeyframe(0, duration: 0.62)
                        }
                    }
            } else {
                artwork(motion: MokuMotionValues())
            }
        }
        .frame(width: side, height: side)
        .task(id: motionAllowed) {
            guard motionAllowed, !hasEntered else { return }
            hasEntered = true
            isLeap = state == .delight || leapsOnArrival
            motionTrigger += 1
        }
        .onChange(of: state) { _, newState in
            guard motionAllowed else { return }
            isLeap = newState == .delight
            motionTrigger += 1
        }
        .task(id: MokuInteractionTask(interaction: interaction, enabled: motionAllowed)) {
            guard interaction > lastPlayedInteraction else {
                lastPlayedInteraction = max(lastPlayedInteraction, interaction)
                return
            }
            lastPlayedInteraction = interaction
            // Reduce Motion removes the leap, not the acknowledgement. The screens
            // that own this still say "Tap Moku to say hello", so a tap that did
            // nothing at all was a dead control for exactly the people who cannot
            // see the animation answer. `Haptics` applies its own audit and
            // inactive-app suppression, so this stays silent where it must.
            if interactionFeedback { Haptics.characterTouched() }
            guard motionAllowed else { return }
            isLeap = true
            motionTrigger += 1
            do { try await Task.sleep(for: .milliseconds(680)) } catch { return }
            guard motionAllowed, !Task.isCancelled else { return }
            if interactionFeedback { Haptics.characterLanded() }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var motionAllowed: Bool {
        !reduceMotion && scenePhase == .active && MokuMotionPolicy.animationsEnabled
    }

    /// `nonisolated`: `keyframeAnimator`'s content closure is not main-actor
    /// isolated, and calling a main-actor method from it is an error under Swift 6.
    /// Everything read here is a `let` on this value type.
    nonisolated private func artwork(motion: MokuMotionValues) -> some View {
        ZStack {
            Ellipse()
                .fill(MokuColor.ink.opacity(0.12))
                .frame(width: side * 0.61, height: side * 0.075)
                .scaleEffect(x: max(0.48, 1 + motion.lift * 1.5), y: 1)
                .opacity(max(0.25, 1 + motion.lift * 2))
                .offset(y: side * 0.52)
            MokuArtwork(
                state: state,
                capturedSkyPalette: state.mayUseCapturedSkyPalette ? capturedSkyPalette : [],
                motion: motion
            )
            .frame(width: side, height: side)
            .scaleEffect(x: motion.scaleX * pose.scale, y: motion.scaleY * pose.scale, anchor: .bottom)
            .rotationEffect(.degrees(pose.rotationDegrees + motion.turn), anchor: .bottom)
            .offset(y: side * (pose.verticalOffset + motion.lift))
        }
        .frame(width: side, height: side)
    }

    /// Thirteen solid cells form a 4x4 cluster with one deliberately offset lower
    /// corner. Keeping the coordinates as data makes the silhouette deterministic
    /// in previews and independently testable without snapshot tooling.
    static let bodyPixels: [MokuPixel] = [
        MokuPixel(column: 1, row: 0),
        MokuPixel(column: 2, row: 0),
        MokuPixel(column: 0, row: 1),
        MokuPixel(column: 1, row: 1),
        MokuPixel(column: 2, row: 1),
        MokuPixel(column: 3, row: 1),
        MokuPixel(column: 0, row: 2),
        MokuPixel(column: 1, row: 2),
        MokuPixel(column: 2, row: 2),
        MokuPixel(column: 3, row: 2),
        MokuPixel(column: 0, row: 3),
        MokuPixel(column: 1, row: 3),
        MokuPixel(column: 2, row: 3),
    ]

    nonisolated private var pose: MokuPose {
        switch state {
        case .waiting:
            MokuPose(scale: 0.98, rotationDegrees: 0, verticalOffset: 0.01)
        case .ready:
            MokuPose(scale: 1, rotationDegrees: 0, verticalOffset: -0.01)
        case .bracing:
            MokuPose(scale: 0.9, rotationDegrees: 0, verticalOffset: 0.045)
        case .delight:
            MokuPose(scale: 1.08, rotationDegrees: -4, verticalOffset: -0.08)
        case .settled:
            MokuPose(scale: 1, rotationDegrees: 0, verticalOffset: 0)
        case .error:
            MokuPose(scale: 0.98, rotationDegrees: 3, verticalOffset: 0.01)
        }
    }
}

private struct MokuPose {
    let scale: CGFloat
    let rotationDegrees: Double
    let verticalOffset: CGFloat
}

private struct MokuArtwork: View {
    let state: MokuState
    let capturedSkyPalette: [Color]
    let motion: MokuMotionValues

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let cell = side * 0.177
            let gap = side * 0.011
            let bodySide = cell * 4 + gap * 3
            let origin = CGPoint(
                x: (size.width - bodySide) / 2,
                y: size.height * 0.13
            )

            drawLimbs(in: &context, canvasSide: side, origin: origin, cell: cell, gap: gap)

            for (index, pixel) in MokuView.bodyPixels.enumerated() {
                let rect = CGRect(
                    x: origin.x + CGFloat(pixel.column) * (cell + gap),
                    y: origin.y + CGFloat(pixel.row) * (cell + gap),
                    width: cell,
                    height: cell
                )
                let outer = Path(roundedRect: rect, cornerRadius: cell * 0.19)
                context.fill(outer, with: .color(MokuColor.nightStage.opacity(0.9)))

                let inset = rect.insetBy(dx: max(1, side * 0.008), dy: max(1, side * 0.008))
                let inner = Path(roundedRect: inset, cornerRadius: cell * 0.14)
                context.fill(inner, with: .color(bodyColor(at: index, pixel: pixel)))
            }

            drawEyes(in: &context, canvasSide: side, origin: origin, cell: cell, gap: gap)
        }
    }

    private func bodyColor(at index: Int, pixel: MokuPixel) -> Color {
        // Moku always retains one dawn pixel so the silhouette remains identifiable
        // before and after capture.
        if pixel == MokuPixel(column: 3, row: 1) {
            return MokuColor.dawnSpark
        }
        guard !capturedSkyPalette.isEmpty else { return MokuColor.cloud }
        return capturedSkyPalette[index % capturedSkyPalette.count]
    }

    private func drawEyes(
        in context: inout GraphicsContext,
        canvasSide: CGFloat,
        origin: CGPoint,
        cell: CGFloat,
        gap: CGFloat
    ) {
        let metrics = eyeMetrics
        let centers = [
            CGPoint(
                x: origin.x + cell * 1.5 + gap,
                y: origin.y + cell * 1.62 + gap
            ),
            CGPoint(
                x: origin.x + cell * 2.5 + gap * 2,
                y: origin.y + cell * 1.62 + gap
            ),
        ]

        for (index, center) in centers.enumerated() {
            let size = CGSize(
                width: cell * (index == 1 ? metrics.rightWidth : metrics.leftWidth),
                height: cell * (index == 1 ? metrics.rightHeight : metrics.leftHeight) * motion.blink
            )
            let yOffset = index == 1 ? metrics.rightVerticalOffset * cell : 0
            let rect = CGRect(
                x: center.x - size.width / 2 + cell * motion.gaze,
                y: center.y - size.height / 2 + yOffset,
                width: size.width,
                height: size.height
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: min(size.width, size.height) * 0.16),
                with: .color(MokuColor.ink)
            )
        }
    }

    private func drawLimbs(
        in context: inout GraphicsContext,
        canvasSide: CGFloat,
        origin: CGPoint,
        cell: CGFloat,
        gap: CGFloat
    ) {
        let bodyWidth = cell * 4 + gap * 3
        let armThickness = canvasSide * 0.055
        let short = canvasSide * 0.14
        let long = canvasSide * 0.2
        let bodyBottom = origin.y + cell * 4 + gap * 3
        let armY = origin.y + cell * limbPose.armRow

        let leftArm = CGRect(
            x: origin.x - limbPose.leftArmLength * canvasSide,
            y: armY,
            width: limbPose.leftArmLength * canvasSide,
            height: armThickness
        )
        let rightArm = CGRect(
            x: origin.x + bodyWidth,
            y: armY + limbPose.rightArmVerticalOffset * canvasSide,
            width: limbPose.rightArmLength * canvasSide,
            height: armThickness
        )
        let leftLeg = CGRect(
            x: origin.x + cell * 0.82,
            y: bodyBottom - canvasSide * limbPose.leftLegLift,
            width: armThickness,
            height: state == .delight ? short : long
        )
        let rightLeg = CGRect(
            x: origin.x + bodyWidth - cell * 1.18,
            y: bodyBottom - canvasSide * limbPose.rightLegLift,
            width: armThickness,
            height: state == .delight ? long : short
        )

        let joints: [(CGRect, CGPoint, Double)] = [
            (leftArm, CGPoint(x: leftArm.maxX, y: leftArm.midY), motion.wave * 0.55),
            (rightArm, CGPoint(x: rightArm.minX, y: rightArm.midY), -motion.wave),
            (leftLeg, CGPoint(x: leftLeg.midX, y: leftLeg.minY), -motion.wave * 0.28),
            (rightLeg, CGPoint(x: rightLeg.midX, y: rightLeg.minY), motion.wave * 0.32),
        ]
        for (rect, joint, angle) in joints where rect.width > 0 && rect.height > 0 {
            var limbContext = context
            limbContext.translateBy(x: joint.x, y: joint.y)
            limbContext.rotate(by: .degrees(angle))
            limbContext.translateBy(x: -joint.x, y: -joint.y)
            limbContext.fill(
                Path(roundedRect: rect, cornerRadius: armThickness * 0.18),
                with: .color(MokuColor.ink)
            )
        }
    }

    private var eyeMetrics: MokuEyeMetrics {
        switch state {
        case .waiting:
            MokuEyeMetrics(leftWidth: 0.25, leftHeight: 0.25, rightWidth: 0.25, rightHeight: 0.25)
        case .ready:
            MokuEyeMetrics(leftWidth: 0.32, leftHeight: 0.38, rightWidth: 0.32, rightHeight: 0.38)
        case .bracing:
            MokuEyeMetrics(leftWidth: 0.48, leftHeight: 0.13, rightWidth: 0.48, rightHeight: 0.13)
        case .delight:
            MokuEyeMetrics(leftWidth: 0.2, leftHeight: 0.48, rightWidth: 0.2, rightHeight: 0.48)
        case .settled:
            MokuEyeMetrics(leftWidth: 0.26, leftHeight: 0.22, rightWidth: 0.26, rightHeight: 0.22)
        case .error:
            MokuEyeMetrics(
                leftWidth: 0.34,
                leftHeight: 0.34,
                rightWidth: 0.18,
                rightHeight: 0.18,
                rightVerticalOffset: 0.08
            )
        }
    }

    private var limbPose: MokuLimbPose {
        switch state {
        case .waiting:
            MokuLimbPose(leftArmLength: 0.1, rightArmLength: 0.1, armRow: 2.15)
        case .ready:
            MokuLimbPose(leftArmLength: 0.08, rightArmLength: 0.2, armRow: 1.72)
        case .bracing:
            MokuLimbPose(leftArmLength: 0.045, rightArmLength: 0.045, armRow: 2.6)
        case .delight:
            MokuLimbPose(
                leftArmLength: 0.14,
                rightArmLength: 0.14,
                armRow: 0.8,
                leftLegLift: 0.06
            )
        case .settled:
            MokuLimbPose(leftArmLength: 0.08, rightArmLength: 0.08, armRow: 2.25)
        case .error:
            MokuLimbPose(
                leftArmLength: 0.16,
                rightArmLength: 0.16,
                armRow: 2,
                rightArmVerticalOffset: 0.06
            )
        }
    }
}

private struct MokuMotionValues {
    var lift: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var turn: Double = 0
    var wave: Double = 0
    var blink: CGFloat = 1
    var gaze: CGFloat = 0
}

private struct MokuInteractionTask: Equatable {
    let interaction: Int
    let enabled: Bool
}

/// Stills stay deterministic; a separate audit launch may opt into real motion.
/// Haptics are suppressed for both kinds of audit by their own central policy.
enum MokuMotionPolicy {
    static var animationsEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return !arguments.contains("-SkyGridUIAudit") || arguments.contains("-SkyGridUIAuditLiveMotion")
    }
}

private struct MokuEyeMetrics {
    let leftWidth: CGFloat
    let leftHeight: CGFloat
    let rightWidth: CGFloat
    let rightHeight: CGFloat
    var rightVerticalOffset: CGFloat = 0
}

private struct MokuLimbPose {
    let leftArmLength: CGFloat
    let rightArmLength: CGFloat
    let armRow: CGFloat
    var rightArmVerticalOffset: CGFloat = 0
    var leftLegLift: CGFloat = 0
    var rightLegLift: CGFloat = 0
}

/// Internal (not `private`) so `ConfettiView` can sample the same Dawn Spark/Cloud
/// tokens DESIGN.md's confetti rule names, rather than duplicating their hex values.
enum MokuColor {
    static let nightStage = Color(red: 8 / 255, green: 10 / 255, blue: 15 / 255)
    static let cloud = Color(red: 244 / 255, green: 241 / 255, blue: 234 / 255)
    static let ink = Color(red: 23 / 255, green: 24 / 255, blue: 27 / 255)
    static let dawnSpark = Color(red: 255 / 255, green: 104 / 255, blue: 70 / 255)
    static let morningPaper = Color(red: 255 / 255, green: 248 / 255, blue: 238 / 255)
}

#if DEBUG
/// A deterministic host for checking every truthful Moku state without wiring the
/// mascot into production navigation. The palette is explicitly synthetic fixture
/// data and does not imply that a real capture exists.
struct MokuPreviewGallery: View {
    private let fixtureSkyPalette: [Color] = [
        Color(red: 0.36, green: 0.7, blue: 0.91),
        Color(red: 0.86, green: 0.72, blue: 0.62),
        Color(red: 0.65, green: 0.84, blue: 0.94),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 16
            ) {
                ForEach(MokuState.allCases) { state in
                    VStack(spacing: 8) {
                        MokuView(
                            state: state,
                            side: 112,
                            capturedSkyPalette: fixtureSkyPalette
                        )
                        Text(state.rawValue)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(
                                state.mayUseCapturedSkyPalette ? MokuColor.ink : MokuColor.cloud
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: 152)
                    .background(
                        state.mayUseCapturedSkyPalette ? MokuColor.morningPaper : MokuColor.nightStage,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(MokuColor.ink.opacity(0.12), lineWidth: 1)
                    }
                }
            }
            .padding(20)
        }
        .background(MokuColor.morningPaper)
    }
}

#Preview("Moku — deterministic states") {
    MokuPreviewGallery()
}

#endif
