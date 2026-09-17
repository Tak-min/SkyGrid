import Foundation
import SwiftUI
import Testing
@testable import SkyGrid

@Suite("App appearance")
@MainActor
struct AppearanceControllerTests {
    init() {
        LocalDefaults.selectedAppearanceMode = nil
    }

    @Test("maps each mode to the SwiftUI color scheme it should force, or nil for system")
    func colorSchemeMapping() {
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
        #expect(AppAppearance.system.colorScheme == nil)
    }

    @Test("defaults to system when no explicit choice has ever been made")
    func defaultsToSystem() {
        let controller = AppearanceController()
        #expect(controller.mode == .system)
    }

    @Test("selecting a mode persists it and a new controller picks it back up")
    func selectionPersistsAcrossInstances() {
        let controller = AppearanceController()
        controller.select(.dark)
        #expect(controller.mode == .dark)
        #expect(LocalDefaults.selectedAppearanceMode == "dark")

        let reloaded = AppearanceController()
        #expect(reloaded.mode == .dark)
    }

    @Test("selecting every mode round-trips through persistence", arguments: AppAppearance.allCases)
    func everyModeRoundTrips(mode: AppAppearance) {
        let controller = AppearanceController()
        controller.select(mode)
        #expect(AppearanceController().mode == mode)
    }
}
