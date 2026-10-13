import XCTest
import CellBase
@testable import Binding

/// Client actions use synthetic owners and the real local cells. No HTTP,
/// platform contacts, Apple Intelligence, or stored credentials are used.
@MainActor
final class Inv10InvitationChatTests: XCTestCase {
    func testRecipientChangeClearsPreviousEndpointForBothEntryActions() async throws {
        try await withFixture { fixture in
            for key in ["invite", "chatHub.invite"] {
                let chat = await BindingPersonalChatHubCell(owner: fixture.owner)
                _ = try await chat.set(keypath: key, value: .object([
                    "profileID": .string("previous"), "userUUID": .string("previous-user"),
                    "contactEndpoint": .object(["endpointID": .string("previous-endpoint"),
                                                "cell": .string("cell:///Inv10MissingEndpoint")])
                ]), requester: fixture.owner)
                let result = try object(try await chat.set(keypath: key, value: .object([
                    "profileID": .string("next")
                ]), requester: fixture.owner))
                XCTAssertEqual(string(result["status"]), "bootstrap_required")
                let visibleStatus = try await chat.get(keypath: "state.status", requester: fixture.owner)
                XCTAssertEqual(string(visibleStatus), string(result["message"]))
                let invite = try object(result["invite"])
                XCTAssertEqual(string(invite["profileID"]), "next")
                XCTAssertNil(string(invite["userUUID"]))
                XCTAssertNil(BindingChatValue.object(invite["contactEndpoint"]))
            }
        }
    }

    func testEditingEitherRecipientFieldInvalidatesDeliveryTarget() async throws {
        try await withFixture { fixture in
            for field in ["profileID", "userUUID"] {
                var state = BindingPersonalChatHubCell.initialState()
                BindingChatValue.set(.object(["helperID": .string("invite"), "status": .string("suggested")]),
                    for: "assistant.latestSuggestion", in: &state)
                state["inviteDraft"] = .object(["profileID": .string("old"), "userUUID": .string("old-user"),
                    "contactEndpoint": .object(["endpointID": .string("old-endpoint")])])
                let chat = try await restoredChat(owner: fixture.owner, state: state)
                _ = try await chat.set(keypath: "chatHub.inviteDraft.\(field)", value: .string("new"), requester: fixture.owner)
                let after = try object(try await chat.get(keypath: "state", requester: fixture.owner))
                let draft = try object(after["inviteDraft"])
                XCTAssertNil(BindingChatValue.object(draft["contactEndpoint"]))
                XCTAssertEqual(string(draft[field]), "new")
                XCTAssertNil(string(BindingChatValue.nested("assistant.latestSuggestion.helperID", in: after)))
                XCTAssertNil(string(draft[field == "profileID" ? "userUUID" : "profileID"]))
            }
        }
    }

    func testExplicitNullEndpointCannotReusePreviousRecipient() async throws {
        try await withFixture { fixture in
            var state = BindingPersonalChatHubCell.initialState()
            state["inviteDraft"] = .object(["profileID": .string("same"), "userUUID": .string("same-user"),
                "contactEndpoint": .object(["endpointID": .string("old"), "cell": .string("cell:///Inv10MissingEndpoint")])])
            let chat = try await restoredChat(owner: fixture.owner, state: state)
            let result = try object(try await chat.set(keypath: "invite", value: .object([
                "contactEndpoint": .null
            ]), requester: fixture.owner))
            XCTAssertEqual(string(result["status"]), "bootstrap_required")
        }
    }

