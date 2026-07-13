import Foundation
@preconcurrency import CellBase
import Testing
@testable import HavenAgentCellRuntime
@testable import HavenAgentCells
@testable import HavenMacAutomation
@testable import HavenAgentRuntime
@testable import HavenRuntimeBootstrap

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

private struct RecordingProcessRunner: ProcessRunning {
    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        SubprocessResult(
            command: [executableURL.path] + arguments,
            terminationStatus: 0,
            standardOutput: "ok",
            standardError: ""
        )
    }
}

private actor StubAgentLocalModelClient: AgentLocalModelInvoking {
    var response = AgentLocalModelInvokeResponse(
        providerID: "agent-qwen",
        model: "qwen-test",
        outputText: "local qwen answer",
        finishReason: "stop",
        inputTokens: 7,
        outputTokens: 3
    )
    var error: Error?
    private(set) var callCount = 0
    private(set) var lastConfig: AgentLocalModelBackendConfig?
    private(set) var lastRequest: AgentLocalModelInvokeRequest?

    func invoke(
        config: AgentLocalModelBackendConfig,
        request: AgentLocalModelInvokeRequest
    ) async throws -> AgentLocalModelInvokeResponse {
        callCount += 1
        lastConfig = config
        lastRequest = request
        if let error {
            throw error
        }
        return response
    }
}

private actor RecordingSecureCredentialStore: SecureCredentialStore {
    private var values: [String: Data] = [:]

    func store(secret: Data, handleID: String) async throws {
        values[handleID] = secret
    }

    func loadSecret(handleID: String) async throws -> Data? {
        values[handleID]
    }

    func deleteSecret(handleID: String) async throws {
        values[handleID] = nil
    }

    func storedValue(handleID: String) -> Data? {
        values[handleID]
    }
}

private final class MockIdentityVault: IdentityVaultProtocol, @unchecked Sendable {
    private var identities: [String: Identity] = [:]
    private var privateKeys: [String: Curve25519.Signing.PrivateKey] = [:]

    func initialize() async -> IdentityVaultProtocol {
        self
    }

    func addIdentity(identity: inout Identity, for identityContext: String) async {
        ensureSigningKey(for: identity)
        identities[identityContext] = identity
    }

    func identity(for identityContext: String, makeNewIfNotFound: Bool) async -> Identity? {
        if let existing = identities[identityContext] {
            return existing
        }
        guard makeNewIfNotFound else {
            return nil
        }
        let identity = Identity(identityContext, displayName: identityContext, identityVault: self)
        ensureSigningKey(for: identity)
        identities[identityContext] = identity
        return identity
    }

    func saveIdentity(_ identity: Identity) async {
        ensureSigningKey(for: identity)
        identities[identity.displayName] = identity
    }

    func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        guard let privateKey = privateKeys[identity.uuid] else {
            throw MockIdentityVaultError.noPrivateKey
        }
        return try privateKey.signature(for: messageData)
    }

    func verifySignature(signature: Data, messageData: Data, for identity: Identity) async throws -> Bool {
        guard let publicKeyData = identity.publicSecureKey?.compressedKey else {
            return false
        }
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        return publicKey.isValidSignature(signature, for: messageData)
    }

    func randomBytes64() async -> Data? {
        Data(repeating: 0xAA, count: 64)
    }

    func aquireKeyForTag(tag: String) async throws -> (key: String, iv: String) {
        ("test-\(tag)", "iv-\(tag)")
    }

    private func ensureSigningKey(for identity: Identity) {
        identity.identityVault = self
        if privateKeys[identity.uuid] != nil,
           identity.publicSecureKey?.compressedKey?.isEmpty == false {
            return
        }

        let privateKey = Curve25519.Signing.PrivateKey()
        identity.publicSecureKey = SecureKey(
            date: Date(timeIntervalSince1970: 0),
            privateKey: false,
            use: .signature,
            algorithm: .EdDSA,
            size: 32,
            curveType: .Curve25519,
            x: nil,
            y: nil,
            compressedKey: privateKey.publicKey.rawRepresentation
        )
        privateKeys[identity.uuid] = privateKey
    }

    enum MockIdentityVaultError: Error {
        case noPrivateKey
    }
}

@Suite(.serialized)
struct AgentCellsTests {
    @Test
    func decodedAgentSupervisorIsReadyForImmediateConcurrentStateReads() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        let previousVault = CellBase.defaultIdentityVault
        let vault = EphemeralIdentityVault()
        let owner = try #require(await vault.identity(
            for: "haven-agent-supervisor-decoded-readiness-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        CellBase.debugValidateAccessForEverything = false
        CellBase.defaultIdentityVault = vault
        defer {
            CellBase.debugValidateAccessForEverything = previousDebugAccess
            CellBase.defaultIdentityVault = previousVault
        }

