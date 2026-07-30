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
                    .overlay {
                        if isWorking {
                            ProgressView().tint(displayColor.readableInk)
                        }
                    }
            }
            .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        }
        .accessibilityLabel("Capture the sky")
        .disabled(isWorking)
    }
}