    func testButlerAndComponentPrepareSelectedExternalRelationLink() async throws {
        for key in ["assistant.acceptSuggestion", "chatHub.invite"] {
            try await withFixture { fixture in
                let relations = await BindingRelationsCell(owner: fixture.owner)
                let invitation = await BindingInvitationCell(owner: fixture.owner)
                try await fixture.resolver.registerNamedEmitCell(name: "Relations", emitCell: relations,
                    scope: .identityUnique, identity: fixture.owner)
                try await fixture.resolver.registerNamedEmitCell(name: "Invitation", emitCell: invitation,
                    scope: .identityUnique, identity: fixture.owner)
                // Disable publication BEFORE any preparation; Invitation defaults to production.
                _ = try await invitation.set(keypath: "invite.configure", value: .object([
                    "autoPublish": .bool(false), "landingBase": .string("https://staging.haven.digipomps.org"),
                    "fallbackLandingBase": .string("")
                ]), requester: fixture.owner)
                _ = try await relations.set(keypath: "relations.upsert", value: .object([
                    "contacts": .list([.object(["displayName": .string("Synthetic External"),
                        "email": .string("external@example.invalid")])])
                ]), requester: fixture.owner)
                let chat = await BindingPersonalChatHubCell(owner: fixture.owner)
                chat.localLanguageResponder = { _ in
                    ButlerLanguageSupport.Reply(answer: "Velg invitasjonen.", helper: "invite",
                        confidence: 0.95, reason: "Eksplisitt invitasjon")
                }
                _ = try await chat.set(keypath: "prompt.submit", value: .string("inviter Synthetic External"), requester: fixture.owner)
                _ = try await chat.set(keypath: "assistant.setCandidateQuery", value: .string("NobodyMatchesThis"), requester: fixture.owner)
                let missing = try object(try await chat.get(keypath: "state", requester: fixture.owner))
                XCTAssertTrue(BindingChatValue.list(BindingChatValue.nested("assistant.latestSuggestion.candidates", in: missing))?.isEmpty == true)
                _ = try await chat.set(keypath: "assistant.setCandidateQuery", value: .string("Synthetic External"), requester: fixture.owner)
                let found = try object(try await chat.get(keypath: "state", requester: fixture.owner))
                XCTAssertEqual(BindingChatValue.list(BindingChatValue.nested("assistant.latestSuggestion.candidates", in: found))?.count, 1)
                let before = try object(try await invitation.get(keypath: "state", requester: fixture.owner))
                let beforeCount = BindingChatValue.list(before["outbox"])?.count ?? 0
                _ = try await chat.set(keypath: "ui.openSuggestedHelper", value: .object([:]), requester: fixture.owner)
                let opened = try object(try await invitation.get(keypath: "state", requester: fixture.owner))
                XCTAssertEqual(BindingChatValue.list(opened["outbox"])?.count, beforeCount, "Opening the helper must not mint or send")
                let result = try object(try await chat.set(keypath: key, value: .object([:]), requester: fixture.owner))
                let prepared = try object(result["preparedInvite"])
                let link = try XCTUnwrap(string(prepared["link"]))
                XCTAssertFalse(link.isEmpty)
                let ticket = try HavenInviteLink.decode(HavenInviteLink.token(fromLink: link))
                XCTAssertTrue(HavenInviteVerifier.verify(ticket: ticket).isValid)
                XCTAssertEqual(BindingChatValue.bool(prepared["requiresUserToPressSend"]), true)
                XCTAssertEqual(BindingChatValue.bool(prepared["published"]), false)
            }
        }
    }

    func testChangingCandidateHidesPreviouslyPreparedExternalLink() async throws {
        try await withFixture { fixture in
            var state = BindingPersonalChatHubCell.initialState()
            BindingChatValue.set(.object(["link": .string("https://example.invalid/previous")]),
                for: "assistant.lastPreparedInvite", in: &state)
            let chat = try await restoredChat(owner: fixture.owner, state: state)
            _ = try await chat.set(keypath: "assistant.selectCandidate", value: .string("next"), requester: fixture.owner)
            let after = try await chat.get(keypath: "state.assistant.lastPreparedInvite.link", requester: fixture.owner)
            XCTAssertNil(string(after))
        }
    }

    func testStaleButlerSelectionCannotInviteTheOnlyRemainingCandidateOrOldDraft() async throws {
        try await withFixture { fixture in
            var state = BindingPersonalChatHubCell.initialState()
            BindingChatValue.set(.object([
                "helperID": .string("invite"), "status": .string("suggested"),
                "selectedCandidateProfileID": .string("stale"),
                "candidates": .list([.object(["id": .string("another"), "relationID": .string("another")])])
            ]), for: "assistant.latestSuggestion", in: &state)
            let chat = try await restoredChat(owner: fixture.owner, state: state)
            let result = try object(try await chat.set(keypath: "chatHub.invite", value: .object([:]), requester: fixture.owner))
            XCTAssertEqual(string(result["status"]), "blocked")
            XCTAssertTrue(string(result["message"])?.contains("Velg") == true)
            let after = try object(try await chat.get(keypath: "state", requester: fixture.owner))
            XCTAssertTrue(BindingChatValue.list(after["invites"])?.isEmpty == true)
        }
    }

