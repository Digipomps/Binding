import Foundation
import Testing
import HavenMacAutomation
import HavenRuntimeBootstrap
import SproutCore
import SproutCrypto
import SproutResolverAdapter
@testable import HavenAgentRuntime
import Darwin

private enum PortholeLifecycleFixtureFactory {
    static let resolverSeed = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"

    static func makeBootstrapContext(
        contractID: String,
        expiresAt: Date
    ) throws -> BootstrapExecutionContext {
        let formatter = ISO8601DateFormatter()
        let resolverPublicKey = try Ed25519.publicKeyBase64URL(fromSeedBase64URL: resolverSeed)
        var contract = PortholeAccessContract(
            contract_id: contractID,
            scaffold_domain: "test.haven.local",
            entity_id: "entity_test_primary",
            identity_public_key: "m2J3MyPvQaEYNIJBlOVRZNMl65zcwQ3dp9EK3k-9j20",
            scaffold_admin_public_key: resolverPublicKey,
            bridge_descriptor_id: "bd_test_0001",
            bridge_endpoint: "wss://bridge.test.haven.local/cell",
            client_kind: .native,
            porthole_protocol: .cellprotocol,
            capability_grants: ["cap.native_porthole"],
            purpose: "bootstrap.join_scaffold",
            goal: "Exercise reconnect and renewal flow in tests",
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
            domain: "test.haven.local",
            requestedPortholeKind: .native,
            portholeAccessContract: contract
        )
    }

    static func makeConfig(
        paths: RuntimePaths,
        executablePath: String,
        renewalLeadTimeSeconds: Int = 1
    ) -> AgentConfig {
        AgentConfig(
            instanceName: "haven-agentd-tests",
            heartbeatIntervalSeconds: 1,
            scaffold: ScaffoldConnectionConfig(
                sproutBinaryPath: executablePath,
                startupMode: .join,
                runtime: "mac-agent",
                domain: "test.haven.local",
                purpose: "bootstrap.join_scaffold",
                goal: "Exercise reconnect and renewal flow in tests",
                interests: ["haven.core.bootstrap", "haven.core.bridge"],
                resolverBaseURL: nil,
                starterAuthPath: nil,
                discoveryURL: nil,
                catalogPath: nil,
                enableLiveResolver: false,
                trustedResolverKey: nil,
                requestedCapabilities: ["cap.native_porthole"],
                requestedPortholeKind: "native",
                renewalLeadTimeSeconds: renewalLeadTimeSeconds,
                portholeHealthPollSeconds: 1,
                portholeRetryBaseDelaySeconds: 1,
                portholeRetryMaxDelaySeconds: 1
            ),
            watchFolders: [],
            automationPolicy: AutomationPolicy(),
            remoteIntentPolicy: RemoteIntentPolicy()
        )
    }

    static func writeExecutableStub(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url, options: [.atomic])
        chmod(url.path, 0o755)
    }
}

private actor ScriptedLifecycleProcessRunner: ProcessRunning {
    enum Outcome {
        case fail(String)
        case success(contractID: String, expiresAt: Date)
    }

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
                standardError: "No scripted lifecycle outcome remains."
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
            guard let outputPath = Self.artifactPath(arguments) else {
                return SubprocessResult(
                    command: command,
                    terminationStatus: 1,
                    standardOutput: "",
                    standardError: "Missing --state-out path."
                )
            }
            let artifactURL = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(
                at: artifactURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let context = try PortholeLifecycleFixtureFactory.makeBootstrapContext(
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
        }
    }

    private static func artifactPath(_ arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--state-out"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return NSString(string: arguments[index + 1]).expandingTildeInPath
    }
}

