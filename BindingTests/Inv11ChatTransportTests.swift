import XCTest
import CellBase
@testable import Binding

/// Per-test server, injected behind exactly the app's transport boundary.
/// Serial actor state is scoped to this fixture, never a production registry.
actor Inv11ChatServer {
    struct Thread {
        let id: String
        var title: String
        var members: Set<String>
        var pending: Set<String>
        var messages: [Object] = []
    }
    private var threads: [String: Thread] = [:]
    private var serial = 0
    private var fail = false
    func setUnavailable(_ value: Bool) { fail = value }
    nonisolated func client(_ identity: String) -> any BindingChatTransport { Client(server: self, identity: identity) }
    private struct Client: BindingChatTransport {
        let server: Inv11ChatServer
        let identity: String
        func request(_ path: String, payload: Object?) async throws -> Object {
            // Exercise JSON values on both sides, not shared Swift object identity.
            let decoded = try payload.map { try JSONDecoder().decode(Object.self, from: JSONEncoder().encode($0)) }
            let reply = try await server.request(path, payload: decoded, identity: identity)
            return try JSONDecoder().decode(Object.self, from: JSONEncoder().encode(reply))
        }
    }
    func request(_ path: String, payload: Object?, identity: String) throws -> Object {
        if fail { throw URLError(.notConnectedToInternet) }
        let payload = payload ?? [:]
        let id = BindingChatValue.string(payload["threadID"])
        let denied: Object = ["ok": .bool(false), "error": .bool(true)]
        if path == "identity" { return ["uuid": .string(identity)] }
        if path == "state" {
            let visible = threads.values.filter { $0.members.contains(identity) }.sorted { $0.id < $1.id }
            let invites = threads.values.filter { $0.pending.contains(identity) }.sorted { $0.id < $1.id }
            return ["threads": .list(visible.map { .object(row($0, identity: identity)) }),
                    "currentThread": visible.first.map { .object(row($0, identity: identity)) } ?? .null,
                    "messages": .list((visible.first?.messages ?? []).map(ValueType.object)),
                    "invites": .list(invites.map { .object(["id": .string($0.id), "title": .string($0.title),
                        "invitationStatus": .object([identity: .string("pending")])]) }),
                    "blockedUsers": .list([]), "collaborationInvites": .list([])]
        }
        if path == "invite" {
            guard let recipient = BindingChatValue.string(payload["userUUID"]) else { return denied }
            var thread: Thread
            if let id {
                guard let current = threads[id], current.members.contains(identity) else { return denied }
                thread = current
            } else {
                serial += 1
                thread = Thread(id: "shared-\(serial)", title: BindingChatValue.string(payload["title"]) ?? "Chat", members: [identity], pending: [])
            }
            thread.pending.insert(recipient); threads[thread.id] = thread
            return ["ok": .bool(true), "status": .string("invited"), "thread": .object(row(thread, identity: identity))]
        }
        guard let id, var thread = threads[id] else { return denied }
        if path == "accept" || path == "decline" {
            guard thread.pending.remove(identity) != nil else { return denied }
            if path == "accept" { thread.members.insert(identity) }
            threads[id] = thread
            return ["ok": .bool(true), "status": .string(path == "accept" ? "accepted" : "declined"),
                    "thread": .object(row(thread, identity: identity))]
        }
        guard thread.members.contains(identity) else { return denied }
        if path == "send" {
            guard let body = BindingChatValue.string(payload["body"]), !body.isEmpty else { return denied }
            thread.messages.append(["id": .string("message-\(thread.messages.count)"), "threadID": .string(id),
                "body": .string(body), "authorUUID": .string(identity), "authorDisplayName": .string(identity)])
            threads[id] = thread
            return ["ok": .bool(true), "thread": .object(row(thread, identity: identity))]
        }
        if path == "collaboration/prepare-external" {
            return ["ok": .bool(true), "status": .string("ready_to_share"),
                "invitation": .object(["id": .string("external-\(id)")]),
                "portholeUI": .object(["openURL": .string("https://chat.example.invalid/personal-copilot-v1/collaborate/\(id)")])]
        }
        return denied
    }
    private func row(_ thread: Thread, identity: String) -> Object {
        ["id": .string(thread.id), "title": .string(thread.title),
         "participantUUIDs": .list(thread.members.sorted().map(ValueType.string)),
         "invitationStatus": .object(Dictionary(uniqueKeysWithValues: thread.members.map { ($0, ValueType.string("accepted")) })),
         "messages": .list(thread.members.contains(identity) ? thread.messages.map(ValueType.object) : []),
         "composer": .object(["body": .string(""), "contentType": .string("text/plain")])]
    }
}

