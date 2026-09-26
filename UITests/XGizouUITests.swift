import XCTest

final class XGizouUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBrowserRendersAndProfileSwitchReturnsHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-seed-profiles"]
        app.launchEnvironment["XGIZOU_TEST_HOME_URL"] =
            "data:text/html,%3Chtml%3E%3Cbody%20style%3D%27background%3Ablack%3Bcolor%3Awhite%3Bfont-size%3A32px%27%3EX-Gizou%20Browser%20Smoke%3Ciframe%20src%3D%27xgizou-test%3A%2F%2Fframe%27%20style%3D%27display%3Anone%27%3E%3C%2Fiframe%3E%3C%2Fbody%3E%3C%2Fhtml%3E"
        app.launch()

        XCTAssertTrue(
            app.staticTexts["UI Profile A"].waitForExistence(timeout: 10),
            "The deterministic test profile must be selected at launch"
        )

        XCTAssertTrue(
            app.staticTexts["X-Gizou Browser Smoke"].waitForExistence(timeout: 10),
            "WKWebView must finish and render its initial navigation"
        )

        XCTAssertFalse(
            app.staticTexts["Xを開けません"].waitForExistence(timeout: 2),
            "A navigation policy interruption must not be surfaced as a network failure"
        )

        let profilesTab = app.tabBars.buttons["プロファイル"]
        XCTAssertTrue(profilesTab.waitForExistence(timeout: 3))
        profilesTab.tap()

        let secondProfile = app.staticTexts["UI Profile B"]
        XCTAssertTrue(secondProfile.waitForExistence(timeout: 5))
        secondProfile.tap()

        XCTAssertTrue(
            app.staticTexts["UI Profile B"].waitForExistence(timeout: 5),
            "Selecting a profile must return home and update the browser header"
        )

        XCTAssertTrue(
            app.staticTexts["X-Gizou Browser Smoke"].waitForExistence(timeout: 10),
            "The replacement profile must create, finish, and render a fresh WKWebView navigation"
        )

        XCTAssertFalse(
            app.staticTexts["Xを開けません"].waitForExistence(timeout: 2),
            "Switching profiles must not surface a transient navigation error"
        )

        XCTAssertTrue(app.tabBars.buttons["ホーム"].isSelected)
    }
}
