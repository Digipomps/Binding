import Foundation
@preconcurrency import CellBase
import HavenAgentRuntime

public final class AgentIdentityCell: HavenAgentRuntimeBindingCell {
    private struct AgentEnrollmentAttestation: Codable, Equatable, Sendable {
        struct Payload: Codable, Equatable, Sendable {
            var version: String
            var instanceName: String
            var agentIdentityUUID: String
            var agentDisplayName: String
            var agentDid: String
            var agentPublicKeyBase64URL: String
            var operatorIdentityUUID: String
            var operatorDid: String
            var operatorPublicKeyBase64URL: String
            var purposeRef: String
            var scaffoldDomain: String
            var challenge: String
            var issuedAt: String
        }

        var payload: Payload
        var signatureAlgorithm: String
        var signatureBase64URL: String

        func canonicalPayloadData() throws -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(payload)
        }

        func asValue() -> ValueType {
            .object([
                "version": .string(payload.version),
                "instanceName": .string(payload.instanceName),
                "agentIdentityUUID": .string(payload.agentIdentityUUID),
                "agentDisplayName": .string(payload.agentDisplayName),
                "agentDid": .string(payload.agentDid),
                "agentPublicKeyBase64URL": .string(payload.agentPublicKeyBase64URL),
                "operatorIdentityUUID": .string(payload.operatorIdentityUUID),
                "operatorDid": .string(payload.operatorDid),
                "operatorPublicKeyBase64URL": .string(payload.operatorPublicKeyBase64URL),
                "purposeRef": .string(payload.purposeRef),
                "scaffoldDomain": .string(payload.scaffoldDomain),
                "challenge": .string(payload.challenge),
                "issuedAt": .string(payload.issuedAt),
                "signatureAlgorithm": .string(signatureAlgorithm),
                "signatureBase64URL": .string(signatureBase64URL)
            ])
        }

