import XCTest

final class XGizouUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBrowserRendersAndProfileSwitchReturnsHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-seed-profiles"]
        app.launchEnvironment["XGIZOU_TEST_HOME_URL"] =
            "data:text/html,%3Chtml%3E%3Cbody%20style%3D%27background%3Ablack%3Bcolor%3Awhite%3Bfont-size%3A32px%27%3EX-Gizou%20Browser%20Smoke%3C/body%3E%3C/html%3E"
        app.launch()

        XCTAssertTrue(
            app.staticTexts["X-Gizou Browser Smoke"].waitForExistence(timeout: 10),
            "WKWebView must render the browser surface after app launch"
        )
        XCTAssertTrue(
            app.staticTexts["UI Profile A"].waitForExistence(timeout: 3),
            "The initially selected profile must be visible in the browser header"
        )

        let profilesTab = app.tabBars.buttons["プロファイル"]
        XCTAssertTrue(profilesTab.waitForExistence(timeout: 3))
        profilesTab.tap()

        let secondProfile = app.staticTexts["UI Profile B"]
        XCTAssertTrue(secondProfile.waitForExistence(timeout: 3))
        secondProfile.tap()

        XCTAssertTrue(
            app.staticTexts["UI Profile B"].waitForExistence(timeout: 5),
            "Selecting a profile must return home and update the browser header"
        )
        XCTAssertTrue(
            app.staticTexts["X-Gizou Browser Smoke"].waitForExistence(timeout: 10),
            "The browser surface must render after switching profiles"
        )

        XCTAssertTrue(app.tabBars.buttons["ホーム"].isSelected)
    }
}
