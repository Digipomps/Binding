import XCTest

/// Uses the normal chat composer and send button with synthetic messages.
/// Requires an unlocked iPad with Apple Intelligence available.
final class ButlerConversationUITests: XCTestCase {
    @MainActor
    func testSendButtonGeneratesAnswerAndOpensPopulatedTaskDraft() throws {
#if os(iOS)
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["--haven-ephemeral-identity", "--enable-conference-automation"]
        app.launchEnvironment["HAVEN_EPHEMERAL_IDENTITY"] = "1"
        app.launch()
        let sidebar = app.collectionViews["Sidebar"].firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 20))
        let entry = sidebar.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Butler Chat,")).firstMatch
        for _ in 0..<5 {
            if entry.exists && entry.isHittable { break }
            sidebar.swipeDown()
        }
        XCTAssertTrue(entry.exists)
        entry.tap()
        let composer = app.textViews.firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 20))
        composer.tap()
        composer.typeText("Skriv en kort høflig melding som ber om å få låne et møterom på fredag.")
        let send = app.buttons["↑"].firstMatch
        XCTAssertTrue(send.exists)
        send.tap()

        let answer = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Formulert på enheten med Apple Intelligence.")).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 60), "The real send path did not produce an on-device answer")
        XCTAssertTrue(answer.label.localizedCaseInsensitiveContains("fredag"))
        XCTAssertFalse(answer.label.contains("Ingen trygg chat-helper"))
        attach(app, name: "Butler answer from the normal send button")

        composer.tap()
        composer.typeText("Jeg må huske å bestille lokalet til konferansen. Kan du legge det på gjøremålslisten?")
        send.tap()
        let proposal = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Forslag til utkast:")).firstMatch
        XCTAssertTrue(proposal.waitForExistence(timeout: 60))
        XCTAssertTrue(proposal.label.contains("Det er ikke utført noen handling"))
        app.buttons["Åpne forslag"].firstMatch.tap()
        let title = app.textFields["Oppgave"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertTrue((title.value as? String)?.localizedCaseInsensitiveContains("lokalet") == true)
        attach(app, name: "Butler populated task draft before confirmation")
#else
        throw XCTSkip("This acceptance path uses the iPad Sidebar")
#endif
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
