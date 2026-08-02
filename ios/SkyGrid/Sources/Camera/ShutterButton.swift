import SwiftUI

/// The shutter's fill IS the live-sampled sky color — the app's core idea made
/// tactile: you can see today's color before you even press the button.
struct ShutterButton: View {
    let liveColor: SkyColor?
    var isWorking = false
    let action: () -> Void

    private var displayColor: SkyColor {
        liveColor ?? SkyColor(uncheckedHex: "#C4C8CB")
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.64), lineWidth: 2)
                    .frame(width: 86, height: 86)
                Circle()
                    .fill(displayColor.ambientGradient)
                    .frame(width: 72, height: 72)
                    .skyAnimation(SGMotion.exchange, value: displayColor.hex)
                    .overlay {
                        if isWorking {
                            ProgressView().tint(displayColor.readableInk)
                        }
                    }
            }
            .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        }
        .buttonStyle(ShutterButtonStyle())
        .accessibilityLabel("Capture the sky")
        .disabled(isWorking)
    }
}

private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(SGMotion.press, value: configuration.isPressed)
    }
}
