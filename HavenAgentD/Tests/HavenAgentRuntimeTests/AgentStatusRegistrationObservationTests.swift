import Foundation
import Testing
@testable import HavenAgentRuntime
@testable import HavenMacAutomation
@testable import HavenRuntimeBootstrap

@Suite struct AgentStatusRegistrationObservationTests {
    @Test func registeredLoopbackBridgeReportsOnlyBrokerKnownAllowlistedActions() throws {
        let paths = RuntimePaths.rooted(
            at: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        var config = AgentConfig.example(paths: paths)
        config.automationPolicy.shortcuts.append(
            ShortcutDefinition(
                id: "shortcut.binding.wake",
                shortcutName: "Wake Binding",
                allowedForRemoteExecution: true
            )
        )
        config.automationPolicy.appleScripts.append(
            AppleScriptDefinition(
                id: "mac.finder.close-all-windows",
                description: "Close Finder windows",
                source: "return",
                allowedForRemoteExecution: true
            )
        )
        config.automationPolicy.shortcuts.append(
            ShortcutDefinition(
                id: "unknown.remote.action",
                shortcutName: "Unknown",
                allowedForRemoteExecution: true
            )
        )
        let observedAt = try #require(ISO8601DateFormatter().date(from: "2026-07-13T09:00:00Z"))

        let observation = AgentStatusRegistrationObservationBuilder.make(
            config: config,
            controlBridge: bridge(listening: true),
            observedAt: observedAt
        )

        #expect(observation.status == "registered")
        #expect(observation.bridgeEndpoint == "ws://127.0.0.1:43110/bridgehead")
        #expect(observation.availableActionIDs == AgentStatusRegistrationObservationBuilder.brokerActionIDs)
        #expect(observation.availableActionIDs.contains("unknown.remote.action") == false)
        #expect(observation.evidenceAuthority == "owner-reported-runtime-observation-not-a-grant")
        #expect(observation.containsAccessToken == false)

        let encoded = String(decoding: try JSONEncoder().encode(observation), as: UTF8.self)
        #expect(encoded.contains("replace-with-strong-local-token") == false)
        #expect(encoded.contains("\"accessToken\"") == false)
        #expect(encoded.contains("privateKey") == false)
    }

    @Test func unavailableOrNonLoopbackBridgeCannotClaimRegistration() {
        let paths = RuntimePaths.rooted(
            at: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let config = AgentConfig.example(paths: paths)
        let observation = AgentStatusRegistrationObservationBuilder.make(
            config: config,
            controlBridge: AgentStatusControlBridgeReport(
                configured: true,
                enabled: true,
                host: "example.com",
                port: 43110,
                loopbackOnly: false,
                websocketBaseURL: "wss://example.com/bridgehead?token=secret",
                listening: true,
                probeDetail: nil
            )
        )

        #expect(observation.status == "installed_not_running")
        #expect(observation.availableActionIDs.isEmpty)
        #expect(observation.bridgeEndpoint == nil)
    }

    private func bridge(listening: Bool) -> AgentStatusControlBridgeReport {
        AgentStatusControlBridgeReport(
            configured: true,
            enabled: true,
            host: "127.0.0.1",
            port: 43110,
            loopbackOnly: true,
            websocketBaseURL: "ws://127.0.0.1:43110/bridgehead",
            listening: listening,
            probeDetail: nil
        )
    }
}
