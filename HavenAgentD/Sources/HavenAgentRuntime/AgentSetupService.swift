import Foundation
import Darwin
import HavenMacAutomation
import HavenRuntimeBootstrap

/// Operator-facing options for `haven-agentd setup`.
///
/// `setup` folds OperatorRunbook phases 2–5 and 9 into one idempotent command:
/// it creates the runtime directory tree, writes (or reuses) a local
/// `config.json`, generates a strong loopback bridge token, installs the
/// per-user LaunchAgent that points at the already-installed binary, and
/// reports provisioning readiness.
///
/// It deliberately does NOT fetch config from the network, invent provisioning
/// evidence, or auto-start a scaffold-bound agent that has no provisioning yet.
/// Config is local admin policy (see Docs/SecurityModel.md).
public struct AgentSetupOptions: Sendable {
    public var instanceName: String?
    public var domain: String?
    public var resolverBaseURL: String?
    public var discoveryURL: String?
    public var purpose: String?
    public var sproutBinaryPath: String?
    public var accessToken: String?
    public var startupMode: SproutStartupMode?
    /// Absolute path to the `haven-agentd` binary the LaunchAgent should run.
    /// Defaults to the running executable; pkg installs pass the libexec path.
    public var executablePath: String
    public var force: Bool
    public var installLaunchAgent: Bool
    public var launchAgentsDirectory: URL?
    public var loadLaunchAgent: Bool

    public init(
        instanceName: String? = nil,
        domain: String? = nil,
        resolverBaseURL: String? = nil,
        discoveryURL: String? = nil,
        purpose: String? = nil,
        sproutBinaryPath: String? = nil,
        accessToken: String? = nil,
        startupMode: SproutStartupMode? = nil,
        executablePath: String,
        force: Bool = false,
        installLaunchAgent: Bool = true,
        launchAgentsDirectory: URL? = nil,
        loadLaunchAgent: Bool = false
    ) {
        self.instanceName = instanceName
        self.domain = domain
        self.resolverBaseURL = resolverBaseURL
        self.discoveryURL = discoveryURL
        self.purpose = purpose
        self.sproutBinaryPath = sproutBinaryPath
        self.accessToken = accessToken
        self.startupMode = startupMode
        self.executablePath = executablePath
        self.force = force
        self.installLaunchAgent = installLaunchAgent
        self.launchAgentsDirectory = launchAgentsDirectory
        self.loadLaunchAgent = loadLaunchAgent
    }
}

public struct LaunchAgentStatus: Codable, Equatable, Sendable {
    public var label: String
    public var plistPath: String
    public var installed: Bool
    public var loaded: Bool
    public var executablePath: String
    public var loadDetail: String?

    public init(
        label: String,
        plistPath: String,
        installed: Bool,
        loaded: Bool,
        executablePath: String,
        loadDetail: String? = nil
    ) {
        self.label = label
        self.plistPath = plistPath
        self.installed = installed
        self.loaded = loaded
        self.executablePath = executablePath
        self.loadDetail = loadDetail
    }
}

public struct AgentSetupProvisioningStatus: Codable, Equatable, Sendable {
    public var readyForBootstrap: Bool
    public var startupMode: String
    public var pairing: String
    public var starterAuth: String
    public var entityLink: String

    public init(
        readyForBootstrap: Bool,
        startupMode: String,
        pairing: String,
        starterAuth: String,
        entityLink: String
    ) {
        self.readyForBootstrap = readyForBootstrap
        self.startupMode = startupMode
        self.pairing = pairing
        self.starterAuth = starterAuth
        self.entityLink = entityLink
    }
}

public struct AgentSetupReport: Codable, Equatable, Sendable {
    public var runtimeRoot: String
    public var configPath: String
    public var configCreated: Bool
    public var accessTokenGenerated: Bool
    public var sproutBinaryPath: String
    public var sproutBinaryExecutable: Bool
    public var createdDirectories: [String]
    public var configValid: Bool
    public var launchAgent: LaunchAgentStatus?
    public var provisioning: AgentSetupProvisioningStatus
    public var warnings: [String]
    public var nextSteps: [String]

    public init(
        runtimeRoot: String,
        configPath: String,
        configCreated: Bool,
        accessTokenGenerated: Bool,
        sproutBinaryPath: String,
        sproutBinaryExecutable: Bool,
        createdDirectories: [String],
        configValid: Bool,
        launchAgent: LaunchAgentStatus?,
        provisioning: AgentSetupProvisioningStatus,
        warnings: [String],
        nextSteps: [String]
    ) {
        self.runtimeRoot = runtimeRoot
        self.configPath = configPath
        self.configCreated = configCreated
        self.accessTokenGenerated = accessTokenGenerated
        self.sproutBinaryPath = sproutBinaryPath
        self.sproutBinaryExecutable = sproutBinaryExecutable
        self.createdDirectories = createdDirectories
        self.configValid = configValid
        self.launchAgent = launchAgent
        self.provisioning = provisioning
        self.warnings = warnings
        self.nextSteps = nextSteps
    }
}