    func testPendingRecipientLookupBlocksOldInviteAndCannotOverwriteANewerDrop() async throws {
        try await withFixture { fixture in
            let relations = await Inv10DelayedRelationsCell(owner: fixture.owner)
            try await fixture.resolver.registerNamedEmitCell(name: "Relations", emitCell: relations,
                scope: .identityUnique, identity: fixture.owner)
            var state = BindingPersonalChatHubCell.initialState()
            BindingChatValue.set(.object(["helperID": .string("invite"), "status": .string("suggested"),
                "selectedCandidateProfileID": .string("old"),
                "candidates": .list([.object(["id": .string("old"), "relationID": .string("old")])])
            ]), for: "assistant.latestSuggestion", in: &state)
            let chat = try await restoredChat(owner: fixture.owner, state: state)
            let lookup = Task { try await chat.set(keypath: "assistant.setCandidateQuery", value: .string("Next"), requester: fixture.owner) }
            defer {
                lookup.cancel()
                Task { await relations.gate.release() }
            }
            let entered = await relations.gate.waitUntilEntered()
            guard entered else {
                XCTFail("The actual relations lookup did not reach the controlled suspension")
                return
            }
            let pending = try object(try await chat.set(keypath: "invite", value: .object([:]), requester: fixture.owner))
            XCTAssertEqual(string(pending["status"]), "blocked")
            _ = try await chat.set(keypath: "drop.receive", value: .object([
                "dragRole": .string("person"), "dropTargetRole": .string("chat-invite-slot"),
                "dragPayload": .object(["profileID": .string("dropped"), "userUUID": .string("dropped-user")])
            ]), requester: fixture.owner)
            await relations.gate.release()
            let completed = try object(try await lookup.value)
            XCTAssertEqual(string(completed["status"]), "superseded")
            let after = try object(try await chat.get(keypath: "state", requester: fixture.owner))
            XCTAssertEqual(string(BindingChatValue.nested("inviteDraft.profileID", in: after)), "dropped")
            XCTAssertNil(string(BindingChatValue.nested("assistant.latestSuggestion.helperID", in: after)))
            XCTAssertTrue(BindingChatValue.list(after["invites"])?.isEmpty == true)
        }
    }

    func testPersonDropReplacesStaleButlerInviteCandidate() async throws {
        try await withFixture { fixture in
            var state = BindingPersonalChatHubCell.initialState()
            BindingChatValue.set(.object(["helperID": .string("invite"), "status": .string("suggested"),
                "selectedCandidateProfileID": .string("old"),
                "candidates": .list([.object(["id": .string("old"), "relationID": .string("old")])])
            ]), for: "assistant.latestSuggestion", in: &state)
            let chat = try await restoredChat(owner: fixture.owner, state: state)
            _ = try await chat.set(keypath: "drop.receive", value: .object([
                "dragRole": .string("person"), "dropTargetRole": .string("chat-invite-slot"),
                "dragPayload": .object(["profileID": .string("new"), "userUUID": .string("new-user")])
            ]), requester: fixture.owner)
            let result = try object(try await chat.set(keypath: "chatHub.invite", value: .object([:]), requester: fixture.owner))
            XCTAssertEqual(string(result["status"]), "bootstrap_required")
            XCTAssertEqual(string(try object(result["invite"])["profileID"]), "new")
        }
    }

    func testBothSurfacesRequireAnActualTicketWhenAcceptingOrDeclining() async throws {
        try await withFixture { fixture in
            for skeleton in try surfaces() {
                for action in ["acceptInvite", "declineInvite"] {
                    let button = try XCTUnwrap(buttons(skeleton).first { $0.keypath == "chatHub.\(action)" })
                    XCTAssertEqual(BindingChatValue.bool(BindingChatValue.object(button.payload)?["requireTicket"]), true)
                    let chat = await BindingPersonalChatHubCell(owner: fixture.owner)
                    let result = try object(try await chat.set(keypath: button.keypath,
                        value: button.payload ?? .object([:]), requester: fixture.owner))
                    XCTAssertEqual(string(result["status"]), "blocked")
                    let after = try object(try await chat.get(keypath: "state", requester: fixture.owner))
                    XCTAssertEqual(string(after["inviteStatus"]), "not invited")
                }
            }
        }
    }

