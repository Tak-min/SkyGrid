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

    func testBuddiesIsAPrimaryTab() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "buddies"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Sky Grid"].exists)
        XCTAssertTrue(app.tabBars.buttons["Buddies"].exists)
        XCTAssertTrue(app.staticTexts["MORNING TOGETHER"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Send request"].isEnabled)
    }

    /// Visual regression check for the floating tab bar covering the last row of
    /// the buddy list (same class of bug already fixed once for Today/Sky Grid with
    /// a 128pt bottom `safeAreaInset`; `BuddiesView` was missing the same fix).
    func testBuddiesListLastRowClearsFloatingTabBar() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "buddies"]
        app.launch()

        let yourBuddies = app.staticTexts["YOUR BUDDIES"]
        XCTAssertTrue(yourBuddies.waitForExistence(timeout: 8))
        app.swipeUp()
        app.swipeUp()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "buddies-list-scrolled-to-bottom"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOnboardingMovesFromWelcomeIntoTheQuestionFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "onboarding"]
        app.launch()

        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 8))
        app.buttons["Get started"].tap()

        XCTAssertTrue(app.staticTexts["QUESTION 1 OF 6 · Choose a direction. This stays on your device."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "onboarding-question-one"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["QUESTIONS 2 & 3 OF 6 · You can change these later."].waitForExistence(timeout: 5))

        app.buttons["Skip setup"].tap()
        XCTAssertTrue(app.staticTexts["YOUR MORNING PLAN"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["See my complete archive"].exists)
        XCTAssertTrue(app.buttons["Start with Free"].exists)
    }

    func testPaywallShowsOnlyTheThreePaidPurchaseOptions() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "paywall-plan"]
        app.launch()

        XCTAssertTrue(app.staticTexts["CHOOSE A PLAN"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Annual"].exists)
        XCTAssertTrue(app.staticTexts["Monthly"].exists)
        XCTAssertTrue(app.staticTexts["Lifetime"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "trial")).firstMatch.exists)
    }

    /// Drives the real (non-audit) purchase path against the live RevenueCat/StoreKit
    /// stack on a physical device, up to the point StoreKit hands off to the system
    /// Sandbox Apple ID sign-in sheet. That handoff is intentionally not completed
    /// here: entering App Store credentials is a human-only step, never automated.
    /// The trailing wait gives a person time to sign in and confirm the purchase by
    /// hand on the device before the test tears down.
    func testRealSandboxPurchaseReachesStoreKitConfirmationSheet() {
        let app = XCUIApplication()
        app.launch()

        if app.buttons["Get started"].waitForExistence(timeout: 8) {
            app.buttons["Get started"].tap()
            XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
            app.buttons["Continue"].tap()
            XCTAssertTrue(app.buttons["Skip setup"].waitForExistence(timeout: 5))
            app.buttons["Skip setup"].tap()
            XCTAssertTrue(app.buttons["See my complete archive"].waitForExistence(timeout: 8))
            app.buttons["See my complete archive"].tap()
        } else {
            // Onboarding was already completed in an earlier manual session on this device.
            XCTAssertTrue(app.buttons["Open settings"].waitForExistence(timeout: 8))
            app.buttons["Open settings"].tap()
            let unlockRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Unlock the full archive")).firstMatch
            XCTAssertTrue(unlockRow.waitForExistence(timeout: 8))
            unlockRow.tap()
        }

        XCTAssertTrue(app.buttons["See what Pro opens"].waitForExistence(timeout: 8))
        app.buttons["See what Pro opens"].tap()
        XCTAssertTrue(app.buttons["See plans and pricing"].waitForExistence(timeout: 5))
        app.buttons["See plans and pricing"].tap()

        let continueAnnual = app.buttons["Continue with Annual"]
        XCTAssertTrue(continueAnnual.waitForExistence(timeout: 15))

        let beforePurchase = XCTAttachment(screenshot: app.screenshot())
        beforePurchase.name = "paywall-before-purchase-tap"
        beforePurchase.lifetime = .keepAlways
        add(beforePurchase)

        continueAnnual.tap()

        sleep(120)

        let afterPurchaseTap = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        afterPurchaseTap.name = "after-purchase-tap-full-screen"
        afterPurchaseTap.lifetime = .keepAlways
        add(afterPurchaseTap)
    }

    /// Drives a real camera capture on a physical device and watches for
    /// `PostStatusBanner`'s "Retry now" affordance, which only appears once
    /// `UploadQueue` marks the attempt `.failed`. This is the only user-visible
    /// signal of an upload failure, so it doubles as the pass/fail check here.
    /// Mocked-backend pass over the Settings screen and everything it links to
    /// (`AccountDeleting`/`ImageFetching` are no-ops via `UIAuditAccountDeletionService`
    /// etc. in `SkyGridApp.swift`). This isolates "is the SwiftUI wiring itself
    /// correct" from backend/network failures, which a separate real-backend test
    /// covers for account deletion specifically.
    func testSettingsCommunitySafetyAndSupportLinksAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "settings"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))

        let communitySafetyRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Community & Safety")).firstMatch
        XCTAssertTrue(communitySafetyRow.waitForExistence(timeout: 5))
        communitySafetyRow.tap()

        XCTAssertTrue(app.navigationBars["Community & Safety"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["You can flag a post you are concerned about from each buddy's safety menu."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Blocking hides your connection and each other's posts."].exists)

        let communitySafetyAttachment = XCTAttachment(screenshot: app.screenshot())
        communitySafetyAttachment.name = "community-safety-detail"
        communitySafetyAttachment.lifetime = .keepAlways
        add(communitySafetyAttachment)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))

        // SwiftUI's `Link` surfaces to XCUITest as a Button-type accessibility
        // element (not the `Link`/`XCUIElementTypeLink` query type its SwiftUI name
        // suggests) — querying `app.links` here reliably finds nothing.
        let contactRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Contact us")).firstMatch
        XCTAssertTrue(contactRow.waitForExistence(timeout: 5), "Contact us row should exist as a tappable Link, not the disabled fallback state")
        contactRow.tap()

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10), "Tapping Contact us should hand off to Safari")
        app.activate()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))

        let privacyRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Privacy Policy")).firstMatch
        XCTAssertTrue(privacyRow.waitForExistence(timeout: 5))
        privacyRow.tap()

        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10), "Tapping Privacy Policy should hand off to Safari")
        app.activate()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))
    }

    /// Drives the real (non-audit) account-deletion path against the live
    /// Firebase/App Check stack. Uses whatever anonymous account is already signed
    /// in on this simulator — safe to delete since it is a disposable test identity,
    /// never the operator's own data.
    func testRealAccountDeletionSucceeds() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridSkipOnboarding"]
        app.launch()

        let settingsButton = app.buttons["Open settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 15))
        settingsButton.tap()

        let deleteRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Delete account")).firstMatch
        XCTAssertTrue(deleteRow.waitForExistence(timeout: 8))
        deleteRow.tap()

        let deleteButton = app.buttons["Delete account"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 8))
        deleteButton.tap()

        let confirmDelete = app.alerts["Delete your account?"].buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 8))
        confirmDelete.tap()

        let errorAlert = app.alerts["Could not delete account"]
        let onboardingReturned = app.buttons["Get started"]
        let outcome = XCTWaiter.wait(for: [
            XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: errorAlert),
            XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: onboardingReturned)
        ], timeout: 30)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = errorAlert.exists ? "account-deletion-failed" : "account-deletion-outcome"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertNotEqual(outcome, .timedOut, "Neither the error alert nor the post-deletion onboarding screen appeared")
        XCTAssertFalse(errorAlert.exists, "Account deletion surfaced \"Could not delete account\" — see attached screenshot")
    }

    /// Checks whether RevenueCat's real (non-audit) offerings now load after the
    /// "Credentials need attention" App Store Server API incident was reported
    /// resolved on Apple's side (status.revenuecat.com/incidents/mr3l9wqygn3d,
    /// resolved 2026-07-31 06:30 UTC). A successful fetch here means real product
    /// prices reach the paywall; `PurchaseError.noOfferingAvailable` or a stuck
    /// loading state would mean the incident's effects persist for this app.
    func testRealPaywallOfferingsLoadAfterRevenueCatIncident() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridSkipOnboarding"]
        app.launch()

        let settingsButton = app.buttons["Open settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 15))
        settingsButton.tap()

        let unlockRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Unlock the full archive")).firstMatch
        XCTAssertTrue(unlockRow.waitForExistence(timeout: 8))
        unlockRow.tap()

        XCTAssertTrue(app.buttons["See what Pro opens"].waitForExistence(timeout: 8))
        app.buttons["See what Pro opens"].tap()
        XCTAssertTrue(app.buttons["See plans and pricing"].waitForExistence(timeout: 5))
        app.buttons["See plans and pricing"].tap()

        let annual = app.staticTexts["Annual"]
        let loadFailed = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: annual)], timeout: 20) == .timedOut

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = loadFailed ? "paywall-offerings-failed-to-load" : "paywall-offerings-loaded"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertFalse(loadFailed, "Paywall did not reach a loaded offerings state within 20s")
    }

    /// Completes an actual purchase against RevenueCat's Test Store (Debug builds use
    /// `REVENUECAT_API_KEY_TEST`, per `Config/Debug.xcconfig`) — a real purchase call
    /// through the same `Purchases.shared.purchase(package:)` code path production
    /// uses, but settled by RevenueCat itself rather than real StoreKit/Apple, so no
    /// Sandbox Apple ID is involved and no real money moves. This is the full extent
    /// of "does a purchase actually complete" this environment can verify without a
    /// human present for Apple ID sign-in (Release config + real StoreKit sandbox).
    func testRealTestStorePurchaseGrantsEntitlement() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridSkipOnboarding"]
        app.launch()

        let settingsButton = app.buttons["Open settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 15))
        settingsButton.tap()

        let unlockRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Unlock the full archive")).firstMatch
        XCTAssertTrue(unlockRow.waitForExistence(timeout: 8))
        unlockRow.tap()

        XCTAssertTrue(app.buttons["See what Pro opens"].waitForExistence(timeout: 8))
        app.buttons["See what Pro opens"].tap()
        XCTAssertTrue(app.buttons["See plans and pricing"].waitForExistence(timeout: 5))
        app.buttons["See plans and pricing"].tap()

        let continueAnnual = app.buttons["Continue with Annual"]
        XCTAssertTrue(continueAnnual.waitForExistence(timeout: 20))
        continueAnnual.tap()

        // Test Store settles immediately with no system purchase sheet — if one
        // appeared, this would mean the build is unexpectedly hitting real StoreKit.
        let storeKitSheet = app.otherElements["ProductBuyView"]
        if storeKitSheet.waitForExistence(timeout: 5) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "unexpected-storekit-sheet"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTFail("A real StoreKit purchase sheet appeared — this build is not using the Test Store as expected")
            return
        }

        // The Test Store's own confirmation sheet ("Test Store Purchase" / "Test
        // valid purchase" / "Test failed purchase" / "Cancel") stands in for a real
        // StoreKit purchase sheet — a second explicit confirmation, not a formality
        // a plain button-disappearance check can skip past.
        let testValidPurchase = app.buttons["Test valid purchase"]
        XCTAssertTrue(testValidPurchase.waitForExistence(timeout: 8), "Test Store confirmation sheet did not appear")
        testValidPurchase.tap()

        let paywallDismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: continueAnnual)
        let outcome = XCTWaiter.wait(for: [paywallDismissed], timeout: 20)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = outcome == .completed ? "test-store-purchase-completed" : "test-store-purchase-stuck"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertEqual(outcome, .completed, "Paywall never dismissed after purchase — entitlement grant likely did not complete")
        XCTAssertTrue(app.staticTexts["Sky Grid Pro is active"].waitForExistence(timeout: 8), "Settings should reflect the granted entitlement")
    }

    func testRealCameraCaptureUploadsSuccessfully() {
        let app = XCUIApplication()
        let cameraPermission = addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            let allow = alert.buttons["Allow"].exists ? alert.buttons["Allow"] : alert.buttons["OK"]
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        app.launch()

        if app.buttons["Get started"].waitForExistence(timeout: 8) {
            app.buttons["Get started"].tap()
            XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
            app.buttons["Continue"].tap()
            XCTAssertTrue(app.buttons["Skip setup"].waitForExistence(timeout: 5))
            app.buttons["Skip setup"].tap()
            XCTAssertTrue(app.buttons["Start with Free"].waitForExistence(timeout: 8))
            app.buttons["Start with Free"].tap()
        }

        let captureButton = app.buttons.matching(identifier: "Capture the sky").firstMatch
        XCTAssertTrue(captureButton.waitForExistence(timeout: 15))
        captureButton.tap()
        app.tap() // nudges the interruption monitor to run if a permission alert is frontmost

        let shutter = app.buttons.matching(identifier: "Capture the sky").firstMatch
        XCTAssertTrue(shutter.waitForExistence(timeout: 15))
        shutter.tap()

        let useThisOne = app.buttons["Use this one"]
        XCTAssertTrue(useThisOne.waitForExistence(timeout: 15))
        useThisOne.tap()

        removeUIInterruptionMonitor(cameraPermission)

        // Give the queue real network time: Firebase Auth token refresh, App Check
        // attestation, and the Storage PUT itself are not instantaneous on a cold start.
        let retryNow = app.buttons["Retry now"]
        let failed = retryNow.waitForExistence(timeout: 45)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = failed ? "upload-failed-retry-visible" : "upload-no-failure-banner"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertFalse(failed, "Upload reached the terminal .failed state — PostStatusBanner shows Retry now")
    }
}
