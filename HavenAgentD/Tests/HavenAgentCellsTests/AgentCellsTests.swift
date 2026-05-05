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

private final class MockIdentityVault: IdentityVaultProtocol, @unchecked Sendable {
    private var identities: [String: Identity] = [:]

    func initialize() async -> IdentityVaultProtocol {
        self
    }

    func addIdentity(identity: inout Identity, for identityContext: String) async {
        identity.identityVault = self
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
        identities[identityContext] = identity
        return identity
    }

    func saveIdentity(_ identity: Identity) async {
        identities[identity.displayName] = identity
    }

    func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        messageData + Data(identity.uuid.utf8)
    }

    func verifySignature(signature: Data, messageData: Data, for identity: Identity) async throws -> Bool {
        signature == messageData + Data(identity.uuid.utf8)
    }

    func randomBytes64() async -> Data? {
        Data(repeating: 0xAA, count: 64)
    }

    func aquireKeyForTag(tag: String) async throws -> (key: String, iv: String) {
        ("test-\(tag)", "iv-\(tag)")
    }
}

@Suite(.serialized)
struct AgentCellsTests {
    @Test
    func registryInstantiatesConcreteCells() async throws {
        let vault = MockIdentityVault()
        let owner = try #require(await vault.identity(for: "owner", makeNewIfNotFound: true))

        let cells = await AgentCellRegistry.instantiateDefaultCells(owner: owner)

        #expect(cells.count == 4)
        #expect(AgentCellRegistry.concreteDescriptors.map(\.kind) == [.agentSupervisor, .agentIdentity, .remoteIntentInbox, .remoteIntentReview])
        #expect(cells.contains { $0 is AgentSupervisorCell })
        #expect(cells.contains { $0 is AgentIdentityCell })
        #expect(cells.contains { $0 is RemoteIntentInboxCell })
        #expect(cells.contains { $0 is RemoteIntentReviewCell })
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
