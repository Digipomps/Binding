// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

@_spi(Testing) import CellBase
import enum CellBase.IdentityVaultError
import CellApple
import Foundation
import XCTest
@testable import Binding

final class PersonEntityReadClientTests: XCTestCase {
    private typealias C = BindingPersonEntityReadRouteContract

    func testPartialReplyPreservesNullValueAndExactOriginWithoutInventingUnavailableData() throws {
        let fixture = replyFixture()
        let result = try PersonEntityReadResult.decode(.object(fixture), keypaths: replyPaths,
            origin: replyOrigin, anchorUUID: replyAnchor)
        XCTAssertEqual(result.status, .partial)
        XCTAssertEqual(result.fragments.count, 2)
        XCTAssertEqual(result.fragments[0].value, .null, "a returned JSON null is a value, not a missing fragment")
        XCTAssertEqual(result.fragments[0].sourceOrigin, replyOrigin)
        XCTAssertEqual(result.fragments[0].sourceReference, "cell:///" + replyAnchor)
        XCTAssertNil(result.fragments[1].value)
        XCTAssertNil(result.fragments[1].sourceOrigin)
        XCTAssertNil(result.fragments[1].sourceReference)
    }

    func testReplyRejectsChangedSourceRequestCompletenessAndHiddenDeniedValues() throws {
        let original = replyFixture()
        let topChanges: [(String, ValueType)] = [
            ("status", .string("complete")), ("schema", .string("future-schema")),
            ("revisionVerified", .bool(true)), ("retained", .bool(true)),
            ("consistency", .string("coherent-snapshot")), ("hidden", .string("unexpected"))
        ]
        for (key, value) in topChanges {
            var changed = original; changed[key] = value
            assertInvalidReply(changed)
        }
        guard case let .list(rows)? = original["fragments"], case let .object(first) = rows[0],
              case let .object(second) = rows[1] else { return XCTFail("invalid synthetic reply") }
        let rowChanges: [(String, ValueType)] = [
            ("sourceOrigin", .string("https://other.example")),
            ("sourceReference", .string("cell:///" + UUID().uuidString)),
            ("requestID", .string("1")), ("keypath", .string("another.path")),
            ("revision", .integer(1)), ("status", .string("denied")),
            ("value", .float(.infinity)), ("value", .string(String(repeating: "x", count: 65_536)))
        ]
        for (key, value) in rowChanges {
            var changed = original, row = first; row[key] = value
            changed["fragments"] = .list([.object(row), .object(second)])
            assertInvalidReply(changed)
        }
        var deniedWithValue = second
        deniedWithValue["value"] = .string("must not be disclosed")
        var changed = original
        changed["fragments"] = .list([.object(first), .object(deniedWithValue)])
        assertInvalidReply(changed)
        changed["fragments"] = .list([.object(first)])
        assertInvalidReply(changed)
        changed["fragments"] = .list([.object(first), .object(first)])
        assertInvalidReply(changed)
    }

    func testWholeQueryDenialCarriesNoValuesOrServerErrorText() throws {
        let value: ValueType = .object(["status": .string("denied"),
            "error": .object(["code": .string("person-entity-link-required"),
                              "message": .string("synthetic-backend-detail-not-for-display")])])
        let result = try PersonEntityReadResult.decode(value, keypaths: replyPaths,
            origin: replyOrigin, anchorUUID: replyAnchor)
        XCTAssertEqual(result.status, .denied)
        XCTAssertTrue(result.fragments.isEmpty)
        XCTAssertFalse(String(describing: result).contains("synthetic-backend-detail"))
    }