        let fresh = await AgentSupervisorCell(owner: owner)
        let encoded = try JSONEncoder().encode(fresh)
        let decoded = try JSONDecoder().decode(AgentSupervisorCell.self, from: encoded)
        let decodedReference = UncheckedSendableReference(value: decoded)
        let baselineGrantKeypaths = decoded.agreementTemplate.grants.map(\.keypath)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<40 {
                group.addTask {
                    let state = try await decodedReference.value.get(keypath: "state", requester: owner)
                    guard case .object = state else {
                        Issue.record("Decoded AgentSupervisorCell must return its state object immediately.")
                        return
                    }
                }
            }
            try await group.waitForAll()
        }

        let installedGrantKeypaths = decoded.agreementTemplate.grants.map(\.keypath)
        #expect(installedGrantKeypaths == baselineGrantKeypaths)
        #expect(Set(installedGrantKeypaths).count == installedGrantKeypaths.count)
    }

    @Test
    func decodedDefaultAgentCellsInstallBindingsOnceBeforeImmediateStateReads() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        let previousVault = CellBase.defaultIdentityVault
        let previousMetadataStoreFactory = SecretCredentialCell.metadataStoreFactory
        let previousSecureStoreFactory = SecretCredentialCell.secureStoreFactory
        let previousRuntimeVaultFactory = SecretCredentialCell.runtimeVaultFactory
        let metadataStore = InMemorySecretCredentialMetadataStore()
        let secureStore = RecordingSecureCredentialStore()
        let runtimeVault = SecretCredentialRuntimeVault()
        let vault = EphemeralIdentityVault()
        let owner = try #require(await vault.identity(
            for: "haven-agent-default-cells-decoded-readiness-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        CellBase.debugValidateAccessForEverything = false
        CellBase.defaultIdentityVault = vault
        SecretCredentialCell.metadataStoreFactory = { metadataStore }
        SecretCredentialCell.secureStoreFactory = { secureStore }
        SecretCredentialCell.runtimeVaultFactory = { runtimeVault }
        defer {
            CellBase.debugValidateAccessForEverything = previousDebugAccess
            CellBase.defaultIdentityVault = previousVault
            SecretCredentialCell.metadataStoreFactory = previousMetadataStoreFactory
            SecretCredentialCell.secureStoreFactory = previousSecureStoreFactory
            SecretCredentialCell.runtimeVaultFactory = previousRuntimeVaultFactory
        }

        let supervisor = try JSONDecoder().decode(
            AgentSupervisorCell.self,
            from: JSONEncoder().encode(await AgentSupervisorCell(owner: owner))
        )
        let identity = try JSONDecoder().decode(
            AgentIdentityCell.self,
            from: JSONEncoder().encode(await AgentIdentityCell(owner: owner))
        )
        let inbox = try JSONDecoder().decode(
            RemoteIntentInboxCell.self,
            from: JSONEncoder().encode(await RemoteIntentInboxCell(owner: owner))
        )
        let review = try JSONDecoder().decode(
            RemoteIntentReviewCell.self,
            from: JSONEncoder().encode(await RemoteIntentReviewCell(owner: owner))
        )
        let localModel = try JSONDecoder().decode(
            AgentLocalModelCell.self,
            from: JSONEncoder().encode(await AgentLocalModelCell(owner: owner))
        )
        let network = try JSONDecoder().decode(
            NetworkSentinelCell.self,
            from: JSONEncoder().encode(await NetworkSentinelCell(owner: owner))
        )
        let credentials = try JSONDecoder().decode(
            SecretCredentialCell.self,
            from: JSONEncoder().encode(await SecretCredentialCell(owner: owner))
        )
        let mail = try JSONDecoder().decode(
            AgentMailDraftCell.self,
            from: JSONEncoder().encode(await AgentMailDraftCell(owner: owner))
        )
        let signature = try JSONDecoder().decode(
            AgentSignatureCell.self,
            from: JSONEncoder().encode(await AgentSignatureCell(owner: owner))
        )

        let cells: [HavenAgentRuntimeBindingCell] = [
            supervisor,
            identity,
            inbox,
            review,
            localModel,
            network,
            credentials,
            mail,
            signature
        ]
        let baselineGrantKeypaths = cells.map { $0.agreementTemplate.grants.map(\.keypath) }

        for cell in cells {
            let cellReference = UncheckedSendableReference(value: cell)
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<20 {
                    group.addTask {
                        try await cellReference.value.ensureRuntimeBindings()
                    }
                }
                try await group.waitForAll()
            }
        }

        for (index, cell) in cells.enumerated() {
            let installedGrantKeypaths = cell.agreementTemplate.grants.map(\.keypath)
            #expect(installedGrantKeypaths == baselineGrantKeypaths[index])
            #expect(Set(installedGrantKeypaths).count == installedGrantKeypaths.count)
            let state = try await cell.get(keypath: "state", requester: owner)
            guard case .object = state else {
                Issue.record("Decoded default HavenAgent cell at index \(index) must expose state immediately.")
                continue
            }
        }
    }

    @Test
    func decodedAgentCellRejectsSameUUIDDifferentKeyAndRetriesWithOwnerVault() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        let previousVault = CellBase.defaultIdentityVault
        let identityUUID = "haven-agent-decoded-owner-\(UUID().uuidString)"
        let ownerVault = EphemeralIdentityVault()
        var owner = Identity(identityUUID, displayName: "Haven Agent Owner", identityVault: ownerVault)
        await ownerVault.addIdentity(identity: &owner, for: "haven-agent-owner")
        let attackerVault = EphemeralIdentityVault()
        var sameUUIDDifferentKey = Identity(
            identityUUID,
            displayName: "Same UUID Different Key",
            identityVault: attackerVault
        )
        await attackerVault.addIdentity(identity: &sameUUIDDifferentKey, for: "haven-agent-attacker")

        CellBase.debugValidateAccessForEverything = false
        CellBase.defaultIdentityVault = attackerVault
        defer {
            CellBase.debugValidateAccessForEverything = previousDebugAccess
            CellBase.defaultIdentityVault = previousVault
        }

        #expect(owner.signingPublicKeyFingerprint != sameUUIDDifferentKey.signingPublicKeyFingerprint)
        let fresh = await AgentSupervisorCell(owner: owner)
        let decoded = try JSONDecoder().decode(
            AgentSupervisorCell.self,
            from: JSONEncoder().encode(fresh)
        )

        do {
            _ = try await decoded.get(keypath: "state", requester: sameUUIDDifferentKey)
            Issue.record("Same UUID with a different signing key must not hydrate decoded agent bindings.")
        } catch HavenAgentRuntimeBindingError.ownerProofUnavailable {
            // Expected fail-closed result.
        }

        let state = try await decoded.get(keypath: "state", requester: owner)
        guard case .object = state else {
            Issue.record("Decoded agent cell must recover once the proof-capable owner vault is restored.")
            return
        }
    }

    @Test
    func registryInstantiatesConcreteCells() async throws {
        let vault = MockIdentityVault()
        let owner = try #require(await vault.identity(for: "owner", makeNewIfNotFound: true))

        let cells = await AgentCellRegistry.instantiateDefaultCells(owner: owner)

        #expect(cells.count == AgentCellRegistry.concreteDescriptors.count)
        #expect(AgentCellRegistry.concreteDescriptors.map(\.kind) == [.agentSupervisor, .agentIdentity, .remoteIntentInbox, .remoteIntentReview, .localModel, .networkSentinel, .secretCredential, .emailOutbox, .signatureStatements])
        #expect(cells.contains { $0 is AgentSupervisorCell })
        #expect(cells.contains { $0 is AgentIdentityCell })
        #expect(cells.contains { $0 is RemoteIntentInboxCell })
        #expect(cells.contains { $0 is RemoteIntentReviewCell })
        #expect(cells.contains { $0 is AgentLocalModelCell })
        #expect(cells.contains { $0 is NetworkSentinelCell })
        #expect(cells.contains { $0 is SecretCredentialCell })
        #expect(cells.contains { $0 is AgentMailDraftCell })
        #expect(cells.contains { $0 is AgentSignatureCell })
    }

    @Test
    func mailDraftCellPreparesReviewIntentWithoutDispatching() async throws {
        let vault = MockIdentityVault()
        let owner = try #require(await vault.identity(for: "owner", makeNewIfNotFound: true))
        let cell = await AgentMailDraftCell(owner: owner)

        let state = try await cell.get(keypath: "state", requester: owner)
        guard case let .object(stateObject) = state else {
            Issue.record("Expected mail draft state object.")
            return
        }
        #expect(stateObject["actionID"] == .string(AgentMailDraftAutomation.actionID))
        #expect(stateObject["requiresLocalReview"] == .bool(true))

        let result = try await cell.set(
            keypath: "draftIntent",
            value: .object([
                "to": .string("ane@example.com"),
                "subject": .string("Oppfolging"),
                "body": .string("Hei Ane,\n\nSkal vi ta en prat?"),
                "correlationID": .string("mail-test-1")
            ]),
            requester: owner
        )
        guard case let .object(resultObject)? = result,
              case let .object(intent)? = resultObject["intent"],
              case let .object(arguments)? = intent["arguments"] else {
            Issue.record("Expected prepared draft intent object.")
            return
        }

        #expect(resultObject["status"] == .string("draft_intent_prepared"))
        #expect(intent["actionID"] == .string(AgentMailDraftAutomation.actionID))
        #expect(intent["topic"] == .string(AgentMailDraftAutomation.topic))
        #expect(intent["requiresLocalReview"] == .bool(true))
        #expect(intent["sideEffectUntilReview"] == .bool(false))
        #expect(arguments["to"] == .string("ane@example.com"))
        #expect(arguments["body"] == .string("Hei Ane,\n\nSkal vi ta en prat?"))
    }

    @Test
    func signatureCellPreparesRedactedSigningIntentWithoutSigning() async throws {
        let vault = MockIdentityVault()
        let owner = try #require(await vault.identity(for: "owner", makeNewIfNotFound: true))
        let cell = await AgentSignatureCell(owner: owner)

        let state = try await cell.get(keypath: "state", requester: owner)
        guard case let .object(stateObject) = state else {
            Issue.record("Expected signature state object.")
            return
        }
        #expect(stateObject["actionID"] == .string("identity.sign-statement"))
        #expect(stateObject["requiresAudience"] == .bool(true))
        #expect(stateObject["requiresNonce"] == .bool(true))

        let payload = Data("Signer denne teksten".utf8)
        let payloadBase64URL = Self.base64URLEncode(payload)
        let result = try await cell.set(
            keypath: "signIntent",
            value: .object([
                "purposeRef": .string(AgentSignatureStatement.purposeRef),
                "payloadBase64URL": .string(payloadBase64URL),
                "payloadMediaType": .string("text/plain"),
                "payloadDescription": .string("Kort testtekst"),
                "audience": .object([
                    "entityRef": .string("entity:victoria"),
                    "publicKeyFingerprint": .string("sha256:victoria-key")
                ]),
                "expiresAt": .string(ISO8601DateFormatter().string(from: Date().addingTimeInterval(3_600))),
                "nonce": .string("signature-cell-nonce-123")
            ]),
            requester: owner
        )

        guard case let .object(resultObject)? = result,
              case let .object(intent)? = resultObject["intent"],
              case let .object(payloadDescriptor)? = intent["payload"] else {
            Issue.record("Expected prepared signing intent object.")
            return
        }

        #expect(resultObject["status"] == .string("sign_intent_prepared"))
        #expect(intent["actionID"] == .string("identity.sign-statement"))
        #expect(intent["topic"] == .string(AgentSignatureStatement.topic))
        #expect(payloadDescriptor["sha256Base64URL"] == .string(Self.base64URLEncode(Data(SHA256.hash(data: payload)))))
        #expect(payloadDescriptor["sizeBytes"] == .number(payload.count))
        #expect(String(describing: intent).contains(payloadBase64URL) == false)
        #expect(String(describing: resultObject).contains("signatureBase64URL") == false)
    }

    @Test
    func secretCredentialCellStoresEncryptedBlobAndAuthorizesWithoutReturningRawSecret() async throws {
        let previousMetadataStoreFactory = SecretCredentialCell.metadataStoreFactory
        let previousSecureStoreFactory = SecretCredentialCell.secureStoreFactory
        let previousRuntimeVaultFactory = SecretCredentialCell.runtimeVaultFactory
        let metadataStore = InMemorySecretCredentialMetadataStore()
        let secureStore = RecordingSecureCredentialStore()
        let runtimeVault = SecretCredentialRuntimeVault()
        SecretCredentialCell.metadataStoreFactory = { metadataStore }
        SecretCredentialCell.secureStoreFactory = { secureStore }
        SecretCredentialCell.runtimeVaultFactory = { runtimeVault }
        defer {
            SecretCredentialCell.metadataStoreFactory = previousMetadataStoreFactory
            SecretCredentialCell.secureStoreFactory = previousSecureStoreFactory
            SecretCredentialCell.runtimeVaultFactory = previousRuntimeVaultFactory
        }

        let rawSecret = "mistral-test-api-key-material"
        let unlockKey = "unlock-key-with-enough-entropy-123456"
        let vault = MockIdentityVault()
        let owner = try #require(await vault.identity(for: "owner", makeNewIfNotFound: true))
        let cell = await SecretCredentialCell(owner: owner)

        let registration = try await cell.set(
            keypath: "credential.register",
            value: .object([
                "credentialID": .string("mistral-primary"),
                "providerID": .string("mistral"),
                "credentialLabel": .string("Mistral primary"),
                "secret": .string(rawSecret),
                "unlockKey": .string(unlockKey),
                "allowedPurposeRefs": .list([.string("purpose://model.provider-discovery")]),
                "allowedScaffolds": .list([.string("agentd")]),
                "allowedDataClasses": .list([.string("synthetic"), .string("public")]),
                "blockedDataClasses": .list([.string("private-contact-info")]),
                "requiresUserApproval": .bool(false),
                "dpaStatus": .string("needs-review"),
                "sourceURLs": .list([.string("https://console.mistral.ai")])
            ]),
            requester: owner
        )

        guard case let .object(registrationObject) = registration else {
            Issue.record("Expected registration object.")
            return
        }
        #expect(registrationObject["status"] == .string("registered"))
        #expect(String(describing: registration).contains(rawSecret) == false)

        let encrypted = try #require(await secureStore.storedValue(handleID: "haven.agentd.secretcredential.v1.mistral-primary"))
        #expect(String(decoding: encrypted, as: UTF8.self).contains(rawSecret) == false)

        let credentials = try await cell.get(keypath: "credentials", requester: owner)
        #expect(String(describing: credentials).contains(rawSecret) == false)
        #expect(String(describing: credentials).contains("mistral-primary"))

        let wrongUnlock = try await cell.set(
            keypath: "credential.authorizeUse",
            value: .object([
                "credentialID": .string("mistral-primary"),
                "unlockKey": .string("wrong-unlock-key-with-enough-entropy"),
                "purposeRef": .string("purpose://model.provider-discovery"),
                "requestingScaffold": .string("agentd"),
                "dataClass": .string("synthetic")
            ]),
            requester: owner
        )
        guard case let .object(wrongObject) = wrongUnlock else {
            Issue.record("Expected wrong unlock object.")
            return
        }
        #expect(wrongObject["status"] == .string("invalidUnlockKey"))

        let authorized = try await cell.set(
            keypath: "credential.authorizeUse",
            value: .object([
                "credentialID": .string("mistral-primary"),
                "unlockKey": .string(unlockKey),
                "purposeRef": .string("purpose://model.provider-discovery"),
                "requestingScaffold": .string("agentd"),
                "dataClass": .string("synthetic"),
                "ttlSeconds": .integer(60)
            ]),
            requester: owner
        )
        guard case let .object(authorizedObject) = authorized,
              case let .string(authorizedUseID)? = authorizedObject["authorizedUseID"] else {
            Issue.record("Expected authorizedUseID.")
            return
        }
        #expect(authorizedObject["status"] == .string("authorized"))
        #expect(String(describing: authorized).contains(rawSecret) == false)
        let openedSecret = try #require(await runtimeVault.secretData(for: authorizedUseID))
        #expect(String(decoding: openedSecret, as: UTF8.self) == rawSecret)
    }

    @Test
    func localModelCellGeneratesThroughConfiguredLoopbackBackendAndEmitsState() async throws {
        let client = StubAgentLocalModelClient()
        AgentLocalModelCell.clientFactory = { client }
        AgentLocalModelCell.backendConfigFactory = {
            AgentLocalModelBackendConfig(
                profileID: "qwen2.5-0.5b-instruct-q4_k_m",
                providerID: "agent-qwen",
                baseURL: "http://127.0.0.1:8080",
                apiPath: "/v1/chat/completions",
                model: "qwen-test",
                timeoutMs: 1_500
            )
        }
        defer {
            AgentLocalModelCell.clientFactory = { AgentLocalModelHTTPClient() }
            AgentLocalModelCell.backendConfigFactory = { AgentLocalModelBackendConfig.load() }
        }

        let vault = MockIdentityVault()
        let owner = try #require(await vault.identity(for: "owner", makeNewIfNotFound: true))
        let cell = await AgentLocalModelCell(owner: owner)

        let result = try await cell.set(
            keypath: "llm.generate",
            value: .object([
                "prompt": .string("Teach Qwen one HAVEN concept."),
                "systemPrompt": .string("You are a local teacher."),
                "maxTokens": .integer(64),
                "correlationID": .string("local-model-test")
            ]),
            requester: owner
        )

        guard case let .object(object) = result else {
            Issue.record("Expected local model generation object.")
            return
        }
        #expect(object["status"] == .string("completed"))
        #expect(object["providerID"] == .string("agent-qwen"))
        #expect(object["model"] == .string("qwen-test"))
        #expect(object["outputText"] == .string("local qwen answer"))
        #expect(await client.callCount == 1)
        #expect(await client.lastConfig?.baseURL == "http://127.0.0.1:8080")
        #expect(await client.lastRequest?.prompt == "Teach Qwen one HAVEN concept.")
        #expect(await client.lastRequest?.correlationID == "local-model-test")

        let state = try await cell.get(keypath: "state", requester: owner)
        guard case let .object(stateObject) = state,
              case let .object(lastInvocation)? = stateObject["lastInvocation"] else {
            Issue.record("Expected local model state with lastInvocation.")
            return
        }
        #expect(stateObject["endpoint"] == .string("cell:///agent/local-model"))
        #expect(stateObject["selectedModel"] == .string("qwen-test"))
        #expect(stateObject["backendStatus"] == .string("healthy"))
        #expect(lastInvocation["correlationID"] == .string("local-model-test"))
        guard case let .list(modelProfiles)? = stateObject["modelProfiles"] else {
            Issue.record("Expected local model profiles in state.")
            return
        }
        #expect(modelProfiles.contains { item in
            guard case let .object(profile) = item else { return false }
            return profile["id"] == .string("borealis-4b-instruct-q4_k_m")
        })
    }

    @Test
    func localModelBackendRejectsNonLoopbackByDefault() throws {
        let config = AgentLocalModelBackendConfig(
            providerID: "remote",
            baseURL: "https://models.example.com",
            apiPath: "/v1/chat/completions",
            model: "remote-model",
            timeoutMs: 1_500
        )

        #expect(throws: AgentLocalModelError.nonLoopbackBackend("models.example.com")) {
            _ = try config.endpointURL()
        }
    }

    @Test
    func localModelBackendConfigSelectsBorealisProfileFromEnvironment() throws {
        let config = AgentLocalModelBackendConfig.load(environment: [
            "HAVEN_AGENTD_LOCAL_LLM_PROFILE": "borealis-4b-instruct-q4_k_m"
        ])

        #expect(config.profileID == "borealis-4b-instruct-q4_k_m")
        #expect(config.providerID == "agent-borealis")
        #expect(config.baseURL == "http://127.0.0.1:8082")
        #expect(config.model == "NbAiLab/borealis-4b-instruct-preview-gguf:Q4_K_M")
    }

    @Test
    func supervisorCellProjectsRuntimeState() async throws {
        let plan = SproutBootstrapPlan(
            scaffoldDomain: "example.haven.local",
            requestedPortholeKind: "native",
            requestedCapabilities: ["cap.native_porthole"],
            resolverBaseURL: "https://example.haven.local",
            starterAuthPath: "/tmp/starter.json",
            entityLinkPath: "/tmp/entity-link.json",
            continuityProofPath: nil,
            admissionContractPath: nil,
            renewalLeadTimeSeconds: 600
        )
        let runtimeState = AgentRuntimeState(
            instanceName: "agent",
            status: "running",
            activeWatchIDs: ["downloads"],
            lastHeartbeatAt: "2026-03-12T10:00:00Z",
            lastEventSummary: "downloads:write",
            lastError: nil,
            lastExecutedAction: ExecutedActionRecord(
                kind: .shortcut,
                id: "ingest-download",
                status: "succeeded",
                recordedAt: "2026-03-12T10:00:00Z"
            ),
            lastSproutBootstrap: SproutBootstrapInvocationRecord(
                mode: .plan,
                executablePath: "/tmp/sprout",
                commandArguments: ["bootstrap", "plan"],
                artifactPath: "/tmp/plan.json",
                finalState: "done",
                resultSummary: "{}",
                recordedAt: "2026-03-12T10:00:00Z"
            ),
            bootstrapPlan: plan
        )
        await AgentRuntimeBridge.shared.update(runtimeState: runtimeState)
        #expect(await AgentRuntimeBridge.shared.runtimeStateSnapshot()?.status == "running")

        let vault = MockIdentityVault()
        let owner = try #require(await vault.identity(for: "owner", makeNewIfNotFound: true))
        let cell = await AgentSupervisorCell(owner: owner)
        let value = try await cell.get(keypath: "state", requester: owner)

        guard case let .object(object) = value else {
            Issue.record("Expected object payload from supervisor state.")
            return
        }
        #expect(object["status"] == .string("running"))
        #expect(object["instanceName"] == .string("agent"))
    }

    @Test
    func agentIdentityCellIssuesVerifiableEnrollmentAttestation() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let descriptor = AgentIdentityDescriptor(
            instanceName: "agent",
            identityContext: "haven.agent.owner.agent",
            identityUUID: UUID().uuidString,
            displayName: "HAVEN Agent (agent)",
            publicKeyBase64URL: privateKey.publicKey.rawRepresentation.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: ""),
            didKey: "did:key:test-agent",
            createdAt: "2026-03-15T12:00:00Z",
            storageKind: "state-file"
        )

        let vault = LocalIdentityVault()
        let owner = await vault.installIdentity(descriptor: descriptor, privateKey: privateKey)
        await AgentRuntimeBridge.shared.update(agentIdentityDescriptor: descriptor)
        let operatorIdentity = try #require(await vault.identity(for: "private", makeNewIfNotFound: true))
        let operatorDid = (try? operatorIdentity.did()) ?? operatorIdentity.uuid
        let operatorPublicKey = try #require(operatorIdentity.publicSecureKey?.compressedKey)
        let operatorPublicKeyBase64URL = Self.base64URLEncode(operatorPublicKey)

        let cell = await AgentIdentityCell(owner: owner)
        try await Self.authorize(operatorIdentity, for: cell)
        let response = try await cell.set(
            keypath: "enrollment.attest",
            value: .object([
                "challenge": .string("pair-test"),
                "purposeRef": .string("purpose://operate-local-haven-agent"),
                "scaffoldDomain": .string("staging.haven.digipomps.org"),
                "operatorIdentityUUID": .string(operatorIdentity.uuid),
                "operatorDid": .string(operatorDid),
                "operatorPublicKeyBase64URL": .string(operatorPublicKeyBase64URL)
            ]),
            requester: operatorIdentity
        )

        guard case let .object(object) = response else {
            Issue.record("Expected attestation object from AgentIdentityCell.")
            return
        }

        let canonicalAgentDid = (try? owner.did()) ?? owner.uuid
        #expect(object["agentIdentityUUID"] == .string(descriptor.identityUUID))
        #expect(object["agentDid"] == .string(canonicalAgentDid))
        #expect(object["purposeRef"] == .string("purpose://operate-local-haven-agent"))

        guard case let .string(signatureBase64URL)? = object["signatureBase64URL"] else {
            Issue.record("Expected signatureBase64URL in attestation.")
            return
        }

        let payloadData = try JSONEncoder.sortedKeyData([
            "agentDid": Self.requireString(object["agentDid"]),
            "agentDisplayName": Self.requireString(object["agentDisplayName"]),
            "agentIdentityUUID": Self.requireString(object["agentIdentityUUID"]),
            "agentPublicKeyBase64URL": Self.requireString(object["agentPublicKeyBase64URL"]),
            "challenge": Self.requireString(object["challenge"]),
            "instanceName": Self.requireString(object["instanceName"]),
            "issuedAt": Self.requireString(object["issuedAt"]),
            "operatorDid": Self.requireString(object["operatorDid"]),
            "operatorIdentityUUID": Self.requireString(object["operatorIdentityUUID"]),
            "operatorPublicKeyBase64URL": Self.requireString(object["operatorPublicKeyBase64URL"]),
            "purposeRef": Self.requireString(object["purposeRef"]),
            "scaffoldDomain": Self.requireString(object["scaffoldDomain"]),
            "version": Self.requireString(object["version"])
        ])

        let signature = try Self.base64URLDecode(signatureBase64URL)
        #expect(privateKey.publicKey.isValidSignature(signature, for: payloadData))
    }

    @Test
    func agentIdentityCellIssuesVerifiableStarterAuthPayload() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let descriptor = AgentIdentityDescriptor(
            instanceName: "agent",
            identityContext: "haven.agent.owner.agent",
            identityUUID: UUID().uuidString,
            displayName: "HAVEN Agent (agent)",
            publicKeyBase64URL: privateKey.publicKey.rawRepresentation.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: ""),
            didKey: "did:key:test-agent",
            createdAt: "2026-03-15T12:00:00Z",
            storageKind: "state-file"
        )

        let vault = LocalIdentityVault()
        let owner = await vault.installIdentity(descriptor: descriptor, privateKey: privateKey)
        await AgentRuntimeBridge.shared.update(agentIdentityDescriptor: descriptor)

        let cell = await AgentIdentityCell(owner: owner)
        let response = try await cell.set(
            keypath: "starterAuth.issue",
            value: .object([
                "domain": .string("staging.haven.digipomps.org"),
                "purpose": .string("purpose://operate-local-haven-agent"),
                "interests": .list([
                    .string("cellprotocol"),
                    .string("agent"),
                    .string("automation")
                ]),
                "ttlSeconds": .integer(600)
            ]),
            requester: owner
        )

        guard case let .object(object) = response,
              case let .object(purposeInterest)? = object["purpose_interest"],
              case let .object(signature)? = object["signature"] else {
            Issue.record("Expected starter auth object from AgentIdentityCell.")
            return
        }

        let payload = AgentStarterAuthPayload(
            domain: Self.requireString(object["domain"]),
            identity_public_key: Self.requireString(object["identity_public_key"]),
            created_at: Self.requireString(object["created_at"]),
            expires_at: Self.requireString(object["expires_at"]),
            nonce: Self.requireString(object["nonce"]),
            purpose_interest: AgentStarterPurposeInterest(
                purpose: Self.requireString(purposeInterest["purpose"]),
                interests: Self.requireStringList(purposeInterest["interests"])
            ),
            signature: AgentResolverSignatureEnvelope(
                alg: Self.requireString(signature["alg"]),
                sig: Self.requireString(signature["sig"])
            )
        )

        #expect(payload.domain == "staging.haven.digipomps.org")
        #expect(payload.purpose_interest.purpose == "purpose://operate-local-haven-agent")
        #expect(payload.purpose_interest.interests == ["cellprotocol", "agent", "automation"])
        #expect(try payload.verifySignature())
    }

    @Test
    func agentIdentityCellCountersignsEntityLinkForCurrentRequester() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let descriptor = AgentIdentityDescriptor(
            instanceName: "agent",
            identityContext: "haven.agent.owner.agent",
            identityUUID: UUID().uuidString,
            displayName: "HAVEN Agent (agent)",
            publicKeyBase64URL: privateKey.publicKey.rawRepresentation.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: ""),
            didKey: "did:key:test-agent",
            createdAt: "2026-03-15T12:00:00Z",
            storageKind: "state-file"
        )

        let vault = LocalIdentityVault()
        let owner = await vault.installIdentity(descriptor: descriptor, privateKey: privateKey)
        await AgentRuntimeBridge.shared.update(agentIdentityDescriptor: descriptor)

        let operatorIdentity = try #require(await vault.identity(for: "private", makeNewIfNotFound: true))
        let operatorPublicKey = try #require(operatorIdentity.publicSecureKey?.compressedKey)
        let operatorPublicKeyBase64URL = Self.base64URLEncode(operatorPublicKey)
        let pairingArtifactDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: pairingArtifactDirectory, withIntermediateDirectories: true)
        let pairingArtifactFile = pairingArtifactDirectory.appendingPathComponent("agent-enrollment-pairing.json")
        try await Self.writePairingArtifact(
            to: pairingArtifactFile,
            pairingID: "pairing-test",
            purposeRef: "purpose://operate-local-haven-agent",
            scaffoldDomain: "staging.haven.digipomps.org",
            approvedAt: "2026-03-15T12:00:00Z",
            operatorIdentity: operatorIdentity,
            operatorPublicKeyBase64URL: operatorPublicKeyBase64URL,
            agentDescriptor: descriptor,
            agentPrivateKey: privateKey
        )
        await AgentRuntimeBridge.shared.configure(pairingArtifactFileURL: pairingArtifactFile)

        let cell = await AgentIdentityCell(owner: owner)
        try await Self.authorize(operatorIdentity, for: cell)
        let response = try await cell.set(
            keypath: "entityLink.countersign",
            value: .object([
                "contract_id": .string("elc_test_001"),
                "domain_a": .string("staging.haven.digipomps.org"),
                "pubkey_a": .string(operatorPublicKeyBase64URL),
                "domain_b": .string("staging.haven.digipomps.org"),
                "pubkey_b": .string(descriptor.publicKeyBase64URL),
                "scope": .string("purpose-bound:purpose://operate-local-haven-agent"),
                "created_at": .string("2026-03-15T12:00:00Z"),
                "revocation": .object([
                    "mode": .string("mutual")
                ])
            ]),
            requester: operatorIdentity
        )

        guard case let .object(object) = response else {
            Issue.record("Expected entity-link signature object from AgentIdentityCell.")
            return
        }

        let signature = AgentEntityLinkSignature(
            by_pubkey: Self.requireString(object["by_pubkey"]),
            alg: Self.requireString(object["alg"]),
            sig: Self.requireString(object["sig"])
        )
        let contract = AgentEntityLinkContract(
            contract_id: "elc_test_001",
            domain_a: "staging.haven.digipomps.org",
            pubkey_a: operatorPublicKeyBase64URL,
            domain_b: "staging.haven.digipomps.org",
            pubkey_b: descriptor.publicKeyBase64URL,
            scope: "purpose-bound:purpose://operate-local-haven-agent",
            created_at: "2026-03-15T12:00:00Z",
            revocation: AgentEntityLinkRevocation(mode: "mutual"),
            signatures: [
                AgentEntityLinkSignature(by_pubkey: operatorPublicKeyBase64URL, alg: "Ed25519", sig: ""),
                signature
            ]
        )

        #expect(signature.by_pubkey == descriptor.publicKeyBase64URL)
        #expect(signature.alg == "Ed25519")
        let signatureData = try Self.base64URLDecode(signature.sig)
        #expect(privateKey.publicKey.isValidSignature(signatureData, for: try contract.canonicalPayloadData()))
    }

    @Test
    func remoteIntentInboxCellQueuesStructuredIntent() async throws {
        await AgentRuntimeBridge.shared.resetRemoteIntentState()
        await AgentRuntimeBridge.shared.update(remoteIntentPolicy: nil)

        let vault = MockIdentityVault()
        let owner = try #require(await vault.identity(for: "owner", makeNewIfNotFound: true))
        let cell = await RemoteIntentInboxCell(owner: owner)

        let payload: ValueType = .object([
            "topic": .string("intent.inbox"),
            "origin": .string("trustedRemote"),
            "actionID": .string("open-url-in-safari"),
            "arguments": .object([
                "url": .string("https://example.com")
            ])
        ])

        _ = try await cell.set(keypath: "enqueue", value: payload, requester: owner)
        let state = try await cell.get(keypath: "state", requester: owner)

        guard case let .object(object) = state else {
            Issue.record("Expected state object from inbox cell.")
            return
        }
        guard case let .integer(count)? = object["count"] else {
            Issue.record("Expected integer count in inbox state.")
            return
        }
        #expect(count == 1)
        #expect(object["lastTopic"] == .string("intent.inbox"))
    }

    @Test
    func remoteIntentInboxCellVerifiesSignedEnvelopeBeforeQueueing() async throws {
        await AgentRuntimeBridge.shared.resetRemoteIntentState()

        let privateKey = Curve25519.Signing.PrivateKey()
        let issuedAt = ISO8601DateFormatter().string(from: Date())
        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(60))
        let issuerID = "scaffold-entity.example"

        await AgentRuntimeBridge.shared.update(
            remoteIntentPolicy: RemoteIntentPolicy(
                issuers: [
                    TrustedRemoteIntentIssuer(
                        issuerID: issuerID,
                        publicSigningKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString(),
                        allowedTopics: ["intent.inbox"],
                        allowedActionIDs: ["open-url-in-safari"]
                    )
                ],
                requireExpiry: true,
                maxClockSkewSeconds: 300,
                maxArgumentCount: 8
            )
        )

        let payload = SignedRemoteIntentPayload(
            issuerID: issuerID,
            nonce: "nonce-1",
            topic: "intent.inbox",
            origin: "scaffold-entity.example",
            actionID: "open-url-in-safari",
            arguments: ["url": "https://example.com"],
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
        let signature = try privateKey.signature(for: RemoteIntentVerifier.canonicalPayloadData(payload))

        let vault = MockIdentityVault()
        let owner = try #require(await vault.identity(for: "owner", makeNewIfNotFound: true))
        let cell = await RemoteIntentInboxCell(owner: owner)

        let envelopeValue: ValueType = .object([
            "payload": .object([
                "issuerID": .string(payload.issuerID),
                "nonce": .string(payload.nonce),
                "topic": .string(payload.topic),
                "origin": .string(payload.origin),
                "actionID": .string(payload.actionID),
                "arguments": .object(payload.arguments.mapValues(ValueType.string)),
                "issuedAt": .string(payload.issuedAt),
                "expiresAt": .string(try #require(payload.expiresAt))
            ]),
            "signatureBase64": .string(signature.base64EncodedString())
        ])

        _ = try await cell.set(keypath: "enqueueSigned", value: envelopeValue, requester: owner)
        let state = try await cell.get(keypath: "state", requester: owner)

        guard case let .object(object) = state else {
            Issue.record("Expected state object from inbox cell.")
            return
        }
        guard case let .integer(count)? = object["count"] else {
            Issue.record("Expected integer count in inbox state.")
            return
        }
        #expect(count == 1)
        #expect(object["lastVerificationStatus"] == .string("verified"))
        #expect(object["lastIssuerID"] == .string(issuerID))
    }

    @Test
    func portholeIngressSessionQueuesVerifiedEnvelopeFromFlowEvent() async throws {
        await AgentRuntimeBridge.shared.resetRemoteIntentState()

        let privateKey = Curve25519.Signing.PrivateKey()
        let issuedAt = ISO8601DateFormatter().string(from: Date())
        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(60))
        let issuerID = "scaffold-entity.example"

        await AgentRuntimeBridge.shared.update(
            remoteIntentPolicy: RemoteIntentPolicy(
                issuers: [
                    TrustedRemoteIntentIssuer(
                        issuerID: issuerID,
                        publicSigningKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString(),
                        allowedTopics: ["intent.inbox"],
                        allowedActionIDs: ["open-url-in-safari"]
                    )
                ],
                requireExpiry: true,
                maxClockSkewSeconds: 300,
                maxArgumentCount: 8
            )
        )

        let payload = SignedRemoteIntentPayload(
            issuerID: issuerID,
            nonce: "nonce-porthole-1",
            topic: "intent.inbox",
            origin: issuerID,
            actionID: "open-url-in-safari",
            arguments: ["url": "https://example.com"],
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
        let envelope = SignedRemoteIntentEnvelope(
            payload: payload,
            signatureBase64: try privateKey.signature(
                for: RemoteIntentVerifier.canonicalPayloadData(payload)
            ).base64EncodedString()
        )

        var flowElement = FlowElement(
            title: "remote.intent",
            content: .object([
                "remoteIntentEnvelope": SignedRemoteIntentEnvelopeValueCodec.encode(envelope)
            ]),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "porthole"

        let session = PortholeIngressSession()
        await session.consume(flowElement: flowElement)

        let queued = await AgentRuntimeBridge.shared.queuedIntentSnapshot()
        #expect(queued.count == 1)
        #expect(queued.first?.verificationStatus == "verified")
        #expect(queued.first?.issuerID == issuerID)

        let status = await session.statusSnapshot()
        #expect(status.lastAcceptedIntentID == "nonce-porthole-1")
        #expect(status.lastRejectedReason == nil)
    }

    @Test
    func remoteIntentReviewCellApprovesVerifiedIntentAndRecordsAudit() async throws {
        await AgentRuntimeBridge.shared.resetRemoteIntentState()
        await AgentRuntimeBridge.shared.update(
            remoteIntentExecutor: RemoteIntentExecutionBridge(processRunner: RecordingProcessRunner())
        )
        await AgentRuntimeBridge.shared.update(
            remoteIntentPolicy: RemoteIntentPolicy(
                issuers: [
                    TrustedRemoteIntentIssuer(
                        issuerID: "scaffold-entity.example",
                        publicSigningKeyBase64: Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString(),
                        allowedTopics: ["intent.inbox"],
                        allowedActionIDs: ["open-url-in-safari"]
                    )
                ]
            )
        )
        await (AgentRuntimeBridge.shared.remoteIntentExecutorSnapshot())?.update(
            policy: AutomationPolicy(
                appleScripts: [
                    AppleScriptDefinition(
                        id: "open-url-in-safari",
                        description: "No-op test runner.",
                        source: "on run argv\nreturn \"ok\"\nend run",
                        argumentOrder: ["url"],
                        argumentConstraints: [
                            "url": StringConstraint(
                                required: true,
                                maxLength: 1024,
                                allowedValues: [],
                                pattern: #"https://[A-Za-z0-9\.\-/_~:%\?#\[\]@!\$&'\(\)\*\+,;=]+"#
                            )
                        ],
                        allowedForRemoteExecution: true,
                        requiresUserSession: false
                    )
                ]
            )
        )

        await AgentRuntimeBridge.shared.enqueue(
            intent: QueuedRemoteIntent(
                id: "review-intent-1",
                topic: "intent.inbox",
                origin: "scaffold-entity.example",
                actionID: "open-url-in-safari",
                arguments: ["url": "https://example.com"],
                receivedAt: ISO8601DateFormatter().string(from: Date()),
                issuerID: "scaffold-entity.example",
                issuedAt: ISO8601DateFormatter().string(from: Date()),
                expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(60)),
                verificationStatus: "verified"
            )
        )

        let vault = MockIdentityVault()
        let owner = try #require(await vault.identity(for: "owner", makeNewIfNotFound: true))
        let cell = await RemoteIntentReviewCell(owner: owner)

        let payload: ValueType = .object([
            "intentID": .string("review-intent-1"),
            "note": .string("Approved for dispatch")
        ])

        _ = try await cell.set(keypath: "approve", value: payload, requester: owner)

        let state = try await cell.get(keypath: "state", requester: owner)
        guard case let .object(object) = state else {
            Issue.record("Expected review state object.")
            return
        }
        guard case let .integer(pendingCount)? = object["pendingCount"] else {
            Issue.record("Expected integer pendingCount in review state.")
            return
        }
        guard case let .integer(auditCount)? = object["auditCount"] else {
            Issue.record("Expected integer auditCount in review state.")
            return
        }
        #expect(pendingCount == 0)
        #expect(auditCount == 1)
        #expect(object["lastOutcome"] == .string("approved_dispatched"))

        let audit = try await cell.get(keypath: "audit", requester: owner)
        guard case let .list(items) = audit, let first = items.first, case let .object(auditObject) = first else {
            Issue.record("Expected audit list with one record.")
            return
        }
        #expect(auditObject["intentID"] == .string("review-intent-1"))
        #expect(auditObject["outcome"] == .string("approved_dispatched"))
    }
}

