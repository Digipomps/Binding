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
            remoteIntentStateFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/remote-intent-state.json"),
            agentIdentityFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/State/agent-identity.json"),
            pairingArtifactFile: URL(fileURLWithPath: "/Users/tester/Library/Application Support/HAVENAgent/Out/agent-enrollment-pairing.json")
        )
        let config = AgentConfig.example(paths: paths)
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(AgentConfig.self, from: data)

        #expect(decoded == config)
        #expect(config.localControlBridge.accessToken == "replace-with-strong-local-token")
        #expect(config.localControlBridge.routes.contains { $0.name == "local-model" })
        #expect(config.localControlBridge.routes.contains { $0.name == AgentMailDraftAutomation.controlBridgeRouteName })
        #expect(config.localControlBridge.routes.contains { $0.name == "butler-scheduler" })
        #expect(config.scaffold.requestedCapabilities.contains("cap.local_model.generate"))
        #expect(config.scaffold.requestedCapabilities.contains(AgentMailDraftAutomation.capabilityRef))
        #expect(config.scaffold.interests.contains("contact.fallback.email"))
        #expect(config.automationPolicy.appleScripts.contains { $0.id == AgentMailDraftAutomation.actionID })
        let mailDefinition = try #require(config.automationPolicy.appleScripts.first { $0.id == AgentMailDraftAutomation.actionID })
        #expect(mailDefinition.allowedForRemoteExecution == true)
        #expect(mailDefinition.argumentConstraints["body"]?.allowsNewlines == true)
        #expect(config.remoteIntentPolicy.issuers.first?.allowedActionIDs.contains(AgentMailDraftAutomation.actionID) == true)
        #expect(config.remoteIntentPolicy.issuers.first?.allowedActionIDs.contains(PersonalButlerScheduleService.remoteWakeActionID) == true)
        #expect(config.remoteIntentPolicy.issuers.first?.allowedTopics.contains(PersonalButlerScheduleService.remoteWakeTopic) == true)
    }

    @Test
    func bootstrapPlanReflectsScaffoldConfiguration() throws {
        let config = AgentConfig(
            instanceName: "agent",
            scaffold: ScaffoldConnectionConfig(
                sproutBinaryPath: "/tmp/sprout",
                startupMode: .disabled,
                runtime: "macos-app",
                domain: "example.haven.local",
                purpose: "bootstrap.join_scaffold",
                goal: "Join scaffold",
                interests: ["haven.core.bootstrap"],
                resolverBaseURL: "https://example.haven.local",
                starterAuthPath: "/tmp/starter.json",
                entityLinkPath: "/tmp/entity-link.json",
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

        let plan = config.makeSproutBootstrapPlan()
        #expect(plan.scaffoldDomain == "example.haven.local")
        #expect(plan.requestedPortholeKind == "native")
        #expect(plan.renewalLeadTimeSeconds == 600)
        #expect(plan.entityLinkPath == "/tmp/entity-link.json")
    }
}