    func testBothSurfacesExposeInvitationActionsAndPreparedLink() throws {
        for skeleton in try surfaces() {
            let actions = Set(buttons(skeleton).map(\.keypath))
            for action in ["invite", "contactInbox.refresh", "acceptInvite", "declineInvite", "invite.refreshStatuses"] {
                XCTAssertTrue(actions.contains("chatHub.\(action)"), action)
            }
            let json = String(decoding: try JSONEncoder().encode(skeleton), as: UTF8.self)
            XCTAssertTrue(json.contains("chatHub.assistant.selectCandidate"))
            XCTAssertTrue(json.contains("chatHub.state.assistant.lastPreparedInvite.link"))
            XCTAssertTrue(json.contains("chatHub.state.assistant.lastPreparedInvite.body"))
        }
    }

    func testUnavailableKnownHavenRecipientDoesNotRecordStartedConversation() async throws {
        try await withFixture { fixture in
            let spy = await Inv10InteractionSpyCell(owner: fixture.owner)
            try await fixture.resolver.registerNamedEmitCell(name: "Relations", emitCell: spy,
                scope: .identityUnique, identity: fixture.owner)
            var state = BindingPersonalChatHubCell.initialState()
            BindingChatValue.set(.object(["helperID": .string("invite"), "status": .string("suggested"),
                "selectedCandidateProfileID": .string("known"),
                "candidates": .list([.object(["id": .string("known"), "relationID": .string("known"),
                    "displayName": .string("Synthetic Known"), "reachAction": .string("open-chat"),
                    "entityRef": .string("cell:///SyntheticKnown")])])
            ]), for: "assistant.latestSuggestion", in: &state)
            let chat = try await restoredChat(owner: fixture.owner, state: state)
            let result = try object(try await chat.set(keypath: "assistant.acceptSuggestion", value: .object([:]), requester: fixture.owner))
            XCTAssertEqual(string(result["status"]), "bootstrap_required")
            XCTAssertEqual(spy.interactionCount, 0)
        }
    }

    func testConcurrentInvitationReceiptsAreBothRetained() async throws {
        try await withFixture { fixture in
            let pair = try await invitePair(fixture: fixture, skeleton: try surfaces()[0])
            let payload: Object = ["profileID": .string("same-recipient"),
                "userUUID": .string(pair.recipient.uuid), "contactEndpoint": .object(pair.descriptor)]
            async let first = pair.sender.set(keypath: "invite", value: .object(payload), requester: fixture.owner)
            async let second = pair.sender.set(keypath: "invite", value: .object(payload), requester: fixture.owner)
            let results = try await (first, second)
            for result in [results.0, results.1] { XCTAssertEqual(string(try object(result)["status"]), "delivered") }
            let state = try object(try await pair.sender.get(keypath: "state", requester: fixture.owner))
            let invites = try XCTUnwrap(BindingChatValue.list(state["invites"]))
            XCTAssertEqual(invites.count, 3, "The original and both concurrent receipts must survive")
            XCTAssertEqual(Set(invites.compactMap { string(BindingChatValue.object($0)?["ticketID"]) }).count, 3)
        }
    }

    func testSignedKnownContactInviteAndExplicitAcceptanceFromBothSurfaces() async throws {
        try await withFixture { fixture in
            for skeleton in try surfaces() {
                let pair = try await invitePair(fixture: fixture, skeleton: skeleton)
                let refreshed = try object(try await pair.sender.set(keypath: "invite.refreshStatuses",
                    value: .object([:]), requester: fixture.owner))
                let state = try object(refreshed["state"])
                let invite = try object(BindingChatValue.list(state["invites"])?.last)
                XCTAssertEqual(string(invite["status"]), "accepted")
                XCTAssertEqual(string(invite["contactDeliveryStatus"]), "responded")
            }
        }
    }
}

// These are required acceptance tests, intentionally kept as ordinary tests.
// The injected per-test server uses the same JSON boundary as production.
// The host run must report their actual outcome.
@MainActor
final class Inv10ChatEndToEndTests: XCTestCase {
    func testButlerTwoParticipantsReceiveEachOthersMessages() async throws { try await messaging(entry: 0, group: false) }
    func testComponentTwoParticipantsReceiveEachOthersMessages() async throws { try await messaging(entry: 1, group: false) }
    func testButlerThreeParticipantsShareOneThread() async throws { try await messaging(entry: 0, group: true) }
    func testComponentThreeParticipantsShareOneThread() async throws { try await messaging(entry: 1, group: true) }

