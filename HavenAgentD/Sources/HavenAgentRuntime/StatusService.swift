import Darwin
import Foundation
import HavenMacAutomation
import HavenRuntimeBootstrap

public struct AgentStatusOptions: Sendable {
    public var executablePath: String
    public var rootPathArgument: String?
    public var configPathArgument: String?
    public var launchAgentsDirectory: URL?
    public var defaultSetupDomain: String

    public init(
        executablePath: String,
        rootPathArgument: String? = nil,
        configPathArgument: String? = nil,
        launchAgentsDirectory: URL? = nil,
        defaultSetupDomain: String = "staging.haven.digipomps.org"
    ) {
        self.executablePath = executablePath
        self.rootPathArgument = rootPathArgument
        self.configPathArgument = configPathArgument
        self.launchAgentsDirectory = launchAgentsDirectory
        self.defaultSetupDomain = defaultSetupDomain
    }
}

public struct AgentStatusBinaryReport: Codable, Equatable, Sendable {
    public var resolvedBinaryPath: String
    public var pathShimPath: String
    public var pathShimExists: Bool
    public var pathShimExecutable: Bool
    public var pathShimResolvedPath: String?
    public var pathShimPointsToResolvedBinary: Bool
    public var havenAgentDOnPATH: Bool
}

public struct AgentStatusConfigReport: Codable, Equatable, Sendable {
    public var path: String
    public var present: Bool
    public var valid: Bool
    public var scaffoldDomain: String?
    public var startupMode: String?
    public var error: String?
}

public struct AgentStatusSproutReport: Codable, Equatable, Sendable {
    public var configuredPath: String?
    public var executable: Bool
}

public struct AgentStatusIdentityReport: Codable, Equatable, Sendable {
    public var path: String
    public var present: Bool
    public var identityUUID: String?
    public var didKey: String?
    public var publicKeyShort: String?
    public var storageKind: String?
    public var error: String?
}

public struct AgentStatusProvisioningReport: Codable, Equatable, Sendable {
    public var readyForBootstrap: Bool
    public var pairingArtifact: BootstrapProbeArtifactStatus
    public var starterAuth: BootstrapProbeArtifactStatus
    public var entityLink: BootstrapProbeArtifactStatus
}

public struct AgentStatusBootstrapArtifactReport: Codable, Equatable, Sendable {
    public var path: String?
    public var exists: Bool
}

public struct AgentStatusControlBridgeReport: Codable, Equatable, Sendable {
    public var configured: Bool
    public var enabled: Bool?
    public var host: String?
    public var port: Int?
    public var loopbackOnly: Bool?
    public var websocketBaseURL: String?
    public var listening: Bool
    public var probeDetail: String?
}

public struct AgentStatusNextStep: Codable, Equatable, Sendable {
    public var command: String?
    public var summary: String
}

public struct AgentStatusReport: Codable, Equatable, Sendable {
    public var runtimeRoot: String
    public var configPath: String
    public var binary: AgentStatusBinaryReport
    public var sprout: AgentStatusSproutReport
    public var identity: AgentStatusIdentityReport
    public var config: AgentStatusConfigReport
    public var provisioning: AgentStatusProvisioningReport
    public var bootstrapArtifact: AgentStatusBootstrapArtifactReport?
    public var launchAgent: LaunchAgentStatus
    public var controlBridge: AgentStatusControlBridgeReport
    public var nextStep: AgentStatusNextStep
}

