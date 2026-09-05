import SwiftUI

/// One bounded burst of square confetti, per DESIGN.md's daily reward motion
/// contract: "18-28 square confetti pieces mark the landing... emits from the
/// landing slot, falls once, and is removed. No endless emitters, fireworks, coins,
/// stars, or emoji particles."
///
/// Deterministic given a `seed`, so a UI-audit capture of the reward beat is
/// reproducible rather than a different random burst on every screenshot.
struct ConfettiView: View {
    let palette: [Color]
    let seed: UInt64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasLaunched = false

    private static let pieceCount = 24
    private static let pieceSide: CGFloat = 7

    var body: some View {
        // Reduce Motion never shows moving confetti — see `RewardOverlayView` for
        // the static-halo equivalent it presents instead. Guarding here too means
        // this view can never be misused as a moving-particle fallback.
        if reduceMotion {
            EmptyView()
        } else {
            GeometryReader { proxy in
                ZStack {
                    ForEach(pieces) { piece in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(piece.color)
                            .frame(width: Self.pieceSide, height: Self.pieceSide)
                            .rotationEffect(.degrees(hasLaunched ? piece.finalRotation : 0))
                            .offset(
                                x: hasLaunched ? piece.dx * proxy.size.width : 0,
                                y: hasLaunched ? piece.dy * proxy.size.height : 0
                            )
                            .opacity(hasLaunched ? 0 : 1)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                // Falls once, then the whole burst opacity-fades to nothing — there
                // is no repeating emitter to stop later.
                withAnimation(.easeOut(duration: 0.7)) {
                    hasLaunched = true
                }
            }
        }
    }

    private struct Piece: Identifiable {
        let id: Int
        let color: Color
        let dx: CGFloat
        let dy: CGFloat
        let finalRotation: Double
    }

    private var pieces: [Piece] {
        var generator = SeededGenerator(seed: seed)
        return (0..<Self.pieceCount).map { index in
            let angle = Double.random(in: 0..<(2 * .pi), using: &generator)
            let distance = CGFloat.random(in: 0.18...0.42, using: &generator)
            return Piece(
                id: index,
                color: palette[index % palette.count],
                dx: cos(angle) * distance,
                dy: abs(sin(angle)) * distance + 0.15,
                finalRotation: Double.random(in: -140...140, using: &generator)
            )
        }
    }
}

/// A tiny deterministic `RandomNumberGenerator` so a given `seed` always lays out
/// the same burst — no third-party dependency for something this small.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        // SplitMix64 — small, fast, and good enough for cosmetic layout, not
        // cryptography.
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
