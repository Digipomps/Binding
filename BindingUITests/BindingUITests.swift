//
//  BindingUITests.swift
//  BindingUITests
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import XCTest

final class BindingUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testButterpopStudioLaunchesFromHAVEN() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CELL_SCAFFOLD_PUBLIC_BASE_URL"] = "http://127.0.0.1:9097"
        app.launch()

        let studioEntry = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Butterpop Studio,")
        ).firstMatch
        XCTAssertTrue(studioEntry.waitForExistence(timeout: 20), "Butterpop Studio mangler i HAVEN-menyen")
        studioEntry.click()

        let launchButton = app.buttons["Åpne Butterpop Studio"].firstMatch
        XCTAssertTrue(launchButton.waitForExistence(timeout: 15), "Butterpop-launcheren ble ikke rendret")
        XCTAssertTrue(launchButton.isHittable, "Butterpop-launcheren kan ikke aktiveres")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Butterpop Studio in HAVEN"
        attachment.lifetime = .keepAlways
        add(attachment)

        launchButton.click()
        XCTAssertNotEqual(app.state, .notRunning, "HAVEN krasjet etter Butterpop-navigasjon")
    }

    @MainActor
    func testArendalsukaPromptOpensParticipantProgram() throws {
        let app = XCUIApplication()
        app.launchEnvironment["BINDING_VERIFIER_IDENTITY_MODE"] = "local"
        app.launch()

        let labeledEntry = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Co-Pilot,")
        ).firstMatch
        let plainEntry = app.buttons["Co-Pilot"].firstMatch
        let copilotEntry = labeledEntry.waitForExistence(timeout: 20) ? labeledEntry : plainEntry
        XCTAssertTrue(copilotEntry.waitForExistence(timeout: 10), "Co-Pilot mangler i HAVEN-menyen")
        copilotEntry.click()

        let composer = app.textViews.firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 20), "Co-Pilot-komponisten ble ikke rendret")
        composer.click()
        composer.typeText("Hva skjer på arendalsuka?\n")

        let participantProgram = app.staticTexts["Arendalsuka Participant Program"].firstMatch
        XCTAssertTrue(
            participantProgram.waitForExistence(timeout: 30),
            "Arendalsuka-prompten åpnet ikke deltakerprogrammet"
        )
        XCTAssertNotEqual(app.state, .notRunning, "HAVEN krasjet etter Arendalsuka-navigasjon")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Arendalsuka prompt opened participant program"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
