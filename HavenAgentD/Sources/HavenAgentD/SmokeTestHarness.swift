import Foundation
import CellBase
import HavenAgentCellRuntime
import HavenAgentCells
import HavenAgentRuntime
import HavenMacAutomation
import HavenRuntimeBootstrap
import SproutCore
import SproutCrypto
import SproutResolverAdapter
import Darwin

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

struct SmokeTestSummary: Codable, Sendable {
    var runtimeRoot: String
    var configPath: String
    var statePath: String
    var remoteIntentStatePath: String
    var finalPhase: String
    var finalContractID: String?
    var bootstrapArtifactPath: String?
    var queuedIntentCount: Int
    var lastAcceptedIntentID: String?
    var reviewAuditCount: Int
    var lastReviewOutcome: String?
    var lastExecutedActionID: String?
    var lastExecutedActionKind: String?
}

private enum SmokeTestHarnessError: Error, LocalizedError {
    case missingRuntimeState(String)
    case missingRemoteIntentState(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .missingRuntimeState(let path):
            return "Smoke test could not load runtime state: \(path)"
        case .missingRemoteIntentState(let path):
            return "Smoke test could not load remote intent state: \(path)"
        case .timedOut(let reason):
            return "Smoke test timed out: \(reason)"
        }
    }
}

