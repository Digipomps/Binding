import Foundation
import Testing
import CellBase
@testable import Binding

@Suite struct EntityScaffoldExtensionSecurityTests {
    @Test func legacyMutationsCannotCreateAnActiveLinkEvenWithClaimedFreshAuthentication() async throws {
        let vault = EphemeralIdentityVault()
        var owner = Identity(UUID().uuidString, displayName: "Test owner", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "private")
        let cell = await BindingEntityScaffoldExtensionCell(owner: owner)
        for key in ["extension.beginRequest", "extension.approveRequest", "extension.acceptApproval", "extension.revokeLink"] {
            for payload: ValueType in [.null, .string("unsigned-approval"), .object([
                "audience": .string("staging.haven.digipomps.org"),
                "freshAuthMethod": .string("biometric"),
                "approvedScopes": .list([.string("entity.write")])
            ])] {
                let reply = try #require(HavenValue.object(try await cell.set(keypath: key, value: payload, requester: owner)))
                #expect(HavenValue.string(reply["code"]) == "verified_completion_required")
                #expect(reply["sideEffect"] == .bool(false))
                let links = try await cell.get(keypath: "extension.links", requester: owner)
                #expect(try #require(HavenValue.list(links)).isEmpty)
            }
        }
    }

    @Test func legacyActiveRowsAreQuarantinedOnDecodeWithoutLosingRevocations() async throws {
        let vault = EphemeralIdentityVault()
        var owner = Identity(UUID().uuidString, displayName: "Test owner", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "private")
        let descriptor = try #require(IdentityPublicKeySignatureVerifier.descriptor(for: owner))
        let cell = await BindingEntityScaffoldExtensionCell(owner: owner)
        let records = [IdentityLinkStatus.active, .revoked, .expired, .pending].map { status in
            IdentityLinkRecord(linkID: "legacy-\(status.rawValue)",
                entityBinding: EntityBindingDescriptor(mode: .localEntityAnchor, audience: "test"),
                linkedIdentity: descriptor, approvedDomains: [], approvedIdentityContexts: [],
                approvedScopes: ["entity.read"], issuerIdentityUUID: owner.uuid,
                issuerType: .existingDevice, status: status, linkedAt: "2026-09-01T00:00:00Z",
                revokedAt: status == .revoked ? "2026-09-02T00:00:00Z" : nil,
                revocationReference: status == .revoked ? "retained-evidence" : nil)
        }
        var archived = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(cell)) as? [String: Any])
        archived["links"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(records))
        archived["lastResult"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
            HavenValue.ok("Koblet", sideEffect: true)))
        let restored = try JSONDecoder().decode(BindingEntityScaffoldExtensionCell.self,
            from: JSONSerialization.data(withJSONObject: archived))
        let reencoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
        let restoredRecords = try JSONDecoder().decode([IdentityLinkRecord].self,
            from: JSONSerialization.data(withJSONObject: try #require(reencoded["links"])))
        #expect(restoredRecords.map(\.status) == [.pending, .revoked, .expired, .pending])
        #expect(restoredRecords.map(\.linkID) == records.map(\.linkID))
        #expect(restoredRecords[1].revocationReference == "retained-evidence")
        #expect(restoredRecords[1].revokedAt == records[1].revokedAt)
        let lastResult = try JSONDecoder().decode(Object.self,
            from: JSONSerialization.data(withJSONObject: try #require(reencoded["lastResult"])))
        #expect(HavenValue.string(lastResult["code"]) == "verified_completion_required")
    }
    @Test func matchingRequestHashDoesNotMakeAnUnsignedApprovalAuthoritative() async throws {
        let vault = EphemeralIdentityVault()
        var owner = Identity(UUID().uuidString, displayName: "Test owner", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "private")
        let descriptor = try #require(IdentityPublicKeySignatureVerifier.descriptor(for: owner))
        let cell = await BindingEntityScaffoldExtensionCell(owner: owner)
        let now = Date()
        let binding = EntityBindingDescriptor(mode: .localEntityAnchor, audience: "test.invalid")
        let request = IdentityEnrollmentRequest(requestID: "legacy-pending", entityBinding: binding,
            newIdentity: descriptor, requestedDomains: ["private"], requestedIdentityContexts: ["default"],
            requestedScopes: ["entity.read"], audience: "test.invalid", origin: "cell:///EntityScaffoldExtension",
            createdAt: HavenValue.iso(now), expiresAt: HavenValue.iso(now.addingTimeInterval(600)),
            nonce: Data(repeating: 1, count: 32))
        var archived = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(cell)) as? [String: Any])
        archived["outgoingRequests"] = [[
            "request": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)),
            "humanCode": "synthetic", "createdAt": now.timeIntervalSinceReferenceDate
        ]]
        let restored = try JSONDecoder().decode(BindingEntityScaffoldExtensionCell.self,
            from: JSONSerialization.data(withJSONObject: archived))
        let approval = IdentityEnrollmentApproval(approvalID: "unsigned",
            requestHash: Data(HavenRelationNormalizer.sha256Hex(try request.canonicalPayloadData().base64EncodedString()).utf8),
            entityBinding: binding, subjectIdentity: descriptor, approvedDomains: ["private"],
            approvedIdentityContexts: ["default"], approvedScopes: ["entity.write"],
            issuerIdentityUUID: "invented-issuer", issuerType: .existingDevice,
            audience: "wrong-audience", origin: "https://untrusted.invalid",
            createdAt: HavenValue.iso(now), expiresAt: "invalid-date", jti: "replayable",
            freshAuthRequired: true)
        #expect(approval.proof == nil)
        let reply = try #require(HavenValue.object(try await restored.set(keypath: "extension.acceptApproval",
            value: HavenValue.value(approval), requester: owner)))
        #expect(HavenValue.string(reply["code"]) == "verified_completion_required")
        let links = try await restored.get(keypath: "extension.links", requester: owner)
        #expect(try #require(HavenValue.list(links)).isEmpty)
    }

}