private actor RecordingLifecycleIngress: PortholeIngressControlling {
    private let disconnectAfterFirstConnect: Bool
    private var connectAttempts = 0
    private var currentStatus = PortholeIngressStatus(phase: .idle)
    private var statusHandler: (@Sendable (PortholeIngressStatus) async -> Void)?

    init(disconnectAfterFirstConnect: Bool = false) {
        self.disconnectAfterFirstConnect = disconnectAfterFirstConnect
    }

    func setStatusHandler(_ handler: @escaping @Sendable (PortholeIngressStatus) async -> Void) async {
        statusHandler = handler
    }

    func connect(using artifact: SproutBootstrapSessionArtifact) async throws {
        connectAttempts += 1
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

        if disconnectAfterFirstConnect && connectAttempts == 1 {
            let ingress = self
            let lastRenewedAt = currentStatus.lastRenewedAt
            Task {
                try? await Task.sleep(nanoseconds: 200_000_000)
                await ingress.reportLifecycleStatus(
                    PortholeIngressStatus(
                        phase: .disconnected,
                        contractID: artifact.session.contract.contract_id,
                        bridgeEndpoint: artifact.session.nativeDescriptor?.bridge_endpoint,
                        artifactExpiresAt: artifact.session.contract.expires_at,
                        lastRenewedAt: lastRenewedAt,
                        lastMessageAt: nil,
                        lastAcceptedIntentID: nil,
                        lastRejectedReason: nil,
                        nextRetryAt: nil,
                        retryCount: nil,
                        lastError: "Simulated ingress disconnect"
                    )
                )
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

    func attemptCount() async -> Int {
        connectAttempts
    }
}

private actor LifecycleStatusCollector {
    private var statuses: [PortholeIngressStatus] = []

    func append(_ status: PortholeIngressStatus) {
        statuses.append(status)
    }

    func latest() -> PortholeIngressStatus? {
        statuses.last
    }

    func hasConnected(contractID: String) -> Bool {
        statuses.contains { $0.phase == .connected && $0.contractID == contractID }
    }
}

private func waitUntil(
    timeout: TimeInterval = 8,
    intervalNanoseconds: UInt64 = 200_000_000,
    condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        if await condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: intervalNanoseconds)
    }
    return false
}

@Suite(.serialized)
struct PortholeLifecycleControllerTests {
    @Test
    func lifecycleControllerRetriesBootstrapFailureAndRenewsBeforeExpiry() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentDLifecycle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let executableURL = root.appendingPathComponent("fake-sprout")
        try PortholeLifecycleFixtureFactory.writeExecutableStub(at: executableURL)
        let paths = RuntimePaths.rooted(at: root)
        let config = PortholeLifecycleFixtureFactory.makeConfig(
            paths: paths,
            executablePath: executableURL.path
        )
        let processRunner = ScriptedLifecycleProcessRunner(
            outcomes: [
                .fail("Simulated initial bootstrap failure."),
                .success(contractID: "pac_test_0002", expiresAt: Date().addingTimeInterval(2)),
                .success(contractID: "pac_test_0003", expiresAt: Date().addingTimeInterval(120))
            ]
        )
        let client = SproutBootstrapClient(processRunner: processRunner)
        let ingress = RecordingLifecycleIngress()
        let renewalService = ContractRenewalService()
        await renewalService.update(plan: config.makeSproutBootstrapPlan())
        let collector = LifecycleStatusCollector()
        let controller = PortholeLifecycleController(
            paths: paths,
            sproutBootstrapClient: client,
            ingress: ingress,
            renewalService: renewalService
        )

        await controller.start(
            config: config,
            onBootstrapRecord: { _ in },
            onStatus: { status in
                await collector.append(status)
            }
        )
        let didRecover = await waitUntil {
            let hasConnected = await collector.hasConnected(contractID: "pac_test_0003")
            let attemptCount = await ingress.attemptCount()
            return hasConnected && attemptCount == 2
        }
        await controller.stop()
        let latestStatus = await collector.latest()
        let renewalStatus = await renewalService.status()
        let attemptCount = await ingress.attemptCount()

        #expect(didRecover)
        #expect(attemptCount == 2)
        #expect(latestStatus?.contractID == "pac_test_0003")
        #expect(latestStatus?.lastRenewedAt != nil)
        #expect(renewalStatus?.status == "stopped")
        #expect(renewalStatus?.contractID == "pac_test_0003")
    }

    @Test
    func lifecycleControllerReconnectsAfterIngressDisconnect() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentDLifecycle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let executableURL = root.appendingPathComponent("fake-sprout")
        try PortholeLifecycleFixtureFactory.writeExecutableStub(at: executableURL)
        let paths = RuntimePaths.rooted(at: root)
        let config = PortholeLifecycleFixtureFactory.makeConfig(
            paths: paths,
            executablePath: executableURL.path,
            renewalLeadTimeSeconds: 10
        )
        let processRunner = ScriptedLifecycleProcessRunner(
            outcomes: [
                .success(contractID: "pac_test_0101", expiresAt: Date().addingTimeInterval(120)),
                .success(contractID: "pac_test_0102", expiresAt: Date().addingTimeInterval(120))
            ]
        )
        let client = SproutBootstrapClient(processRunner: processRunner)
        let ingress = RecordingLifecycleIngress(disconnectAfterFirstConnect: true)
        let renewalService = ContractRenewalService()
        await renewalService.update(plan: config.makeSproutBootstrapPlan())
        let collector = LifecycleStatusCollector()
        let controller = PortholeLifecycleController(
            paths: paths,
            sproutBootstrapClient: client,
            ingress: ingress,
            renewalService: renewalService
        )

        await controller.start(
            config: config,
            onBootstrapRecord: { _ in },
            onStatus: { status in
                await collector.append(status)
            }
        )
        let didReconnect = await waitUntil {
            let hasConnected = await collector.hasConnected(contractID: "pac_test_0102")
            let attemptCount = await ingress.attemptCount()
            return hasConnected && attemptCount == 2
        }
        await controller.stop()
        let latestStatus = await collector.latest()
        let renewalStatus = await renewalService.status()
        let attemptCount = await ingress.attemptCount()

        #expect(didReconnect)
        #expect(attemptCount == 2)
        #expect(latestStatus?.contractID == "pac_test_0102")
        #expect(renewalStatus?.contractID == "pac_test_0102")
    }
}
