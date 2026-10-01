import XCTest

final class XGizouUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRealXHomeRendersNonBlank() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-seed-profiles"]
        app.launchEnvironment["XGIZOU_REAL_X_SMOKE"] = "1"
        app.launch()

        let loadedWebView = app.webViews["x-browser-real-x-loaded"]
        XCTAssertTrue(
            loadedWebView.waitForExistence(timeout: 35),
            "The real x.com/home page must render non-empty interactive content in WKWebView"
        )

        XCTAssertFalse(
            app.staticTexts["Xを開けません"].exists,
            "Real X must not end on the browser failure overlay"
        )
    }

    func testCreatingProfileDismissesEditorBeforeOpeningX() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-seed-profiles"]
        app.launchEnvironment["XGIZOU_TEST_HOME_URL"] =
            "data:text/html,%3Chtml%3E%3Cbody%20style%3D%27background%3Ablack%3Bcolor%3Awhite%3Bfont-size%3A32px%27%3EX-Gizou%20Browser%20Smoke%3C%2Fbody%3E%3C%2Fhtml%3E"
        app.launch()

        let profilesTab = app.tabBars.buttons["プロファイル"]
        XCTAssertTrue(profilesTab.waitForExistence(timeout: 3))
        profilesTab.tap()

        let addProfile = app.buttons["新規プロフィールを作成"]
        XCTAssertTrue(addProfile.waitForExistence(timeout: 5))
        addProfile.tap()

        let save = app.buttons["保存"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertTrue(
            app.tabBars.buttons["ホーム"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.tabBars.buttons["ホーム"].isSelected,
            "Creating a profile must switch to Home only after the editor sheet has dismissed"
        )

        XCTAssertTrue(
            app.staticTexts["新しいプロフィール"].waitForExistence(timeout: 5),
            "The newly created profile must become the active browser profile"
        )

        XCTAssertTrue(
            app.staticTexts["X-Gizou Browser Smoke"].waitForExistence(timeout: 10),
            "The new profile must start its first browser navigation after creation"
        )

        XCTAssertFalse(
            app.staticTexts["Xを開けません"].exists,
            "Creating a profile must not leave the browser on the failure overlay"
        )
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