@MainActor
final class Inv11ChatTransportTests: XCTestCase {
    func testNativeRequestResourceMatchesServerGolden() {
        XCTAssertEqual(BindingNativeChatWire.resource(method: "GET", path: "/personal-copilot-v1/chat/api/state", body: Data(), nonce: "test-nonce", evidenceReference: "reference", linkID: "link"),
            "personal-chat:GET:/personal-copilot-v1/chat/api/state:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855:test-nonce:reference:link")
    }

    func testFailedSendKeepsDraftAndNeverAppendsLocalMessage() async throws {
        let oldVault = CellBase.defaultIdentityVault, oldResolver = CellBase.defaultCellResolver
        let vault = EphemeralIdentityVault()
        CellBase.defaultIdentityVault = vault; CellBase.defaultCellResolver = CellResolver.sharedInstance
        defer { CellBase.defaultIdentityVault = oldVault; CellBase.defaultCellResolver = oldResolver }
        var owner = Identity(UUID().uuidString, displayName: "Synthetic", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "inv11-failure-" + UUID().uuidString)
        let server = Inv11ChatServer()
        let chat = await BindingPersonalChatHubCell(owner: owner)
        chat.chatTransport = server.client(owner.uuid)
        _ = try await chat.set(keypath: "invite", value: .object(["userUUID": .string("B")]), requester: owner)
        _ = try await chat.set(keypath: "message.setComposer", value: .string("Keep this draft"), requester: owner)
        await server.setUnavailable(true)
        let failed = try await chat.set(keypath: "sendComposedMessage", value: .object([:]), requester: owner)
        XCTAssertEqual(BindingChatValue.bool(BindingChatValue.object(failed)?["ok"]), false)
        let draft = try await chat.get(keypath: "state.messageComposer.body", requester: owner)
        XCTAssertEqual(BindingChatValue.string(draft), "Keep this draft")
        let state = BindingChatValue.object(try await chat.get(keypath: "state", requester: owner))
        XCTAssertEqual(BindingChatValue.list(state?["messages"])?.count, 0)
        XCTAssertEqual(BindingChatValue.list(state?["threads"])?.count, 0)
    }

    func testDecodedInv10CellInstallsConnectedRuntimeAndDropsLocalMessageProjection() async throws {
        let oldVault = CellBase.defaultIdentityVault
        let vault = EphemeralIdentityVault(); CellBase.defaultIdentityVault = vault
        defer { CellBase.defaultIdentityVault = oldVault }
        var owner = Identity(UUID().uuidString, displayName: "Synthetic", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "inv11-decode-" + UUID().uuidString)
        let old = await BindingPersonalChatHubCell(owner: owner)
        let decoded = try JSONDecoder().decode(BindingConnectedPersonalChatHubCell.self, from: JSONEncoder().encode(old))
        // This installs bindings only; no state read, network, or saved receipt lookup.
        await decoded.installRuntimeBindings(owner: owner)
        XCTAssertTrue(decoded.chatTransport is BindingNativeChatTransport)
    }

