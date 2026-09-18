import XCTest

final class NearbyScannerNavigationUITests: XCTestCase {
    @MainActor
    func testScannerOpensAndSharingClosesWithoutCrashing() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["--haven-ephemeral-identity", "--enable-conference-automation"]
        app.launchEnvironment["HAVEN_EPHEMERAL_IDENTITY"] = "1"
        app.launch()
        for _ in 0..<2 {
#if os(iOS)
            let sidebar = app.collectionViews["Sidebar"].firstMatch
            XCTAssertTrue(sidebar.waitForExistence(timeout: 20))
            let entry = sidebar.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Entity Scanner,")).firstMatch
            for _ in 0..<4 {
                if entry.exists && entry.isHittable { break }
                sidebar.swipeUp()
            }
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
#else
            let surfaces = app.buttons["Flater"].firstMatch
            XCTAssertTrue(surfaces.waitForExistence(timeout: 20))
            surfaces.click()
            app.menuItems["Entity Scanner"].firstMatch.click()
#endif
            let sharing = app.buttons["nearby.sharing"]
            XCTAssertTrue(sharing.waitForExistence(timeout: 20), "Scanner did not render")
            XCTAssertTrue(app.buttons["nearby.start"].exists)
            XCTAssertTrue(app.textFields["nearby.search"].exists)
#if os(iOS)
            sharing.tap()
#else
            sharing.click()
#endif
            XCTAssertTrue(app.staticTexts["Det du annonserer"].waitForExistence(timeout: 5))
#if os(iOS)
            app.buttons["Lukk"].firstMatch.tap()
#else
            app.buttons["Lukk"].firstMatch.click()
#endif
            XCTAssertTrue(sharing.waitForExistence(timeout: 5))
            XCTAssertEqual(app.state, .runningForeground)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Entity Scanner after repeated navigation and sharing"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
