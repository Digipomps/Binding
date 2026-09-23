import XCTest

final class DatabaseCustodyUITests: XCTestCase {
    @MainActor
    func testNativeCustodyEntryShowsLockedStateAndExplicitActions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--haven-ephemeral-identity"]
        app.launchEnvironment["BINDING_VERIFIER_IDENTITY_MODE"] = "local"
        app.launchEnvironment["BINDING_FORCE_TEMP_DOCUMENT_ROOT"] = "1"
        app.launch()
        defer { app.terminate() }
        app.menuBars.menuBarItems.element(boundBy: 1).click()
        let item = app.menuItems["Private celledata …"]
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        item.click()
        let window = app.windows["Private celledata"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.buttons["Opprett ny Keychain-mottaker"].exists)
        XCTAssertTrue(window.buttons["Åpne signert forespørsel …"].exists)
        XCTAssertFalse(window.buttons["Eksporter offentlig mottaker"].isEnabled)
        window.buttons["Lås og avbryt lokal godkjenning"].click()
        let status = window.staticTexts["database-custody-status"]
        let locked = NSPredicate { _, _ in
            status.label.hasPrefix("Låst.") || (status.value as? String)?.hasPrefix("Låst.") == true
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: locked, object: status)], timeout: 5), .completed)
        let screenshot = XCTAttachment(screenshot: window.screenshot())
        screenshot.name = "Native database custody locked owner workflow"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