    private var replyOrigin: String { "https://synthetic-person.example" }
    private var replyAnchor: String { "CD31755A-8B1C-43AB-A4C4-73BC80EC0ACF" }
    private var replyPaths: [String] { ["entityRepresentation.name", "relations.people"] }
    private func replyFixture() -> Object {
        let first: ValueType = .object([
            "requestID": .string("0"), "keypath": .string(replyPaths[0]), "status": .string("available"),
            "sourceOrigin": .string(replyOrigin), "sourceReference": .string("cell:///" + replyAnchor),
            "revision": .null, "value": .null
        ])
        let second: ValueType = .object([
            "requestID": .string("1"), "keypath": .string(replyPaths[1]), "status": .string("unavailable"),
            "sourceOrigin": .null, "sourceReference": .null, "revision": .null,
            "error": .object(["code": .string("entity-data-read-failed"), "message": .string("This requested fragment is not available.")])
        ])
        return ["schema": .string("haven.entity-data-query-result.v1"), "status": .string("partial"),
                "consistency": .string("independent-reads"), "revisionVerified": .bool(false),
                "retained": .bool(false), "fragments": .list([first, second])]
    }
    private func assertInvalidReply(_ object: Object, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try PersonEntityReadResult.decode(.object(object), keypaths: replyPaths,
            origin: replyOrigin, anchorUUID: replyAnchor), file: file, line: line)
    }

    func testMissingExactKeyAfterRelaunchDeniesWithoutProvisioning() async throws {
        let (entry, phone) = try await fixture()
        let lookup = expectation(description: "existing UUID lookup")
        let client = PersonEntityReadClient { uuid in
            XCTAssertEqual(uuid, phone.uuid)
            lookup.fulfill()
            return nil
        }
        do { try await client.connect(entry: entry); XCTFail("missing historical key must not connect") }
        catch { XCTAssertEqual(error as? C.Failure, .denied) }
        await fulfillment(of: [lookup], timeout: 1)
        await client.close()
    }

    func testDifferentKeyCannotRepairAStoredPersonReceipt() async throws {
        let (entry, _) = try await fixture()
        let otherVault = EphemeralIdentityVault()
        var other = Identity(UUID().uuidString, displayName: "synthetic-other", identityVault: otherVault)
        await otherVault.addIdentity(identity: &other, for: "private")
        let client = PersonEntityReadClient { _ in other }
        do { try await client.connect(entry: entry); XCTFail("different key must not connect") }
        catch { XCTAssertEqual(error as? C.Failure, .denied) }
        await client.close()
        let disconnected = AppleBridgeTransport()
        let fallback = await disconnected.identityVault(for: other)
        let fallbackIdentity = await fallback.identity(for: "private", makeNewIfNotFound: true)
        XCTAssertNil(fallbackIdentity, "a disconnected transport must never provision an app key")
        let nonce = await otherVault.randomBytes64()
        let challenge = try IdentitySigningChallenge.signingData(for: other, trustedIdentity: other,
            domain: C.domain, resource: "synthetic-disconnected-resource", action: "checkIdentityOrigin",
            audience: "GeneralCell", nonce: try XCTUnwrap(nonce))
        do {
            _ = try await fallback.signMessageForIdentity(messageData: challenge, identity: other)
            XCTFail("the disconnected fallback has no signing authority")
        } catch { XCTAssertTrue(error is IdentityVaultError) }
        let bound = AppleBridgeTransport()
        await bound.close()
        let closedVault = await bound.identityVault(for: other)
        let closedIdentity = await closedVault.identity(for: "private", makeNewIfNotFound: true)
        XCTAssertNil(closedIdentity, "closing a bound transport must hide its former local signer")
        do {
            _ = try await closedVault.signMessageForIdentity(messageData: challenge, identity: other)
            XCTFail("a closed transport must not return its former signing vault")
        } catch { XCTAssertTrue(error is IdentityVaultError) }
    }

    func testChangedEvidenceReferenceIsRejectedBeforeKeyLookup() async throws {
        var (entry, _) = try await fixture()
        entry.personEvidenceReference = String(repeating: "b", count: 64)
        let client = PersonEntityReadClient { _ in XCTFail("invalid receipt must not request a key"); return nil }
        do { try await client.connect(entry: entry); XCTFail("changed evidence reference must not connect") }
        catch { XCTAssertEqual(error as? C.Failure, .denied) }
    }

    func testDescriptorRequiresExactOriginReceiptKeyGatewayAndThreeApprovedScopes() async throws {
        let (entry, phone) = try await fixture()
        let now = Date(), reference = try XCTUnwrap(entry.personEvidenceReference), gateway = UUID().uuidString
        let descriptor = C.Descriptor(origin: entry.origin, evidenceReference: reference, linkID: entry.record.linkID,
            linkedIdentityUUID: phone.uuid, linkedKeyFingerprint: try XCTUnwrap(phone.signingPublicKeyFingerprint),
            expiresAt: now.addingTimeInterval(60).timeIntervalSince1970, scopes: [
                .init(role: .gateway, domain: C.domain, cellUUID: gateway),
                .init(role: .query, domain: C.domain, cellUUID: UUID().uuidString),
                .init(role: .anchor, domain: C.domain, cellUUID: UUID().uuidString)
            ])
        func validate(_ candidate: C.Descriptor, domains: [String]? = nil, gatewayUUID: String? = nil) throws {
            try C.validateDescriptor(candidate, reference: reference, linkID: entry.record.linkID, identity: phone,
                origin: entry.origin, gatewayUUID: gatewayUUID ?? gateway,
                approvedDomains: domains ?? entry.record.approvedDomains, now: now)
        }
        try validate(descriptor)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: C.encode(descriptor)) as? [String: Any])
        let changes: [(String, Any)] = [
            ("schema", "future-schema"), ("status", "ready-with-any-scope"),
            ("origin", "https://other.example"), ("evidenceReference", String(repeating: "0", count: 64)),
            ("linkID", UUID().uuidString), ("linkedIdentityUUID", UUID().uuidString),
            ("linkedKeyFingerprint", "other-key"), ("expiresAt", now.timeIntervalSince1970 - 1),
            ("expiresAt", now.timeIntervalSince1970 + 3600),
            ("scopes", [["role": "gateway", "domain": "private", "cellUUID": gateway]])
        ]
        for (key, value) in changes {
            var changed = original; changed[key] = value
            let decoded = try JSONDecoder().decode(C.Descriptor.self, from: JSONSerialization.data(withJSONObject: changed))
            XCTAssertThrowsError(try validate(decoded), key)
        }
        XCTAssertThrowsError(try validate(descriptor, domains: ["scaffold"]))
        XCTAssertThrowsError(try validate(descriptor, gatewayUUID: UUID().uuidString))
        for scopes in [
            [descriptor.scopes[0], descriptor.scopes[0], descriptor.scopes[2]],
            [descriptor.scopes[0], .init(role: .query, domain: C.domain, cellUUID: gateway), descriptor.scopes[2]],
            [descriptor.scopes[0], .init(role: .query, domain: "scaffold", cellUUID: UUID().uuidString), descriptor.scopes[2]]
        ] {
            var copy = original
            copy["scopes"] = try JSONSerialization.jsonObject(with: C.encode(scopes))
            XCTAssertThrowsError(try validate(JSONDecoder().decode(C.Descriptor.self, from: JSONSerialization.data(withJSONObject: copy))))
        }
        let value = try JSONDecoder().decode(ValueType.self, from: C.encode(descriptor))
        let decoded = try C.decodeDescriptor(value, reference: reference, linkID: entry.record.linkID, identity: phone,
            origin: entry.origin, gatewayUUID: gateway, approvedDomains: entry.record.approvedDomains, now: now)
        XCTAssertEqual(decoded, descriptor)
        guard case var .object(extra) = value else { return XCTFail("Missing object") }
        extra["extraAuthority"] = .string("any-cell")
        XCTAssertThrowsError(try C.decodeDescriptor(.object(extra), reference: reference, linkID: entry.record.linkID,
            identity: phone, origin: entry.origin, gatewayUUID: gateway, approvedDomains: entry.record.approvedDomains, now: now))
    }

    func testCancellationRetiresSuspendedScopeAttemptWithoutClosingItsReplacement() async throws {
        try await exerciseCancellation(duringRead: false)
    }

    func testCancellationRetiresSuspendedReadWithoutClosingItsReplacement() async throws {
        try await exerciseCancellation(duringRead: true)
    }

    private func exerciseCancellation(duringRead: Bool) async throws {
        let (entry, phone) = try await fixture()
        let previous = CellBase.defaultCellResolver
        let resolver = CellResolver.makeIsolatedForTesting()
        CellBase.defaultCellResolver = resolver
        defer { CellBase.defaultCellResolver = previous }
        let serverVault = EphemeralIdentityVault()
        var server = Identity(UUID().uuidString, displayName: "synthetic-bridge", identityVault: serverVault)
        await serverVault.addIdentity(identity: &server, for: "private")
        let publisher = await PersonScopeTestCell(owner: server)
        let descriptor = C.Descriptor(origin: entry.origin, evidenceReference: try XCTUnwrap(entry.personEvidenceReference),
            linkID: entry.record.linkID, linkedIdentityUUID: phone.uuid,
            linkedKeyFingerprint: try XCTUnwrap(phone.signingPublicKeyFingerprint),
            expiresAt: Date().addingTimeInterval(60).timeIntervalSince1970, scopes: [
                .init(role: .gateway, domain: "private", cellUUID: publisher.uuid),
                .init(role: .query, domain: "private", cellUUID: UUID().uuidString),
                .init(role: .anchor, domain: "private", cellUUID: UUID().uuidString)
            ])
        publisher.reply = try JSONDecoder().decode(ValueType.self, from: C.encode(descriptor))
        publisher.queryReply = .object([
            "schema": .string("haven.entity-data-query-result.v1"), "status": .string("complete"),
            "consistency": .string("independent-reads"), "revisionVerified": .bool(false), "retained": .bool(false),
            "fragments": .list([.object([
                "requestID": .string("0"), "keypath": .string("entityRepresentation.name"),
                "status": .string("available"), "sourceOrigin": .string(entry.origin),
                "sourceReference": .string("cell:///" + descriptor.scopes[2].cellUUID),
                "revision": .null, "value": .string("synthetic-after-cancellation")
            ])])
        ])
        try await resolver.registerNamedEmitCell(name: "EntityDataGateway", emitCell: publisher, scope: .template, identity: server)
        let entered = expectation(description: "scope response suspended")
        let closed = expectation(description: "cancelled exact physical attempt closed")
        let barrier = PersonScopeBarrier()
        let heldIndex = duringRead ? 1 : 0
        let rig = PersonBridgeTestRig(owner: server, entered: entered, closed: closed, barrier: barrier, heldIndex: heldIndex)
        let client = PersonEntityReadClient(resolveIdentity: { uuid in uuid == phone.uuid ? phone : nil },
            makeTransport: { endpoint, _ in try await rig.transport(endpoint) })
        if duringRead { try await client.connect(entry: entry) }
        let old = Task {
            if duringRead { _ = try await client.read(keypaths: ["entityRepresentation.name"]) }
            else { try await client.connect(entry: entry) }
        }
        await fulfillment(of: [entered], timeout: 3)
        old.cancel()
        await fulfillment(of: [closed], timeout: 3)
        let retired = await rig.isRetired(heldIndex)
        XCTAssertTrue(retired, "cancellation must close the authenticated gate before the response resumes")
        await client.close()
        try await client.connect(entry: entry)
        let replacementIndex = duringRead ? 3 : 2
        let replacementBefore = await rig.isRetired(replacementIndex)
        XCTAssertFalse(replacementBefore)
        await barrier.resume()
        do { try await old.value; XCTFail("cancelled scope attempt succeeded") }
        catch { XCTAssertTrue(error is CancellationError) }
        let replacementAfter = await rig.isRetired(replacementIndex)
        XCTAssertFalse(replacementAfter, "old cancellation cleanup must not close the later connection")
        let freshRead = try await client.read(keypaths: ["entityRepresentation.name"])
        XCTAssertEqual(freshRead.status, .complete)
        XCTAssertEqual(freshRead.fragments.first?.value, .string("synthetic-after-cancellation"))
        await client.close()
        await rig.close()
        await resolver.unregisterEmitCell(uuid: publisher.uuid)
    }

    func testSharedEndpointUsesExistingBridgePathAndRejectsAlternateOrigins() throws {
        let id = UUID().uuidString
        XCTAssertEqual(try C.endpoint(origin: "https://synthetic-person.example", bridgeID: id).absoluteString,
            "wss://synthetic-person.example/bridgehead/EntityDataGateway/" + id)
        for origin in ["http://synthetic-person.example", "https://user@synthetic-person.example",
                       "https://synthetic-person.example/?token=secret", "https://synthetic-person.example/#fragment"] {
            XCTAssertThrowsError(try C.endpoint(origin: origin))
        }
    }

    /// Real local request/approval/VC/VP signatures. This fixture does not
    /// exercise a human authenticator or establish current server evidence.
    private func fixture() async throws -> (IdentityLinkCompletionStore.Entry, Identity) {
        let origin = "https://staging.haven.digipomps.org", audience = "staging.haven.digipomps.org"
        let vault = EphemeralIdentityVault()
        var phone = Identity(UUID().uuidString, displayName: "synthetic-phone", identityVault: vault)
        await vault.addIdentity(identity: &phone, for: "private")
        var owner = Identity(UUID().uuidString, displayName: "synthetic-person", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "web")
        let now = Date(), expires = now.addingTimeInterval(600)
        let descriptor = try IdentityLinkProtocolService.descriptor(for: phone)
        var request = IdentityEnrollmentRequest(requestID: UUID().uuidString,
            entityBinding: .init(mode: .localEntityAnchor, entityAnchorReference: "cell:///EntityAnchor", audience: audience),
            newIdentity: descriptor, requestedDomains: ["private", "scaffold"], requestedIdentityContexts: ["binding"],
            requestedScopes: [IdentityLinkScope.sameEntity], audience: audience, origin: origin,
            createdAt: IdentityLinkProtocolService.iso8601(now), expiresAt: IdentityLinkProtocolService.iso8601(expires),
            nonce: Data(repeating: 0x31, count: 32), platform: "synthetic", deviceLabel: "Synthetic client")
        let signature = try await phone.sign(data: request.canonicalPayloadData())
        request.proof = .init(byIdentityUUID: phone.uuid, algorithm: descriptor.algorithm, curveType: descriptor.curveType, signature: try XCTUnwrap(signature))
        let approval = try await IdentityLinkProtocolService.approveEnrollmentRequest(request, issuerIdentity: owner,
            createdAt: now, expiresAt: expires, freshAuthPerformedAt: now)
        let credential = try await IdentityLinkProtocolService.issueSameEntityCredential(request: request, approval: approval,
            issuerIdentity: owner, validUntil: expires, revocationReference: nil)
        let challenge = Data(repeating: 0x37, count: 32)
        let presentation = try await IdentityLinkProtocolService.makeVerifierBoundPresentation(credential: credential,
            holderIdentity: phone, challenge: challenge, domain: origin)
        let envelope = IdentityLinkCompletionEnvelope(request: request, approval: approval,
            sameEntityCredential: credential, presentation: presentation,
            issuerIdentity: try IdentityLinkProtocolService.descriptor(for: owner), expectedAudience: audience,
            expectedOrigin: origin, expectedPresentationChallenge: challenge, expectedPresentationDomain: origin)
        let verified = try await IdentityLinkProtocolService.verifyCompletion(envelope, now: now)
        return (.init(origin: origin, record: verified.record, envelope: envelope,
                      storedAt: IdentityLinkProtocolService.iso8601(now), personEvidenceReference: C.digest(verified.requestHash)), phone)
    }
}

