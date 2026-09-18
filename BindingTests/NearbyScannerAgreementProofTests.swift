import XCTest
import MultipeerConnectivity
@testable import CellApple
@testable import CellBase

@MainActor
final class NearbyScannerAgreementProofTests: XCTestCase {
    private struct Fixture {
        let authority: Identity
        let reader: Identity
        let outsider: Identity
        let agreement: Agreement
        var policy: NearbyAccessAgreement
    }

    private func withFixture(_ body: (Fixture) async throws -> Void) async throws {
        let oldVault = CellBase.defaultIdentityVault
        let oldBypass = CellBase.debugValidateAccessForEverything
        defer { CellBase.defaultIdentityVault = oldVault; CellBase.debugValidateAccessForEverything = oldBypass }
        let vault = EphemeralIdentityVault()
        CellBase.defaultIdentityVault = vault
        CellBase.debugValidateAccessForEverything = false
        let authority = await vault.identity(for: "synthetic-authority", makeNewIfNotFound: true)!
        let reader = await vault.identity(for: "synthetic-reader", makeNewIfNotFound: true)!
        let outsider = await vault.identity(for: "synthetic-outsider", makeNewIfNotFound: true)!
        let agreement = Agreement(owner: authority)
        agreement.name = "Medlem av gruppen og relasjonen"
        let member = ProvedClaimCondition(name: "Medlem av eksempelgruppen",
            statement: "credentialSubject.groupID == \"group://example\"",
            requiredCredentialType: "GroupMembershipCredential", subjectClaimPath: "credentialSubject.groupID")
        // This is a synthetic authority lookup, not a claim that this graph route exists.
        var relation = LookupCondition(keypath: "target.relations.example.$identity.isMember", expectedValue: .bool(true))
        relation.name = "Medlem av den valgte relasjonen"
        agreement.conditions = [member, relation]
        agreement.grants = [Grant(keypath: NearbyAccessAgreement.readKeypath, permission: "r---")]
        agreement.duration = 120
        agreement.signatories = [authority, reader]
        agreement.state = .signed
        let policy = NearbyAccessAgreement(title: agreement.name, domain: "nearby://example-group",
            verifierDID: try authority.did(), conditions: try NearbyAccessAgreement.typedConditions(agreement))
        try await body(Fixture(authority: authority, reader: reader, outsider: outsider, agreement: agreement, policy: policy))
    }

    private func lease(_ fixture: Fixture, issuer: Identity? = nil, domain: String? = nil,
                       duration: Int = 120, issuedAt: Date = Date(), conditions: [any Condition]? = nil,
                       grant: String = NearbyAccessAgreement.readKeypath) async throws -> Contract {
        let agreement = try JSONDecoder().decode(Agreement.self, from: JSONEncoder().encode(fixture.agreement))
        agreement.duration = duration
        agreement.owner = issuer ?? fixture.authority
        agreement.signatories = [issuer ?? fixture.authority, fixture.reader]
        if let conditions { agreement.conditions = conditions }
        agreement.grants = [Grant(keypath: grant, permission: "r---")]
        return try await Contract.signed(agreement: agreement, issuer: issuer ?? fixture.authority,
            subject: fixture.reader, domain: domain ?? fixture.policy.domain, issuedAt: issuedAt)
    }

    func testPolicyPreservesNativeConditionsAndRejectsLossyDecode() async throws {
        try await withFixture { fixture in
            XCTAssertNoThrow(try fixture.policy.validate())
            let imported = try NearbyAccessAgreement.importing(JSONEncoder().encode(fixture.agreement),
                domain: fixture.policy.domain, verifierDID: fixture.policy.verifierDID)
            XCTAssertEqual(imported, fixture.policy)
            var policy = fixture.policy
            policy.conditions[0]["type"] = .string("future-unknown-condition")
            XCTAssertThrowsError(try policy.validate())
            policy = fixture.policy; policy.conditions[0]["condition"] = .object(["name": .string("Missing condition data")])
            XCTAssertThrowsError(try policy.validate())
            policy = fixture.policy; policy.conditions.append(policy.conditions[0])
            XCTAssertThrowsError(try policy.validate())
            policy = fixture.policy; policy.conditions = []
            XCTAssertThrowsError(try policy.validate())
            let demoAgreement = Agreement(owner: fixture.authority)
            policy.conditions = try NearbyAccessAgreement.typedConditions(demoAgreement)
            XCTAssertThrowsError(try policy.validate(), "Placeholder/demo Conditions cannot protect an excerpt")
        }
    }

