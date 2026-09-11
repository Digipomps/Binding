//
//  IdentityLinkFlowTests.swift
//  BindingTests
//
//  purpose://candidate.entity-link.binding-uses-link — test.binding.completion-persisted m.fl.
//

import XCTest
import CellBase
@testable import Binding

final class IdentityLinkFlowTests: XCTestCase {
    private let origin = "https://staging.haven.digipomps.org"

    // MARK: Billett

    func testTicketDecodeRejectsUntrustedOriginsAndExpiry() throws {
        let good = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
        let decoded = try IdentityLinkTicket.decode(deepLink: try deepLink(good))
        XCTAssertEqual(decoded, good)

        let evil = try makeTicket(origin: "https://haven.attacker.example", audience: "haven.attacker.example", expiresIn: 600)
        XCTAssertThrowsError(try IdentityLinkTicket.decode(deepLink: try deepLink(evil))) { error in
            XCTAssertEqual(error as? IdentityLinkTicket.DecodeError, .untrustedOrigin)
        }
        let wrongAudience = try makeTicket(origin: origin, audience: "somewhere-else", expiresIn: 600)
        XCTAssertThrowsError(try IdentityLinkTicket.decode(deepLink: try deepLink(wrongAudience))) { error in
            XCTAssertEqual(error as? IdentityLinkTicket.DecodeError, .untrustedOrigin)
        }
        let stale = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: -1)
        XCTAssertThrowsError(try IdentityLinkTicket.decode(deepLink: try deepLink(stale))) { error in
            XCTAssertEqual(error as? IdentityLinkTicket.DecodeError, .expired)
        }
        XCTAssertThrowsError(try IdentityLinkTicket.decode(deepLink: "https://staging.haven.digipomps.org/link")) { error in
            XCTAssertEqual(error as? IdentityLinkTicket.DecodeError, .notATicket)
        }
    }

    func testEndpointLookalikesAndDuplicateTicketFieldsAreRejected() throws {
        var ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
        for endpoint in [origin + ".evil.example/link/api", origin + "@evil.example/link/api", origin + ":8443/link/api", origin + "/link/api/../other"] {
            ticket.rendezvousURL = endpoint
            XCTAssertThrowsError(try IdentityLinkTicket.decode(deepLink: deepLink(ticket)))
        }
        ticket.rendezvousURL = origin + "/link/api"
        XCTAssertThrowsError(try IdentityLinkTicket.decode(deepLink: deepLink(ticket) + "&t=duplicate"))
        ticket.presentationDomain = "https://evil.example"
        XCTAssertThrowsError(try IdentityLinkTicket.decode(deepLink: deepLink(ticket)))
        XCTAssertFalse(IdentityLinkTrust.isTrustedOrigin("https://user@staging.haven.digipomps.org"))
    }

    func testReviewAndResetDoNotLoadKeysOrSendRequests() async throws {
        let ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
        let coordinator = IdentityLinkFlowCoordinator(outbox: MemoryIdentityLinkOutbox(), identityProvider: {
            XCTFail("Review must not request a signing identity")
            return nil
        }, completionSaver: { _, _, _, _ in XCTFail("Review must not persist authority") })
        await coordinator.review(deepLink: try deepLink(ticket))
        let reviewed = await coordinator.state
        XCTAssertEqual(reviewed, .reviewing(ticket: ticket))
        await coordinator.reset()
        await coordinator.confirmReviewedEntity()
        let reset = await coordinator.state
        XCTAssertEqual(reset, .idle)
    }

    // MARK: Forespørselen

    func testSignedRequestValidatesAndProducesTheSameWordsAsTheServer() async throws {
        let vault = EphemeralIdentityVault()
        var phone = Identity(UUID().uuidString, displayName: "phone", identityVault: vault)
        await vault.addIdentity(identity: &phone, for: "private")
        let ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)

        let request = try await IdentityLinkFlowCoordinator.makeSignedRequest(ticket: ticket, identity: phone, now: Date())
        XCTAssertEqual(request.nonce, ticket.nonce)
        XCTAssertEqual(request.audience, ticket.audience)
        XCTAssertEqual(request.origin, ticket.origin)
        XCTAssertEqual(request.requestedScopes, [IdentityLinkScope.sameEntity])
        let hash = try await IdentityLinkProtocolService.validateEnrollmentRequest(request)
        XCTAssertEqual(IdentityLinkSAS.words(requestHash: hash).count, 4)
    }

    // MARK: Hele flyten mot en falsk møteplass

    func testCoordinatorRunsFromDeepLinkToDoneAndPersistsTheEnvelope() async throws {
        let vault = EphemeralIdentityVault()
        var phone = Identity(UUID().uuidString, displayName: "phone", identityVault: vault)
        await vault.addIdentity(identity: &phone, for: "private")
        var web = Identity(UUID().uuidString, displayName: "web", identityVault: vault)
        await vault.addIdentity(identity: &web, for: "web")
        let ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
        let transport = FakeRendezvous(issuer: web, ticket: ticket)
        let coordinator = IdentityLinkFlowCoordinator(
            transport: transport,
            outbox: MemoryIdentityLinkOutbox(),
            identityProvider: { phone },
            completionSaver: { envelope, record, origin, reference in await transport.remember(envelope: envelope, record: record, origin: origin, reference: reference) },
            localRuntimeAvailable: { false }
        )

        let done = expectation(description: "done")
        let observer = await coordinator.observe { state in
            if case .done = state { done.fulfill() }
            if case let .failed(message) = state { XCTFail(message) }
        }
        await coordinator.start(deepLink: try deepLink(ticket))
        await fulfillment(of: [done], timeout: 15)
        await coordinator.stopObserving(observer)

        let state = await coordinator.state
        guard case let .done(record, ownerDisplayName, doneOrigin, localConfirmed) = state else {
            return XCTFail("forventet done, fikk \(state)")
        }
        XCTAssertEqual(record.status, .active)
        XCTAssertEqual(record.linkedIdentity.uuid, phone.uuid)
        XCTAssertEqual(ownerDisplayName, ticket.ownerDisplayName)
        XCTAssertEqual(doneOrigin, origin)
        XCTAssertFalse(localConfirmed, "A remote success is not evidence of local activation.")
        let verifiable = await transport.completedEnvelopeWasVerifiable
        XCTAssertTrue(verifiable)
        // test.binding.completion-persisted
        let stored = await transport.remembered
        XCTAssertEqual(stored?.record.linkID, record.linkID)
        XCTAssertEqual(stored?.envelope.request.newIdentity.uuid, phone.uuid)
        XCTAssertEqual(stored?.personEvidenceReference, String(repeating: "a", count: 64))
    }

    func testCoordinatorRefusesAPackageForAnotherRequest() async throws {
        let vault = EphemeralIdentityVault()
        var phone = Identity(UUID().uuidString, displayName: "phone", identityVault: vault)
        await vault.addIdentity(identity: &phone, for: "private")
        var web = Identity(UUID().uuidString, displayName: "web", identityVault: vault)
        await vault.addIdentity(identity: &web, for: "web")
        let ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
        let transport = FakeRendezvous(issuer: web, ticket: ticket, tamperChallenge: true)
        let coordinator = IdentityLinkFlowCoordinator(transport: transport, outbox: MemoryIdentityLinkOutbox(), identityProvider: { phone }, completionSaver: { _, _, _, _ in }, localRuntimeAvailable: { false })

        let failed = expectation(description: "failed")
        let observer = await coordinator.observe { state in
            if case .failed = state { failed.fulfill() }
            if case .done = state { XCTFail("skulle ikke fullføre") }
        }
        await coordinator.start(deepLink: try deepLink(ticket))
        await fulfillment(of: [failed], timeout: 15)
        await coordinator.stopObserving(observer)
        let completeWasCalled = await transport.completeWasCalled
        XCTAssertFalse(completeWasCalled, "ingenting skal sendes når pakken ikke passer")
    }

    func testCompletionResponseCannotChangeOriginOrPresentationDomain() async throws {
        for tamper in [FakeRendezvous.Tamper.pollURL, .completeURL, .presentationDomain] {
            let vault = EphemeralIdentityVault()
            var phone = Identity(UUID().uuidString, displayName: "phone", identityVault: vault)
            await vault.addIdentity(identity: &phone, for: "private")
            var web = Identity(UUID().uuidString, displayName: "web", identityVault: vault)
            await vault.addIdentity(identity: &web, for: "web")
            let ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
            let transport = FakeRendezvous(issuer: web, ticket: ticket, tamper: tamper)
            let coordinator = IdentityLinkFlowCoordinator(transport: transport, outbox: MemoryIdentityLinkOutbox(), identityProvider: { phone },
                completionSaver: { _, _, _, _ in XCTFail("Must not persist a mismatched approval") }, localRuntimeAvailable: { false })
            let failed = expectation(description: "reject mismatched response")
            let observer = await coordinator.observe { state in
                if case .failed = state { failed.fulfill() }
                if case .done = state { XCTFail("Unexpected completion") }
            }
            await coordinator.start(deepLink: try deepLink(ticket))
            await fulfillment(of: [failed], timeout: 10)
            await coordinator.stopObserving(observer)
            let completeWasCalled = await transport.completeWasCalled
            XCTAssertFalse(completeWasCalled)
            await coordinator.reset()
        }
    }

    func testResetWhileLoadingIdentityCannotResumeSigning() async throws {
        let vault = EphemeralIdentityVault()
        var phone = Identity(UUID().uuidString, displayName: "phone", identityVault: vault)
        await vault.addIdentity(identity: &phone, for: "private")
        let gate = IdentityLoadGate()
        let entered = expectation(description: "identity lookup entered")
        let coordinator = IdentityLinkFlowCoordinator(outbox: MemoryIdentityLinkOutbox(), identityProvider: {
            entered.fulfill()
            return await gate.wait()
        }, completionSaver: { _, _, _, _ in XCTFail("Cancelled flow persisted") })
        let ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
        let link = try deepLink(ticket)
        let pending = Task { await coordinator.start(deepLink: link) }
        await fulfillment(of: [entered], timeout: 5)
        await coordinator.reset()
        await gate.release(phone)
        await pending.value
        let state = await coordinator.state
        XCTAssertEqual(state, .idle)
    }

    func testEncryptedExactCompletionSurvivesRestartAndLostResponse() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = Data(repeating: 0x51, count: 32)
        let outbox = EncryptedIdentityLinkOutbox(directory: directory, keyProvider: { _ in key })
        let vault = EphemeralIdentityVault()
        var phone = Identity(UUID().uuidString, displayName: "synthetic-phone", identityVault: vault)
        await vault.addIdentity(identity: &phone, for: "private")
        var web = Identity(UUID().uuidString, displayName: "synthetic-owner", identityVault: vault)
        await vault.addIdentity(identity: &web, for: "web")
        let ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
        let transport = FakeRendezvous(issuer: web, ticket: ticket, failFirstCompletion: true, outbox: outbox)
        let first = IdentityLinkFlowCoordinator(transport: transport, outbox: outbox,
            identityProvider: { phone }, completionSaver: { _, _, _, _ in XCTFail("Lost response cannot activate locally") }, localRuntimeAvailable: { false })
        let pending = expectation(description: "durable recovery offered")
        let observer = await first.observe {
            if case .recovery = $0 { pending.fulfill() }
            if case let .failed(message) = $0 { XCTFail(message); pending.fulfill() }
        }
        await first.start(deepLink: try deepLink(ticket))
        await fulfillment(of: [pending], timeout: 10)
        await first.stopObserving(observer)
        await first.reset()
        let encrypted = try Data(contentsOf: directory.appendingPathComponent("completion.sealed"))
        XCTAssertNil(encrypted.range(of: Data(phone.uuid.utf8)))
        XCTAssertNil(encrypted.range(of: Data(ticket.ownerDisplayName.utf8)))
        let restarted = EncryptedIdentityLinkOutbox(directory: directory, keyProvider: { _ in key })
        let recovered = try await restarted.load()
        XCTAssertNotNil(recovered)
        let second = IdentityLinkFlowCoordinator(transport: transport, outbox: restarted,
            identityProvider: { phone }, completionSaver: { envelope, record, origin, reference in
                await transport.remember(envelope: envelope, record: record, origin: origin, reference: reference)
            }, localRuntimeAvailable: { false })
        await second.beginScanning()
        guard case .recovery = await second.state else { return XCTFail("Restart did not offer recovery") }
        await second.resumePendingCompletion()
        guard case .done = await second.state else { return XCTFail("Exact retry did not complete") }
        let calls = await transport.completionEnvelopes
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls.first, calls.last, "Retry must not sign a new envelope")
        let remaining = try await restarted.load()
        XCTAssertNil(remaining)
    }

    func testRevokedCompletionRetryNeverActivatesLocalAuthority() async throws {
        let outbox = MemoryIdentityLinkOutbox()
        let vault = EphemeralIdentityVault()
        var phone = Identity(UUID().uuidString, displayName: "phone", identityVault: vault)
        await vault.addIdentity(identity: &phone, for: "private")
        var web = Identity(UUID().uuidString, displayName: "web", identityVault: vault)
        await vault.addIdentity(identity: &web, for: "web")
        let ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
        let transport = FakeRendezvous(issuer: web, ticket: ticket, failFirstCompletion: true, outbox: outbox)
        let coordinator = IdentityLinkFlowCoordinator(transport: transport, outbox: outbox,
            identityProvider: { phone }, completionSaver: { _, _, _, _ in XCTFail("Revoked completion persisted") },
            localRuntimeAvailable: { XCTFail("Revoked completion reached local runtime"); return false })
        let pending = expectation(description: "lost response")
        let observer = await coordinator.observe { if case .recovery = $0 { pending.fulfill() } }
        await coordinator.start(deepLink: try deepLink(ticket))
        await fulfillment(of: [pending], timeout: 10)
        await coordinator.stopObserving(observer)
        await transport.rejectCompletion(status: 410)
        await coordinator.resumePendingCompletion()
        guard case let .recovery(_, _, canRetry) = await coordinator.state else { return XCTFail("Expected rejection") }
        XCTAssertFalse(canRetry)
        let retained = try await outbox.load()
        XCTAssertNotNil(retained, "Do not silently destroy recovery evidence")
        await coordinator.discardPendingCompletion()
        let discarded = try await outbox.load()
        XCTAssertNil(discarded)
    }

    func testCorruptEncryptedOutboxBlocksNewSigning() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 0x32, count: 96).write(to: directory.appendingPathComponent("completion.sealed"))
        let outbox = EncryptedIdentityLinkOutbox(directory: directory, keyProvider: { _ in Data(repeating: 0x51, count: 32) })
        let coordinator = IdentityLinkFlowCoordinator(outbox: outbox,
            identityProvider: { XCTFail("Corrupt outbox must block new signatures"); return nil }, completionSaver: { _, _, _, _ in })
        let ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
        await coordinator.start(deepLink: try deepLink(ticket))
        guard case .failed = await coordinator.state else { return XCTFail("Corruption failed open") }
    }

    // MARK: Hjelpere

    private func makeTicket(origin: String, audience: String, expiresIn: TimeInterval) throws -> IdentityLinkTicket {
        IdentityLinkTicket(
            schema: IdentityLinkTicket.currentSchema,
            ticketID: "lt-\(UUID().uuidString.lowercased())",
            audience: audience,
            origin: origin,
            entityBinding: EntityBindingDescriptor(mode: .localEntityAnchor, entityAnchorReference: "cell:///EntityAnchor", audience: audience),
            rendezvousURL: "\(origin)/link/api",
            nonce: Data((0..<32).map { UInt8($0) }),
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(expiresIn)),
            presentationChallenge: Data((0..<32).map { UInt8(255 - $0) }),
            presentationDomain: origin,
            ownerDisplayName: "Kjetil",
            approverLabel: "Safari på Mac"
        )
    }

    private func deepLink(_ ticket: IdentityLinkTicket) throws -> String {
        "haven://identity-link?t=" + IdentityLinkWire.base64URL(try IdentityLinkWire.encoder.encode(ticket))
    }
}

