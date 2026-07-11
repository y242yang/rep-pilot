import XCTest

final class RepPilotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Drives the app through its main tabs with rich demo data (see `DemoDataSeeder`,
    /// DEBUG-only, activated by `-UITestDemoData`) and attaches a screenshot at each
    /// stop — for generating App Store screenshots without manual navigation.
    ///
    /// Uses normalized-coordinate taps for the tab bar rather than
    /// `tabBar.buttons["Name"].tap()` — the latter was resolving to a degenerate
    /// {-1,-1} hit point in this environment (Simulator/host scaling quirk), which
    /// silently tapped near the top-left corner (the Settings gear button) instead
    /// of the intended tab.
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestDemoData"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        sleep(1)
        capture(app, name: "01_Log")

        let firstWorkout = app.staticTexts["Running"].firstMatch
        if firstWorkout.waitForExistence(timeout: 5) {
            firstWorkout.tap()
            sleep(1)
            capture(app, name: "02_WorkoutDetail")
            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
            }
        }

        tapTab(app, dx: 0.30, name: "03_Calendar")
        tapTab(app, dx: 0.50, name: "04_Progress")
        tapTab(app, dx: 0.70, name: "05_Coaching")
        tapTab(app, dx: 0.90, name: "06_Profile")
    }

    private func tapTab(_ app: XCUIApplication, dx: CGFloat, name: String) {
        app.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.9424)).tap()
        sleep(1)
        capture(app, name: name)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