private extension AgentCellsTests {
    static func requireString(_ value: ValueType?) -> String {
        guard case let .string(string)? = value else {
            Issue.record("Expected string in attestation payload.")
            return ""
        }
        return string
    }

    static func base64URLDecode(_ value: String) throws -> Data {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - (base64.count % 4)) % 4
        if padding > 0 {
            base64 += String(repeating: "=", count: padding)
        }
        guard let data = Data(base64Encoded: base64) else {
            throw NSError(domain: "AgentCellsTests", code: 1)
        }
        return data
    }

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func requireStringList(_ value: ValueType?) -> [String] {
        guard case let .list(items)? = value else {
            Issue.record("Expected string list in starter auth payload.")
            return []
        }
        return items.compactMap { item in
            guard case let .string(string) = item else {
                Issue.record("Expected string item in starter auth payload.")
                return nil
            }
            return string
        }
    }

    static func writePairingArtifact(
        to fileURL: URL,
        pairingID: String,
        purposeRef: String,
        scaffoldDomain: String,
        approvedAt: String,
        operatorIdentity: Identity,
        operatorPublicKeyBase64URL: String,
        agentDescriptor: AgentIdentityDescriptor,
        agentPrivateKey: Curve25519.Signing.PrivateKey
    ) async throws {
        struct AttestationPayload: Codable {
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
        struct Attestation: Codable {
            var payload: AttestationPayload
            var signatureAlgorithm: String
            var signatureBase64URL: String
        }
        struct ApprovalPayload: Codable {
            var version: String
            var pairingID: String
            var scaffoldDomain: String
            var purposeRef: String
            var challenge: String
            var attestationSHA256Base64URL: String
            var operatorIdentityUUID: String
            var operatorDisplayName: String
            var operatorDid: String
            var operatorPublicKeyBase64URL: String
            var approvedAt: String
        }
        struct Approval: Codable {
            var payload: ApprovalPayload
            var signatureBase64: String
            var curveType: String
        }
        struct Artifact: Codable {
            var version: String
            var pairingID: String
            var recordedAt: String
            var verificationStatus: String
            var agentAttestation: Attestation
            var operatorApproval: Approval
        }

        let challenge = "pair-test"
        let operatorDid = (try? operatorIdentity.did()) ?? operatorIdentity.uuid
        let attestationPayload = AttestationPayload(
            version: "1.0",
            instanceName: agentDescriptor.instanceName,
            agentIdentityUUID: agentDescriptor.identityUUID,
            agentDisplayName: agentDescriptor.displayName,
            agentDid: agentDescriptor.didKey,
            agentPublicKeyBase64URL: agentDescriptor.publicKeyBase64URL,
            operatorIdentityUUID: operatorIdentity.uuid,
            operatorDid: operatorDid,
            operatorPublicKeyBase64URL: operatorPublicKeyBase64URL,
            purposeRef: purposeRef,
            scaffoldDomain: scaffoldDomain,
            challenge: challenge,
            issuedAt: approvedAt
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let attestationPayloadData = try encoder.encode(attestationPayload)
        let attestationSignature = try agentPrivateKey.signature(for: attestationPayloadData)
        let attestation = Attestation(
            payload: attestationPayload,
            signatureAlgorithm: "Ed25519",
            signatureBase64URL: base64URLEncode(attestationSignature)
        )

        let approvalPayload = ApprovalPayload(
            version: "1.0",
            pairingID: pairingID,
            scaffoldDomain: scaffoldDomain,
            purposeRef: purposeRef,
            challenge: challenge,
            attestationSHA256Base64URL: base64URLEncode(Data(SHA256.hash(data: attestationPayloadData))),
            operatorIdentityUUID: operatorIdentity.uuid,
            operatorDisplayName: operatorIdentity.displayName,
            operatorDid: operatorDid,
            operatorPublicKeyBase64URL: operatorPublicKeyBase64URL,
            approvedAt: approvedAt
        )
        let approvalPayloadData = try encoder.encode(approvalPayload)
        let operatorSignature = try #require(await operatorIdentity.sign(data: approvalPayloadData))
        let approval = Approval(
            payload: approvalPayload,
            signatureBase64: operatorSignature.base64EncodedString(),
            curveType: operatorIdentity.publicSecureKey?.curveType.rawValue ?? "unknown"
        )

        let artifact = Artifact(
            version: "1.0",
            pairingID: pairingID,
            recordedAt: approvedAt,
            verificationStatus: "agent-attestation-verified",
            agentAttestation: attestation,
            operatorApproval: approval
        )
        let artifactEncoder = JSONEncoder()
        artifactEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try artifactEncoder.encode(artifact).write(to: fileURL, options: [.atomic])
    }

    static func authorize(_ identity: Identity, for cell: GeneralCell) async throws {
        let agreement = cell.agreementTemplate
        agreement.signatories.append(identity)
        let state = await cell.addAgreement(agreement, for: identity)
        #expect(state == .signed)
    }
}

private extension JSONEncoder {
    static func sortedKeyData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}