    func testAuthorityLeaseBindsAllConditionsDomainGrantAndHolder() async throws {
        try await withFixture { fixture in
            let contract = try await lease(fixture)
            let evidence = NearbyAccessEvidence(contracts: [contract])
            let allowed = await NearbyAgreementAuthorization.allows(evidence, policy: fixture.policy, reader: fixture.reader)
            XCTAssertTrue(allowed)
            let outsider = await NearbyAgreementAuthorization.allows(evidence, policy: fixture.policy, reader: fixture.outsider)
            XCTAssertFalse(outsider)
            // Ephemeral vaults start with the same UUIDs but independently generated signing keys.
            let otherVault = EphemeralIdentityVault()
            _ = await otherVault.identity(for: "authority", makeNewIfNotFound: true)
            let copiedUUID = await otherVault.identity(for: "reader", makeNewIfNotFound: true)!
            XCTAssertEqual(copiedUUID.uuid, fixture.reader.uuid)
            let copied = await NearbyAgreementAuthorization.allows(evidence, policy: fixture.policy, reader: copiedUUID)
            XCTAssertFalse(copied)
            for badContract in [
                try await lease(fixture, issuer: fixture.outsider),
                try await lease(fixture, domain: "nearby://other-group"),
                try await lease(fixture, conditions: [fixture.agreement.conditions[0]]),
                try await lease(fixture, grant: "profile.read")
            ] {
                let accepted = await NearbyAgreementAuthorization.allows(.init(contracts: [badContract]), policy: fixture.policy, reader: fixture.reader)
                XCTAssertFalse(accepted)
            }
            var changed = fixture.policy
            if case var .object(row)? = changed.conditions[1]["condition"] {
                row["keypath"] = .string("target.relations.other.$identity.isMember")
                changed.conditions[1]["condition"] = .object(row)
            }
            let otherRelation = await NearbyAgreementAuthorization.allows(evidence, policy: changed, reader: fixture.reader)
            XCTAssertFalse(otherRelation)
        }
    }

    func testExpiredOverlongMissingAndTamperedProofsStayClosed() async throws {
        try await withFixture { fixture in
            var tampered = try await lease(fixture)
            tampered.signature = Data(repeating: 0, count: 64)
            for evidence in [NearbyAccessEvidence(), .init(contracts: [tampered]),
                .init(contracts: [try await lease(fixture, issuedAt: Date().addingTimeInterval(-400))]),
                .init(contracts: [try await lease(fixture, duration: 301)]),
                .init(contracts: [try await lease(fixture, issuedAt: Date().addingTimeInterval(60))])] {
                let accepted = await NearbyAgreementAuthorization.allows(evidence, policy: fixture.policy, reader: fixture.reader)
                XCTAssertFalse(accepted)
            }
            XCTAssertThrowsError(try NearbyAccessEvidence.importing(Data("{}".utf8)))
            XCTAssertThrowsError(try NearbyAccessEvidence.importing(Data(repeating: 0, count: 196_609)))
            let contract = try await lease(fixture)
            let imported = try NearbyAccessEvidence.importing(JSONEncoder().encode(contract))
            XCTAssertEqual(imported.contracts.count, 1)
            let bundle: Object = ["contracts": .list([.object(try NearbyAccessAgreement.object(contract))])]
            XCTAssertEqual(try NearbyAccessEvidence.importing(JSONEncoder().encode(bundle)).contracts.count, 1)
        }
    }

