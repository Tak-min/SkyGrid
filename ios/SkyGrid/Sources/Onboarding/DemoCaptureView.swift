import SwiftUI

/// A local-only rehearsal of the capture-to-mosaic reward. It deliberately never
/// opens the camera or reads a buddy: this moment teaches the gesture, not state.
struct DemoCaptureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasCaptured = false

    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                HStack {
                    onboardingBackButton(action: onBack)
                    Spacer()
                }
                .font(SGFont.caption(14))
                .foregroundStyle(SGT.ink2)

                OnboardingProgress(step: 13, total: OnboardingStep.allCases.count)

                VStack(alignment: .leading, spacing: SGSpacing.sm) {
                    Text(L10n.string("onboarding.demoCapture.headline"))
                        .font(SGFont.title(38))
                        .foregroundStyle(SGT.ink)
                    Text(L10n.string("onboarding.demoCapture.body"))
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink2)
                }

                mosaic
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SGSpacing.md)

                Button(action: capture) {
                    Label(
                        L10n.string(hasCaptured ? "onboarding.demoCapture.captured" : "onboarding.demoCapture.capture"),
                        systemImage: hasCaptured ? "checkmark" : "camera.fill"
                    )
                    .font(SGFont.body(17))
                    .foregroundStyle(SGT.accentInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 76)
                    .background(SGT.accent, in: RoundedRectangle(cornerRadius: SGSpacing.xl, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(hasCaptured)
                .opacity(hasCaptured ? 0.72 : 1)
                .accessibilityLabel(L10n.string("onboarding.demoCapture.capture.accessibilityLabel"))
                .accessibilityHint(L10n.string("onboarding.demoCapture.capture.accessibilityHint"))
                .accessibilityValue(hasCaptured ? L10n.string("onboarding.demoCapture.captured") : "")
                .accessibilityIdentifier("onboarding.demoCapture.capture")

                Spacer(minLength: SGSpacing.lg)
            }
            .padding(SGSpacing.xl)
            .padding(.bottom, SGSpacing.md)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasCaptured {
                onboardingContinueButton(action: onContinue)
                    .transition(.opacity)
            }
        }
    }

    private var mosaic: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: SGSpacing.xs), count: 3),
            spacing: SGSpacing.xs
        ) {
            ForEach(0..<9, id: \.self) { index in
                RoundedRectangle(cornerRadius: SGSpacing.md, style: .continuous)
                    .fill(tileFill(for: index))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if index == 4, !hasCaptured {
                            Image(systemName: "plus")
                                .font(SGFont.title(SGSpacing.xl))
                                .foregroundStyle(SGT.ink3)
                                .accessibilityHidden(true)
                        }
                    }
                    .scaleEffect(index == 4 && hasCaptured && !reduceMotion ? 1.04 : 1)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: 232)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("onboarding.demoCapture.mosaic.accessibilityLabel"))
        .accessibilityValue(hasCaptured ? L10n.string("onboarding.demoCapture.mosaic.capturedValue") : L10n.string("onboarding.demoCapture.mosaic.emptyValue"))
    }

    private func tileFill(for index: Int) -> AnyShapeStyle {
        if index == 4, hasCaptured {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [SGT.accentSecondary, SGT.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(index == 4 ? SGT.ghost : SGT.ghostFaint)
    }

    private func capture() {
        guard !hasCaptured else { return }
        Haptics.postCompleted()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : SGMotion.settle) {
            hasCaptured = true
        }
    }
}