    func testButlerAndComponentExternalLinkTargetsTheCurrentSharedThread() async throws {
        let oldVault = CellBase.defaultIdentityVault, oldResolver = CellBase.defaultCellResolver
        let vault = EphemeralIdentityVault()
        CellBase.defaultIdentityVault = vault; CellBase.defaultCellResolver = CellResolver.sharedInstance
        defer { CellBase.defaultIdentityVault = oldVault; CellBase.defaultCellResolver = oldResolver }
        var owner = Identity(UUID().uuidString, displayName: "Synthetic", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "inv11-external-" + UUID().uuidString)
        let relations = await BindingRelationsCell(owner: owner)
        try await CellResolver.sharedInstance.registerNamedEmitCell(name: "Relations", emitCell: relations, scope: .identityUnique, identity: owner)
        _ = try await relations.set(keypath: "relations.upsert", value: .object([
            "contacts": .list([.object(["displayName": .string("Synthetic External"), "email": .string("external@example.invalid")])])
        ]), requester: owner)
        for action in ["assistant.acceptSuggestion", "chatHub.invite"] {
            let server = Inv11ChatServer()
            let chat = await BindingPersonalChatHubCell(owner: owner)
            chat.chatTransport = server.client(owner.uuid)
            chat.localLanguageResponder = { _ in
                ButlerLanguageSupport.Reply(answer: "Velg invitasjonen.", helper: "invite", confidence: 0.95, reason: "Invitasjon")
            }
            let invited = BindingChatValue.object(try await chat.set(keypath: "invite",
                value: .object(["userUUID": .string("B")]), requester: owner)) ?? [:]
            let id = try XCTUnwrap(BindingChatValue.string(BindingChatValue.nested("thread.id", in: invited)))
            _ = try await chat.set(keypath: "prompt.submit", value: .string("inviter Synthetic External"), requester: owner)
            _ = try await chat.set(keypath: "assistant.setCandidateQuery", value: .string("Synthetic External"), requester: owner)
            let result = BindingChatValue.object(try await chat.set(keypath: action, value: .object([:]), requester: owner)) ?? [:]
            XCTAssertEqual(BindingChatValue.string(result["status"]), "ready_to_share")
            XCTAssertEqual(BindingChatValue.string(BindingChatValue.nested("preparedInvite.link", in: result)),
                "https://chat.example.invalid/personal-copilot-v1/collaborate/" + id)
            XCTAssertEqual(BindingChatValue.bool(BindingChatValue.nested("preparedInvite.requiresUserToPressSend", in: result)), true)
        }
    }

    func testSmokeJSONShapeAndUninvitedReadWriteDecline() async throws {
        let server = Inv11ChatServer()
        let a = server.client("A"), b = server.client("B"), outsider = server.client("outsider")
        let invitation = try await a.request("invite", payload: ["userUUID": .string("B")])
        let id = try XCTUnwrap(BindingChatValue.string(BindingChatValue.nested("thread.id", in: invitation)))
        let refused = try await outsider.request("send", payload: ["threadID": .string(id), "body": .string("intrusion")])
        XCTAssertEqual(BindingChatValue.bool(refused["ok"]), false)
        let state = try await outsider.request("state", payload: nil)
        XCTAssertEqual(BindingChatValue.list(state["threads"])?.count, 0)
        _ = try await b.request("decline", payload: ["threadID": .string(id)])
        let accept = try await b.request("accept", payload: ["threadID": .string(id)])
        XCTAssertEqual(BindingChatValue.bool(accept["ok"]), false)
    }

    func testLiteralSmokeStateDecodesWithoutChangingWireShape() throws {
        let bytes = Data(#"{"threads":[{"id":"shared","title":"Chat","participantUUIDs":["A","B"],"invitationStatus":{"A":"accepted","B":"accepted"},"composer":{"body":"","contentType":"text/plain"},"messages":[{"id":"m1","threadID":"shared","authorUUID":"A","authorDisplayName":"A","body":"hello"}]}],"currentThread":{"id":"shared","messages":[{"id":"m1","body":"hello"}]},"messages":[{"id":"m1","body":"hello"}],"invites":[],"collaborationInvites":[]}"#.utf8)
        let state = try JSONDecoder().decode(Object.self, from: bytes)
        let thread = try XCTUnwrap(BindingChatValue.object(BindingChatValue.list(state["threads"])?.first))
        XCTAssertEqual(BindingChatValue.string(thread["id"]), "shared")
        XCTAssertEqual(BindingChatValue.list(thread["participantUUIDs"])?.count, 2)
        let message = try XCTUnwrap(BindingChatValue.object(BindingChatValue.list(thread["messages"])?.first))
        XCTAssertEqual(BindingChatValue.string(message["body"]), "hello")
    }
}
