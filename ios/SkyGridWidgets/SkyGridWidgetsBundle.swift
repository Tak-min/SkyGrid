import WidgetKit
import SwiftUI

/// This extension exists solely to host the morning-ritual Live Activity — it
/// ships no home-screen widget. `WidgetBundle` is still the required entry point
/// per Apple's Live-Activities-without-widgets pattern.
@main
struct SkyGridWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MorningRitualLiveActivity()
    }
}