    private func messaging(entry: Int, group: Bool) async throws {
        let server = Inv11ChatServer()
        try await withFixture { fixture in
            let skeleton = try surfaces()[entry]
            let pair = try await sharedInvitePair(server: server, fixture: fixture, skeleton: skeleton)
            _ = try await pair.sender.set(keypath: "invite.refreshStatuses", value: .object([:]), requester: fixture.owner)
            _ = try await pair.sender.set(keypath: "message.setComposer", value: .string("A to everyone"), requester: fixture.owner)
            _ = try await pair.sender.set(keypath: "sendComposedMessage", value: .object([:]), requester: fixture.owner)
            _ = try await pair.receiver.set(keypath: "message.setComposer", value: .string("B to everyone"), requester: pair.recipient)
            _ = try await pair.receiver.set(keypath: "sendComposedMessage", value: .object([:]), requester: pair.recipient)
            var participants: [(BindingPersonalChatHubCell, Identity)] = [(pair.sender, fixture.owner), (pair.receiver, pair.recipient)]
            var expected = Set(["A to everyone", "B to everyone"])
            if group {
                let third = try await sharedInvitePair(server: server, fixture: fixture, skeleton: skeleton, sender: pair.sender)
                _ = try await third.receiver.set(keypath: "message.setComposer", value: .string("C to everyone"), requester: third.recipient)
                _ = try await third.receiver.set(keypath: "sendComposedMessage", value: .object([:]), requester: third.recipient)
                participants.append((third.receiver, third.recipient))
                expected.insert("C to everyone")
            }
            var threadIDs = Set<String>()
            for (chat, owner) in participants {
                let state = try object(try await chat.get(keypath: "state", requester: owner))
                let messages = BindingChatValue.list(state["messages"]) ?? []
                XCTAssertEqual(Set(messages.compactMap { string(BindingChatValue.object($0)?["body"]) }), expected,
                    "Every accepted participant must receive the same messages, not only their local sends")
                let threads = BindingChatValue.list(state["threads"]) ?? []
                XCTAssertEqual(threads.count, 1)
                threadIDs.formUnion(threads.compactMap { string(BindingChatValue.object($0)?["id"]) })
            }
            XCTAssertEqual(threadIDs.count, 1)
            // The actual surface must offer a human-message send action too.
            XCTAssertTrue(buttons(skeleton).contains { $0.keypath == "chatHub.sendComposedMessage" })
        }
    }

    func testButlerPushOpensAcceptedThreadBeforeFirstMessage() async throws { try await push(entry: 0) }
    func testComponentPushOpensAcceptedThreadBeforeFirstMessage() async throws { try await push(entry: 1) }
    private func push(entry: Int) async throws {
        let server = Inv11ChatServer()
        try await withFixture { fixture in
            let pair = try await sharedInvitePair(server: server, fixture: fixture, skeleton: try surfaces()[entry])
            let url = try XCTUnwrap(BindingChatNotificationRoute.url(userInfo: ["payload": ["threadID": pair.threadID]]))
            let threadID = try XCTUnwrap(BindingChatNotificationRoute.threadID(from: url))
            let result = try object(try await pair.receiver.set(keypath: "ui.setCurrentThread",
                value: .string(threadID), requester: pair.recipient))
            XCTAssertEqual(string(result["threadID"]), pair.threadID,
                "An accepted thread from a notification must open before a local message creates a cached row")
        }
    }
}

@MainActor
private struct Fixture {
    let vault: EphemeralIdentityVault
    let owner: Identity
    let resolver: CellResolver
}

@MainActor
private func withFixture(_ run: (Fixture) async throws -> Void) async throws {
    let oldVault = CellBase.defaultIdentityVault
    let oldResolver = CellBase.defaultCellResolver
    let oldAccess = CellBase.debugValidateAccessForEverything
    let vault = EphemeralIdentityVault()
    CellBase.defaultIdentityVault = vault
    CellBase.defaultCellResolver = CellResolver.sharedInstance
    CellBase.debugValidateAccessForEverything = false
    defer {
        CellBase.defaultIdentityVault = oldVault
        CellBase.defaultCellResolver = oldResolver
        CellBase.debugValidateAccessForEverything = oldAccess
    }
    var owner = Identity(UUID().uuidString, displayName: "Synthetic owner", identityVault: vault)
    await vault.addIdentity(identity: &owner, for: "inv10-owner-\(UUID().uuidString)")
    try await run(Fixture(vault: vault, owner: owner, resolver: CellResolver.sharedInstance))
}