    func testPresentationBindsFreshNonceBothPeersPolicyAndEvidence() async throws {
        try await withFixture { fixture in
            let evidence = NearbyAccessEvidence(contracts: [try await lease(fixture)])
            let challenge = NearbyAccessChallenge(requestID: UUID(), nonce: UUID(), publisherSessionID: "publisher",
                readerSessionID: "reader", policy: fixture.policy, expiresAt: Date().timeIntervalSince1970 + 8)
            let proof = try await NearbyProofPresentation.signed(challenge: challenge, evidence: evidence, reader: fixture.reader)
            XCTAssertTrue(proof.verifies(challenge: challenge))
            let wireCopy = try JSONDecoder().decode(NearbyProofPresentation.self, from: JSONEncoder().encode(proof))
            XCTAssertTrue(wireCopy.verifies(challenge: challenge))
            var other = challenge; other.nonce = UUID()
            XCTAssertFalse(proof.verifies(challenge: other))
            other = challenge; other.publisherSessionID = "another-publisher"
            XCTAssertFalse(proof.verifies(challenge: other))
            other = challenge; other.readerSessionID = "another-reader"
            XCTAssertFalse(proof.verifies(challenge: other))
            XCTAssertFalse(proof.verifies(challenge: challenge, now: Date().addingTimeInterval(20)))
            var mutation = wireCopy; mutation.evidence = .init()
            XCTAssertFalse(mutation.verifies(challenge: challenge))
            mutation = wireCopy; mutation.reader = fixture.outsider.publicIdentitySnapshot()
            XCTAssertFalse(mutation.verifies(challenge: challenge))
            mutation = wireCopy; mutation.challenge.policy.domain = "nearby://other"
            XCTAssertFalse(mutation.verifies(challenge: mutation.challenge))
        }
    }

    func testRestrictedPublicationCannotFallBackToPublicProtocolOrScopeString() async throws {
        try await withFixture { fixture in
            var ad = NearbyAdvertisement(displayName: "Synthetic member", purposes: [:], interests: [:],
                scope: .agreement, scopeID: fixture.policy.domain, expiresAt: Date().timeIntervalSince1970 + 600,
                accessAgreement: fixture.policy)
            XCTAssertNoThrow(try ad.validate())
            let exchange = NearbyAdvertisementExchange()
            try exchange.publish(ad)
            let peer = MCPeerID(displayName: "Remote fixture")
            let local = MCPeerID(displayName: "Local fixture")
            let request = try JSONEncoder().encode(NearbyAdvertisementEnvelope(requestID: UUID()))
            var accepted: Bool?
            XCTAssertTrue(exchange.accept(context: request, peer: peer, localPeer: local) { allowed, _ in accepted = allowed })
            XCTAssertEqual(accepted, false)
            let v2 = try JSONEncoder().encode(NearbyAdvertisementV2Envelope(requestID: UUID()))
            XCTAssertLessThanOrEqual(v2.count, 256)
            XCTAssertTrue(exchange.accept(context: v2, peer: peer, localPeer: local,
                reply: { allowed, _ in accepted = allowed }, localSessionID: "local", remoteSessionID: "remote"))
            XCTAssertEqual(accepted, true)
            exchange.stop()
            ad.scopeID = "nearby://wrong-domain"
            XCTAssertThrowsError(try ad.validate())
            ad.scopeID = fixture.policy.domain; ad.accessAgreement = nil
            XCTAssertThrowsError(try ad.validate())
            ad.scope = .nearby; ad.accessAgreement = fixture.policy
            XCTAssertThrowsError(try ad.validate())
        }
    }

    func testReaderShowsChallengeWithoutSendingProofAndRejectsWrongPeer() async throws {
        try await withFixture { fixture in
            let peer = MCPeerID(displayName: "Publisher")
            let local = MCPeerID(displayName: "Reader")
            let request = UUID()
            var completions = [NearbyAdvertisementReadResult]()
            let channel = AdvertisementProofSession(localPeer: local, peer: peer, localID: "reader", remoteID: "publisher",
                requestID: request, reader: fixture.reader) { completions.append($0) }
            let challenge = NearbyAccessChallenge(requestID: request, nonce: UUID(), publisherSessionID: "publisher",
                readerSessionID: "reader", policy: fixture.policy, expiresAt: Date().timeIntervalSince1970 + 8)
            let bytes = try JSONEncoder().encode(NearbyAdvertisementV2Envelope(requestID: request, challenge: challenge))
            channel.session(channel.session, didReceive: bytes, fromPeer: MCPeerID(displayName: "Other"))
            for _ in 0..<10 { await Task.yield() }
            XCTAssertTrue(completions.isEmpty)
            channel.session(channel.session, didReceive: bytes, fromPeer: peer)
            for _ in 0..<10 { await Task.yield() }
            XCTAssertEqual(completions.count, 1)
            XCTAssertEqual(completions.first?.challenge, challenge)
            XCTAssertNil(completions.first?.advertisement)
            channel.finish(.unavailable)
            XCTAssertEqual(completions.count, 1)
        }
    }

