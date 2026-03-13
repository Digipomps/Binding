import Foundation
@preconcurrency import CellBase
import Testing
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

private final class MockIdentityVault: IdentityVaultProtocol {
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

        #expect(cells.count == 3)
        #expect(AgentCellRegistry.concreteDescriptors.map(\.kind) == [.agentSupervisor, .remoteIntentInbox, .remoteIntentReview])
        #expect(cells.contains { $0 is AgentSupervisorCell })
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
