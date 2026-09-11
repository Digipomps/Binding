// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import CellBase
import Foundation
import XCTest
@testable import Binding

final class PersonEntityReadClientTests: XCTestCase {
    private typealias C = BindingPersonEntityReadRouteContract

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
    }

    func testChangedEvidenceReferenceIsRejectedBeforeKeyLookup() async throws {
        var (entry, _) = try await fixture()
        entry.personEvidenceReference = String(repeating: "b", count: 64)
        let client = PersonEntityReadClient { _ in XCTFail("invalid receipt must not request a key"); return nil }
        do { try await client.connect(entry: entry); XCTFail("changed evidence reference must not connect") }
        catch { XCTAssertEqual(error as? C.Failure, .denied) }
    }

    func testDescriptorRequiresExactOriginReceiptKeyAndThreeApprovedScopes() async throws {
        let (entry, phone) = try await fixture()
        let now = Date(), reference = try XCTUnwrap(entry.personEvidenceReference)
        let nonce = await phone.identityVault?.randomBytes64()
        let challenge = try IdentitySigningChallenge.signingData(for: phone, trustedIdentity: phone,
            domain: C.domain, resource: C.discoveryResource(reference: reference, linkID: entry.record.linkID),
            action: C.discoveryAction, audience: entry.origin, nonce: try XCTUnwrap(nonce), issuedAt: now)
        let signature = try await phone.sign(data: challenge)
        let proof = C.Proof(evidenceReference: reference, linkID: entry.record.linkID, challenge: challenge, signature: try XCTUnwrap(signature))
        let descriptor = C.Descriptor(origin: entry.origin, websocketURL: try C.websocketURL(origin: entry.origin),
            evidenceReference: reference, linkID: entry.record.linkID, linkedIdentityUUID: phone.uuid,
            linkedKeyFingerprint: try XCTUnwrap(phone.signingPublicKeyFingerprint), requestDigest: C.digest(try C.encode(proof)),
            instanceNonce: String(repeating: "a", count: 64), setupExpiresAt: now.addingTimeInterval(60).timeIntervalSince1970,
            connectionLifetimeSeconds: C.connectionLifetime, scopes: [
                .init(role: .gateway, domain: C.domain, cellUUID: UUID().uuidString),
                .init(role: .query, domain: C.domain, cellUUID: UUID().uuidString),
                .init(role: .anchor, domain: C.domain, cellUUID: UUID().uuidString)
            ])
        try C.validateDescriptor(descriptor, proof: proof, identity: phone, origin: entry.origin,
                                 approvedDomains: entry.record.approvedDomains, now: now)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: C.encode(descriptor)) as? [String: Any])
        let changes: [(String, Any)] = [
            ("origin", "https://other.example"), ("websocketURL", "wss://other.example/entity-data/read/bridge"),
            ("evidenceReference", String(repeating: "0", count: 64)), ("linkID", UUID().uuidString),
            ("linkedIdentityUUID", UUID().uuidString), ("linkedKeyFingerprint", "other-key"),
            ("requestDigest", String(repeating: "0", count: 64)), ("setupExpiresAt", now.timeIntervalSince1970 - 1),
            ("connectionLifetimeSeconds", 3600), ("scopes", [["role": "gateway", "domain": "private", "cellUUID": UUID().uuidString]])
        ]
        for (key, value) in changes {
            var changed = original; changed[key] = value
            let decoded = try JSONDecoder().decode(C.Descriptor.self, from: JSONSerialization.data(withJSONObject: changed))
            XCTAssertThrowsError(try C.validateDescriptor(decoded, proof: proof, identity: phone,
                origin: entry.origin, approvedDomains: entry.record.approvedDomains, now: now), key)
        }
        XCTAssertThrowsError(try C.validateDescriptor(descriptor, proof: proof, identity: phone,
            origin: entry.origin, approvedDomains: ["scaffold"], now: now))
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
