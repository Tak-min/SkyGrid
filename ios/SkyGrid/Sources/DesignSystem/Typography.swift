import SwiftUI
import UIKit

/// Interactive headlines use the system rounded family; body text uses system sans.
/// New York serif is reserved for fixed exported photo artifacts (DESIGN.md).
/// Numeric readouts use tabular figures.
enum SGFont {
    private static func scaled(
        _ size: CGFloat,
        relativeTo textStyle: UIFont.TextStyle,
        maximumScale: CGFloat? = nil
    ) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        if let maximumScale {
            return min(metrics.scaledValue(for: size), size * maximumScale)
        }
        return metrics.scaledValue(for: size)
    }

    /// Persistent interactive headline, scaled for Dynamic Type.
    static func title(_ size: CGFloat = 34) -> Font {
        .system(
            size: scaled(size, relativeTo: .title1, maximumScale: 1.55),
            weight: .bold,
            design: .rounded
        )
    }

    /// The huge capture-time readout on the Today screen — ultralight, tabular.
    static func bigTime(_ size: CGFloat = 96) -> Font {
        .system(
            size: scaled(size, relativeTo: .largeTitle, maximumScale: 1.3),
            weight: .ultraLight,
            design: .default
        )
        .monospacedDigit()
    }

    /// The heavy numeral used where a single number *is* the screen: the streak on
    /// Today and in the milestone moment. Distinct from `bigTime`, which is
    /// ultraLight because it always sits over a photo with a scrim behind it — the
    /// same hairline weight on a flat background reads as a font-loading failure.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(
            size: scaled(size, relativeTo: .largeTitle, maximumScale: 1.25),
            weight: weight,
            design: .default
        )
        .monospacedDigit()
    }

    /// `display` for the fixed-size export canvases, which must not scale with the
    /// exporting user's Dynamic Type setting — a share card is a fixed artifact.
    static func fixedDisplay(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }

    static func body(_ size: CGFloat = 17, maximumScale: CGFloat? = nil) -> Font {
        .system(size: scaled(size, relativeTo: .body, maximumScale: maximumScale), weight: .regular, design: .default)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: scaled(size, relativeTo: .caption1), weight: .medium, design: .default)
    }

    /// Small numeric readouts (day counts, minute offsets) — tabular figures so
    /// digits don't jitter in width as they change.
    static func numeric(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size, relativeTo: .body), weight: weight, design: .default).monospacedDigit()
    }

    /// Serif is only for fixed exported photo artifacts, never interactive UI.
    static func fixedSerifTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func fixedCaption(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    static func fixedNumeric(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }
}
