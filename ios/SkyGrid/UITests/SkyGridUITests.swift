import XCTest

/// A credentials-free launch must fail transparently rather than falling back to
/// fabricated local users, photos, or purchases. End-to-end camera and backend
/// coverage belongs to a Firebase Emulator / physical-device test plan.
final class SkyGridUITests: XCTestCase {
    func testMissingFirebaseConfigurationIsExplained() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridForceFirebaseUnconfigured"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Sky Grid needs setup"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["Try again"].exists)
    }
}