/// En møteplass som godkjenner med utstederens nøkkel med én gang, uten passkey-bevis (det håndhever
/// scaffoldets EntityAnchor, ikke telefonen).
private actor FakeRendezvous: IdentityLinkTransport {
    enum Tamper: Sendable { case none, pollURL, completeURL, presentationDomain }
    let tamper: Tamper
    private(set) var remembered: IdentityLinkCompletionStore.Entry?
    func remember(envelope: IdentityLinkCompletionEnvelope, record: IdentityLinkRecord, origin: String, reference: String?) {
        remembered = .init(origin: origin, record: record, envelope: envelope, storedAt: "synthetic-test", personEvidenceReference: reference)
    }
    let issuer: Identity
    let ticket: IdentityLinkTicket
    let tamperChallenge: Bool
    private var package: IdentityLinkCompletionPackage?
    private var polls = 0
    var completeWasCalled = false
    var completedEnvelopeWasVerifiable = false
    var completionEnvelopes: [Data] = []
    var failFirstCompletion: Bool
    var rejectionStatus: Int?
    let outbox: (any IdentityLinkOutbox)?
    func rejectCompletion(status: Int) { rejectionStatus = status }

    init(issuer: Identity, ticket: IdentityLinkTicket, tamperChallenge: Bool = false, tamper: Tamper = .none, failFirstCompletion: Bool = false, outbox: (any IdentityLinkOutbox)? = nil) {
        self.failFirstCompletion = failFirstCompletion
        self.outbox = outbox
        self.tamper = tamper
        self.issuer = issuer
        self.ticket = ticket
        self.tamperChallenge = tamperChallenge
    }

    func submitRequest(ticketID: String, request: IdentityEnrollmentRequest, to rendezvousURL: String) async throws -> IdentityLinkSubmitResponse {
        let hash = try await IdentityLinkProtocolService.validateEnrollmentRequest(request)
        let now = Date()
        let approval = try await IdentityLinkProtocolService.approveEnrollmentRequest(
            request, issuerIdentity: issuer, approvedScopes: [IdentityLinkScope.sameEntity],
            createdAt: now, expiresAt: now.addingTimeInterval(300), jti: "jti-\(UUID().uuidString)"
        )
        let credential = try await IdentityLinkProtocolService.issueSameEntityCredential(
            request: request, approval: approval, issuerIdentity: issuer, validUntil: now.addingTimeInterval(600), revocationReference: nil
        )
        package = IdentityLinkCompletionPackage(
            requestHash: IdentityLinkWire.base64URL(hash),
            approval: approval,
            sameEntityCredential: credential,
            issuerIdentity: try IdentityLinkProtocolService.descriptor(for: issuer),
            presentationChallenge: tamperChallenge ? Data(repeating: 7, count: 32) : ticket.presentationChallenge,
            presentationDomain: tamper == .presentationDomain ? "https://haven.digipomps.org" : ticket.presentationDomain,
            audience: ticket.audience,
            origin: ticket.origin,
            completeURL: tamper == .completeURL ? "https://haven.digipomps.org/link/api/complete" : "\(ticket.origin)/link/api/complete"
        )
        return IdentityLinkSubmitResponse(
            requestHash: IdentityLinkWire.base64URL(hash),
            sas: IdentityLinkSAS.words(requestHash: hash),
            completionURL: tamper == .pollURL ? "https://haven.digipomps.org/link/api/completion/\(IdentityLinkWire.base64URL(hash))" : "\(ticket.origin)/link/api/completion/\(IdentityLinkWire.base64URL(hash))"
        )
    }

    func fetchCompletion(url: String) async throws -> IdentityLinkCompletionPackage? {
        polls += 1
        return polls >= 2 ? package : nil
    }

    func complete(envelope: IdentityLinkCompletionEnvelope, url: String) async throws -> ValueType {
        completeWasCalled = true
        completionEnvelopes.append(try IdentityLinkWire.encoder.encode(envelope))
        if let outbox {
            let saved = try await outbox.load()
            XCTAssertEqual(try saved.map { try IdentityLinkWire.encoder.encode($0.envelope) }, completionEnvelopes.last,
                "Exact package must be durable before HTTP completion")
        }
        if let rejectionStatus { throw IdentityLinkTransportError.http(rejectionStatus, "revoked") }
        if failFirstCompletion {
            failFirstCompletion = false
            throw URLError(.networkConnectionLost)
        }
        let result = try await IdentityLinkProtocolService.verifyCompletion(envelope)
        completedEnvelopeWasVerifiable = result.record.status == .active
        return .object(["status": .string("completed"), "evidenceReference": .string(String(repeating: "a", count: 64)), "linkID": .string(result.record.linkID)])
    }
}

private actor IdentityLoadGate {
    private var continuation: CheckedContinuation<Identity?, Never>?
    private var released = false
    private var identity: Identity?
    func wait() async -> Identity? {
        if released { return identity }
        return await withCheckedContinuation { continuation = $0 }
    }
    func release(_ value: Identity) {
        released = true
        identity = value
        continuation?.resume(returning: value)
        continuation = nil
    }
}

private actor MemoryIdentityLinkOutbox: IdentityLinkOutbox {
    var entry: IdentityLinkPendingCompletion?
    func load() -> IdentityLinkPendingCompletion? { entry }
    func save(_ entry: IdentityLinkPendingCompletion) throws { self.entry = entry }
    func remove(requestID: String) throws {
        guard entry?.requestID == requestID else { throw IdentityLinkOutboxError.occupied }
        entry = nil
    }
}
