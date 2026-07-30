import SwiftUI

/// `nil` by default, deliberately — `SkyGridApp` must explicitly inject real
/// services once at the root (`.environment(\.appServices, ...)`). This sidesteps
/// `EnvironmentKey.defaultValue` needing to construct `@MainActor`-isolated services
/// in a non-isolated static context.
private struct AppServicesKey: EnvironmentKey {
    static let defaultValue: AppServices? = nil
}

extension EnvironmentValues {
    var appServices: AppServices? {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}
