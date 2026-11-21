import XCTest
import CellBase
@testable import Binding

private actor ContactRepairTransport: BindingChatTransport {
    private(set) var paths: [String] = []
    private(set) var invitation: Object?
    private var partialOnce: Bool
    init(partialOnce: Bool = false) { self.partialOnce = partialOnce }
    func request(_ path: String, payload: Object?) async throws -> Object {
        paths.append(path)
        if path == "assistant/candidate-query" { return ["ok": .bool(true), "candidates": .list([.object(["id": .string("profile-b"), "displayName": .string("Synthetic B")])])] }
        if path == "assistant/select-candidate" { return ["ok": .bool(true), "inviteDraft": .object([
            "profileID": .string("profile-b"), "userUUID": .string("B"), "title": .string("Selected B"),
            "contactEndpoint": .object(["endpointID": .string("cell-b"), "endpointCell": .string("cell:///Contact-cell-b")]),
            "contactAgreement": .object(["synthetic": .string("subject-bound-b")])])] }
        if path == "invite" {
            invitation = payload
            if partialOnce {
                partialOnce = false
                let recipient: Object = ["userUUID": .string("B"), "profileID": .string("profile-b")]
                return ["ok": .bool(false), "partial": .bool(true), "threadID": .string("synthetic-group"),
                    "remainingRecipients": .list([.object(recipient)]),
                    "contactChoices": .list([.object(["id": .string("cell-b"), "recipient": .object(recipient),
                        "contactEndpoint": .object(["endpointID": .string("cell-b"), "endpointCell": .string("cell:///Contact-cell-b")])])])]
            }
            return ["ok": .bool(true), "status": .string("invited")]
        }
        if path == "assistant/provider/invoke" { return ["ok": .bool(true), "success": .bool(false), "answer": .string("Synthetic policy denial") ] }
        if path == "assistant/provider/status" { return ["ok": .bool(true)] }
        if path == "assistant/provider/recommend" {
            return ["ok": .bool(true), "assistantState": .object([
                "providerChoices": .list([.object(["id": .string("own-model"), "title": .string("Own model")])])]),
                "providerRecommendation": .object(["title": .string("Own model")])]
        }
        if path == "assistant/provider/select" {
            return ["ok": .bool(true), "ui": .object([
                "selectedProviderID": .string("own-model"), "selectedProviderTitle": .string("Own model"),
                "selectedProviderReview": .string("Review before sending")])]
        }
        throw BindingNativeChatConnectionError.personLinkRequired
    }
}

@MainActor
final class ChatContactRepairTests: XCTestCase {
    private func fixture() async -> (BindingPersonalChatHubCell, Identity, ContactRepairTransport) {
        let vault = EphemeralIdentityVault()
        var owner = Identity(UUID().uuidString, displayName: "Synthetic owner", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "private")
        let cell = await BindingPersonalChatHubCell(owner: owner)
        let transport = ContactRepairTransport()
        cell.chatTransport = transport
        return (cell, owner, transport)
    }
    func testProviderDiscoveryAndSelectionUseAuthenticatedTransport() async throws {
        let (cell, owner, transport) = await fixture()
        _ = try await cell.set(keypath: "assistant.provider.recommend", value: .object([:]), requester: owner)
        _ = try await cell.set(keypath: "assistant.provider.select", value: .string("own-model"), requester: owner)
        let paths = await transport.paths
        XCTAssertEqual(paths, ["assistant/provider/status", "assistant/provider/recommend", "assistant/provider/select"])
        let title = try await cell.get(keypath: "state.ui.selectedProviderTitle", requester: owner)
        XCTAssertEqual(title, .string("Own model"))
    }
    func testMissingPersonLinkPreservesDraftAndExplainsConnection() async throws {
        let (cell, owner, _) = await fixture()
        _ = try await cell.set(keypath: "message.setComposer", value: .string("Unsent test draft"), requester: owner)
        _ = await cell.refreshSharedChat()
        let status = try await cell.get(keypath: "state.status", requester: owner)
        XCTAssertEqual(status, .string(BindingNativeChatConnectionError.personLinkRequired.message))
        let draft = try await cell.get(keypath: "state.messageComposer.body", requester: owner)
        XCTAssertEqual(draft, .string("Unsent test draft"))
    }
    func testConfirmedPersonAndContactReferenceReachInviteTogether() async throws {
        let (cell, owner, transport) = await fixture()
        _ = try await cell.set(keypath: "assistant.setCandidateQuery", value: .string("Synthetic B"), requester: owner)
        let beforeSelection = await transport.invitation
        XCTAssertNil(beforeSelection, "Searching must never send")
        _ = try await cell.set(keypath: "assistant.selectCandidate", value: .string("profile-b"), requester: owner)
        let beforeSend = await transport.invitation
        XCTAssertNil(beforeSend, "Selecting must never send")
        _ = try await cell.set(keypath: "chatHub.invite", value: .object([:]), requester: owner)
        let sent = await transport.invitation
        XCTAssertEqual(sent?["userUUID"], .string("B"))
        XCTAssertEqual(sent?["profileID"], .string("profile-b"))
        XCTAssertEqual(sent.flatMap { BindingChatValue.nested("contactEndpoint.endpointCell", in: $0) }, .string("cell:///Contact-cell-b"))
        XCTAssertEqual(sent.flatMap { BindingChatValue.nested("contactAgreement.synthetic", in: $0) }, .string("subject-bound-b"))
    }

