import Foundation
import Testing
@testable import HavenMacAutomation
@testable import HavenAgentRuntime
@testable import HavenRuntimeBootstrap

/// Records launchctl invocations instead of actually loading a LaunchAgent.
private final class RecordingProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var invocations: [[String]] = []

    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        lock.withLock {
            invocations.append([executableURL.path] + arguments)
        }
        return SubprocessResult(
            command: [executableURL.path] + arguments,
            terminationStatus: 0,
            standardOutput: "",
            standardError: ""
        )
    }
}

private func makeTempRoot() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("haven-setup-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite struct AgentSetupServiceTests {
    @Test func freshSetupWritesConfigGeneratesTokenAndInstallsPlist() async throws {
        let root = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths.rooted(at: root)
        let launchAgentsDir = root.appendingPathComponent("LaunchAgents", isDirectory: true)

        let service = AgentSetupService(paths: paths, configURL: paths.configFile)
        let report = try await service.run(options: AgentSetupOptions(
            domain: "staging.haven.digipomps.org",
            resolverBaseURL: "https://staging.haven.digipomps.org",
            executablePath: "/usr/local/libexec/havenagent/haven-agentd",
            launchAgentsDirectory: launchAgentsDir,
            loadLaunchAgent: false
        ))

        #expect(report.configCreated)
        #expect(report.accessTokenGenerated)
        #expect(report.configValid)
        #expect(report.provisioning.startupMode == "disabled")
        #expect(report.provisioning.readyForBootstrap == false)

        // Config landed and reflects the overrides + a real (non-placeholder) token.
        let config = try AgentConfig.load(from: paths.configFile)
        #expect(config.scaffold.domain == "staging.haven.digipomps.org")
        #expect(config.scaffold.resolverBaseURL == "https://staging.haven.digipomps.org")
        #expect(config.scaffold.startupMode == .disabled)
        #expect(config.localControlBridge.accessToken != "replace-with-strong-local-token")
        #expect((config.localControlBridge.accessToken?.count ?? 0) >= 16)

        // LaunchAgent plist written (but not loaded) and points at the binary.
        let launchAgent = try #require(report.launchAgent)
        #expect(launchAgent.installed)
        #expect(launchAgent.loaded == false)
        #expect(FileManager.default.fileExists(atPath: launchAgent.plistPath))
        let plist = try String(contentsOfFile: launchAgent.plistPath, encoding: .utf8)
        #expect(plist.contains("/usr/local/libexec/havenagent/haven-agentd"))
        #expect(plist.contains(paths.configFile.path))
    }

    @Test func rerunWithoutForceKeepsExistingTokenAndConfig() async throws {
        let root = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths.rooted(at: root)
        let launchAgentsDir = root.appendingPathComponent("LaunchAgents", isDirectory: true)

        let service = AgentSetupService(paths: paths, configURL: paths.configFile)
        let first = try await service.run(options: AgentSetupOptions(
            domain: "staging.haven.digipomps.org",
            executablePath: "/usr/local/libexec/havenagent/haven-agentd",
            launchAgentsDirectory: launchAgentsDir
        ))
        let firstToken = try AgentConfig.load(from: paths.configFile).localControlBridge.accessToken

        // Second run without --force must not regenerate or overwrite config.
        let second = try await service.run(options: AgentSetupOptions(
            domain: "OTHER-domain",
            executablePath: "/usr/local/libexec/havenagent/haven-agentd",
            launchAgentsDirectory: launchAgentsDir
        ))
        let secondConfig = try AgentConfig.load(from: paths.configFile)

        #expect(first.configCreated)
        #expect(second.configCreated == false)
        #expect(second.accessTokenGenerated == false)
        #expect(secondConfig.localControlBridge.accessToken == firstToken)
        #expect(secondConfig.scaffold.domain == "staging.haven.digipomps.org") // unchanged
    }

    @Test func loadInvokesLaunchctlForDisabledStartup() async throws {
        let root = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths.rooted(at: root)
        let launchAgentsDir = root.appendingPathComponent("LaunchAgents", isDirectory: true)
        let runner = RecordingProcessRunner()

        let service = AgentSetupService(
            paths: paths,
            configURL: paths.configFile,
            processRunner: runner
        )
        let report = try await service.run(options: AgentSetupOptions(
            domain: "staging.haven.digipomps.org",
            startupMode: .disabled,
            executablePath: "/usr/local/libexec/havenagent/haven-agentd",
            launchAgentsDirectory: launchAgentsDir,
            loadLaunchAgent: true
        ))

        let launchAgent = try #require(report.launchAgent)
        #expect(launchAgent.loaded)
        // bootout + bootstrap + kickstart
        #expect(runner.invocations.contains { $0.contains("bootstrap") })
        #expect(runner.invocations.contains { $0.contains("kickstart") })
    }

    @Test func loadRefusedForUnprovisionedJoinStartup() async throws {
        let root = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths.rooted(at: root)
        let launchAgentsDir = root.appendingPathComponent("LaunchAgents", isDirectory: true)
        let runner = RecordingProcessRunner()

        let service = AgentSetupService(
            paths: paths,
            configURL: paths.configFile,
            processRunner: runner
        )
        let report = try await service.run(options: AgentSetupOptions(
            domain: "staging.haven.digipomps.org",
            startupMode: .join,
            executablePath: "/usr/local/libexec/havenagent/haven-agentd",
            launchAgentsDirectory: launchAgentsDir,
            loadLaunchAgent: true
        ))

        let launchAgent = try #require(report.launchAgent)
        #expect(launchAgent.installed)            // plist still written
        #expect(launchAgent.loaded == false)      // but not loaded
        #expect(runner.invocations.isEmpty)       // launchctl never called
        #expect(report.warnings.contains { $0.contains("crashloop") })
    }
}