    func testProofSubmissionIsOwnerOnlyAndRequiresSelectedChallenge() async throws {
        try await withFixture { fixture in
            let cell = await EntityScannerCell(owner: fixture.reader)
            XCTAssertFalse(cell.agreementTemplate.grants.contains { $0.keypath == "submitAdvertisementProof" })
            do {
                _ = try await cell.set(keypath: "submitAdvertisementProof", value: .object([:]), requester: fixture.outsider)
                XCTFail("Foreign callers cannot submit the owner's evidence")
            } catch CellAuthorizationError.denied { }
            do {
                _ = try await cell.set(keypath: "submitAdvertisementProof", value: .object([:]), requester: fixture.reader)
                XCTFail("A reviewed selected-peer challenge is required")
            } catch { }
        }
    }

    func testSignedEvaluationReceiptCannotStandInForAgreementAuthorization() async throws {
        try await withFixture { fixture in
            let context = "Synthetic group membership"
            let verifier = await TrustedIssuerCell(owner: fixture.reader)
            _ = try await verifier.set(keypath: "trustedIssuers.policy.upsert", value: .object([
                "contextId": .string(context), "threshold": .float(0.5),
                "maximumCredentialAgeSeconds": .float(86_400), "requireRevocationCheck": .bool(false),
                "requireSubjectBinding": .bool(true), "requireIndependentSources": .integer(0),
                "acceptedDidMethods": .list([.string("did:key")]),
                "claimSchema": .object(["credentialType": .string("GroupMembershipCredential"),
                    "subjectPath": .string("credentialSubject.groupID"), "operator": .string("=="),
                    "expectedValue": .string("group://example")])
            ]), requester: fixture.reader)
            _ = try await verifier.set(keypath: "trustedIssuers.issuer.upsert", value: .object([
                "issuerId": .string(try fixture.authority.did()), "issuerKind": .string("institution"),
                "baseWeight": .float(0.9), "contexts": .list([.string(context)]), "status": .string("active")
            ]), requester: fixture.reader)
            var claim = try await VCClaim(type: "GroupMembershipCredential", issuerIdentity: fixture.authority,
                subjectIdentity: fixture.reader, credentialSubject: ["groupID": .string("group://example")])
            try await claim.generateProof(issuerIdentity: fixture.authority)
            let value = try await verifier.set(keypath: "trustedIssuers.evaluateSigned", value: .object([
                "issuerId": .string(try fixture.authority.did()), "contextId": .string(context),
                "requesterId": .string(try fixture.reader.did()), "candidateVc": .object(try NearbyAccessAgreement.object(claim)),
                "agreementCondition": .object([
                    "kind": .string("prove"), "title": .string(context), "permission": .string("r---"),
                    "requiredCredentialType": .string("GroupMembershipCredential"),
                    "subjectClaimPath": .string("credentialSubject.groupID"),
                    // Current receipt issuance checks type/path, but does not evaluate this whole expression.
                    "technicalRule": .string("credentialSubject.groupID == \"group://other\"")
                ])
            ]), requester: fixture.reader)
            guard case let .object(object)? = value else { return XCTFail("Expected a signed evaluation receipt") }
            let receipt = try TrustedIssuerEvaluationReceipt.from(object: object)
            XCTAssertTrue(receipt.verifySignature())
            XCTAssertTrue(receipt.verifyTrustedEvaluation(expectedRequesterID: try fixture.reader.did()))
            XCTAssertThrowsError(try NearbyAccessEvidence.importing(JSONEncoder().encode(receipt)),
                "A valid evaluation signature alone must not authorize a different group predicate")
        }
    }
}
