import XCTest
import CellBase
@testable import Binding

final class ButlerLanguageSupportTests: XCTestCase {
    func testConversationUsesOnlyRecentMessagesFromActiveThread() {
        let messages: ValueTypeList = [
            .object(["threadID": .string("other"), "role": .string("user"), "body": .string("PRIVATE_OTHER_THREAD")]),
            .object(["threadID": .string("active"), "role": .string("system"), "body": .string("SYSTEM_NOT_HISTORY")]),
            .object(["threadID": .string("active"), "role": .string("user"), "body": .string("UNSUBMITTED_DRAFT"), "submittedTurn": .bool(false)]),
            .object(["threadID": .string("active"), "role": .string("user"), "body": .string("Bestille et lokale")]),
            .object(["threadID": .string("active"), "role": .string("assistant"), "body": .string("Hvilken dag?")])
        ]
        let context = ButlerLanguageSupport.conversation(from: messages, threadID: "active")
        XCTAssertEqual(context, "user: Bestille et lokale\nassistant: Hvilken dag?")
        let large = (0..<100).map { index in
            ValueType.object(["threadID": .string("active"), "role": .string("user"),
                              "body": .string("\(index):" + String(repeating: "x", count: 2_000))])
        }
        XCTAssertLessThanOrEqual(ButlerLanguageSupport.conversation(from: large, threadID: "active").count, 2_650)
    }

    func testConfiguredRemoteKeepsPrecedenceAfterDescriptorNormalization() throws {
        let state: ValueType = .object(["providerID": .string("binding.remote-llm"),
            "status": .string("ready"), "canInvokeFromChat": .bool(true)])
        let provider = try XCTUnwrap(BindingChatProviderRouter.descriptor(from: state, defaultKind: "remote_llm"))
        XCTAssertTrue(ButlerLanguageSupport.hasConfiguredRemoteProvider([provider]))
        XCTAssertFalse(ButlerLanguageSupport.hasConfiguredRemoteProvider([BindingChatProviderRouter.localRulesProvider()]))
    }

    func testTextRequestsDoNotBecomeActionsBecauseOfTheirSubject() {
        for prompt in ["Kan du skrive en møteinvitasjon?", "Hjelp meg å formulere en påminnelse.",
                       "Oversett: Legg til en oppgave.", "Could you explain how reminders work?"] {
            XCTAssertTrue(ButlerLanguageSupport.requestsTextOnly(prompt), prompt)
        }
        for prompt in ["Skriv opp kjøp av kaffe på listen", "Minn meg på å skrive en invitasjon i morgen",
                       "Skriv en invitasjon og send den til Per"] {
            XCTAssertFalse(ButlerLanguageSupport.requestsTextOnly(prompt), prompt)
        }
    }

    func testModelCannotInventRoutesOrOverrideNegation() {
        let baseline = BindingChatIntentClassifier.classify(prompt: "Hei")
        let invalid = ButlerLanguageSupport.Reply(answer: "Svar", helper: "shell.execute", confidence: 1, reason: "")
        XCTAssertEqual(ButlerLanguageSupport.suggestion(from: invalid, fallback: baseline).helperID, baseline.helperID)
        let task = ButlerLanguageSupport.Reply(answer: "Et oppgaveutkast", helper: "todo", confidence: 0.95, reason: "Brukeren ber om en oppgave.")
        let suggestion = ButlerLanguageSupport.suggestion(from: task, fallback: baseline)
        XCTAssertEqual(suggestion.helperID, "todo")
        XCTAssertEqual(suggestion.purposeRef, "personal.chat.assist.todo")
        XCTAssertTrue(suggestion.requiresUserApproval)
        let negative = BindingChatIntentClassifier.classify(prompt: "Ikke inviter noen")
        XCTAssertFalse(ButlerLanguageSupport.suggestion(from: task, fallback: negative).shouldSuggest)
        var uncertain = task
        uncertain.confidence = .nan
        XCTAssertEqual(ButlerLanguageSupport.suggestion(from: uncertain, fallback: baseline).helperID, baseline.helperID)
    }