public enum AgentSetupError: Error, LocalizedError {
    case configWriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .configWriteFailed(let detail):
            return "Failed to write config: \(detail)"
        }
    }
}

public actor AgentSetupService {
    public static let launchAgentLabel = "io.digipomps.haven.agentd"
    private static let placeholderToken = "replace-with-strong-local-token"
    private static let placeholderSproutPath = "/absolute/path/to/sprout"

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

    public func run(options: AgentSetupOptions) async throws -> AgentSetupReport {
        var warnings: [String] = []
        var nextSteps: [String] = []

        // 1. Directory tree (idempotent).
        let createdDirectories = try RuntimeBootstrap(fileManager: fileManager)
            .bootstrap(paths: paths)
            .createdDirectories

        // 2. Config: reuse an existing one unless --force.
        let configExists = fileManager.fileExists(atPath: configURL.path)
        var accessTokenGenerated = false
        var configCreated = false
        var resolvedSproutPath = options.sproutBinaryPath ?? Self.placeholderSproutPath

        if configExists && !options.force {
            // Honour the operator's existing local policy; only warn on placeholders.
            let existing = try? AgentConfig.load(from: configURL)
            if let existing {
                resolvedSproutPath = existing.scaffold.sproutBinaryPath
                if existing.localControlBridge.accessToken == Self.placeholderToken
                    || (existing.localControlBridge.accessToken?.isEmpty ?? true) {
                    warnings.append("Existing config still uses a placeholder/empty localControlBridge.accessToken. Re-run with --force to regenerate, or edit it before exposing the bridge.")
                }
                if existing.scaffold.sproutBinaryPath == Self.placeholderSproutPath {
                    warnings.append("Existing config still has the placeholder sprout path. Set scaffold.sproutBinaryPath before bootstrap.")
                }
            } else {
                warnings.append("Existing config at \(configURL.path) did not decode; leaving it untouched. Use --force to overwrite.")
            }
        } else {
            var config = AgentConfig.example(paths: paths)
            if let instanceName = options.instanceName { config.instanceName = instanceName }
            if let domain = options.domain { config.scaffold.domain = domain }
            if let resolverBaseURL = options.resolverBaseURL { config.scaffold.resolverBaseURL = resolverBaseURL }
            if let discoveryURL = options.discoveryURL { config.scaffold.discoveryURL = discoveryURL }
            if let purpose = options.purpose { config.scaffold.purpose = purpose }
            config.scaffold.startupMode = options.startupMode ?? .disabled

            // sprout path: explicit > sibling of the binary > placeholder.
            resolvedSproutPath = options.sproutBinaryPath
                ?? siblingSproutPath(of: options.executablePath)
                ?? Self.placeholderSproutPath
            config.scaffold.sproutBinaryPath = resolvedSproutPath

            // Always replace the placeholder token with a real one.
            if let token = options.accessToken, !token.isEmpty {
                config.localControlBridge.accessToken = token
            } else {
                config.localControlBridge.accessToken = Self.generateAccessToken()
                accessTokenGenerated = true
            }

            do {
                try config.write(to: configURL)
                configCreated = true
            } catch {
                throw AgentSetupError.configWriteFailed(error.localizedDescription)
            }
        }

        if resolvedSproutPath == Self.placeholderSproutPath {
            warnings.append("No sprout binary configured. Set scaffold.sproutBinaryPath (or pass --sprout-path) before any scaffold bootstrap.")
        }
        let sproutExecutable = fileManager.isExecutableFile(atPath: resolvedSproutPath)

        // 3. Validate the config we will run with.
        let loadedConfig = try? AgentConfig.load(from: configURL)
        let configValid = loadedConfig != nil
        if !configValid {
            warnings.append("Config at \(configURL.path) is not valid JSON for AgentConfig.")
        }
        let startupMode = loadedConfig?.scaffold.startupMode ?? options.startupMode ?? .disabled

        // 4. Provisioning readiness (reuse the probe — no bootstrap attempted).
        let probe = await BootstrapProbeService(paths: paths).probe(configURL: configURL, runBootstrap: false)
        let provisioning = AgentSetupProvisioningStatus(
            readyForBootstrap: probe.readyForBootstrap,
            startupMode: startupMode.rawValue,
            pairing: probe.pairingArtifact.summary,
            starterAuth: probe.starterAuth.summary,
            entityLink: probe.entityLink.summary
        )

        // 5. LaunchAgent.
        var launchAgent: LaunchAgentStatus?
        if options.installLaunchAgent {
            launchAgent = try await installAndMaybeLoadLaunchAgent(
                options: options,
                configValid: configValid,
                startupMode: startupMode,
                readyForBootstrap: probe.readyForBootstrap,
                warnings: &warnings,
                nextSteps: &nextSteps
            )
        }

        // 6. Next steps.
        if resolvedSproutPath == Self.placeholderSproutPath || !sproutExecutable {
            nextSteps.append("Set scaffold.sproutBinaryPath to an executable sprout binary in \(configURL.path).")
        }
        if !probe.readyForBootstrap {
            nextSteps.append("Import a provisioning pack (pairing + starter-auth + entity-link) so the agent can join the scaffold. Until then it runs local-only.")
        }
        if startupMode != .disabled && !probe.readyForBootstrap {
            nextSteps.append("scaffold.startupMode is '\(startupMode.rawValue)' but provisioning is not ready; the agent will retry bootstrap and log failures until evidence is present.")
        }
        if let launchAgent, !launchAgent.loaded {
            nextSteps.append("Activate at login: launchctl bootstrap gui/\(getuid()) \"\(launchAgent.plistPath)\" && launchctl kickstart -k gui/\(getuid())/\(launchAgent.label)")
        }
        nextSteps.append("Grant Automation/Accessibility consent in the logged-in session the first time an action runs.")

        return AgentSetupReport(
            runtimeRoot: paths.homeDirectory.path,
            configPath: configURL.path,
            configCreated: configCreated,
            accessTokenGenerated: accessTokenGenerated,
            sproutBinaryPath: resolvedSproutPath,
            sproutBinaryExecutable: sproutExecutable,
            createdDirectories: createdDirectories,
            configValid: configValid,
            launchAgent: launchAgent,
            provisioning: provisioning,
            warnings: warnings,
            nextSteps: nextSteps
        )
    }

    // MARK: - LaunchAgent

    private func installAndMaybeLoadLaunchAgent(
        options: AgentSetupOptions,
        configValid: Bool,
        startupMode: SproutStartupMode,
        readyForBootstrap: Bool,
        warnings: inout [String],
        nextSteps: inout [String]
    ) async throws -> LaunchAgentStatus {
        let launchAgentsDir = options.launchAgentsDirectory
            ?? paths.homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("LaunchAgents", isDirectory: true)
        try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        let plistURL = launchAgentsDir.appendingPathComponent("\(Self.launchAgentLabel).plist")

        let plist = LaunchAgentTemplate.render(
            label: Self.launchAgentLabel,
            executablePath: options.executablePath,
            configPath: configURL.path,
            logDirectory: paths.logsDirectory.path
        )
        try Data(plist.utf8).write(to: plistURL, options: [.atomic])

        var loaded = false
        var loadDetail: String?

        if options.loadLaunchAgent {
            // Refuse to load a scaffold-bound config that can't bootstrap yet:
            // KeepAlive would crashloop it. A disabled (local-only) agent is safe.
            let safeToLoad = configValid && (startupMode == .disabled || readyForBootstrap)
            if safeToLoad {
                loadDetail = await loadViaLaunchctl(plistPath: plistURL.path)
                loaded = (loadDetail == nil)
                if let loadDetail {
                    warnings.append("LaunchAgent load reported: \(loadDetail)")
                }
            } else {
                loadDetail = "skipped: config invalid or scaffold-bound startup not provisioned"
                warnings.append("Did not load the LaunchAgent because startupMode '\(startupMode.rawValue)' is not provisioned (would crashloop under KeepAlive).")
            }
        }

        return LaunchAgentStatus(
            label: Self.launchAgentLabel,
            plistPath: plistURL.path,
            installed: true,
            loaded: loaded,
            executablePath: options.executablePath,
            loadDetail: loadDetail
        )
    }

    /// Returns nil on success, or a short error detail string on failure.
    private func loadViaLaunchctl(plistPath: String) async -> String? {
        let launchctl = URL(fileURLWithPath: "/bin/launchctl")
        let domain = "gui/\(getuid())"
        let target = "\(domain)/\(Self.launchAgentLabel)"

        // bootout first (ignore failure — it may not be loaded yet).
        _ = try? await processRunner.run(executableURL: launchctl, arguments: ["bootout", target])

        do {
            let bootstrap = try await processRunner.run(
                executableURL: launchctl,
                arguments: ["bootstrap", domain, plistPath]
            )
            if bootstrap.terminationStatus != 0 {
                return "bootstrap exit \(bootstrap.terminationStatus): \(bootstrap.standardError.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            let kickstart = try await processRunner.run(
                executableURL: launchctl,
                arguments: ["kickstart", "-k", target]
            )
            if kickstart.terminationStatus != 0 {
                return "kickstart exit \(kickstart.terminationStatus): \(kickstart.standardError.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func siblingSproutPath(of executablePath: String) -> String? {
        let sibling = URL(fileURLWithPath: executablePath)
            .deletingLastPathComponent()
            .appendingPathComponent("sprout")
            .path
        return fileManager.isExecutableFile(atPath: sibling) ? sibling : nil
    }

    private static func generateAccessToken(byteCount: Int = 32) -> String {
        var generator = SystemRandomNumberGenerator()
        var bytes = [UInt8]()
        bytes.reserveCapacity(byteCount)
        for _ in 0..<byteCount {
            bytes.append(UInt8.random(in: UInt8.min...UInt8.max, using: &generator))
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
