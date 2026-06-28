import Darwin
import Foundation
import Testing
@testable import HavenAgentRuntime
@testable import HavenMacAutomation
@testable import HavenRuntimeBootstrap

private final class StatusLaunchctlRunner: ProcessRunning, @unchecked Sendable {
    private let result: SubprocessResult
    private let lock = NSLock()
    private(set) var invocations: [[String]] = []

    init(terminationStatus: Int32 = 0, standardOutput: String = "", standardError: String = "") {
        self.result = SubprocessResult(
            command: [],
            terminationStatus: terminationStatus,
            standardOutput: standardOutput,
            standardError: standardError
        )
    }

    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        let command = [executableURL.path] + arguments
        lock.withLock {
            invocations.append(command)
        }
        return SubprocessResult(
            command: command,
            terminationStatus: result.terminationStatus,
            standardOutput: result.standardOutput,
            standardError: result.standardError
        )
    }
}

private func makeStatusTempRoot() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("haven-status-service-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite struct StatusServiceTests {
    @Test func reportsFreshSetupRootAndNextLoadCommand() async throws {
        let root = makeStatusTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths.rooted(at: root)

        _ = try await AgentSetupService(paths: paths, configURL: paths.configFile).run(
            options: AgentSetupOptions(
                domain: "staging.haven.digipomps.org",
                executablePath: "/usr/local/libexec/havenagent/haven-agentd",
                installLaunchAgent: false
            )
        )
        var config = try AgentConfig.load(from: paths.configFile)
        config.localControlBridge.port = 1
        try config.write(to: paths.configFile)

        let report = await StatusService(paths: paths, configURL: paths.configFile).report(
            options: AgentStatusOptions(
                executablePath: "/usr/local/libexec/havenagent/haven-agentd",
                rootPathArgument: root.path
            )
        )

        #expect(report.config.present)
        #expect(report.config.valid)
        #expect(report.config.scaffoldDomain == "staging.haven.digipomps.org")
        #expect(report.config.startupMode == "disabled")
        #expect(report.identity.present == false)
        #expect(report.launchAgent.installed == false)
        #expect(report.controlBridge.host == "127.0.0.1")
        #expect(report.controlBridge.port == 1)
        #expect(report.controlBridge.listening == false)
        #expect(report.nextStep.command == "haven-agentd setup --root \(root.path) --load")

        let text = AgentStatusTextRenderer.render(report)
        #expect(text.contains("HAVEN AgentD status"))
        #expect(text.contains("Next step: haven-agentd setup --root \(root.path) --load"))
    }

    @Test func reportsIdentityAndLoadedLaunchAgent() async throws {
        let root = makeStatusTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths.rooted(at: root)
        let executablePath = "/usr/local/libexec/havenagent/haven-agentd"
        let sproutPath = root.appendingPathComponent("sprout").path
        try Data("#!/bin/sh\nexit 0\n".utf8).write(
            to: URL(fileURLWithPath: sproutPath),
            options: [.atomic]
        )
        chmod(sproutPath, 0o755)

        var config = AgentConfig.example(paths: paths)
        config.scaffold.domain = "staging.haven.digipomps.org"
        config.scaffold.startupMode = .disabled
        config.scaffold.sproutBinaryPath = sproutPath
        config.localControlBridge.port = 1
        try config.write(to: paths.configFile)

        let material = try await AgentIdentityStore(fileURL: paths.agentIdentityFile)
            .loadOrCreate(instanceName: config.instanceName)

        let launchAgentsDirectory = root.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        try FileManager.default.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)
        let plistURL = launchAgentsDirectory
            .appendingPathComponent("\(AgentSetupService.launchAgentLabel).plist")
        let plist = LaunchAgentTemplate.render(
            executablePath: executablePath,
            configPath: paths.configFile.path,
            logDirectory: paths.logsDirectory.path
        )
        try Data(plist.utf8).write(to: plistURL, options: [.atomic])

        let runner = StatusLaunchctlRunner()
        let report = await StatusService(
            paths: paths,
            configURL: paths.configFile,
            processRunner: runner
        ).report(
            options: AgentStatusOptions(
                executablePath: executablePath,
                rootPathArgument: root.path
            )
        )

        #expect(report.identity.present)
        #expect(report.identity.identityUUID == material.descriptor.identityUUID)
        #expect(report.identity.didKey == material.descriptor.didKey)
        #expect(report.identity.publicKeyShort?.contains("...") == true)
        #expect(report.sprout.configuredPath == sproutPath)
        #expect(report.sprout.executable)
        #expect(report.launchAgent.installed)
        #expect(report.launchAgent.loaded)
        #expect(report.launchAgent.executablePath == executablePath)
        #expect(runner.invocations.contains { $0.contains("print") })
        #expect(report.nextStep.command == nil)
    }
}
