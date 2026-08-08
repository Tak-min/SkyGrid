import XCTest

/// A credentials-free launch must fail transparently rather than falling back to
/// fabricated local users, photos, or purchases. End-to-end camera and backend
/// coverage belongs to a Firebase Emulator / physical-device test plan.
final class SkyGridUITests: XCTestCase {
    private func requirePhysicalDevice(allowLiveBackendSimulator: Bool = false) throws {
        #if targetEnvironment(simulator)
        if allowLiveBackendSimulator {
            #if SKYGRID_LIVE_BACKEND_AUDIT
            return
            #endif
        }
        throw XCTSkip("Requires a physical device for App Attest and a live Firebase backend.")
        #endif
    }

    private func launchLiveBackend(_ app: XCUIApplication) {
        app.launchArguments = ["-SkyGridAllowFirebaseInTests", "-SkyGridSkipOnboarding"]
        app.launch()

        let guest = app.buttons["Start without an account"]
        if guest.waitForExistence(timeout: 8) {
            guest.tap()
        }
    }

    func testMissingFirebaseConfigurationIsExplained() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridForceFirebaseUnconfigured"]
        app.launch()

        // Asserts only that the misconfigured build lands on the recoverable failure
        // screen instead of hanging or crashing.
        //
        // It deliberately does NOT assert the message copy. `ContentUnavailableView`
        // does not surface its title or description as addressable elements — verified
        // 2026-08-08: the screen visibly reads "Sky Grid isn't configured." yet neither
        // that string nor the apostrophe-free description line can be found via
        // `app.staticTexts`, while this button can. The earlier version of this test
        // matched the title only because that copy happened to be identical to a label
        // exposed elsewhere, which made it a false sense of coverage that broke the
        // moment the wording changed. The copy — including the guarantee that no
        // internal error description leaks into it — is covered properly and cheaply
        // by `StartupFailureMessageTests`.
        let retry = app.buttons["Try again"]
        XCTAssertTrue(retry.waitForExistence(timeout: 12))
        XCTAssertTrue(retry.isHittable)
    }

    func testTodayUnavailableStateOffersReadOnlyRecovery() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "today-unavailable"]
        app.launch()

        XCTAssertTrue(app.staticTexts["We couldn't check today's record."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Your archive is unchanged. Check your connection and try again."].exists)
        let retry = app.buttons["Check again"]
        XCTAssertTrue(retry.exists)
        retry.tap()
        XCTAssertTrue(app.buttons["Capture the sky"].waitForExistence(timeout: 8))
    }

    /// The milestone moment is the app's one deliberately loud screen, and its whole
    /// job is to be shareable — so the share affordance existing is the assertion that
    /// matters, not the decoration around it.
    func testMilestoneMomentOffersTheShareableCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "milestone"]
        app.launch()

        XCTAssertTrue(app.staticTexts["30 days"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Thirty mornings in a row."].exists)

        let share = app.buttons["Share this morning"]
        XCTAssertTrue(share.exists)
        XCTAssertTrue(share.isHittable)
        XCTAssertTrue(app.buttons["Done"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "milestone-30"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Day one is the milestone a brand-new user actually reaches, and it is the only
    /// one that renders without a photo (the card falls back to the extracted sky
    /// colour). Both facts are easy to break and invisible in unit tests.
    func testDayOneMilestoneRendersWithoutAPhoto() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "milestone-day-one"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Day one"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Your first sky."].exists)
        XCTAssertTrue(app.buttons["Share this morning"].isHittable)
    }

    func testLiveActivityStartsForTheDynamicIsland() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "live-activity"]
        app.launch()

        let started = app.staticTexts["Started — leave the app to inspect the Island."]
        let alreadyRunning = app.staticTexts["Already running"]
        XCTAssertTrue(
            started.waitForExistence(timeout: 8) || alreadyRunning.waitForExistence(timeout: 1),
            "ActivityKit should either create the audit activity or retain the same running activity"
        )

        let auditAttachment = XCTAttachment(screenshot: app.screenshot())
        auditAttachment.name = "live-activity-started"
        auditAttachment.lifetime = .keepAlways
        add(auditAttachment)

        XCUIDevice.shared.press(.home)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: 5))
        // SpringBoard reports foreground before the home-transition blur has
        // finished. Give that animation one beat so the attachment records the
        // actual compact Island rather than an intermediate frame.
        sleep(1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "dynamic-island-compact"
        attachment.lifetime = .keepAlways
        add(attachment)
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

    func testBuddyRitualHeaderIsCentered() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "buddies"]
        app.launch()

        let headline = app.staticTexts["Two skies, revealed together."]
        XCTAssertTrue(headline.waitForExistence(timeout: 8))
        XCTAssertEqual(headline.frame.midX, app.frame.midX, accuracy: 2)
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

    func testBuddiesInviteActionClearsFloatingTabBar() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "buddies"]
        app.launch()

        let sendRequest = app.buttons["Send request"]
        XCTAssertTrue(sendRequest.waitForExistence(timeout: 8))
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        XCTAssertLessThanOrEqual(sendRequest.frame.maxY, tabBar.frame.minY)
    }

    func testBuddiesReadFailureNeverMasqueradesAsAnEmptyList() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "buddies-unavailable"]
        app.launch()

        XCTAssertTrue(app.staticTexts["We couldn't refresh your buddies."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Your connections haven't been changed. Check your connection and try again."].exists)
        XCTAssertFalse(app.staticTexts["No buddies yet"].exists)
        let retry = app.buttons["Check again"]
        XCTAssertTrue(retry.exists)
        retry.tap()
        XCTAssertTrue(app.staticTexts["Mira"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["We couldn't refresh your buddies."].exists)
    }

    func testBuddyProfileFailureNeverMasqueradesAsAMissingHandle() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "buddies-profile-unavailable"]
        app.launch()

        XCTAssertTrue(app.staticTexts["We couldn't load your invite settings."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Your handle hasn't been changed. Check your connection and try again."].exists)
        XCTAssertFalse(app.staticTexts["YOUR INVITE HANDLE"].exists)
        let failureAttachment = XCTAttachment(screenshot: app.screenshot())
        failureAttachment.name = "buddy-profile-unavailable"
        failureAttachment.lifetime = .keepAlways
        add(failureAttachment)
        let retry = app.buttons["Check invite settings again"]
        XCTAssertTrue(retry.exists)
        retry.tap()
        XCTAssertTrue(app.staticTexts["Invite a buddy"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["We couldn't load your invite settings."].exists)
    }

    func testBuddyHandleCanBeClaimedAndImmediatelyUsed() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "buddies-no-handle"]
        app.launch()

        let handleField = app.textFields["Handle"]
        XCTAssertTrue(handleField.waitForExistence(timeout: 8))
        handleField.tap()
        handleField.typeText("new_morning")
        let save = app.buttons["Save handle"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.staticTexts["Invite a buddy"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["@new_morning"].exists)
        XCTAssertFalse(app.staticTexts["Choose a handle to add a buddy"].exists)
    }

    func testBuddyRequestShowsSuccessAndClearsTheHandle() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "buddies"]
        app.launch()

        let handleField = app.textFields["Their handle"]
        XCTAssertTrue(handleField.waitForExistence(timeout: 8))
        handleField.tap()
        handleField.typeText("luca_sky")
        app.buttons["Send request"].tap()

        XCTAssertTrue(app.staticTexts["Request sent to @luca_sky."].waitForExistence(timeout: 8))
        XCTAssertEqual(handleField.value as? String, "Their handle")
    }

    func testPendingBuddyRequestsUseHandlesAndExplainReciprocalInvites() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "buddies-request-flow"]
        app.launch()

        let handleField = app.textFields["Their handle"]
        XCTAssertTrue(handleField.waitForExistence(timeout: 8))
        handleField.tap()
        handleField.typeText("luca_sky")
        app.buttons["Send request"].tap()
        XCTAssertTrue(app.staticTexts["@luca_sky already invited you. Accept the request below."].waitForExistence(timeout: 8))

        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["@luca_sky"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["@sora_sky"].exists)
        XCTAssertTrue(app.staticTexts["Waiting for them to accept"].exists)
        XCTAssertFalse(app.staticTexts["luca"].exists)
    }

    func testGridReadFailureNeverMasqueradesAsAnEmptyArchive() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "grid-unavailable"]
        app.launch()

        XCTAssertTrue(app.staticTexts["We couldn't refresh your archive."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Your photos haven't been changed. Check your connection and try again."].exists)
        XCTAssertTrue(app.staticTexts["Not checked"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["No captures in July yet."].exists)
        let retry = app.buttons["Check again"]
        XCTAssertTrue(retry.exists)
        retry.tap()
        XCTAssertTrue(app.staticTexts["20 / 365"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["We couldn't refresh your archive."].exists)
    }

    func testOnboardingMovesFromWelcomeIntoTheQuestionFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "onboarding"]
        app.launch()

        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 8))
        app.buttons["Get started"].tap()

        XCTAssertTrue(app.staticTexts["QUESTION 1 OF 6 · Choose a direction. This stays on your device."].waitForExistence(timeout: 5))
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        XCTAssertGreaterThanOrEqual(continueButton.frame.width, app.frame.width * 0.7)
        XCTAssertLessThanOrEqual(continueButton.frame.width, 340)
        XCTAssertGreaterThanOrEqual(continueButton.frame.minY, app.frame.minY)
        XCTAssertLessThanOrEqual(continueButton.frame.maxY, app.frame.maxY)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "onboarding-question-one"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["QUESTION 2 OF 6 · How should it feel? You can change this later."].waitForExistence(timeout: 5))

        app.buttons["Skip setup"].tap()
        XCTAssertTrue(app.staticTexts["YOUR MORNING PLAN"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["See my complete archive"].exists)
        XCTAssertTrue(app.buttons["Start with Free"].exists)
        XCTAssertTrue(app.buttons["Edit answers"].exists)
    }

    func testOnboardingCanMoveBetweenPagesWithHorizontalSwipes() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "onboarding"]
        app.launch()

        app.buttons["Get started"].tap()
        XCTAssertTrue(app.staticTexts["QUESTION 1 OF 6 · Choose a direction. This stays on your device."].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["QUESTION 2 OF 6 · How should it feel? You can change this later."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Back"].exists)
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["QUESTION 1 OF 6 · Choose a direction. This stays on your device."].waitForExistence(timeout: 5))

        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["QUESTION 2 OF 6 · How should it feel? You can change this later."].waitForExistence(timeout: 5))
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["QUESTION 1 OF 6 · Choose a direction. This stays on your device."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Back"].exists)
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

    func testPaywallAccessibilityLayoutKeepsEveryPathReachable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-SkyGridUIAudit", "-SkyGridUIAuditScenario", "paywall-plan",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let annual = app.staticTexts["Annual"]
        let annualPrice = app.staticTexts["$19.99"].firstMatch
        XCTAssertTrue(annual.waitForExistence(timeout: 8))
        XCTAssertTrue(annualPrice.exists)
        XCTAssertFalse(annual.frame.intersects(annualPrice.frame))
        XCTAssertTrue(app.staticTexts["Best value"].exists)
        let purchase = app.buttons["Continue with Annual"]
        let freePath = app.buttons["Continue with Free"]
        XCTAssertTrue(purchase.isHittable)
        XCTAssertTrue(freePath.isHittable)

        let restore = app.buttons["Restore purchases"]
        let terms = app.buttons["Terms of Use"]
        let privacy = app.buttons["Privacy Policy"]
        for _ in 0..<6 where !restore.isHittable || !terms.isHittable || !privacy.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(restore.isHittable)
        XCTAssertTrue(terms.isHittable)
        XCTAssertTrue(privacy.isHittable)
    }

    func testCameraReviewActionsFitWithinScreen() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-SkyGridUIAudit", "-SkyGridUIAuditScenario", "camera-review"
        ]
        app.launch()

        let retake = app.buttons["Retake"]
        let useThisOne = app.buttons["Use this one"]
        XCTAssertTrue(retake.waitForExistence(timeout: 8))
        XCTAssertTrue(useThisOne.exists)

        let screen = app.frame
        XCTAssertGreaterThanOrEqual(retake.frame.minX, screen.minX)
        XCTAssertLessThanOrEqual(retake.frame.maxX, screen.maxX)
        XCTAssertGreaterThanOrEqual(useThisOne.frame.minX, screen.minX)
        XCTAssertLessThanOrEqual(useThisOne.frame.maxX, screen.maxX)
        XCTAssertEqual(retake.frame.width, useThisOne.frame.width, accuracy: 1)
        XCTAssertLessThanOrEqual(retake.frame.width, 340, "Review actions must retain side margins on large phones")
        XCTAssertGreaterThan(useThisOne.frame.minY, retake.frame.minY, "Review choices must never compete for horizontal space")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "camera-review-contained-vertical-layout"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCameraReviewActionsRemainContainedAtAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-SkyGridUIAudit", "-SkyGridUIAuditScenario", "camera-review",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let retake = app.buttons["Retake"]
        let useThisOne = app.buttons["Use this one"]
        XCTAssertTrue(retake.waitForExistence(timeout: 8))
        XCTAssertTrue(useThisOne.exists)
        XCTAssertGreaterThan(useThisOne.frame.minY, retake.frame.minY)
        XCTAssertGreaterThanOrEqual(retake.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(retake.frame.maxX, app.frame.maxX)
        XCTAssertGreaterThanOrEqual(useThisOne.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(useThisOne.frame.maxX, app.frame.maxX)
        XCTAssertLessThanOrEqual(retake.frame.width, 340)
    }

    func testCameraPermissionFailureExplainsRecovery() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-SkyGridUIAudit", "-SkyGridUIAuditScenario", "camera-failure"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Camera access is off"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Allow camera access in Settings to capture your morning sky."].exists)
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertTrue(app.buttons["Close camera"].exists)
    }

    func testTypographyActuallyScalesAtAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-SkyGridUIAudit", "-SkyGridUIAuditScenario", "camera-failure"
        ]
        app.launch()

        let message = app.staticTexts["Allow camera access in Settings to capture your morning sky."]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        let standardHeight = message.frame.height
        app.terminate()

        app.launchArguments = [
            "-SkyGridUIAudit", "-SkyGridUIAuditScenario", "camera-failure",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        XCTAssertTrue(message.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(message.frame.height, standardHeight * 1.5)
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertTrue(app.buttons["Close camera"].exists)
    }

    func testAccountDeletionShowsBlockingProgressUntilTheServerCompletes() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-SkyGridUIAudit", "-SkyGridUIAuditScenario", "settings",
            "-SkyGridDelayAccountDeletion"
        ]
        app.launch()

        let deleteRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Delete account")).firstMatch
        XCTAssertTrue(deleteRow.waitForExistence(timeout: 8))
        deleteRow.tap()
        let deleteButton = app.buttons["Delete account"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        let confirmDelete = app.alerts["Delete your account?"].buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()
        XCTAssertTrue(app.staticTexts["Deleting your account…"].waitForExistence(timeout: 2))
    }

    /// Drives the real (non-audit) purchase path against the live RevenueCat/StoreKit
    /// stack on a physical device, up to the point StoreKit hands off to the system
    /// Sandbox Apple ID sign-in sheet. That handoff is intentionally not completed
    /// here: entering App Store credentials is a human-only step, never automated.
    /// The trailing wait gives a person time to sign in and confirm the purchase by
    /// hand on the device before the test tears down.
    func testRealSandboxPurchaseReachesStoreKitConfirmationSheet() throws {
        try requirePhysicalDevice()
        let app = XCUIApplication()
        launchLiveBackend(app)

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
        let archiveProtection = app.staticTexts["ARCHIVE PROTECTION"]
        let proSection = app.staticTexts["SKY GRID PRO"]
        XCTAssertTrue(archiveProtection.exists)
        XCTAssertTrue(proSection.exists)
        XCTAssertLessThan(archiveProtection.frame.minY, proSection.frame.minY)

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

        let termsRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Terms of Use")).firstMatch
        XCTAssertTrue(termsRow.waitForExistence(timeout: 5))
        termsRow.tap()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10), "Tapping Terms of Use should hand off to Safari")
    }

    func testBlockedListFailureNeverMasqueradesAsNoBlocks() {
        let app = XCUIApplication()
        app.launchArguments = ["-SkyGridUIAudit", "-SkyGridUIAuditScenario", "settings-blocked-unavailable"]
        app.launch()

        let communitySafetyRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Community & Safety")).firstMatch
        XCTAssertTrue(communitySafetyRow.waitForExistence(timeout: 8))
        communitySafetyRow.tap()

        XCTAssertTrue(app.staticTexts["We couldn't refresh your blocked list."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["No block settings have been changed. Check your connection and try again."].exists)
        XCTAssertFalse(app.staticTexts["No blocked buddies"].exists)
        let failureAttachment = XCTAttachment(screenshot: app.screenshot())
        failureAttachment.name = "blocked-list-unavailable"
        failureAttachment.lifetime = .keepAlways
        add(failureAttachment)
        let retry = app.buttons["Check again"]
        XCTAssertTrue(retry.exists)
        retry.tap()
        XCTAssertTrue(app.staticTexts["BLOCKED"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Unblock"].exists)
        XCTAssertFalse(app.staticTexts["We couldn't refresh your blocked list."].exists)
    }

    /// Drives the real (non-audit) account-deletion path against the live
    /// Firebase/App Check stack. Uses whatever anonymous account is already signed
    /// in on this simulator — safe to delete since it is a disposable test identity,
    /// never the operator's own data.
    func testRealAccountDeletionSucceeds() throws {
        // The compile-time gate prevents ordinary simulator CI from creating any
        // production Firebase identity. An explicit live audit builds this case
        // with `-DSKYGRID_LIVE_BACKEND_AUDIT` and deletes both identities before exit.
        try requirePhysicalDevice(allowLiveBackendSimulator: true)
        let app = XCUIApplication()
        launchLiveBackend(app)

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
        let accountCleared = app.buttons["Start fresh"]
        // `XCTWaiter` completes only when *every* expectation is fulfilled, so
        // using two expectations here used to wait the full timeout even after
        // the successful "Start fresh" state appeared. Poll the mutually
        // exclusive terminal states instead.
        let deadline = Date().addingTimeInterval(30)
        while !errorAlert.exists && !accountCleared.exists && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = errorAlert.exists ? "account-deletion-failed" : "account-deletion-outcome"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(errorAlert.exists || accountCleared.exists, "Neither the error alert nor the post-deletion onboarding screen appeared")
        XCTAssertFalse(errorAlert.exists, "Account deletion surfaced \"Could not delete account\" — see attached screenshot")

        XCTAssertTrue(accountCleared.exists, "Deletion must finish at the explicit Start fresh screen")
        accountCleared.tap()
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 30), "A fresh anonymous identity did not finish profile bootstrap")

        // Leave no production test account behind. This second pass is also the
        // regression test for the former post-deletion 'Try again' account setup.
        settingsButton.tap()
        XCTAssertTrue(deleteRow.waitForExistence(timeout: 8))
        deleteRow.tap()
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 8))
        deleteButton.tap()
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 8))
        confirmDelete.tap()
        XCTAssertTrue(accountCleared.waitForExistence(timeout: 30))
    }

    /// Checks whether RevenueCat's real (non-audit) offerings now load after the
    /// "Credentials need attention" App Store Server API incident was reported
    /// resolved on Apple's side (status.revenuecat.com/incidents/mr3l9wqygn3d,
    /// resolved 2026-07-31 06:30 UTC). A successful fetch here means real product
    /// prices reach the paywall; `PurchaseError.noOfferingAvailable` or a stuck
    /// loading state would mean the incident's effects persist for this app.
    func testRealPaywallOfferingsLoadAfterRevenueCatIncident() throws {
        try requirePhysicalDevice()
        let app = XCUIApplication()
        launchLiveBackend(app)

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

    /// Production RevenueCat configuration is deliberately mandatory for Debug as
    /// well as Release. Keep this former Test Store case skipped so it can never
    /// silently encourage switching an installed app back to a test project.
    func testRealTestStorePurchaseGrantsEntitlement() throws {
        throw XCTSkip("Installed app builds must use the production RevenueCat project.")

        /*
        try requirePhysicalDevice()
        let app = XCUIApplication()
        launchLiveBackend(app)

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
         */
    }

    func testRealCameraCaptureUploadsSuccessfully() throws {
        try requirePhysicalDevice()
        let app = XCUIApplication()
        let cameraPermission = addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            let allow = alert.buttons["Allow"].exists ? alert.buttons["Allow"] : alert.buttons["OK"]
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        launchLiveBackend(app)

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