public actor StatusService {
    private static let pathShimPath = "/usr/local/bin/haven-agentd"

    private let paths: RuntimePaths
    private let configURL: URL
    private let fileManager: FileManager
    private let processRunner: any ProcessRunning

    public init(
        paths: RuntimePaths,
        configURL: URL,
        fileManager: FileManager = .default,
        processRunner: any ProcessRunning = FoundationProcessRunner()
    ) {
        self.paths = paths
        self.configURL = configURL.standardizedFileURL
        self.fileManager = fileManager
        self.processRunner = processRunner
    }

    public func report(options: AgentStatusOptions) async -> AgentStatusReport {
        let configLoad = loadConfig()
        let binary = binaryReport(executablePath: options.executablePath)
        let sprout = sproutReport(config: configLoad.config)
        let identity = await identityReport()
        let config = configReport(load: configLoad)
        let probe = await BootstrapProbeService(paths: paths)
            .probe(configURL: configURL, runBootstrap: false)
        let provisioning = AgentStatusProvisioningReport(
            readyForBootstrap: probe.readyForBootstrap,
            pairingArtifact: probe.pairingArtifact,
            starterAuth: probe.starterAuth,
            entityLink: probe.entityLink
        )
        let bootstrapArtifact = bootstrapArtifactReport(config: configLoad.config)
        let launchAgent = await launchAgentReport(options: options)
        let controlBridge = controlBridgeReport(config: configLoad.config)
        let nextStep = nextStepReport(
            options: options,
            config: config,
            loadedConfig: configLoad.config,
            identity: identity,
            provisioning: provisioning,
            bootstrapArtifact: bootstrapArtifact,
            launchAgent: launchAgent
        )

        return AgentStatusReport(
            runtimeRoot: paths.homeDirectory.path,
            configPath: configURL.path,
            binary: binary,
            sprout: sprout,
            identity: identity,
            config: config,
            provisioning: provisioning,
            bootstrapArtifact: bootstrapArtifact,
            launchAgent: launchAgent,
            controlBridge: controlBridge,
            nextStep: nextStep
        )
    }

    private func loadConfig() -> (config: AgentConfig?, error: String?) {
        do {
            return (try AgentConfig.load(from: configURL), nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    private func binaryReport(executablePath: String) -> AgentStatusBinaryReport {
        let resolvedBinaryPath = URL(fileURLWithPath: executablePath)
            .resolvingSymlinksInPath()
            .path
        let pathShimPath = Self.pathShimPath
        let pathShimExists = fileManager.fileExists(atPath: pathShimPath)
        let pathShimExecutable = fileManager.isExecutableFile(atPath: pathShimPath)
        let pathShimResolvedPath = pathShimExists
            ? URL(fileURLWithPath: pathShimPath).resolvingSymlinksInPath().path
            : nil
        return AgentStatusBinaryReport(
            resolvedBinaryPath: resolvedBinaryPath,
            pathShimPath: pathShimPath,
            pathShimExists: pathShimExists,
            pathShimExecutable: pathShimExecutable,
            pathShimResolvedPath: pathShimResolvedPath,
            pathShimPointsToResolvedBinary: pathShimResolvedPath == resolvedBinaryPath,
            havenAgentDOnPATH: pathShimExecutable
        )
    }

    private func configReport(load: (config: AgentConfig?, error: String?)) -> AgentStatusConfigReport {
        let present = fileManager.fileExists(atPath: configURL.path)
        return AgentStatusConfigReport(
            path: configURL.path,
            present: present,
            valid: load.config != nil,
            scaffoldDomain: load.config?.scaffold.domain,
            startupMode: load.config?.scaffold.startupMode.rawValue,
            error: present ? load.error : nil
        )
    }

    private func sproutReport(config: AgentConfig?) -> AgentStatusSproutReport {
        guard let rawPath = config?.scaffold.sproutBinaryPath, rawPath.isEmpty == false else {
            return AgentStatusSproutReport(configuredPath: nil, executable: false)
        }
        let resolvedPath = NSString(string: rawPath).expandingTildeInPath
        return AgentStatusSproutReport(
            configuredPath: resolvedPath,
            executable: fileManager.isExecutableFile(atPath: resolvedPath)
        )
    }

    private func identityReport() async -> AgentStatusIdentityReport {
        let exists = fileManager.fileExists(atPath: paths.agentIdentityFile.path)
        do {
            guard let descriptor = try await AgentIdentityStore(fileURL: paths.agentIdentityFile)
                .loadExistingDescriptor() else {
                return AgentStatusIdentityReport(
                    path: paths.agentIdentityFile.path,
                    present: false,
                    identityUUID: nil,
                    didKey: nil,
                    publicKeyShort: nil,
                    storageKind: nil,
                    error: nil
                )
            }
            return AgentStatusIdentityReport(
                path: paths.agentIdentityFile.path,
                present: true,
                identityUUID: descriptor.identityUUID,
                didKey: descriptor.didKey,
                publicKeyShort: Self.shortKey(descriptor.publicKeyBase64URL),
                storageKind: descriptor.storageKind,
                error: nil
            )
        } catch {
            return AgentStatusIdentityReport(
                path: paths.agentIdentityFile.path,
                present: false,
                identityUUID: nil,
                didKey: nil,
                publicKeyShort: nil,
                storageKind: nil,
                error: exists ? error.localizedDescription : nil
            )
        }
    }

    private func bootstrapArtifactReport(config: AgentConfig?) -> AgentStatusBootstrapArtifactReport? {
        guard let config,
              let invocation = try? SproutBootstrapClient(fileManager: fileManager)
                .makeInvocation(config: config, paths: paths),
              let artifactPath = invocation.artifactPath else {
            return nil
        }
        return AgentStatusBootstrapArtifactReport(
            path: artifactPath,
            exists: fileManager.fileExists(atPath: artifactPath)
        )
    }

    private func launchAgentReport(options: AgentStatusOptions) async -> LaunchAgentStatus {
        let launchAgentsDirectory = options.launchAgentsDirectory
            ?? paths.homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("LaunchAgents", isDirectory: true)
        let plistURL = launchAgentsDirectory
            .appendingPathComponent("\(AgentSetupService.launchAgentLabel).plist")
        let installed = fileManager.fileExists(atPath: plistURL.path)
        let executablePath = installed
            ? launchAgentExecutablePath(plistURL: plistURL) ?? ""
            : ""
        let loadStatus = installed ? await launchAgentLoadedStatus() : (loaded: false, detail: nil)

        return LaunchAgentStatus(
            label: AgentSetupService.launchAgentLabel,
            plistPath: plistURL.path,
            installed: installed,
            loaded: loadStatus.loaded,
            executablePath: executablePath,
            loadDetail: loadStatus.detail
        )
    }

    private func launchAgentExecutablePath(plistURL: URL) -> String? {
        guard let data = fileManager.contents(atPath: plistURL.path),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let arguments = dictionary["ProgramArguments"] as? [String],
              let executablePath = arguments.first,
              executablePath.isEmpty == false else {
            return nil
        }
        return executablePath
    }

    private func launchAgentLoadedStatus() async -> (loaded: Bool, detail: String?) {
        let launchctl = URL(fileURLWithPath: "/bin/launchctl")
        let target = "gui/\(getuid())/\(AgentSetupService.launchAgentLabel)"
        do {
            let result = try await processRunner.run(executableURL: launchctl, arguments: ["print", target])
            if result.terminationStatus == 0 {
                return (true, nil)
            }
            let detail = [result.standardError, result.standardOutput]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
            return (false, detail.map { "launchctl print exit \(result.terminationStatus): \($0)" })
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private func controlBridgeReport(config: AgentConfig?) -> AgentStatusControlBridgeReport {
        guard let bridge = config?.localControlBridge else {
            return AgentStatusControlBridgeReport(
                configured: false,
                enabled: nil,
                host: nil,
                port: nil,
                loopbackOnly: nil,
                websocketBaseURL: nil,
                listening: false,
                probeDetail: "Config is missing or invalid."
            )
        }

        guard bridge.enabled else {
            return AgentStatusControlBridgeReport(
                configured: true,
                enabled: false,
                host: bridge.host,
                port: bridge.port,
                loopbackOnly: bridge.loopbackOnly,
                websocketBaseURL: bridge.websocketBaseURL,
                listening: false,
                probeDetail: "Control bridge is disabled in config."
            )
        }

        guard bridge.loopbackOnly else {
            return AgentStatusControlBridgeReport(
                configured: true,
                enabled: true,
                host: bridge.host,
                port: bridge.port,
                loopbackOnly: false,
                websocketBaseURL: bridge.websocketBaseURL,
                listening: false,
                probeDetail: "Not probed because the configured host is not loopback-only."
            )
        }

        let listening = Self.tcpListenerExists(host: bridge.host, port: bridge.port)
        return AgentStatusControlBridgeReport(
            configured: true,
            enabled: true,
            host: bridge.host,
            port: bridge.port,
            loopbackOnly: true,
            websocketBaseURL: bridge.websocketBaseURL,
            listening: listening,
            probeDetail: listening ? "TCP listener accepted a loopback connection." : nil
        )
    }

    private func nextStepReport(
        options: AgentStatusOptions,
        config: AgentStatusConfigReport,
        loadedConfig: AgentConfig?,
        identity: AgentStatusIdentityReport,
        provisioning: AgentStatusProvisioningReport,
        bootstrapArtifact: AgentStatusBootstrapArtifactReport?,
        launchAgent: LaunchAgentStatus
    ) -> AgentStatusNextStep {
        let scope = commandScopeArguments(options: options)
        if !config.present || !config.valid {
            return nextStep(
                commandParts: ["haven-agentd", "setup"] + scope + ["--domain", options.defaultSetupDomain],
                summary: "Create the local runtime config and directories."
            )
        }

        guard let loadedConfig else {
            return nextStep(
                commandParts: ["haven-agentd", "setup"] + scope + ["--domain", options.defaultSetupDomain],
                summary: "Repair the local runtime config."
            )
        }

        if loadedConfig.scaffold.startupMode != .disabled {
            if !identity.present {
                let requestPath = paths.outputDirectory.appendingPathComponent("provisioning-request.json").path
                let command = (["haven-agentd", "provisioning-request"] + scope)
                    .map(Self.shellQuoted)
                    .joined(separator: " ")
                    + " > "
                    + Self.shellQuoted(requestPath)
                return AgentStatusNextStep(
                    command: command,
                    summary: "Generate the provisioning request for the operator."
                )
            }
            if !provisioning.readyForBootstrap {
                let packPath = paths.inboxDirectory.appendingPathComponent("provisioning-pack.json").path
                return nextStep(
                    commandParts: ["haven-agentd", "provisioning-import"] + scope + ["--pack", packPath],
                    summary: "Import the provisioning pack after the operator returns it."
                )
            }
            if bootstrapArtifact?.exists != true {
                return nextStep(
                    commandParts: ["haven-agentd", "bootstrap-probe"] + scope + ["--run-bootstrap"],
                    summary: "Verify provisioning and run the sprout bootstrap once."
                )
            }
        }

        if !launchAgent.installed {
            return nextStep(
                commandParts: ["haven-agentd", "setup"] + scope + ["--load"],
                summary: "Install and load the per-user LaunchAgent."
            )
        }
        if !launchAgent.loaded {
            let domain = "gui/\(getuid())"
            return AgentStatusNextStep(
                command: "launchctl bootstrap \(domain) \(Self.shellQuoted(launchAgent.plistPath)) && launchctl kickstart -k \(domain)/\(launchAgent.label)",
                summary: "Load the installed LaunchAgent."
            )
        }

        return AgentStatusNextStep(
            command: nil,
            summary: "No command needed; the runtime is configured and the LaunchAgent is loaded."
        )
    }

    private func commandScopeArguments(options: AgentStatusOptions) -> [String] {
        if let configPath = options.configPathArgument, !configPath.isEmpty {
            return ["--config", NSString(string: configPath).expandingTildeInPath]
        }
        if let rootPath = options.rootPathArgument, !rootPath.isEmpty {
            return ["--root", NSString(string: rootPath).expandingTildeInPath]
        }
        return []
    }

    private func nextStep(commandParts: [String], summary: String) -> AgentStatusNextStep {
        AgentStatusNextStep(
            command: commandParts.map(Self.shellQuoted).joined(separator: " "),
            summary: summary
        )
    }

    private static func shortKey(_ value: String) -> String {
        guard value.count > 18 else {
            return value
        }
        return "\(value.prefix(12))...\(value.suffix(6))"
    }

    private static func shellQuoted(_ value: String) -> String {
        guard value.rangeOfCharacter(from: CharacterSet(charactersIn: " \t\n\"'\\$`!&;()<>|*?[]{}")) != nil else {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func tcpListenerExists(host: String, port: Int, timeoutMilliseconds: Int32 = 250) -> Bool {
        guard port > 0, port <= 65_535 else {
            return false
        }

        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var resultPointer: UnsafeMutablePointer<addrinfo>?
        let lookup = getaddrinfo(host, String(port), &hints, &resultPointer)
        guard lookup == 0, let firstResult = resultPointer else {
            return false
        }
        defer { freeaddrinfo(firstResult) }

        var current: UnsafeMutablePointer<addrinfo>? = firstResult
        while let address = current {
            let descriptor = socket(
                address.pointee.ai_family,
                address.pointee.ai_socktype,
                address.pointee.ai_protocol
            )
            if descriptor >= 0 {
                defer { close(descriptor) }
                let flags = fcntl(descriptor, F_GETFL, 0)
                if flags >= 0 {
                    _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)
                }

                let connectResult = connect(
                    descriptor,
                    address.pointee.ai_addr,
                    address.pointee.ai_addrlen
                )
                if connectResult == 0 {
                    return true
                }
                if errno == EINPROGRESS {
                    var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
                    let pollResult = poll(&pollDescriptor, nfds_t(1), timeoutMilliseconds)
                    if pollResult > 0 {
                        var socketError: Int32 = 0
                        var length = socklen_t(MemoryLayout<Int32>.size)
                        let optionResult = getsockopt(
                            descriptor,
                            SOL_SOCKET,
                            SO_ERROR,
                            &socketError,
                            &length
                        )
                        if optionResult == 0, socketError == 0 {
                            return true
                        }
                    }
                }
            }
            current = address.pointee.ai_next
        }

        return false
    }
}

public enum AgentStatusTextRenderer {
    public static func render(_ report: AgentStatusReport) -> String {
        var lines: [String] = []
        lines.append("HAVEN AgentD status")
        lines.append("Runtime root: \(report.runtimeRoot)")
        lines.append("Config: \(configLine(report.config))")
        lines.append("Binary: \(report.binary.resolvedBinaryPath)")
        lines.append("PATH: \(pathLine(report.binary))")
        lines.append("Sprout: \(sproutLine(report.sprout))")
        lines.append("Agent identity: \(identityLine(report.identity))")
        lines.append("Provisioning: \(report.provisioning.readyForBootstrap ? "ready for bootstrap" : "not ready for bootstrap")")
        lines.append("  Pairing: \(validityLine(report.provisioning.pairingArtifact))")
        lines.append("  Starter auth: \(validityLine(report.provisioning.starterAuth))")
        lines.append("  Entity link: \(validityLine(report.provisioning.entityLink))")
        if let bootstrapArtifact = report.bootstrapArtifact {
            lines.append("Bootstrap artifact: \(bootstrapArtifact.exists ? "present" : "missing")\(bootstrapArtifact.path.map { " at \($0)" } ?? "")")
        }
        lines.append("LaunchAgent: \(launchAgentLine(report.launchAgent))")
        lines.append("Control bridge: \(controlBridgeLine(report.controlBridge))")
        lines.append("Next step: \(nextStepLine(report.nextStep))")
        return lines.joined(separator: "\n")
    }

    private static func configLine(_ config: AgentStatusConfigReport) -> String {
        guard config.present else {
            return "missing at \(config.path)"
        }
        guard config.valid else {
            return "present but invalid at \(config.path)\(config.error.map { " (\($0))" } ?? "")"
        }
        return "present at \(config.path); scaffold \(config.scaffoldDomain ?? "unknown"); startupMode \(config.startupMode ?? "unknown")"
    }

    private static func pathLine(_ binary: AgentStatusBinaryReport) -> String {
        guard binary.pathShimExists else {
            return "\(binary.pathShimPath) not found"
        }
        var parts = ["\(binary.pathShimPath) found"]
        parts.append(binary.pathShimExecutable ? "executable" : "not executable")
        if let resolved = binary.pathShimResolvedPath {
            parts.append("resolves to \(resolved)")
        }
        return parts.joined(separator: ", ")
    }

    private static func sproutLine(_ sprout: AgentStatusSproutReport) -> String {
        guard let path = sprout.configuredPath else {
            return "not configured"
        }
        return "\(path) (\(sprout.executable ? "executable" : "not executable"))"
    }

    private static func identityLine(_ identity: AgentStatusIdentityReport) -> String {
        guard identity.present else {
            return "not present at \(identity.path)\(identity.error.map { " (\($0))" } ?? "")"
        }
        return "present; UUID \(identity.identityUUID ?? "unknown"); DID \(identity.didKey ?? "unknown"); pubkey \(identity.publicKeyShort ?? "unknown"); storage \(identity.storageKind ?? "unknown")"
    }

    private static func validityLine(_ artifact: BootstrapProbeArtifactStatus) -> String {
        let state: String
        if artifact.valid {
            state = "valid"
        } else if artifact.exists {
            state = "invalid"
        } else {
            state = "missing"
        }
        return "\(state) - \(artifact.summary)"
    }

    private static func launchAgentLine(_ launchAgent: LaunchAgentStatus) -> String {
        guard launchAgent.installed else {
            return "not installed at \(launchAgent.plistPath)"
        }
        var line = "installed at \(launchAgent.plistPath); \(launchAgent.loaded ? "loaded" : "not loaded")"
        if !launchAgent.executablePath.isEmpty {
            line += "; executable \(launchAgent.executablePath)"
        }
        return line
    }

    private static func controlBridgeLine(_ bridge: AgentStatusControlBridgeReport) -> String {
        guard bridge.configured else {
            return "not configured"
        }
        guard bridge.enabled == true else {
            return "disabled at \(bridge.host ?? "unknown"):\(bridge.port.map(String.init) ?? "unknown")"
        }
        let endpoint = "\(bridge.host ?? "unknown"):\(bridge.port.map(String.init) ?? "unknown")"
        return "\(endpoint) (\(bridge.loopbackOnly == true ? "loopback" : "not loopback")); listening \(bridge.listening ? "yes" : "no")"
    }

    private static func nextStepLine(_ nextStep: AgentStatusNextStep) -> String {
        if let command = nextStep.command {
            return "\(command) - \(nextStep.summary)"
        }
        return nextStep.summary
    }
}
