import Foundation
import Testing
@testable import HavenAgentRuntime
@testable import HavenRuntimeBootstrap
@testable import HavenMacAutomation

private final class StubProcessRunner: ProcessRunning, @unchecked Sendable {
    private let result: SubprocessResult

    init(result: SubprocessResult) {
        self.result = result
    }

    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        SubprocessResult(
            command: [executableURL.path] + arguments,
            terminationStatus: result.terminationStatus,
            standardOutput: result.standardOutput,
            standardError: result.standardError
        )
    }
}

struct SproutBootstrapClientTests {
    @Test
    func planInvocationUsesExplicitFlagsAndArtifactPath() throws {
        let paths = RuntimePaths(
            homeDirectory: URL(fileURLWithPath: "/Users/tester"),
            applicationSupportDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support"),
            agentDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent"),
            stateDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State"),
            cellDocumentDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/CellDocuments"),
            logsDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Logs"),
            inboxDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Inbox"),
            outputDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Out"),
            configFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/config.json"),
            stateFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/agent-state.json"),
            cellRuntimeFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/cell-runtime.json"),
            remoteIntentStateFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/remote-intent-state.json"),
            agentIdentityFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/agent-identity.json"),
            pairingArtifactFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Out/agent-enrollment-pairing.json")
        )

        let config = AgentConfig(
            instanceName: "agent",
            scaffold: ScaffoldConnectionConfig(
                sproutBinaryPath: "/tmp/sprout",
                startupMode: .plan,
                runtime: "macos-app",
                domain: "example.haven.local",
                purpose: "bootstrap.join_scaffold",
                goal: "Join scaffold",
                interests: ["haven.core.bootstrap", "haven.core.bridge"],
                resolverBaseURL: "https://example.haven.local",
                starterAuthPath: "/tmp/starter.json",
                entityLinkPath: "/tmp/entity-link.json",
                continuityProofPath: nil,
                admissionContractPath: nil,
                discoveryURL: "https://example.haven.local/v1/bridges/query",
                catalogPath: nil,
                enableLiveResolver: true,
                trustedResolverKey: "resolver-key",
                requestedCapabilities: ["cap.native_porthole"],
                requestedPortholeKind: "native",
                renewalLeadTimeSeconds: 600
            ),
            watchFolders: [],
            automationPolicy: .init()
        )

        let client = SproutBootstrapClient(processRunner: StubProcessRunner(result: .init(command: [], terminationStatus: 0, standardOutput: "", standardError: "")))
        let maybeInvocation = try client.makeInvocation(config: config, paths: paths)
        let invocation = try #require(maybeInvocation)

        #expect(invocation.mode == .plan)
        #expect(invocation.executablePath == "/tmp/sprout")
        #expect(invocation.arguments.contains("bootstrap"))
        #expect(invocation.arguments.contains("plan"))
        #expect(invocation.arguments.contains("--enable-live-resolver"))
        #expect(invocation.arguments.contains("--resolver-base-url"))
        #expect(invocation.arguments.contains("https://example.haven.local"))
        #expect(invocation.arguments.contains("--entity-link"))
        #expect(invocation.arguments.contains("/tmp/entity-link.json"))
        #expect(invocation.arguments.contains("--trust-root-out"))
        #expect(invocation.arguments.contains("/Users/tester/Library/Application Support/HAVENAgent/State/scaffold-admin-trust-root.json"))
        #expect(invocation.arguments.contains("--out"))
        #expect(invocation.artifactPath == "/Users/tester/Library/Application Support/HAVENAgent/State/sprout-bootstrap-plan.json")
    }

    @Test
    func disabledStartupSkipsInvocation() throws {
        let paths = RuntimePaths(
            homeDirectory: URL(fileURLWithPath: "/Users/tester"),
            applicationSupportDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support"),
            agentDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent"),
            stateDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State"),
            cellDocumentDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/CellDocuments"),
            logsDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Logs"),
            inboxDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Inbox"),
            outputDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Out"),
            configFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/config.json"),
            stateFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/agent-state.json"),
            cellRuntimeFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/cell-runtime.json"),
            remoteIntentStateFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/remote-intent-state.json"),
            agentIdentityFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/agent-identity.json"),
            pairingArtifactFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Out/agent-enrollment-pairing.json")
        )

        let config = AgentConfig(
            instanceName: "agent",
            scaffold: ScaffoldConnectionConfig(
                sproutBinaryPath: "/tmp/sprout",
                startupMode: .disabled,
                runtime: "macos-app",
                domain: "example.haven.local",
                purpose: nil,
                goal: nil,
                interests: [],
                resolverBaseURL: nil,
                starterAuthPath: nil,
                entityLinkPath: nil,
                continuityProofPath: nil,
                admissionContractPath: nil,
                discoveryURL: nil,
                catalogPath: nil,
                enableLiveResolver: false,
                trustedResolverKey: nil,
                requestedCapabilities: ["cap.native_porthole"],
                requestedPortholeKind: "native",
                renewalLeadTimeSeconds: 600
            ),
            watchFolders: [],
            automationPolicy: .init()
        )

        let client = SproutBootstrapClient(processRunner: StubProcessRunner(result: .init(command: [], terminationStatus: 0, standardOutput: "", standardError: "")))
        #expect(try client.makeInvocation(config: config, paths: paths) == nil)
    }

    @Test
    func conflictingEvidenceConfigurationIsRejected() throws {
        let paths = RuntimePaths(
            homeDirectory: URL(fileURLWithPath: "/Users/tester"),
            applicationSupportDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support"),
            agentDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent"),
            stateDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State"),
            cellDocumentDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/CellDocuments"),
            logsDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Logs"),
            inboxDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Inbox"),
            outputDirectory: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Out"),
            configFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/config.json"),
            stateFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/agent-state.json"),
            cellRuntimeFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/cell-runtime.json"),
            remoteIntentStateFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/remote-intent-state.json"),
            agentIdentityFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/agent-identity.json"),
            pairingArtifactFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Out/agent-enrollment-pairing.json")
        )

        let config = AgentConfig(
            instanceName: "agent",
            scaffold: ScaffoldConnectionConfig(
                sproutBinaryPath: "/tmp/sprout",
                startupMode: .join,
                runtime: "macos-app",
                domain: "example.haven.local",
                purpose: "bootstrap.join_scaffold",
                goal: "Join scaffold",
                interests: ["haven.core.bootstrap"],
                resolverBaseURL: "https://example.haven.local",
                starterAuthPath: "/tmp/starter.json",
                entityLinkPath: "/tmp/entity-link.json",
                continuityProofPath: "/tmp/continuity.json",
                admissionContractPath: "/tmp/admission.json",
                discoveryURL: nil,
                catalogPath: nil,
                enableLiveResolver: true,
                trustedResolverKey: nil,
                requestedCapabilities: ["cap.native_porthole"],
                requestedPortholeKind: "native",
                renewalLeadTimeSeconds: 600
            ),
            watchFolders: [],
            automationPolicy: .init()
        )

        let client = SproutBootstrapClient(processRunner: StubProcessRunner(result: .init(command: [], terminationStatus: 0, standardOutput: "", standardError: "")))
        #expect(throws: SproutBootstrapClientError.conflictingEntityEvidence) {
            _ = try client.makeInvocation(config: config, paths: paths)
        }
    }
}