@MainActor
private func restoredChat(owner: Identity, state: Object) async throws -> BindingPersonalChatHubCell {
    let fresh = await BindingPersonalChatHubCell(owner: owner)
    var encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(fresh)) as? [String: Any])
    encoded["cachedState"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
    return try JSONDecoder().decode(BindingPersonalChatHubCell.self, from: JSONSerialization.data(withJSONObject: encoded))
}

@MainActor
private func invitePair(fixture: Fixture, skeleton: SkeletonElement, sender existing: BindingPersonalChatHubCell? = nil) async throws
    -> (sender: BindingPersonalChatHubCell, receiver: BindingPersonalChatHubCell, recipient: Identity, threadID: String, descriptor: Object) {
    let id = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    let recipientVault = EphemeralIdentityVault()
    var recipient = Identity(UUID().uuidString, displayName: "Synthetic recipient", identityVault: recipientVault)
    await recipientVault.addIdentity(identity: &recipient, for: "inv10-recipient-\(id)")
    XCTAssertNotEqual(recipient.uuid, fixture.owner.uuid)
    let contact = await BindingContactEndpointCell(owner: recipient)
    let name = "Inv10Contact\(id)"
    // A separately signed owner grant isolates the chat wiring from first-contact
    // admission. The fixture does not bypass GeneralCell access validation.
    let agreement = Agreement(owner: recipient)
    agreement.addGrant("rw--", for: "contact.request")
    agreement.addGrant("rw--", for: "ticket.status")
    let admitted = await contact.addAgreement(agreement, for: fixture.owner, authorizedBy: recipient)
    XCTAssertEqual(admitted, .signed)
    try await fixture.resolver.registerNamedEmitCell(name: name, emitCell: contact, scope: .scaffoldUnique, identity: recipient)
    let descriptor = try object(try await contact.set(keypath: "publishEndpoint", value: .object([
        "endpointId": .string(name), "cell": .string("cell:///\(name)"),
        "purposes": .list([.string("purpose://contact.introduction")]),
        "acceptedTopics": .list([.string("contact.request")])
    ]), requester: recipient))
    let sender: BindingPersonalChatHubCell
    if let existing { sender = existing } else { sender = await BindingPersonalChatHubCell(owner: fixture.owner) }
    let invite = try XCTUnwrap(buttons(skeleton).first { $0.keypath == "chatHub.invite" })
    let delivery = try object(try await sender.set(keypath: invite.keypath, value: .object([
        "title": .string("Synthetic conversation"), "profileID": .string(name),
        "userUUID": .string(recipient.uuid), "contactEndpoint": .object(descriptor)
    ]), requester: fixture.owner))
    XCTAssertEqual(string(delivery["status"]), "delivered")
    let receiver = await BindingPersonalChatHubCell(owner: recipient)
    _ = try await receiver.set(keypath: "contactInbox.refresh", value: .object([
        "endpointCell": .string("cell:///\(name)")
    ]), requester: recipient)
    let accept = try XCTUnwrap(buttons(skeleton).first { $0.keypath == "chatHub.acceptInvite" })
    let accepted = try object(try await receiver.set(keypath: accept.keypath,
        value: accept.payload ?? .object([:]), requester: recipient))
    XCTAssertEqual(string(accepted["status"]), "accepted")
    let contactState = try object(try await contact.get(keypath: "privateState", requester: recipient))
    let ticket = try object(BindingChatValue.list(contactState["tickets"])?.first)
    let request = try object(ticket["requestPayload"])
    let intro = try object(request["payload"])
    let threadID = try XCTUnwrap(string(intro["introThreadID"]))
    return (sender, receiver, recipient, threadID, descriptor)
}