        func asObject() -> Object {
            [
                "version": .string(payload.version),
                "instanceName": .string(payload.instanceName),
                "agentIdentityUUID": .string(payload.agentIdentityUUID),
                "agentDisplayName": .string(payload.agentDisplayName),
                "agentDid": .string(payload.agentDid),
                "agentPublicKeyBase64URL": .string(payload.agentPublicKeyBase64URL),
                "operatorIdentityUUID": .string(payload.operatorIdentityUUID),
                "operatorDid": .string(payload.operatorDid),
                "operatorPublicKeyBase64URL": .string(payload.operatorPublicKeyBase64URL),
                "purposeRef": .string(payload.purposeRef),
                "scaffoldDomain": .string(payload.scaffoldDomain),
                "challenge": .string(payload.challenge),
                "issuedAt": .string(payload.issuedAt),
                "signatureAlgorithm": .string(signatureAlgorithm),
                "signatureBase64URL": .string(signatureBase64URL)
            ]
        }
    }

    private enum CodingKeys: String, CodingKey {
        case version
    }

    private enum StarterAuthError: LocalizedError {
        case invalidDomain
        case invalidPurpose
        case missingInterests
        case signatureFailed

        var errorDescription: String? {
            switch self {
            case .invalidDomain:
                return "starter auth requires a scaffold domain"
            case .invalidPurpose:
                return "starter auth requires an explicit purpose"
            case .missingInterests:
                return "starter auth requires at least one interest"
            case .signatureFailed:
                return "agent identity failed to sign starter auth payload"
            }
        }
    }

    private enum EntityLinkError: LocalizedError {
        case invalidContract
        case missingRequesterPublicKey
        case requesterDoesNotMatchLinkedKey
        case agentDoesNotMatchLinkedKey
        case signatureFailed

        var errorDescription: String? {
            switch self {
            case .invalidContract:
                return "entity link countersign requires a complete contract payload"
            case .missingRequesterPublicKey:
                return "requester is missing a public signing key"
            case .requesterDoesNotMatchLinkedKey:
                return "entity link must bind the current requester identity"
            case .agentDoesNotMatchLinkedKey:
                return "entity link must bind the stable local agent identity"
            case .signatureFailed:
                return "agent identity failed to countersign entity link contract"
            }
        }
    }

    public required init(owner: Identity) async {
        await super.init(owner: owner)
        await installRuntimeBindings(owner: owner)
        await markRuntimeBindingsInstalled()
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("1", forKey: .version)
    }

    override func installRuntimeBindings(owner: Identity) async {
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
    }

    private func setupPermissions(owner: Identity) async {
        ensureAgreementGrant("r---", for: "state")
        ensureAgreementGrant("r---", for: "descriptor")
        ensureAgreementGrant("rw--", for: "enrollment")
        ensureAgreementGrant("rw--", for: "enrollment.attest")
        ensureAgreementGrant("rw--", for: "starterAuth")
        ensureAgreementGrant("rw--", for: "starterAuth.issue")
        ensureAgreementGrant("rw--", for: "entityLink")
        ensureAgreementGrant("rw--", for: "entityLink.countersign")
        ensureAgreementGrant("r---", for: "flow")
    }

    private func setupKeys(owner: Identity) async {
        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let hasAccess = await self.validateAccess("r---", at: "state", for: requester) ||
                LocalControlCellAccess.allowsIdentityDiscovery(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makeStateValue(owner: owner)
        })

        await addInterceptForGet(requester: owner, key: "descriptor", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let hasAccess = await self.validateAccess("r---", at: "descriptor", for: requester) ||
                LocalControlCellAccess.allowsIdentityDiscovery(requester)
            guard hasAccess else { return .string("denied") }
            return await self.descriptorValue(owner: owner)
        })

        await addInterceptForSet(requester: owner, key: "enrollment.attest", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            return await self.issueEnrollmentAttestation(from: value, owner: owner, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "starterAuth.issue", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("rw--", at: "starterAuth.issue", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.issueStarterAuth(from: value, owner: owner, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "entityLink.countersign", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("rw--", at: "entityLink.countersign", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.countersignEntityLink(from: value, owner: owner, requester: requester)
        })
    }

    private func makeStateValue(owner: Identity) async -> ValueType {
        let descriptor = await descriptorValue(owner: owner)
        return .object([
            "identity": descriptor,
            "status": .string("ready")
        ])
    }

    private func descriptorValue(owner: Identity) async -> ValueType {
        return await effectiveDescriptor(owner: owner).asValue()
    }

    private func makeFallbackDescriptor(owner: Identity) -> AgentIdentityDescriptor {
        AgentIdentityDescriptor(
            instanceName: "unknown",
            identityContext: owner.displayName,
            identityUUID: owner.uuid,
            displayName: owner.displayName,
            publicKeyBase64URL: owner.publicSecureKey?.compressedKey.map(LocalBase64URL.encode) ?? "",
            didKey: (try? owner.did()) ?? owner.uuid,
            createdAt: "unknown",
            storageKind: "runtime-only"
        )
    }

    private func effectiveDescriptor(owner: Identity) async -> AgentIdentityDescriptor {
        let fallback = makeFallbackDescriptor(owner: owner)
        guard let descriptor = await AgentRuntimeBridge.shared.agentIdentityDescriptorSnapshot() else {
            return fallback
        }
        guard !fallback.publicKeyBase64URL.isEmpty else {
            return descriptor
        }
        if descriptor.publicKeyBase64URL == fallback.publicKeyBase64URL || descriptor.identityUUID == owner.uuid {
            return mergedDescriptor(descriptor, withCanonicalIdentityFrom: fallback)
        }
        return fallback
    }

    private func mergedDescriptor(
        _ descriptor: AgentIdentityDescriptor,
        withCanonicalIdentityFrom fallback: AgentIdentityDescriptor
    ) -> AgentIdentityDescriptor {
        var merged = descriptor
        merged.identityUUID = fallback.identityUUID
        merged.publicKeyBase64URL = fallback.publicKeyBase64URL
        merged.didKey = fallback.didKey
        return merged
    }

    private func issueEnrollmentAttestation(
        from value: ValueType,
        owner: Identity,
        requester: Identity
    ) async -> ValueType {
        guard case let .object(object) = value else {
            return .string("error: expected payload object")
        }

        let challenge = Self.stringValue(object["challenge"])
        let purposeRef = Self.stringValue(object["purposeRef"])
        let scaffoldDomain = Self.stringValue(object["scaffoldDomain"])
        let operatorIdentityUUID = Self.stringValue(object["operatorIdentityUUID"])
        let operatorDid = Self.stringValue(object["operatorDid"])
        let operatorPublicKeyBase64URL = Self.stringValue(object["operatorPublicKeyBase64URL"])

        guard !challenge.isEmpty,
              !purposeRef.isEmpty,
              !scaffoldDomain.isEmpty,
              !operatorIdentityUUID.isEmpty,
              !operatorDid.isEmpty,
              !operatorPublicKeyBase64URL.isEmpty else {
            return .string("error: challenge, purposeRef, scaffoldDomain and operator identity fields are required")
        }
        guard LocalControlCellAccess.allowsEnrollmentAttestation(
            requester: requester,
            claimedOperatorPublicKeyBase64URL: operatorPublicKeyBase64URL
        ) else {
            return .string("error: requester identity does not match the claimed operator public key")
        }

        let descriptor = await effectiveDescriptor(owner: owner)
        var attestation = AgentEnrollmentAttestation(
            payload: .init(
                version: "1.0",
                instanceName: descriptor.instanceName,
                agentIdentityUUID: descriptor.identityUUID,
                agentDisplayName: descriptor.displayName,
                agentDid: descriptor.didKey,
                agentPublicKeyBase64URL: descriptor.publicKeyBase64URL,
                operatorIdentityUUID: operatorIdentityUUID,
                operatorDid: operatorDid,
                operatorPublicKeyBase64URL: operatorPublicKeyBase64URL,
                purposeRef: purposeRef,
                scaffoldDomain: scaffoldDomain,
                challenge: challenge,
                issuedAt: ISO8601DateFormatter().string(from: Date())
            ),
            signatureAlgorithm: "Ed25519",
            signatureBase64URL: ""
        )

        do {
            guard let signature = try await owner.sign(data: attestation.canonicalPayloadData()) else {
                return .string("error: agent identity failed to sign attestation")
            }
            attestation.signatureBase64URL = LocalBase64URL.encode(signature)
            await publishAttestationEvent(attestation, requester: requester)
            return attestation.asValue()
        } catch {
            return .string("error: \(error.localizedDescription)")
        }
    }

    private func publishAttestationEvent(_ attestation: AgentEnrollmentAttestation, requester: Identity) async {
        var flowElement = FlowElement(
            title: "agent.identity.enrollment_attest",
            content: .object(attestation.asObject()),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "agent.identity"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func issueStarterAuth(
        from value: ValueType,
        owner: Identity,
        requester: Identity
    ) async -> ValueType {
        do {
            let request = try parseStarterAuthRequest(from: value)
            let descriptor = await effectiveDescriptor(owner: owner)
            let issuedAt = Date()
            let expiresAt = issuedAt.addingTimeInterval(TimeInterval(request.ttlSeconds))

            var payload = AgentStarterAuthPayload(
                domain: request.domain,
                identity_public_key: descriptor.publicKeyBase64URL,
                created_at: ISO8601DateFormatter().string(from: issuedAt),
                expires_at: ISO8601DateFormatter().string(from: expiresAt),
                nonce: "starter-\(UUID().uuidString.lowercased())",
                purpose_interest: AgentStarterPurposeInterest(
                    purpose: request.purpose,
                    interests: request.interests
                ),
                signature: AgentResolverSignatureEnvelope(alg: "Ed25519", sig: "")
            )

            guard let signature = try await owner.sign(data: payload.canonicalPayloadData()) else {
                return .string("error: \(StarterAuthError.signatureFailed.localizedDescription)")
            }

            payload.signature = AgentResolverSignatureEnvelope(
                alg: "Ed25519",
                sig: LocalBase64URL.encode(signature)
            )
            await publishStarterAuthEvent(payload, requester: requester)
            return starterAuthValue(payload)
        } catch {
            return .string("error: \(error.localizedDescription)")
        }
    }

    private func publishStarterAuthEvent(_ payload: AgentStarterAuthPayload, requester: Identity) async {
        var flowElement = FlowElement(
            title: "agent.identity.starter_auth_issue",
            content: .object(starterAuthObject(payload)),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "agent.identity"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func countersignEntityLink(
        from value: ValueType,
        owner: Identity,
        requester: Identity
    ) async -> ValueType {
        do {
            let contract = try parseEntityLinkContract(from: value)
            let descriptor = await effectiveDescriptor(owner: owner)
            let requesterPublicKey = requester.publicSecureKey?.compressedKey.map(LocalBase64URL.encode)

            guard let requesterPublicKey else {
                throw EntityLinkError.missingRequesterPublicKey
            }
            guard contract.pubkey_a == descriptor.publicKeyBase64URL || contract.pubkey_b == descriptor.publicKeyBase64URL else {
                throw EntityLinkError.agentDoesNotMatchLinkedKey
            }
            guard contract.pubkey_a == requesterPublicKey || contract.pubkey_b == requesterPublicKey else {
                throw EntityLinkError.requesterDoesNotMatchLinkedKey
            }

            guard let signature = try await owner.sign(data: contract.canonicalPayloadData()) else {
                throw EntityLinkError.signatureFailed
            }

            let envelope = AgentEntityLinkSignature(
                by_pubkey: descriptor.publicKeyBase64URL,
                alg: "Ed25519",
                sig: LocalBase64URL.encode(signature)
            )
            await publishEntityLinkEvent(contract: contract, signature: envelope, requester: requester)
            return entityLinkSignatureValue(envelope)
        } catch {
            return .string("error: \(error.localizedDescription)")
        }
    }

    private func publishEntityLinkEvent(
        contract: AgentEntityLinkContract,
        signature: AgentEntityLinkSignature,
        requester: Identity
    ) async {
        var flowElement = FlowElement(
            title: "agent.identity.entity_link_countersign",
            content: .object([
                "contract_id": .string(contract.contract_id),
                "scope": .string(contract.scope),
                "agent_pubkey": .string(signature.by_pubkey)
            ]),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "agent.identity"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func parseStarterAuthRequest(from value: ValueType) throws -> StarterAuthRequest {
        guard case let .object(object) = value else {
            throw StarterAuthError.invalidDomain
        }

        let domain = Self.stringValue(object["domain"])
        let purpose = Self.stringValue(object["purpose"])
        let interests = Self.stringList(object["interests"])
        let ttlSeconds = Self.integerValue(object["ttlSeconds"]) ?? 900

        guard !domain.isEmpty else {
            throw StarterAuthError.invalidDomain
        }
        guard !purpose.isEmpty else {
            throw StarterAuthError.invalidPurpose
        }
        guard !interests.isEmpty else {
            throw StarterAuthError.missingInterests
        }

        return StarterAuthRequest(
            domain: domain,
            purpose: purpose,
            interests: interests,
            ttlSeconds: max(60, min(ttlSeconds, 3600))
        )
    }

    private func starterAuthValue(_ payload: AgentStarterAuthPayload) -> ValueType {
        .object(starterAuthObject(payload))
    }

    private func parseEntityLinkContract(from value: ValueType) throws -> AgentEntityLinkContract {
        guard case let .object(object) = value,
              case let .object(revocation)? = object["revocation"] else {
            throw EntityLinkError.invalidContract
        }

        let contract = AgentEntityLinkContract(
            contract_id: Self.stringValue(object["contract_id"]),
            domain_a: Self.stringValue(object["domain_a"]),
            pubkey_a: Self.stringValue(object["pubkey_a"]),
            domain_b: Self.stringValue(object["domain_b"]),
            pubkey_b: Self.stringValue(object["pubkey_b"]),
            scope: Self.stringValue(object["scope"]),
            created_at: Self.stringValue(object["created_at"]),
            revocation: AgentEntityLinkRevocation(mode: Self.stringValue(revocation["mode"])),
            signatures: []
        )

        guard !contract.contract_id.isEmpty,
              !contract.domain_a.isEmpty,
              !contract.pubkey_a.isEmpty,
              !contract.domain_b.isEmpty,
              !contract.pubkey_b.isEmpty,
              !contract.scope.isEmpty,
              !contract.created_at.isEmpty,
              !contract.revocation.mode.isEmpty else {
            throw EntityLinkError.invalidContract
        }
        return contract
    }

    private func starterAuthObject(_ payload: AgentStarterAuthPayload) -> Object {
        [
            "version": .string(payload.version),
            "domain": .string(payload.domain),
            "identity_public_key": .string(payload.identity_public_key),
            "created_at": .string(payload.created_at),
            "expires_at": .string(payload.expires_at),
            "nonce": .string(payload.nonce),
            "purpose_interest": .object([
                "purpose": .string(payload.purpose_interest.purpose),
                "interests": .list(payload.purpose_interest.interests.map { .string($0) })
            ]),
            "signature": .object([
                "alg": .string(payload.signature.alg),
                "sig": .string(payload.signature.sig)
            ])
        ]
    }

    private func entityLinkSignatureValue(_ signature: AgentEntityLinkSignature) -> ValueType {
        .object([
            "by_pubkey": .string(signature.by_pubkey),
            "alg": .string(signature.alg),
            "sig": .string(signature.sig)
        ])
    }

    private static func stringValue(_ value: ValueType?) -> String {
        guard case let .string(string)? = value else {
            return ""
        }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stringList(_ value: ValueType?) -> [String] {
        guard case let .list(items)? = value else {
            return []
        }
        return items.compactMap { item in
            guard case let .string(string) = item else {
                return nil
            }
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private static func integerValue(_ value: ValueType?) -> Int? {
        guard case let .integer(integer)? = value else {
            return nil
        }
        return integer
    }
}

private struct StarterAuthRequest {
    var domain: String
    var purpose: String
    var interests: [String]
    var ttlSeconds: Int
}

private extension AgentIdentityDescriptor {
    func asValue() -> ValueType {
        .object([
            "version": .string(version),
            "instanceName": .string(instanceName),
            "identityContext": .string(identityContext),
            "identityUUID": .string(identityUUID),
            "displayName": .string(displayName),
            "publicKeyBase64URL": .string(publicKeyBase64URL),
            "didKey": .string(didKey),
            "createdAt": .string(createdAt),
            "storageKind": .string(storageKind)
        ])
    }
}

private enum LocalBase64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