private actor SmokeTestProcessRunner: ProcessRunning {
    enum Outcome: Sendable {
        case fail(String)
        case success(contractID: String, expiresAt: Date)
        case commandSuccess(String)
    }

    private static let resolverSeed = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
    private var outcomes: [Outcome]

    init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        let command = [executableURL.path] + arguments
        guard !outcomes.isEmpty else {
            return SubprocessResult(
                command: command,
                terminationStatus: 1,
                standardOutput: "",
                standardError: "No scripted smoke-test outcome remains."
            )
        }

        let outcome = outcomes.removeFirst()
        switch outcome {
        case .fail(let message):
            return SubprocessResult(
                command: command,
                terminationStatus: 1,
                standardOutput: "",
                standardError: message
            )

        case .success(let contractID, let expiresAt):
            guard let artifactPath = Self.artifactPath(from: arguments) else {
                return SubprocessResult(
                    command: command,
                    terminationStatus: 1,
                    standardOutput: "",
                    standardError: "Missing --state-out path."
                )
            }
            let artifactURL = URL(fileURLWithPath: artifactPath)
            try FileManager.default.createDirectory(
                at: artifactURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let context = try Self.makeBootstrapContext(
                contractID: contractID,
                expiresAt: expiresAt
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(context).write(to: artifactURL, options: [.atomic])
            return SubprocessResult(
                command: command,
                terminationStatus: 0,
                standardOutput: #"{"final_state":"joined","contract_id":"\#(contractID)"}"#,
                standardError: ""
            )

        case .commandSuccess(let output):
            return SubprocessResult(
                command: command,
                terminationStatus: 0,
                standardOutput: output,
                standardError: ""
            )
        }
    }

    private static func artifactPath(from arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--state-out"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return NSString(string: arguments[index + 1]).expandingTildeInPath
    }

    private static func makeBootstrapContext(
        contractID: String,
        expiresAt: Date
    ) throws -> BootstrapExecutionContext {
        let formatter = ISO8601DateFormatter()
        let resolverPublicKey = try Ed25519.publicKeyBase64URL(fromSeedBase64URL: resolverSeed)
        var contract = PortholeAccessContract(
            contract_id: contractID,
            scaffold_domain: "smoke.haven.local",
            entity_id: "entity_smoke_primary",
            identity_public_key: "m2J3MyPvQaEYNIJBlOVRZNMl65zcwQ3dp9EK3k-9j20",
            scaffold_admin_public_key: resolverPublicKey,
            bridge_descriptor_id: "bd_smoke_0001",
            bridge_endpoint: "wss://bridge.smoke.haven.local/cell",
            client_kind: .native,
            porthole_protocol: .cellprotocol,
            capability_grants: ["cap.native_porthole", "cap.local_automation"],
            purpose: "bootstrap.join_scaffold",
            goal: "Exercise reconnect and renewal flow locally",
            interests: ["haven.core.bootstrap", "haven.core.bridge"],
            issued_at: formatter.string(from: Date()),
            expires_at: formatter.string(from: expiresAt),
            issued_by: resolverPublicKey,
            entity_evidence_contract_id: nil,
            signature: ResolverSignatureEnvelope(alg: "Ed25519", sig: "")
        )
        contract.signature = ResolverSignatureEnvelope(
            alg: "Ed25519",
            sig: try Ed25519.signBase64URL(
                data: try contract.canonicalPayloadData(),
                seedBase64URL: resolverSeed
            )
        )

        return BootstrapExecutionContext(
            runtime: .macOSApp,
            domain: "smoke.haven.local",
            requestedPortholeKind: .native,
            portholeAccessContract: contract
        )
    }
}

private actor SmokeTestPortholeIngress: PortholeIngressControlling {
    private let envelope: SignedRemoteIntentEnvelope
    private var didInjectEnvelope = false
    private var currentStatus = PortholeIngressStatus(phase: .idle)
    private var statusHandler: (@Sendable (PortholeIngressStatus) async -> Void)?

    init(envelope: SignedRemoteIntentEnvelope) {
        self.envelope = envelope
    }

    func setStatusHandler(_ handler: @escaping @Sendable (PortholeIngressStatus) async -> Void) async {
        statusHandler = handler
    }

    func connect(using artifact: SproutBootstrapSessionArtifact) async throws {
        currentStatus = PortholeIngressStatus(
            phase: .connected,
            contractID: artifact.session.contract.contract_id,
            bridgeEndpoint: artifact.session.nativeDescriptor?.bridge_endpoint,
            artifactExpiresAt: currentStatus.artifactExpiresAt ?? artifact.session.contract.expires_at,
            lastRenewedAt: currentStatus.lastRenewedAt,
            lastMessageAt: nil,
            lastAcceptedIntentID: nil,
            lastRejectedReason: nil,
            nextRetryAt: nil,
            retryCount: nil,
            lastError: nil
        )
        if let statusHandler {
            await statusHandler(currentStatus)
        }

        if !didInjectEnvelope {
            didInjectEnvelope = true
            let accepted = try await RemoteIntentInboxService.enqueueSignedEnvelope(envelope)
            currentStatus.lastMessageAt = ISO8601DateFormatter().string(from: Date())
            currentStatus.lastAcceptedIntentID = accepted.id
            if let statusHandler {
                await statusHandler(currentStatus)
            }
        }
    }

    func disconnect() async {
        guard currentStatus.phase != .idle else {
            return
        }
        currentStatus.phase = .disconnected
        currentStatus.nextRetryAt = nil
        currentStatus.retryCount = nil
        if let statusHandler {
            await statusHandler(currentStatus)
        }
    }

    func reportLifecycleStatus(_ status: PortholeIngressStatus) async {
        currentStatus = status
        if let statusHandler {
            await statusHandler(status)
        }
    }

    func statusSnapshot() async -> PortholeIngressStatus {
        currentStatus
    }
}

enum SmokeTestHarness {
    private static let timeoutSeconds: TimeInterval = 12
    private static let finderCloseActionID = "mac.finder.close-all-windows"
    private static let smokeIntentID = "finder-close-windows-smoke-1"

    static func run(rootPath: String?) async throws -> SmokeTestSummary {
        let runtimeRoot: URL = {
            if let rootPath, !rootPath.isEmpty {
                return URL(fileURLWithPath: NSString(string: rootPath).expandingTildeInPath)
            }
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("HavenAgentDSmoke-\(UUID().uuidString)", isDirectory: true)
        }()

        let paths = RuntimePaths.rooted(at: runtimeRoot)
        try await writeExecutableStubIfNeeded(
            at: runtimeRoot.appendingPathComponent("fake-sprout", isDirectory: false)
        )

        let issuerKey = Curve25519.Signing.PrivateKey()
        let envelope = try makeSignedEnvelope(privateKey: issuerKey)
        let config = makeConfig(
            paths: paths,
            sproutBinaryPath: runtimeRoot.appendingPathComponent("fake-sprout", isDirectory: false).path,
            issuerPublicKeyBase64: issuerKey.publicKey.rawRepresentation.base64EncodedString()
        )
        try config.write(to: paths.configFile)

        let processRunner = SmokeTestProcessRunner(
            outcomes: [
                .fail("Simulated initial bootstrap failure."),
                .success(
                    contractID: "pac_smoke_0002",
                    expiresAt: Date().addingTimeInterval(2)
                ),
                .success(
                    contractID: "pac_smoke_0003",
                    expiresAt: Date().addingTimeInterval(120)
                ),
                .commandSuccess("Finder windows close requested through smoke executor.")
            ]
        )
        let ingress = SmokeTestPortholeIngress(envelope: envelope)
        let runtime = AgentRuntime(
            paths: paths,
            processRunner: processRunner,
            portholeIngressController: ingress
        )
        let cellRuntimeHost = AgentCellRuntimeHost(paths: paths)

        await AgentRuntimeBridge.shared.resetRemoteIntentState()
        let _ = try await cellRuntimeHost.start(instanceName: config.instanceName)
        do {
            try await runtime.start(config: config)
            let finalState = try await waitForRuntimeState(
                fileURL: paths.stateFile,
                expectedContractID: "pac_smoke_0003"
            )
            _ = try await waitForRemoteIntentState(fileURL: paths.remoteIntentStateFile)
            let finalRemoteIntentState = try await approveVerifiedRemoteIntent(
                paths: paths,
                config: config,
                processRunner: processRunner,
                intentID: Self.smokeIntentID
            )
            try await runtime.stop()
            await cellRuntimeHost.stop()
            let lastReview = finalRemoteIntentState.auditTrail.last

            let summary = SmokeTestSummary(
                runtimeRoot: runtimeRoot.path,
                configPath: paths.configFile.path,
                statePath: paths.stateFile.path,
                remoteIntentStatePath: paths.remoteIntentStateFile.path,
                finalPhase: finalState.portholeIngress?.phase.rawValue ?? "unavailable",
                finalContractID: finalState.portholeIngress?.contractID,
                bootstrapArtifactPath: finalState.lastSproutBootstrap?.artifactPath,
                queuedIntentCount: finalRemoteIntentState.queuedIntents.count,
                lastAcceptedIntentID: finalState.portholeIngress?.lastAcceptedIntentID,
                reviewAuditCount: finalRemoteIntentState.auditTrail.count,
                lastReviewOutcome: lastReview?.outcome.rawValue,
                lastExecutedActionID: lastReview?.executedAction?.id,
                lastExecutedActionKind: lastReview?.executedAction?.kind.rawValue
            )
            try writeSummary(summary, to: paths.stateDirectory.appendingPathComponent("smoke-test-summary.json"))
            return summary
        } catch {
            try? await runtime.stop()
            await cellRuntimeHost.stop()
            throw error
        }
    }

    private static func makeConfig(
        paths: RuntimePaths,
        sproutBinaryPath: String,
        issuerPublicKeyBase64: String
    ) -> AgentConfig {
        AgentConfig(
            instanceName: "haven-agentd-smoke",
            heartbeatIntervalSeconds: 1,
            scaffold: ScaffoldConnectionConfig(
                sproutBinaryPath: sproutBinaryPath,
                startupMode: .join,
                runtime: "macos-app",
                domain: "smoke.haven.local",
                purpose: "bootstrap.join_scaffold",
                goal: "Exercise reconnect and renewal flow locally",
                interests: ["haven.core.bootstrap", "haven.core.bridge"],
                resolverBaseURL: "https://smoke.haven.local",
                starterAuthPath: nil,
                discoveryURL: nil,
                catalogPath: nil,
                enableLiveResolver: false,
                trustedResolverKey: nil,
                requestedCapabilities: ["cap.native_porthole"],
                requestedPortholeKind: "native",
                renewalLeadTimeSeconds: 1,
                portholeHealthPollSeconds: 1,
                portholeRetryBaseDelaySeconds: 1,
                portholeRetryMaxDelaySeconds: 1
            ),
            watchFolders: [],
            automationPolicy: AutomationPolicy(
                appleScripts: [
                    AppleScriptDefinition(
                        id: Self.finderCloseActionID,
                        description: "Close all Finder windows after signed remote intent review. Smoke tests inject a stubbed process runner so no user windows are closed.",
                        source: """
                        tell application "Finder"
                            close every window
                        end tell
                        """,
                        allowedForRemoteExecution: true,
                        requiresUserSession: true
                    )
                ]
            ),
            remoteIntentPolicy: RemoteIntentPolicy(
                issuers: [
                    TrustedRemoteIntentIssuer(
                        issuerID: "scaffold-entity.smoke",
                        publicSigningKeyBase64: issuerPublicKeyBase64,
                        allowedTopics: ["intent.inbox"],
                        allowedActionIDs: [Self.finderCloseActionID]
                    )
                ],
                requireExpiry: true,
                maxClockSkewSeconds: 300,
                maxArgumentCount: 8
            )
        )
    }

    private static func makeSignedEnvelope(
        privateKey: Curve25519.Signing.PrivateKey
    ) throws -> SignedRemoteIntentEnvelope {
        let issuedAt = ISO8601DateFormatter().string(from: Date())
        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(120))
        let payload = SignedRemoteIntentPayload(
            issuerID: "scaffold-entity.smoke",
            nonce: Self.smokeIntentID,
            topic: "intent.inbox",
            origin: "scaffold-entity.smoke",
            actionID: Self.finderCloseActionID,
            arguments: [:],
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
        let signature = try privateKey.signature(
            for: RemoteIntentVerifier.canonicalPayloadData(payload)
        )
        return SignedRemoteIntentEnvelope(
            payload: payload,
            signatureBase64: signature.base64EncodedString()
        )
    }

    private static func writeExecutableStubIfNeeded(at url: URL) async throws {
        let data = Data("#!/bin/sh\nexit 0\n".utf8)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: url, options: [.atomic])
        #if os(macOS)
        chmod(url.path, 0o755)
        #endif
    }

    private static func waitForRuntimeState(
        fileURL: URL,
        expectedContractID: String
    ) async throws -> AgentRuntimeState {
        let start = Date()
        let decoder = JSONDecoder()

        while Date().timeIntervalSince(start) < timeoutSeconds {
            if let data = try? Data(contentsOf: fileURL),
               let state = try? decoder.decode(AgentRuntimeState.self, from: data),
               state.portholeIngress?.phase == .connected,
               state.portholeIngress?.contractID == expectedContractID {
                return state
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        throw SmokeTestHarnessError.timedOut("connected renewed contract \(expectedContractID)")
    }

    private static func waitForRemoteIntentState(
        fileURL: URL
    ) async throws -> PersistedRemoteIntentState {
        let start = Date()
        let decoder = JSONDecoder()

        while Date().timeIntervalSince(start) < timeoutSeconds {
            if let data = try? Data(contentsOf: fileURL),
               let state = try? decoder.decode(PersistedRemoteIntentState.self, from: data),
               state.queuedIntents.contains(where: { $0.id == Self.smokeIntentID && $0.verificationStatus == "verified" }) {
                return state
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        throw SmokeTestHarnessError.timedOut("verified queued smoke intent")
    }

    private static func approveVerifiedRemoteIntent(
        paths: RuntimePaths,
        config: AgentConfig,
        processRunner: SmokeTestProcessRunner,
        intentID: String
    ) async throws -> PersistedRemoteIntentState {
        let executor = RemoteIntentExecutionBridge(processRunner: processRunner)
        await executor.update(policy: config.automationPolicy)
        await AgentRuntimeBridge.shared.update(remoteIntentExecutor: executor)

        let vault = LocalIdentityVault()
        guard let requester = await vault.identity(for: "haven-agentd-smoke-reviewer", makeNewIfNotFound: true) else {
            throw SmokeTestHarnessError.timedOut("create local smoke reviewer identity")
        }
        let cell = await RemoteIntentReviewCell(owner: requester)
        let agreement = cell.agreementTemplate
        agreement.signatories.append(requester)
        _ = await cell.addAgreement(agreement, for: requester)
        let payload: Object = [
            "intentID": .string(intentID),
            "reviewer": .string("HAVENAgentD smoke test"),
            "note": .string("Approve the signed Finder close-windows smoke action through a stubbed local executor.")
        ]
        _ = try await cell.set(keypath: "approve", value: .object(payload), requester: requester)

        let finalState = await AgentRuntimeBridge.shared.persistedRemoteIntentStateSnapshot()
        try await RemoteIntentStateStore(fileURL: paths.remoteIntentStateFile).write(finalState)
        guard finalState.auditTrail.contains(where: { record in
            record.intentID == intentID
                && record.actionID == Self.finderCloseActionID
                && record.outcome == .approvedDispatched
                && record.executedAction?.id == Self.finderCloseActionID
        }) else {
            throw SmokeTestHarnessError.timedOut("approved dispatched audit for \(Self.finderCloseActionID)")
        }
        return finalState
    }

    private static func writeSummary(_ summary: SmokeTestSummary, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try encoder.encode(summary).write(to: fileURL, options: [.atomic])
    }
}