@MainActor
private func sharedInvitePair(server: Inv11ChatServer, fixture: Fixture, skeleton: SkeletonElement,
                              sender existing: BindingPersonalChatHubCell? = nil) async throws
    -> (sender: BindingPersonalChatHubCell, receiver: BindingPersonalChatHubCell, recipient: Identity, threadID: String) {
    let recipientVault = EphemeralIdentityVault()
    var recipient = Identity(UUID().uuidString, displayName: "Synthetic recipient", identityVault: recipientVault)
    await recipientVault.addIdentity(identity: &recipient, for: "inv11-" + UUID().uuidString)
    let sender: BindingPersonalChatHubCell
    if let existing { sender = existing } else {
        sender = await BindingPersonalChatHubCell(owner: fixture.owner)
        sender.chatTransport = server.client(fixture.owner.uuid)
    }
    let receiver = await BindingPersonalChatHubCell(owner: recipient)
    receiver.chatTransport = server.client(recipient.uuid)
    let invite = try XCTUnwrap(buttons(skeleton).first { $0.keypath == "chatHub.invite" })
    let result = try object(try await sender.set(keypath: invite.keypath,
        value: .object(["userUUID": .string(recipient.uuid), "title": .string("Shared chat")]), requester: fixture.owner))
    XCTAssertEqual(BindingChatValue.bool(result["ok"]), true)
    let id = try XCTUnwrap(string(BindingChatValue.nested("thread.id", in: result)))
    _ = try await receiver.set(keypath: "contactInbox.refresh", value: .object([:]), requester: recipient)
    let accept = try XCTUnwrap(buttons(skeleton).first { $0.keypath == "chatHub.acceptInvite" })
    let accepted = try object(try await receiver.set(keypath: accept.keypath, value: accept.payload ?? .object([:]), requester: recipient))
    XCTAssertEqual(string(accepted["status"]), "accepted")
    return (sender, receiver, recipient, id)
}

@MainActor
private func surfaces() throws -> [SkeletonElement] {
    [try XCTUnwrap(ConfigurationCatalogCell.personalInviteChatMenuConfiguration().skeleton),
     ComponentPaletteCatalog.embeddedChatCard().recipe.skeletonTemplate]
}

private func object(_ value: ValueType?) throws -> Object { try XCTUnwrap(BindingChatValue.object(value)) }
private func string(_ value: ValueType?) -> String? { BindingChatValue.string(value) }

private func buttons(_ element: SkeletonElement) -> [SkeletonButton] {
    switch element {
    case .Button(let button): return [button]
    case .VStack(let stack): return stack.elements.flatMap(buttons)
    case .HStack(let stack): return stack.elements.flatMap(buttons)
    case .ScrollView(let scroll): return scroll.elements.flatMap(buttons)
    case .Section(let section): return section.content.flatMap(buttons)
    case .Tabs(let tabs): return tabs.panels.flatMap { $0.content.flatMap(buttons) }
    case .Grid(let grid): return grid.elements.flatMap(buttons)
    case .ZStack(let stack): return stack.elements.flatMap(buttons)
    default: return []
    }
}

private final class Inv10InteractionSpyCell: BindingRuntimeBindingCell {
    nonisolated(unsafe) var interactionCount = 0
    required init(owner: Identity) async {
        await super.init(owner: owner)
        await installRuntimeBindings(owner: owner)
        await markRuntimeBindingsInstalled()
    }
    nonisolated required init(from decoder: Decoder) throws { try super.init(from: decoder) }
    override func installRuntimeBindings(owner: Identity) async {
        ensureAgreementGrant("rw--", for: "relations.recordInteraction")
        await registerSet(key: "relations.recordInteraction", owner: owner,
            input: .object([:]), returns: .object([:])) { [weak self] _, _ in
                self?.interactionCount += 1
                return .object(["ok": .bool(true)])
            }
    }
}

private actor Inv10LookupGate {
    private var entered = false
    private var released = false
    private var continuation: CheckedContinuation<Void, Never>?
    func pause() async {
        entered = true
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func waitUntilEntered() async -> Bool {
        for _ in 0..<500 {
            if entered { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
    func release() { released = true; continuation?.resume(); continuation = nil }
}

private final class Inv10DelayedRelationsCell: BindingRuntimeBindingCell {
    let gate = Inv10LookupGate()
    required init(owner: Identity) async {
        await super.init(owner: owner)
        await installRuntimeBindings(owner: owner)
        await markRuntimeBindingsInstalled()
    }
    nonisolated required init(from decoder: Decoder) throws { try super.init(from: decoder) }
    override func installRuntimeBindings(owner: Identity) async {
        ensureAgreementGrant("rw--", for: "relations.reach")
        await registerSet(key: "relations.reach", owner: owner,
            input: .object([:]), returns: .object([:])) { [weak self] _, _ in
                await self?.gate.pause()
                return .object(["status": .string("reachable"),
                    "relation": .object(["id": .string("lookup-result"), "displayName": .string("Next")]),
                    "reach": .object([:])])
            }
    }
}
