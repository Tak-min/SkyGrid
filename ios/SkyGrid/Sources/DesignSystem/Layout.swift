import SwiftUI

/// A small spacing scale keeps the quiet layouts deliberate as new screens land.
enum SGSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum SGMotion {
    /// A value arriving into place (a mark filling a slot, a card settling in).
    static let settle = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// Touch-down feedback on a control.
    static let press = Animation.spring(response: 0.24, dampingFraction: 0.7)
    /// One state replacing another, including digit roll-overs — a spring here
    /// overshoots and reads as unstable.
    static let exchange = Animation.easeInOut(duration: 0.26)
    /// An ambient, non-interactive colour change (light in a room shifting).
    static let drift = Animation.easeInOut(duration: 0.6)
}