    @MainActor
    func testSubmissionUsesLanguageUnderstandingAndCarriesConversationWithoutExecutingTask() async throws {
        let savedVault = CellBase.defaultIdentityVault
        let savedResolver = CellBase.defaultCellResolver
        let savedAccess = CellBase.debugValidateAccessForEverything
        let vault = EphemeralIdentityVault()
        CellBase.defaultIdentityVault = vault
        CellBase.defaultCellResolver = nil
        CellBase.debugValidateAccessForEverything = false
        defer {
            CellBase.defaultIdentityVault = savedVault
            CellBase.defaultCellResolver = savedResolver
            CellBase.debugValidateAccessForEverything = savedAccess
        }
        let maybeOwner = await vault.identity(for: "butler-language-test", makeNewIfNotFound: true)
        let owner = try XCTUnwrap(maybeOwner)
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let requests = Requests()
        chat.localLanguageResponder = { request in
            await requests.record(request)
            return ButlerLanguageSupport.Reply(answer: "Jeg kan klargjøre et oppgaveutkast om å bestille lokalet.",
                helper: "todo", confidence: 0.95, reason: "Brukeren ber om et gjøremål.", draftTitle: "Bestille lokalet")
        }
        _ = try await chat.set(keypath: "assistant.analyzeDraft", value: .string("Bestille lokalet"), requester: owner)
        let before = await requests.values
        XCTAssertEqual(before.count, 0, "Typing must not invoke the language model")
        _ = try await chat.set(keypath: "prompt.submit", value: .string("Jeg må få bestilt lokalet. Legg det på listen min."), requester: owner)
        let stateValue = try await chat.get(keypath: "state", requester: owner)
        let state = try XCTUnwrap(BindingChatValue.object(stateValue))
        XCTAssertEqual(BindingChatValue.string(BindingChatValue.nested("assistant.latestSuggestion.helperID", in: state)), "todo")
        let messages = try XCTUnwrap(BindingChatValue.list(BindingChatValue.nested("ui.promptMessages", in: state)))
        let answer = try XCTUnwrap(BindingChatValue.object(messages.last))
        XCTAssertEqual(BindingChatValue.string(answer["answerSource"]), "language_model")
        XCTAssertTrue(BindingChatValue.string(answer["body"])?.contains("bestille lokalet") == true)
        XCTAssertEqual(BindingChatValue.bool(answer["sideEffect"]), false)
        XCTAssertEqual(BindingChatValue.string(BindingChatValue.nested("workbench.todoDraft.title", in: state)), "Bestille lokalet")
        XCTAssertTrue(BindingChatValue.list(BindingChatValue.nested("workbench.modules", in: state))?.isEmpty == true)
        _ = try await chat.set(keypath: "ui.openSuggestedHelper", value: .object([:]), requester: owner)
        let accepted = try await chat.set(keypath: "todo.create", value: .object([:]), requester: owner)
        XCTAssertEqual(BindingChatValue.bool(BindingChatValue.object(accepted)?["requestedActionExecuted"]), false)
        let savedState = try await chat.get(keypath: "state", requester: owner)
        let modules = BindingChatValue.list(BindingChatValue.nested("workbench.modules", in: BindingChatValue.object(savedState) ?? [:])) ?? []
        let saved = try XCTUnwrap(BindingChatValue.object(modules.last))
        XCTAssertEqual(BindingChatValue.string(saved["title"]), "Bestille lokalet")
        XCTAssertEqual(BindingChatValue.string(BindingChatValue.object(saved["draft"])?["note"]), "Jeg må få bestilt lokalet. Legg det på listen min.")
        _ = try await chat.set(keypath: "prompt.submit", value: .string("Det gjelder neste fredag."), requester: owner)
        let submitted = await requests.values
        XCTAssertEqual(submitted.count, 2)
        XCTAssertTrue(submitted[1].conversation.contains("bestille lokalet"))
        XCTAssertTrue(submitted[1].conversation.contains("Jeg må få bestilt lokalet"))
    }

    func testLiveNorwegianUnderstandingAndAnswerQuality() async throws {
        guard ProcessInfo.processInfo.environment["HAVEN_TEST_LIVE_BUTLER"] == "1" else {
            throw XCTSkip("Opt-in live, on-device Foundation Models evaluation")
        }
        let cases: [(String, String)] = [
            ("Forklar forskjellen mellom en oppgave og en påminnelse i to korte setninger.", "none"),
            ("Jeg må huske å bestille lokalet til konferansen. Kan du legge det på gjøremålslisten?", "todo"),
            ("Skriv en kort høflig melding som ber om å få låne et møterom på fredag.", "none"),
            ("Hjelp meg å formulere en påminnelse til teamet om at fristen nærmer seg. Bare teksten, ikke send noe.", "none"),
            ("Kan du minne meg på å bestille lokalet i morgen?", "reminder")
        ]
        for (prompt, helper) in cases {
            let reply = await ButlerLanguageSupport.respond(to: .init(prompt: prompt, conversation: "", resources: []))
            XCTAssertNil(reply.failure)
            XCTAssertEqual(reply.helper, helper, prompt)
            XCTAssertGreaterThan(reply.answer.count, 30)
            XCTAssertFalse(reply.answer.contains("Ingen trygg chat-helper"))
            print("LIVE BUTLER: \(prompt)\nHELPER: \(reply.helper)\nANSWER: \(reply.answer)")
        }
    }

    private actor Requests {
        var values: [ButlerLanguageSupport.Request] = []
        func record(_ request: ButlerLanguageSupport.Request) { values.append(request) }
    }
}
