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
            identityProvider: { phone },
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
        guard case let .done(record, ownerDisplayName, doneOrigin) = state else {
            return XCTFail("forventet done, fikk \(state)")
        }
        XCTAssertEqual(record.status, .active)
        XCTAssertEqual(record.linkedIdentity.uuid, phone.uuid)
        XCTAssertEqual(ownerDisplayName, ticket.ownerDisplayName)
        XCTAssertEqual(doneOrigin, origin)
        let verifiable = await transport.completedEnvelopeWasVerifiable
        XCTAssertTrue(verifiable)
        // test.binding.completion-persisted
        let stored = IdentityLinkCompletionStore.entry(forOrigin: origin)
        XCTAssertEqual(stored?.record.linkID, record.linkID)
        XCTAssertEqual(stored?.envelope.request.newIdentity.uuid, phone.uuid)
    }

    func testCoordinatorRefusesAPackageForAnotherRequest() async throws {
        let vault = EphemeralIdentityVault()
        var phone = Identity(UUID().uuidString, displayName: "phone", identityVault: vault)
        await vault.addIdentity(identity: &phone, for: "private")
        var web = Identity(UUID().uuidString, displayName: "web", identityVault: vault)
        await vault.addIdentity(identity: &web, for: "web")
        let ticket = try makeTicket(origin: origin, audience: "staging.haven.digipomps.org", expiresIn: 600)
        let transport = FakeRendezvous(issuer: web, ticket: ticket, tamperChallenge: true)
        let coordinator = IdentityLinkFlowCoordinator(transport: transport, identityProvider: { phone }, localRuntimeAvailable: { false })

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
    let issuer: Identity
    let ticket: IdentityLinkTicket
    let tamperChallenge: Bool
    private var package: IdentityLinkCompletionPackage?
    private var polls = 0
    var completeWasCalled = false
    var completedEnvelopeWasVerifiable = false

    init(issuer: Identity, ticket: IdentityLinkTicket, tamperChallenge: Bool = false) {
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
            presentationDomain: ticket.presentationDomain,
            audience: ticket.audience,
            origin: ticket.origin,
            completeURL: "\(ticket.origin)/link/api/complete"
        )
        return IdentityLinkSubmitResponse(
            requestHash: IdentityLinkWire.base64URL(hash),
            sas: IdentityLinkSAS.words(requestHash: hash),
            completionURL: "\(ticket.origin)/link/api/completion/\(IdentityLinkWire.base64URL(hash))"
        )
    }

    func fetchCompletion(url: String) async throws -> IdentityLinkCompletionPackage? {
        polls += 1
        return polls >= 2 ? package : nil
    }

    func complete(envelope: IdentityLinkCompletionEnvelope, url: String) async throws -> ValueType {
        completeWasCalled = true
        let result = try await IdentityLinkProtocolService.verifyCompletion(envelope)
        completedEnvelopeWasVerifiable = result.record.status == .active
        return .object(["status": .string("completed")])
    }
}
