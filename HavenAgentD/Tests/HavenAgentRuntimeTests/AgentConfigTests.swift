import Foundation
import Testing
@testable import HavenAgentRuntime
@testable import HavenRuntimeBootstrap

struct AgentConfigTests {
    @Test
    func exampleConfigRoundTrips() throws {
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
            remoteIntentStateFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/remote-intent-state.json")
        )
        let config = AgentConfig.example(paths: paths)
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(AgentConfig.self, from: data)

        #expect(decoded == config)
    }

    @Test
    func bootstrapPlanReflectsScaffoldConfiguration() throws {
        let config = AgentConfig(
            instanceName: "agent",
            scaffold: ScaffoldConnectionConfig(
                sproutBinaryPath: "/tmp/sprout",
                startupMode: .disabled,
                runtime: "mac-agent",
                domain: "example.haven.local",
                purpose: "bootstrap.join_scaffold",
                goal: "Join scaffold",
                interests: ["haven.core.bootstrap"],
                resolverBaseURL: "https://example.haven.local",
                starterAuthPath: "/tmp/starter.json",
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

        let plan = config.makeSproutBootstrapPlan()
        #expect(plan.scaffoldDomain == "example.haven.local")
        #expect(plan.requestedPortholeKind == "native")
        #expect(plan.renewalLeadTimeSeconds == 600)
    }
}
