import Observation
import SwiftUI

/// The app's own appearance choice, independent of the device's system setting.
/// Mirrors `AppLanguage`/`LocalizationController`'s shape: a persisted raw value,
/// an inferred default, and a single `@Observable` controller that owns both the
/// in-memory state and the write-through to `LocalDefaults`.
enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case light
    case dark
    case system

    var id: String { rawValue }

    /// `nil` tells SwiftUI's `.preferredColorScheme(_:)` to defer to the system
    /// setting, which is exactly what `.system` means here.
    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    var displayName: String {
        switch self {
        case .light: L10n.string("settings.appearance.light")
        case .dark: L10n.string("settings.appearance.dark")
        case .system: L10n.string("settings.appearance.system")
        }
    }
}

@MainActor
@Observable
final class AppearanceController {
    private(set) var mode: AppAppearance

    init() {
        mode = LocalDefaults.selectedAppearanceMode.flatMap(AppAppearance.init(rawValue:)) ?? .system
    }

    func select(_ mode: AppAppearance) {
        guard self.mode != mode else { return }
        self.mode = mode
        LocalDefaults.selectedAppearanceMode = mode.rawValue
    }
}
