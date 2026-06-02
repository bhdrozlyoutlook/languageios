import XCTest

/// Smoke tests that launch the real app. The `--uitest-reset` argument makes the app
/// start from a fresh in-memory state (see LanguageIOSApp), so every run begins at
/// onboarding deterministically.
final class LanguageIOSUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-reset"]
        app.launch()
        return app
    }

    func testLaunchShowsOnboardingContinueButton() {
        let app = launchFreshApp()
        XCTAssertTrue(
            app.buttons["Devam et"].waitForExistence(timeout: 8),
            "Onboarding's primary button should appear on launch"
        )
    }

    func testTappingContinueAdvancesToTargetLanguageStep() {
        let app = launchFreshApp()
        let continueButton = app.buttons["Devam et"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 8))
        continueButton.tap()
        XCTAssertTrue(
            app.staticTexts["Hangi dili öğrenmek istiyorsun?"].waitForExistence(timeout: 4),
            "Tapping continue should advance to the target-language step"
        )
    }

    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments += ["--uitest-reset"]
            app.launch()
        }
    }
}