private final class PersonScopeTestCell: GeneralCell {
    var reply: ValueType = .null
    var queryReply: ValueType = .null
    override func set(keypath: String, value: ValueType, requester: Identity) async throws -> ValueType? {
        keypath == "entityData.query" ? queryReply : reply
    }
}

private actor PersonScopeBarrier {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false
    func wait() async {
        guard !released else { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func resume() { released = true; continuation?.resume(); continuation = nil }
}

private actor PersonBridgeTestRig {
    let owner: Identity
    let entered: XCTestExpectation
    let closed: XCTestExpectation
    let barrier: PersonScopeBarrier
    let heldIndex: Int
    var clients: [PersonScopeWire] = []
    var servers: [BridgeChannelTransport] = []
    var serverWires: [PersonScopeWire] = []
    init(owner: Identity, entered: XCTestExpectation, closed: XCTestExpectation, barrier: PersonScopeBarrier, heldIndex: Int) {
        self.owner = owner; self.entered = entered; self.closed = closed; self.barrier = barrier
        self.heldIndex = heldIndex
    }
    func transport(_ url: URL) async throws -> BridgeTransportProtocol {
        let first = clients.count == heldIndex, client = PersonScopeWire(), wire = PersonScopeWire()
        client.peer = wire; wire.peer = client
        if first {
            let entered = entered, barrier = barrier, closed = closed
            wire.beforeSend = { command in
                if case .setValueResponse = command.payload { entered.fulfill(); await barrier.wait() }
            }
            client.onClose = { closed.fulfill() }
        }
        let owner = owner
        let server = try BridgeChannelTransport(underlying: wire, endpoint: .init(url: url, domain: "bridge"),
            limits: BridgeChannelLimits(), source: "synthetic-cancellation") { transport, _ in
            let bridge = try await BridgeBase(.init(owner: owner.publicIdentitySnapshot(), transport: transport,
                connection: .inbound(publisherUuid: "EntityDataGateway"), inboundPublisherLookupIdentity: owner))
            try await bridge.setTransport(transport, connection: .inbound(publisherUuid: "EntityDataGateway"))
            return bridge
        }
        clients.append(client); servers.append(server); serverWires.append(wire)
        return client
    }
    func isRetired(_ index: Int) -> Bool {
        guard clients.indices.contains(index) else { return true }
        return clients[index].isClosed && clients[index].sessionClosed
    }
    func close() async { for server in servers { await server.close() } }
}

private final class PersonScopeWire: BridgeTransportProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var delegate: BridgeDelegateProtocol?
    private var closed = false
    weak var peer: PersonScopeWire?
    var beforeSend: (@Sendable (BridgeCommand) async -> Void)?
    var onClose: (@Sendable () -> Void)?
    var isClosed: Bool { lock.withLock { closed } }
    var sessionClosed: Bool { lock.withLock { (delegate as? BridgeChannelTransport)?.session.state == .closed } }
    static func new() -> BridgeTransportProtocol { PersonScopeWire() }
    func setDelegate(_ value: BridgeDelegateProtocol) { lock.withLock { delegate = value } }
    func setup(_ endpointURL: URL, identity: Identity) async throws {}
    func sendData(_ data: Data) async throws {
        guard !isClosed else { throw BridgeChannelAuthentication.Failure.closed }
        let command = try JSONDecoder().decode(BridgeCommand.self, from: data)
        await beforeSend?(command)
        guard !isClosed else { throw BridgeChannelAuthentication.Failure.closed }
        guard let peer, let destination = peer.lock.withLock({ peer.delegate }) else {
            throw BridgeChannelAuthentication.Failure.unavailable
        }
        try destination.validateInboundPayload(data)
        if command.command == .response { try await destination.consumeResponse(command: command) }
        else { try await destination.consumeCommand(command: command) }
    }
    func close() async {
        let changed = lock.withLock { () -> Bool in
            guard !closed else { return false }; closed = true; return true
        }
        if changed { onClose?() }
    }
    func identityVault(for identity: Identity?) async -> IdentityVaultProtocol { BridgeIdentityVault() }
}
