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
        #expect(config.scaffoldConnections == nil)
        #expect(config.effectiveScaffoldConnections == [
            ScaffoldConnectionTarget(
                id: "default",
                scaffoldDomain: config.scaffold.domain,
                resolverBaseURL: config.scaffold.resolverBaseURL ?? "",
                sproutBinaryPath: config.scaffold.sproutBinaryPath,
                startupMode: config.scaffold.startupMode
            )
        ])
    }

    @Test
    func legacyConfigLoadsWithoutScaffoldConnections() throws {
        let fileURL = temporaryConfigURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let legacyConfig = AgentConfig.example(paths: testPaths())

        try legacyConfig.write(to: fileURL)
        let json = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(!json.contains("scaffoldConnections"))

        let loaded = try AgentConfig.load(from: fileURL)
        #expect(loaded == legacyConfig)
        #expect(loaded.effectiveScaffoldConnections.count == 1)
        #expect(loaded.effectiveScaffoldConnections.first?.id == "default")
        #expect(loaded.effectiveScaffoldConnections.first?.scaffoldDomain == legacyConfig.scaffold.domain)
    }

    @Test
    func twoScaffoldConnectionsValidateAndRoundTrip() throws {
        let fileURL = temporaryConfigURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        var config = AgentConfig.example(paths: testPaths())
        config.scaffoldConnections = [
            ScaffoldConnectionTarget(
                id: "staging",
                scaffoldDomain: "staging.haven.example",
                resolverBaseURL: "https://staging.haven.example",
                sproutBinaryPath: "/opt/haven/staging/sprout",
                startupMode: .join,
                label: "Staging"
            ),
            ScaffoldConnectionTarget(
                id: "production",
                scaffoldDomain: "haven.example",
                resolverBaseURL: "https://haven.example",
                sproutBinaryPath: "/opt/haven/production/sprout",
                startupMode: .plan,
                enabled: false,
                label: "Production"
            )
        ]

        try config.validate()
        try config.write(to: fileURL)
        let loaded = try AgentConfig.load(from: fileURL)

        #expect(loaded == config)
        #expect(loaded.effectiveScaffoldConnections == config.scaffoldConnections)
    }

    @Test
    func scaffoldConnectionEnabledDefaultsToTrue() throws {
        let data = Data(#"{"id":"staging","scaffoldDomain":"staging.haven.example","resolverBaseURL":"https://staging.haven.example","sproutBinaryPath":"/opt/haven/sprout","startupMode":"join"}"#.utf8)
        let target = try JSONDecoder().decode(ScaffoldConnectionTarget.self, from: data)
        #expect(target.enabled)
    }

    @Test
    func duplicateScaffoldConnectionIDsAreRejected() throws {
        let fileURL = temporaryConfigURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        var config = AgentConfig.example(paths: testPaths())
        let target = ScaffoldConnectionTarget(
            id: "duplicate",
            scaffoldDomain: "staging.haven.example",
            resolverBaseURL: "https://staging.haven.example",
            sproutBinaryPath: "/opt/haven/sprout",
            startupMode: .join
        )
        config.scaffoldConnections = [target, target]
        try writeWithoutValidation(config, to: fileURL)

        #expect(throws: AgentConfigValidationError.duplicateScaffoldConnectionID("duplicate")) {
            try AgentConfig.load(from: fileURL)
        }
    }

    @Test
    func nonHTTPSScaffoldConnectionIsRejected() throws {
        let fileURL = temporaryConfigURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        var config = AgentConfig.example(paths: testPaths())
        config.scaffoldConnections = [
            ScaffoldConnectionTarget(
                id: "insecure",
                scaffoldDomain: "staging.haven.example",
                resolverBaseURL: "http://staging.haven.example",
                sproutBinaryPath: "/opt/haven/sprout",
                startupMode: .join
            )
        ]
        try writeWithoutValidation(config, to: fileURL)

        #expect(throws: AgentConfigValidationError.invalidResolverBaseURL(
            id: "insecure",
            value: "http://staging.haven.example"
        )) {
            try AgentConfig.load(from: fileURL)
        }
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

    private func testPaths() -> RuntimePaths {
        RuntimePaths.rooted(at: URL(fileURLWithPath: "/Users/tester"))
    }

    private func temporaryConfigURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("haven-agent-config-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("config.json")
    }

    private func writeWithoutValidation(_ config: AgentConfig, to fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: fileURL, options: [.atomic])
    }
}
