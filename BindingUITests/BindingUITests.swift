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
        let launchStartedAt = Date()
        app.launch()

        let composer = app.textViews.firstMatch
        if !composer.waitForExistence(timeout: 15) {
            let labeledEntry = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Co-Pilot,")
            ).firstMatch
            let plainEntry = app.buttons["Co-Pilot"].firstMatch
            let copilotEntry = labeledEntry.exists ? labeledEntry : plainEntry
            XCTAssertTrue(copilotEntry.waitForExistence(timeout: 5), "Co-Pilot mangler i HAVEN-menyen")
            copilotEntry.click()
            XCTAssertTrue(composer.waitForExistence(timeout: 5), "Co-Pilot-komponisten ble ikke rendret")
        }
        let readinessDuration = Date().timeIntervalSince(launchStartedAt)
        XCTAssertLessThan(readinessDuration, 15, "Co-Pilot brukte for lang tid på å bli skrivbar")

        let notificationDismiss = app.buttons["Ikke nå"].firstMatch
        if notificationDismiss.exists {
            notificationDismiss.tap()
        }

        composer.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Tastaturet kom ikke opp")

        let sendButton = app.buttons["↑"].firstMatch
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5), "Sendeknappen mangler ved komposisjonsfeltet")
        XCTAssertTrue(composer.isHittable, "Komposisjonsfeltet ligger under tastaturet")
        XCTAssertTrue(sendButton.isHittable, "Sendeknappen ligger under tastaturet")

        let dismissButtons = app.buttons.matching(
            NSPredicate(format: "label == %@", "Skjul tastatur")
        )
        XCTAssertTrue(dismissButtons.firstMatch.waitForExistence(timeout: 5), "Tastaturknappen mangler")
        XCTAssertEqual(dismissButtons.count, 1, "HAVEN skal bare vise én knapp for å skjule tastaturet")

        composer.typeText("Hva skjer i arendalsuka?")
        sendButton.tap()

        let composerCleared = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                (composer.value as? String)?.isEmpty == true
            },
            object: nil
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [composerCleared], timeout: 5),
            .completed,
            "Den sendte prompten ble stående i komposisjonsfeltet"
        )

        let openSuggestion = app.buttons["Åpne forslag"].firstMatch
        XCTAssertTrue(
            openSuggestion.waitForExistence(timeout: 30),
            "Arendalsuka-forslaget manglet en tydelig åpnehandling"
        )
        let openSuggestionHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in openSuggestion.isHittable },
            object: nil
        )
        _ = XCTWaiter.wait(for: [openSuggestionHittable], timeout: 5)
        if openSuggestion.isHittable == false {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Arendalsuka suggestion not hittable"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Arendalsuka suggestion accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(openSuggestion.isHittable, "Åpne forslag kan ikke aktiveres")
        openSuggestion.tap()

        let participantProgram = app.staticTexts["Arendalsuka Participant Program"].firstMatch
        XCTAssertTrue(
            participantProgram.waitForExistence(timeout: 30),
            "Arendalsuka-prompten åpnet ikke deltakerprogrammet"
        )
        XCTAssertTrue(
            composer.waitForNonExistence(timeout: 30),
            "Testen fant bare forslagsteksten; Arendalsuka-flaten erstattet ikke Co-Pilot"
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
