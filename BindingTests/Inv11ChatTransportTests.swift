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
        XCTAssertEqual(BindingChatValue.bool(BindingChatValue.object(failed)?["ok"]), false, "send result=\(failed)")
        XCTAssertEqual(BindingChatValue.string(BindingChatValue.object(failed)?["status"]), "blocked")
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
        _ = try await old.set(keypath: "acceptInvite", value: .object([:]), requester: owner)
        _ = try await old.set(keypath: "setComposer", value: .string("Historical local message"), requester: owner)
        _ = try await old.set(keypath: "sendComposedMessage", value: .object([:]), requester: owner)
        let before = BindingChatValue.list(try await old.get(keypath: "messages", requester: owner))
        XCTAssertEqual(before?.count, 1)
        let decoded = try JSONDecoder().decode(BindingConnectedPersonalChatHubCell.self, from: JSONEncoder().encode(old))
        // This installs bindings only; no state read, network, or saved receipt lookup.
        try await decoded.ensureRuntimeBindings()
        XCTAssertTrue(decoded.chatTransport is BindingNativeChatTransport)
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
        let state = try XCTUnwrap(encoded["cachedState"] as? [String: Any])
        XCTAssertEqual((state["messages"] as? [Any])?.count, 0)
        XCTAssertEqual((state["threads"] as? [Any])?.count, 0)
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

/// Gates, rather than a fast mock response, prove that connected getters finish
/// while receipt lookup / transport are still suspended. No saved links or HTTP.
private actor Inv14ReadGate {
    private var open = false
    private var continuations: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if open { return }
        await withCheckedContinuation { continuations.append($0) }
    }
    func release() {
        open = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }
}

private actor Inv14ReadTransport: BindingChatTransport {
    let lookupGate = Inv14ReadGate()
    let requestGate = Inv14ReadGate()
    private let linked: Bool
    private var lookupCount = 0
    private var requestCount = 0
    private var fail = false
    init(linked: Bool) { self.linked = linked }
    func canRefreshSharedChat() async -> Bool {
        lookupCount += 1
        await lookupGate.wait()
        return linked
    }
    func request(_ path: String, payload: Object?) async throws -> Object {
        requestCount += 1
        await requestGate.wait()
        if fail { throw URLError(.notConnectedToInternet) }
        let thread: Object = ["id": .string("shared"), "messages": .list([
            .object(["id": .string("m1"), "body": .string("From the shared server")])
        ])]
        return ["threads": .list([.object(thread)]), "currentThread": .object(thread)]
    }
    func counts() -> (Int, Int) { (lookupCount, requestCount) }
    func setUnavailable() { fail = true }
    func waitForRequest() async -> Bool {
        for _ in 0..<200 {
            if requestCount > 0 { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
}

@MainActor
final class Inv14NonblockingChatReadTests: XCTestCase {
    private func withChat(_ run: (BindingConnectedPersonalChatHubCell, Identity) async throws -> Void) async throws {
        let oldVault = CellBase.defaultIdentityVault
        let vault = EphemeralIdentityVault()
        CellBase.defaultIdentityVault = vault
        defer { CellBase.defaultIdentityVault = oldVault }
        var owner = Identity(UUID().uuidString, displayName: "Synthetic inv14", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "inv14-" + UUID().uuidString)
        let chat = await BindingConnectedPersonalChatHubCell(owner: owner)
        try await run(chat, owner)
    }

    func testUnlinkedReadsReturnBeforeReceiptLookupAndNeverRequestTransport() async throws {
        try await withChat { chat, owner in
            let transport = Inv14ReadTransport(linked: false)
            chat.chatTransport = transport
            let returned = expectation(description: "all getters return while person-link lookup is suspended")
            let reads = Task {
                for prefix in ["", "chatHub."] {
                    for key in ["state", "threads", "messages", "state.threads", "state.messages", "state.contactInbox.incomingInvites"] {
                        _ = try await chat.get(keypath: prefix + key, requester: owner)
                    }
                }
                returned.fulfill()
            }
            await fulfillment(of: [returned], timeout: 2)
            let pending = chat.readRefreshTask
            await transport.lookupGate.release()
            await transport.requestGate.release()
            try await reads.value
            await pending?.value
            let counts = await transport.counts()
            XCTAssertEqual(counts.0, 1, "Concurrent skeleton reads must coalesce receipt discovery")
            XCTAssertEqual(counts.1, 0, "No completed person-link means no transport request")
        }
    }

    func testLinkedReadsReturnCachedStateWhileTransportWaitsThenApplyRefresh() async throws {
        try await withChat { chat, owner in
            let transport = Inv14ReadTransport(linked: true)
            chat.chatTransport = transport
            await transport.lookupGate.release()
            let returned = expectation(description: "state returns before transport response")
            let read = Task {
                let state = BindingChatValue.object(try await chat.get(keypath: "state", requester: owner))
                XCTAssertEqual(BindingChatValue.list(state?["messages"])?.count, 0)
                for key in ["threads", "messages", "chatHub.state.threads"] {
                    _ = try await chat.get(keypath: key, requester: owner)
                }
                returned.fulfill()
            }
            await fulfillment(of: [returned], timeout: 2)
            let entered = await transport.waitForRequest()
            XCTAssertTrue(entered, "A linked read starts a background transport refresh")
            let pending = chat.readRefreshTask
            let counts = await transport.counts()
            XCTAssertEqual(counts.1, 1, "Repeated reads must not multiply an in-flight request")
            await transport.requestGate.release()
            try await read.value
            await pending?.value
            let body = try await chat.get(keypath: "state.currentThread.id", requester: owner)
            XCTAssertEqual(BindingChatValue.string(body), "shared")
            // The second read returns the populated cache, even if its new refresh fails.
            await transport.setUnavailable()
            let cached = BindingChatValue.object(try await chat.get(keypath: "state", requester: owner))
            XCTAssertEqual(BindingChatValue.list(cached?["messages"])?.count, 1)
            await chat.readRefreshTask?.value
            let thread = try await chat.get(keypath: "state.currentThread", requester: owner)
            XCTAssertEqual(thread, .null, "Failed refresh must still discard stale authorized projection")
        }
    }

    func testExplicitPushRefreshWinsOverPendingReadDiscovery() async throws {
        try await withChat { chat, owner in
            let transport = Inv14ReadTransport(linked: true)
            chat.chatTransport = transport
            _ = try await chat.get(keypath: "threads", requester: owner)
            let pending = chat.readRefreshTask
            await transport.requestGate.release()
            // This is the push handler's existing awaited refresh + select path.
            let result = BindingChatValue.object(try await chat.set(keypath: "ui.setCurrentThread",
                value: .string("shared"), requester: owner))
            XCTAssertEqual(BindingChatValue.string(result?["threadID"]), "shared")
            await transport.lookupGate.release()
            await pending?.value
            let counts = await transport.counts()
            XCTAssertEqual(counts.1, 1, "Late discovery must not supersede the explicit push refresh")
        }
    }
}
