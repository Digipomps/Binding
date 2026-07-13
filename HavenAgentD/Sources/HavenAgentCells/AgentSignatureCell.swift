import Foundation
import CryptoKit
import CellBase
import HavenAgentRuntime
import SproutCrypto

public final class AgentSignatureCell: HavenAgentRuntimeBindingCell {
    private enum CodingKeys: String, CodingKey {
        case version
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
        await setupPermissions()
        await setupKeys(owner: owner)
    }

    private func setupPermissions() async {
        ensureAgreementGrant("r---", for: "state")
        ensureAgreementGrant("r---", for: "contracts")
        ensureAgreementGrant("r---", for: "purposeProfiles")
        ensureAgreementGrant("rw--", for: "signIntent")
        ensureAgreementGrant("r---", for: "flow")
    }

    private func hasAccess(_ access: String, at key: String, requester: Identity) async -> Bool {
        if await validateAccess(access, at: key, for: requester) { return true }
        return await LocalControlCellAccess.isPairedOperator(requester)
    }

    private func setupKeys(owner: Identity) async {
        await setupExploreContracts(owner: owner)

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "state", requester: requester) else { return .string("denied") }
            return self.stateValue()
        })

        await addInterceptForGet(requester: owner, key: "contracts", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "contracts", requester: requester) else { return .string("denied") }
            return self.contractsValue()
        })

        await addInterceptForGet(requester: owner, key: "purposeProfiles", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "purposeProfiles", requester: requester) else { return .string("denied") }
            return .list([.object(Self.purposeProfile())])
        })

        await addInterceptForSet(requester: owner, key: "signIntent", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("rw--", at: "signIntent", requester: requester) else { return .string("denied") }
            return await self.prepareSignIntent(value: value, requester: requester)
        })
    }

    private func setupExploreContracts(owner: Identity) async {
        let audienceSchema = ExploreContract.objectSchema(
            properties: [
                "entityRef": ExploreContract.schema(type: "string"),
                "publicKeyBase64URL": ExploreContract.schema(type: "string"),
                "publicKeyFingerprint": ExploreContract.schema(type: "string")
            ],
            requiredKeys: ["entityRef"]
        )
        let signInput = ExploreContract.objectSchema(
            properties: [
                "purposeRef": ExploreContract.schema(type: "string"),
                "payloadBase64URL": ExploreContract.schema(type: "string"),
                "payloadSHA256Base64URL": ExploreContract.schema(type: "string"),
                "payloadMediaType": ExploreContract.schema(type: "string"),
                "payloadDescription": ExploreContract.schema(type: "string"),
                "signerIdentityUUID": ExploreContract.schema(type: "string"),
                "audience": audienceSchema,
                "expiresAt": ExploreContract.schema(type: "string"),
                "nonce": ExploreContract.schema(type: "string"),
                "correlationID": ExploreContract.schema(type: "string")
            ],
            requiredKeys: ["purposeRef", "audience", "expiresAt", "nonce"]
        )
        await registerExploreContract(
            requester: owner,
            key: "state",
            method: .get,
            returns: ExploreContract.objectSchema(),
            permissions: ["r---"],
            description: .string("Returns the local signed-statement adapter status and purpose metadata.")
        )
        await registerExploreContract(
            requester: owner,
            key: "contracts",
            method: .get,
            returns: ExploreContract.objectSchema(),
            permissions: ["r---"],
            description: .string("Describes the detached signed-statement command shape.")
        )
        await registerExploreContract(
            requester: owner,
            key: "purposeProfiles",
            method: .get,
            returns: ExploreContract.listSchema(item: ExploreContract.objectSchema()),
            permissions: ["r---"],
            description: .string("Returns purpose refs and interests Co-Pilot can use for local identity signing.")
        )
        await registerExploreContract(
            requester: owner,
            key: "signIntent",
            method: .set,
            input: signInput,
            returns: ExploreContract.objectSchema(),
            permissions: ["rw--"],
            flowEffects: [ExploreContract.flowEffect(trigger: .set, topic: AgentSignatureStatement.topic, contentType: "object")],
            description: .string("Prepares a redacted local identity-signing intent. Actual signing happens only through the daemon-owned command endpoint.")
        )
    }

    private func stateValue() -> ValueType {
        .object([
            "status": .string("ready"),
            "endpoint": .string(AgentSignatureStatement.endpoint),
            "actionID": .string("identity.sign-statement"),
            "topic": .string(AgentSignatureStatement.topic),
            "runtimeTarget": .string("macos-agentd"),
            "deliveryMode": .string("detached_signed_statement"),
            "sideEffectBoundary": .string("Uses the local agent identity only after strict purpose, audience, expiry, payload-hash and nonce validation."),
            "requiresAudience": .bool(true),
            "requiresExpiry": .bool(true),
            "requiresNonce": .bool(true),
            "maxPayloadBytes": .number(AgentSignatureStatement.maxPayloadBytes),
            "maxValiditySeconds": .number(Int(AgentSignatureStatement.maxValiditySeconds)),
            "purposeProfiles": .list([.object(Self.purposeProfile())])
        ])
    }

    private func contractsValue() -> ValueType {
        .object([
            "signIntent": .object([
                "expects": .object([
                    "purposeRef": .string("required allowed purpose ref"),
                    "payloadBase64URL": .string("optional detached payload bytes; mutually exclusive with payloadSHA256Base64URL"),
                    "payloadSHA256Base64URL": .string("optional detached SHA-256 hash; mutually exclusive with payloadBase64URL"),
                    "audience": .string("required object with entityRef and public key material/fingerprint"),
                    "expiresAt": .string("required ISO-8601 timestamp, max 24h"),
                    "nonce": .string("required one-time nonce"),
                    "correlationID": .string("optional String")
                ]),
                "returns": .string("A redacted signing intent. The daemon command returns the signed envelope."),
                "sideEffect": .string("none; raw payload is never emitted in FlowElements")
            ]),
            "commandEndpoint": .string("/commands/identity/sign-statement")
        ])
    }

    private static func purposeProfile() -> Object {
        [
            "id": .string("agent-identity-sign-statement"),
            "title": .string("Identity Signature"),
            "purposeRef": .string(AgentSignatureStatement.purposeRef),
            "purposeRefs": .list(AgentSignatureStatement.purposeRefs.map(ValueType.string)),
            "goalID": .string(AgentSignatureStatement.goalID),
            "capabilityRef": .string(AgentSignatureStatement.capabilityRef),
            "interests": .list(AgentSignatureStatement.interests.map(ValueType.string)),
            "privacyLevel": .string("local_key_use"),
            "executionScope": .string("local_agent_identity_signature"),
            "sideEffectBoundary": .string("Creates a detached, audience-bound signed statement; private key never leaves HAVENAgentD.")
        ]
    }

    private func prepareSignIntent(value: ValueType, requester: Identity) async -> ValueType {
        do {
            let request = try Self.parseRequest(value)
            let payload = try Self.payloadDescriptor(from: request)
            let intent: Object = [
                "topic": .string(AgentSignatureStatement.topic),
                "origin": .string(AgentSignatureStatement.endpoint),
                "actionID": .string("identity.sign-statement"),
                "purposeRef": .string(request.purposeRef),
                "goalID": .string(AgentSignatureStatement.goalID),
                "requiresAudience": .bool(true),
                "requiresExpiry": .bool(true),
                "requiresNonce": .bool(true),
                "payload": .object([
                    "encoding": .string(payload.encoding),
                    "sha256Base64URL": .string(payload.sha256Base64URL),
                    "sizeBytes": payload.sizeBytes.map(ValueType.number) ?? .null,
                    "mediaType": payload.mediaType.map(ValueType.string) ?? .null,
                    "description": payload.description.map(ValueType.string) ?? .null
                ]),
                "audience": .object(Self.audienceObject(request.audience)),
                "expiresAt": .string(request.expiresAt),
                "nonce": .string(request.nonce),
                "correlationID": request.correlationID.map(ValueType.string) ?? .null
            ]
            await publishSignIntentPreparedEvent(intent: intent, requester: requester)
            return .object([
                "status": .string("sign_intent_prepared"),
                "message": .string("Identity signing intent prepared. Use the daemon command endpoint to create the signed envelope."),
                "intent": .object(intent),
                "purposeProfile": .object(Self.purposeProfile())
            ])
        } catch {
            return .object([
                "status": .string("invalid_request"),
                "message": .string(error.localizedDescription)
            ])
        }
    }

    private func publishSignIntentPreparedEvent(intent: Object, requester: Identity) async {
        var payload = intent
        payload["preparedAt"] = .string(ISO8601DateFormatter().string(from: Date()))
        var flow = FlowElement(
            title: "agent.identity.signature.intent_prepared",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flow.topic = AgentSignatureStatement.topic
        flow.origin = uuid
        pushFlowElement(flow, requester: requester)
    }

    private static func parseRequest(_ value: ValueType) throws -> AgentSignStatementRequest {
        guard case let .object(object) = value else {
            throw AgentSignatureCellError.invalidPayload
        }
        guard case let .object(audienceObject)? = object["audience"] else {
            throw AgentSignatureCellError.missingRequiredField("audience")
        }
        let purposeRef = optionalString("purposeRef", in: object) ?? AgentSignatureStatement.purposeRef
        return AgentSignStatementRequest(
            purposeRef: purposeRef,
            payloadBase64URL: optionalString("payloadBase64URL", in: object),
            payloadSHA256Base64URL: optionalString("payloadSHA256Base64URL", in: object),
            payloadMediaType: optionalString("payloadMediaType", in: object),
            payloadDescription: optionalString("payloadDescription", in: object),
            signerIdentityUUID: optionalString("signerIdentityUUID", in: object),
            audience: AgentSignatureAudience(
                entityRef: try requiredString("entityRef", in: audienceObject),
                publicKeyBase64URL: optionalString("publicKeyBase64URL", in: audienceObject),
                publicKeyFingerprint: optionalString("publicKeyFingerprint", in: audienceObject)
            ),
            expiresAt: try requiredString("expiresAt", in: object),
            nonce: try requiredString("nonce", in: object),
            correlationID: optionalString("correlationID", in: object) ?? optionalString("correlationId", in: object)
        )
    }

    private static func payloadDescriptor(from request: AgentSignStatementRequest) throws -> AgentSignedStatementPayloadDescriptor {
        if request.payloadBase64URL != nil && request.payloadSHA256Base64URL != nil {
            throw AgentSignatureCellError.conflictingPayloadInputs
        }
        if let payloadBase64URL = request.payloadBase64URL {
            let data = try Base64URL.decode(payloadBase64URL)
            guard data.count <= AgentSignatureStatement.maxPayloadBytes else {
                throw AgentSignatureCellError.payloadTooLarge
            }
            return AgentSignedStatementPayloadDescriptor(
                encoding: "detached-sha256",
                sha256Base64URL: Base64URL.encode(Data(SHA256.hash(data: data))),
                sizeBytes: data.count,
                mediaType: request.payloadMediaType,
                description: request.payloadDescription
            )
        }
        guard let hash = request.payloadSHA256Base64URL,
              (try? Base64URL.decode(hash).count) == 32 else {
            throw AgentSignatureCellError.missingPayloadHash
        }
        return AgentSignedStatementPayloadDescriptor(
            encoding: "detached-sha256",
            sha256Base64URL: hash,
            mediaType: request.payloadMediaType,
            description: request.payloadDescription
        )
    }

    private static func audienceObject(_ audience: AgentSignatureAudience) -> Object {
        [
            "entityRef": .string(audience.entityRef),
            "publicKeyBase64URL": audience.publicKeyBase64URL.map(ValueType.string) ?? .null,
            "publicKeyFingerprint": audience.publicKeyFingerprint.map(ValueType.string) ?? .null
        ]
    }

    private static func requiredString(_ key: String, in object: Object) throws -> String {
        guard let value = optionalString(key, in: object), !value.isEmpty else {
            throw AgentSignatureCellError.missingRequiredField(key)
        }
        return value
    }

    private static func optionalString(_ key: String, in object: Object) -> String? {
        guard case let .string(value)? = object[key] else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum AgentSignatureCellError: Error, LocalizedError {
    case invalidPayload
    case missingRequiredField(String)
    case missingPayloadHash
    case conflictingPayloadInputs
    case payloadTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Expected an object payload."
        case .missingRequiredField(let field):
            return "Missing required field: \(field)."
        case .missingPayloadHash:
            return "Either payloadBase64URL or payloadSHA256Base64URL is required."
        case .conflictingPayloadInputs:
            return "Provide either payloadBase64URL or payloadSHA256Base64URL, not both."
        case .payloadTooLarge:
            return "Payload exceeds the local signing size limit."
        }
    }
}