    func testButlerInvitationPromptResolvesSharedPersonBeforeSending() async throws {
        let (cell, owner, transport) = await fixture()
        cell.localLanguageResponder = { _ in .init(answer: "Inviter Synthetic B?", helper: "invite", confidence: 0.95, reason: "Synthetic invitation", failure: nil) }
        _ = try await cell.set(keypath: "prompt.submit", value: .string("Inviter Synthetic B til samtalen"), requester: owner)
        let source = try await cell.get(keypath: "state.assistant.latestSuggestion.candidateSource", requester: owner)
        XCTAssertEqual(source, .string("shared_people"))
        let before = await transport.invitation
        XCTAssertNil(before)
        let usedModel = try await cell.get(keypath: "state.assistant.lastGeneratedAnswer.model", requester: owner)
        XCTAssertEqual(usedModel, .string("Apple Intelligence"))
        _ = try await cell.set(keypath: "assistant.acceptSuggestion", value: .object([:]), requester: owner)
        let sent = await transport.invitation
        XCTAssertEqual(sent?["userUUID"], .string("B"))
    }

    func testPartialGroupRetryKeepsConversationAndOnlyRemainingRecipient() async throws {
        let (cell, owner, _) = await fixture()
        let transport = ContactRepairTransport(partialOnce: true); cell.chatTransport = transport
        _ = try await cell.set(keypath: "assistant.setCandidateQuery", value: .string("Synthetic B"), requester: owner)
        _ = try await cell.set(keypath: "assistant.selectCandidate", value: .string("profile-b"), requester: owner)
        _ = try await cell.set(keypath: "inviteRecipients.add", value: .object([:]), requester: owner)
        _ = try await cell.set(keypath: "chatHub.invite", value: .object([:]), requester: owner)
        _ = try await cell.set(keypath: "inviteDraft.contactChoice", value: .string("cell-b"), requester: owner)
        _ = try await cell.set(keypath: "chatHub.invite", value: .object([:]), requester: owner)
        let retried = await transport.invitation
        XCTAssertEqual(retried?["threadID"], .string("synthetic-group"))
        let recipients = retried.flatMap { BindingChatValue.list($0["recipients"]) } ?? []
        XCTAssertEqual(recipients.count, 1)
        XCTAssertEqual(BindingChatValue.object(recipients.first ?? .null)?["userUUID"], .string("B"))
        XCTAssertEqual(BindingChatValue.object(recipients.first ?? .null).flatMap { BindingChatValue.nested("contactEndpoint.endpointCell", in: $0) }, .string("cell:///Contact-cell-b"))
    }

    func testEmptyInvitationTextDoesNotRenderNull() async throws {
        let (cell, owner, _) = await fixture()
        let link = try await cell.get(keypath: "state.assistant.lastPreparedInvite.link", requester: owner)
        let body = try await cell.get(keypath: "state.assistant.lastPreparedInvite.body", requester: owner)
        XCTAssertEqual(link, .string("")); XCTAssertEqual(body, .string(""))
    }
}
