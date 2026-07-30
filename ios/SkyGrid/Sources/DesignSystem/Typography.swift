import SwiftUI

/// Headlines use iOS's native serif ("New York" via the `ui-serif`/`.serif` design),
/// numbers use SF Pro with tabular figures. See `design/screens-mockup.html` — the
/// same two font stacks appear on every screen (`ui-serif, "New York", ...` for
/// headings; the default `-apple-system` stack for everything else).
enum SGFont {
    /// Large ritual headline (e.g. the year on the Sky Grid screen).
    static func serifTitle(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    /// The huge capture-time readout on the Today screen — ultralight, tabular.
    static func bigTime(_ size: CGFloat = 96) -> Font {
        .system(size: size, weight: .ultraLight, design: .default).monospacedDigit()
    }

    static func body(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    /// Small numeric readouts (day counts, minute offsets) — tabular figures so
    /// digits don't jitter in width as they change.
    static func numeric(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }
}
