import Foundation
import HavenAgentCells
import HavenAgentCellRuntime
import HavenAgentRuntime
import HavenMacAutomation
import HavenRuntimeBootstrap
import SproutCrypto
import Darwin

enum HavenAgentCommand {
    case printExampleConfig(rootPath: String?)
    case printLaunchAgent(rootPath: String?)
    case validateConfig(configPath: String?, rootPath: String?)
    case bootstrapProbe(configPath: String?, rootPath: String?, runBootstrap: Bool)
    case refreshStarterAuth(configPath: String?, rootPath: String?, ttlSeconds: Int)
    case run(configPath: String?, once: Bool, rootPath: String?)
    case reviewState(configPath: String?, rootPath: String?)
    case reviewApprove(configPath: String?, intentID: String, reviewer: String?, note: String?, rootPath: String?)
    case reviewReject(configPath: String?, intentID: String, reviewer: String?, note: String?, rootPath: String?)
    case listCellBlueprints
    case networkStatus(secondsToObserve: Int)
    case monitor(configPath: String?, rootPath: String?, bridgePort: Int?)
    case smokeTest(rootPath: String?)
    case xcodeEnsureWorkspace(
        workspacePath: String,
        exclusiveLocalPackagePath: String?,
        scheme: String?,
        destinationName: String?,
        destinationPlatform: String?,
        destinationArchitecture: String?,
        closeOtherWorkspaces: Bool,
        build: Bool,
        timeoutSeconds: Int
    )
}

@main
struct HavenAgentMain {
    static func main() async {
        do {
            let command = try parse(arguments: Array(CommandLine.arguments.dropFirst()))

            switch command {
            case .printExampleConfig(let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: nil)
                let config = AgentConfig.example(paths: paths)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(config)
                print(String(decoding: data, as: UTF8.self))

            case .printLaunchAgent(let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: nil)
                let executablePath = paths.agentDirectory.appendingPathComponent("haven-agentd").path
                let plist = LaunchAgentTemplate.render(
                    executablePath: executablePath,
                    configPath: paths.configFile.path,
                    logDirectory: paths.logsDirectory.path
                )
                print(plist)

            case .validateConfig(let configPath, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let runtime = AgentRuntime(paths: paths)
                _ = try await runtime.validate(configURL: configURL)
                print("Config OK: \(configURL.path)")

            case .bootstrapProbe(let configPath, let rootPath, let runBootstrap):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let report = await BootstrapProbeService(paths: paths).probe(
                    configURL: configURL,
                    runBootstrap: runBootstrap
                )
                try printJSON(report)
                let bootstrapFailed = report.bootstrap?.attempted == true && report.bootstrap?.succeeded == false
                guard report.readyForBootstrap, !bootstrapFailed else {
                    Darwin.exit(1)
                }

            case .refreshStarterAuth(let configPath, let rootPath, let ttlSeconds):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let summary = try await refreshStarterAuth(
                    configURL: configURL,
                    paths: paths,
                    ttlSeconds: ttlSeconds
                )
                try printJSON(summary)

            case .run(let configPath, let once, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let config = try AgentConfig.load(from: configURL)
                let cellRuntimeHost = AgentCellRuntimeHost(paths: paths)
                let runtime = AgentRuntime(paths: paths)
                do {
                    let snapshot = try await cellRuntimeHost.start(
                        instanceName: config.instanceName,
                        controlBridge: once ? nil : config.localControlBridge,
                        networkSentinel: config.networkSentinel
                    )
                    try await runtime.run(config: config, once: once)
                    await cellRuntimeHost.stop()
                    if once {
                        print("Bootstrap validated: \(configURL.path)")
                        print("Registered runtime cells: \(snapshot.cells.count)")
                    }
                } catch {
                    await cellRuntimeHost.stop()
                    throw error
                }

            case .reviewState(let configPath, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let summary = try await ReviewCommandService(paths: paths, configURL: configURL).state()
                try printJSON(summary)

            case .reviewApprove(let configPath, let intentID, let reviewer, let note, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let summary = try await ReviewCommandService(paths: paths, configURL: configURL)
                    .approve(intentID: intentID, reviewer: reviewer ?? "binding-operator", note: note)
                try printJSON(summary)

            case .reviewReject(let configPath, let intentID, let reviewer, let note, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let summary = try await ReviewCommandService(paths: paths, configURL: configURL)
                    .reject(intentID: intentID, reviewer: reviewer ?? "binding-operator", note: note)
                try printJSON(summary)

            case .listCellBlueprints:
                for blueprint in AgentCellCatalog.defaultBlueprints {
                    print("\(blueprint.kind.rawValue): \(blueprint.suggestedCellName) - \(blueprint.purpose)")
                }

            case .monitor(let configPath, let rootPath, let bridgePort):
                // Persistent LOCAL daemon: hosts the cells + network sentinel service
                // + loopback control bridge, then waits for a signal. No scaffold, no
                // staging — this watches THIS machine's link continuously and dumps a
                // pcap at the moment of a flood. A local GUI (Binding) connects to the
                // control bridge to render the network tool. `--bridge-port` lets a
                // second instance run alongside an existing agentd on its own port.
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                var config = (try? AgentConfig.load(from: configURL)) ?? AgentConfig.example(paths: paths)
                if let bridgePort { config.localControlBridge.port = bridgePort }
                let host = AgentCellRuntimeHost(paths: paths)
                let snapshot = try await host.start(
                    instanceName: config.instanceName,
                    controlBridge: config.localControlBridge,
                    networkSentinel: config.networkSentinel
                )
                let bridge = snapshot.controlBridge
                FileHandle.standardError.write(Data(
                    "haven-agentd monitor: \(snapshot.cells.count) cells; sentinel on \(config.networkSentinel?.interface ?? "en0"); control bridge \(bridge?.phase.rawValue ?? "—") at \(bridge?.websocketBaseURL ?? "n/a"). SIGTERM/Ctrl-C to stop.\n".utf8
                ))
                await AgentMonitorShutdown().wait()
                await host.stop()
                FileHandle.standardError.write(Data("haven-agentd monitor: stopped cleanly.\n".utf8))

            case .networkStatus(let secondsToObserve):
                // Runs the measurement engine standalone on this machine — no scaffold,
                // no bootstrap, no network. Observes the real wifi interface for a few
                // seconds and prints the live snapshot. Proves the tool works locally.
                let captureDirectory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("haven-network-status", isDirectory: true)
                let service = NetworkSentinelService(captureDirectory: captureDirectory, captureEnabled: false)
                await service.start()
                let deadline = Date().addingTimeInterval(TimeInterval(max(2, secondsToObserve)))
                var snapshot = await service.snapshot()
                while Date() < deadline, snapshot.latest == nil {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    snapshot = await service.snapshot()
                }
                await service.stop()
                try printJSON(snapshot)

            case .smokeTest(let rootPath):
                let summary = try await SmokeTestHarness.run(rootPath: rootPath)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(summary)
                print(String(decoding: data, as: UTF8.self))

            case .xcodeEnsureWorkspace(
                let workspacePath,
                let exclusiveLocalPackagePath,
                let scheme,
                let destinationName,
                let destinationPlatform,
                let destinationArchitecture,
                let closeOtherWorkspaces,
                let build,
                let timeoutSeconds
            ):
                let result = try await XcodeWorkspaceController().ensureWorkspace(
                    XcodeWorkspaceRequest(
                        workspacePath: workspacePath,
                        exclusiveLocalPackagePath: exclusiveLocalPackagePath,
                        scheme: scheme,
                        destinationName: destinationName ?? "My Mac (arm64)",
                        destinationPlatform: destinationPlatform ?? "macosx",
                        destinationArchitecture: destinationArchitecture ?? "arm64",
                        closeOtherWorkspaces: closeOtherWorkspaces,
                        build: build,
                        timeoutSeconds: timeoutSeconds
                    )
                )
                try printJSON(result)
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            Darwin.exit(1)
        }
    }

    private static func parse(arguments: [String]) throws -> HavenAgentCommand {
        guard let command = arguments.first else {
            throw UsageError.invalidArguments(usage())
        }

        switch command {
        case "print-example-config":
            return .printExampleConfig(rootPath: argumentValue(for: "--root", in: Array(arguments.dropFirst())))
        case "print-launch-agent":
            return .printLaunchAgent(rootPath: argumentValue(for: "--root", in: Array(arguments.dropFirst())))
        case "validate-config":
            let remaining = Array(arguments.dropFirst())
            return .validateConfig(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining)
            )
        case "bootstrap-probe":
            let remaining = Array(arguments.dropFirst())
            return .bootstrapProbe(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining),
                runBootstrap: remaining.contains("--run-bootstrap")
            )
        case "refresh-starter-auth":
            let remaining = Array(arguments.dropFirst())
            return .refreshStarterAuth(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining),
                ttlSeconds: intArgumentValue(for: "--ttl-seconds", in: remaining) ?? 900
            )
        case "run":
            let remaining = Array(arguments.dropFirst())
            return .run(
                configPath: argumentValue(for: "--config", in: remaining),
                once: remaining.contains("--once"),
                rootPath: argumentValue(for: "--root", in: remaining)
            )
        case "review-state":
            let remaining = Array(arguments.dropFirst())
            return .reviewState(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining)
            )
        case "review-approve":
            let remaining = Array(arguments.dropFirst())
            guard let intentID = argumentValue(for: "--intent-id", in: remaining) else {
                throw UsageError.invalidArguments(usage())
            }
            return .reviewApprove(
                configPath: argumentValue(for: "--config", in: remaining),
                intentID: intentID,
                reviewer: argumentValue(for: "--reviewer", in: remaining),
                note: argumentValue(for: "--note", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining)
            )
        case "review-reject":
            let remaining = Array(arguments.dropFirst())
            guard let intentID = argumentValue(for: "--intent-id", in: remaining) else {
                throw UsageError.invalidArguments(usage())
            }
            return .reviewReject(
                configPath: argumentValue(for: "--config", in: remaining),
                intentID: intentID,
                reviewer: argumentValue(for: "--reviewer", in: remaining),
                note: argumentValue(for: "--note", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining)
            )
        case "list-cell-blueprints":
            return .listCellBlueprints
        case "network-status":
            let remaining = Array(arguments.dropFirst())
            return .networkStatus(secondsToObserve: intArgumentValue(for: "--seconds", in: remaining) ?? 6)
        case "monitor":
            let remaining = Array(arguments.dropFirst())
            return .monitor(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining),
                bridgePort: intArgumentValue(for: "--bridge-port", in: remaining)
            )
        case "smoke-test":
            return .smokeTest(rootPath: argumentValue(for: "--root", in: Array(arguments.dropFirst())))
        case "xcode-ensure-workspace":
            let remaining = Array(arguments.dropFirst())
            guard let workspacePath = argumentValue(for: "--workspace", in: remaining) else {
                throw UsageError.invalidArguments(usage())
            }
            return .xcodeEnsureWorkspace(
                workspacePath: workspacePath,
                exclusiveLocalPackagePath: argumentValue(for: "--exclusive-package", in: remaining),
                scheme: argumentValue(for: "--scheme", in: remaining),
                destinationName: argumentValue(for: "--destination-name", in: remaining),
                destinationPlatform: argumentValue(for: "--destination-platform", in: remaining),
                destinationArchitecture: argumentValue(for: "--destination-architecture", in: remaining),
                closeOtherWorkspaces: !remaining.contains("--keep-other-workspaces"),
                build: !remaining.contains("--no-build"),
                timeoutSeconds: intArgumentValue(for: "--timeout-seconds", in: remaining) ?? 300
            )
        default:
            throw UsageError.invalidArguments(usage())
        }
    }

    private static func argumentValue(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func intArgumentValue(for flag: String, in arguments: [String]) -> Int? {
        guard let value = argumentValue(for: flag, in: arguments) else {
            return nil
        }
        return Int(value)
    }

    private static func resolveConfigURL(_ configPath: String?, paths: RuntimePaths) -> URL {
        guard let configPath else {
            return paths.configFile
        }
        let expanded = NSString(string: configPath).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    private static func resolvePaths(rootPath: String?, configPath: String?) throws -> RuntimePaths {
        guard let rootPath, !rootPath.isEmpty else {
            if let configPath, !configPath.isEmpty {
                let expandedConfigPath = NSString(string: configPath).expandingTildeInPath
                return RuntimePaths.forConfigFile(URL(fileURLWithPath: expandedConfigPath))
            }
            return try RuntimePaths.default()
        }
        let expanded = NSString(string: rootPath).expandingTildeInPath
        return RuntimePaths.rooted(at: URL(fileURLWithPath: expanded))
    }

    private static func usage() -> String {
        """
        Usage:
          haven-agentd print-example-config [--root /path/to/dev-root]
          haven-agentd print-launch-agent [--root /path/to/dev-root]
          haven-agentd validate-config [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd bootstrap-probe [--config /path/to/config.json] [--root /path/to/dev-root] [--run-bootstrap]
          haven-agentd refresh-starter-auth [--config /path/to/config.json] [--root /path/to/dev-root] [--ttl-seconds N]
          haven-agentd run [--config /path/to/config.json] [--once] [--root /path/to/dev-root]
          haven-agentd review-state [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd review-approve --intent-id ID [--reviewer name] [--note text] [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd review-reject --intent-id ID [--reviewer name] [--note text] [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd list-cell-blueprints
          haven-agentd network-status [--seconds N]
          haven-agentd monitor [--config /path/to/config.json] [--root /path/to/dev-root] [--bridge-port N]
          haven-agentd smoke-test [--root /path/to/dev-root]
          haven-agentd xcode-ensure-workspace --workspace /path/App.xcworkspace [--exclusive-package /path/CellProtocol] [--scheme Run] [--destination-name "My Mac (arm64)"] [--destination-platform macosx] [--destination-architecture arm64] [--keep-other-workspaces] [--no-build] [--timeout-seconds N]
        """
    }

    private static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        print(String(decoding: data, as: UTF8.self))
    }

    private static func refreshStarterAuth(
        configURL: URL,
        paths: RuntimePaths,
        ttlSeconds: Int
    ) async throws -> StarterAuthRefreshSummary {
        let config = try AgentConfig.load(from: configURL)
        guard let rawStarterAuthPath = config.scaffold.starterAuthPath,
              rawStarterAuthPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw StarterAuthRefreshError.missingStarterAuthPath
        }
        guard let rawEntityLinkPath = config.scaffold.entityLinkPath,
              rawEntityLinkPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw StarterAuthRefreshError.missingEntityLinkPath
        }
        guard let purpose = config.scaffold.purpose,
              purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw StarterAuthRefreshError.missingPurpose
        }
        let interests = config.scaffold.interests
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !interests.isEmpty else {
            throw StarterAuthRefreshError.missingInterests
        }

        let entityLinkURL = URL(fileURLWithPath: NSString(string: rawEntityLinkPath).expandingTildeInPath)
        let entityLink = try JSONDecoder().decode(
            AgentEntityLinkContract.self,
            from: Data(contentsOf: entityLinkURL)
        )
        guard try entityLink.verifyMutualSignatures() else {
            throw StarterAuthRefreshError.invalidEntityLink
        }

        let identityStore = AgentIdentityStore(fileURL: paths.agentIdentityFile)
        let identity = try await identityStore.loadOrCreate(instanceName: config.instanceName)
        let agentPublicKey = identity.descriptor.publicKeyBase64URL
        guard entityLink.pubkey_a == agentPublicKey || entityLink.pubkey_b == agentPublicKey else {
            throw StarterAuthRefreshError.entityLinkDoesNotBindAgentIdentity
        }

        let ttl = max(60, min(ttlSeconds, 3600))
        let issuedAt = Date()
        let expiresAt = issuedAt.addingTimeInterval(TimeInterval(ttl))
        let formatter = ISO8601DateFormatter()
        var payload = AgentStarterAuthPayload(
            domain: config.scaffold.domain,
            identity_public_key: agentPublicKey,
            created_at: formatter.string(from: issuedAt),
            expires_at: formatter.string(from: expiresAt),
            nonce: "starter-\(UUID().uuidString.lowercased())",
            purpose_interest: AgentStarterPurposeInterest(
                purpose: purpose,
                interests: interests
            ),
            signature: AgentResolverSignatureEnvelope(alg: "Ed25519", sig: "")
        )
        let signature = try identity.privateKey().signature(for: payload.canonicalPayloadData())
        payload.signature = AgentResolverSignatureEnvelope(
            alg: "Ed25519",
            sig: Base64URL.encode(signature)
        )
        guard try payload.verifySignature() else {
            throw StarterAuthRefreshError.signatureVerificationFailed
        }

        let starterAuthURL = URL(fileURLWithPath: NSString(string: rawStarterAuthPath).expandingTildeInPath)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: starterAuthURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try encoder.encode(payload).write(to: starterAuthURL, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: starterAuthURL.path)

        return StarterAuthRefreshSummary(
            configPath: configURL.path,
            starterAuthPath: starterAuthURL.path,
            entityLinkPath: entityLinkURL.path,
            domain: payload.domain,
            purpose: payload.purpose_interest.purpose,
            interests: payload.purpose_interest.interests,
            identityPublicKey: payload.identity_public_key,
            createdAt: payload.created_at,
            expiresAt: payload.expires_at,
            ttlSeconds: ttl,
            entityLinkContractID: entityLink.contract_id
        )
    }
}

/// Suspends until SIGTERM/SIGINT, so `monitor` runs as a long-lived local daemon
/// and shuts the host down cleanly when launchd (or Ctrl-C) stops it.
final class AgentMonitorShutdown: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var sources: [DispatchSourceSignal] = []

    init(signals: [Int32] = [SIGINT, SIGTERM]) {
        for signalNumber in signals {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler { [weak self] in self?.resume() }
            source.resume()
            sources.append(source)
        }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
        }
    }

    private func resume() {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }
}

enum UsageError: Error, LocalizedError {
    case invalidArguments(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let usage):
            return usage
        }
    }
}

struct StarterAuthRefreshSummary: Codable, Equatable {
    var configPath: String
    var starterAuthPath: String
    var entityLinkPath: String
    var domain: String
    var purpose: String
    var interests: [String]
    var identityPublicKey: String
    var createdAt: String
    var expiresAt: String
    var ttlSeconds: Int
    var entityLinkContractID: String
}

enum StarterAuthRefreshError: Error, LocalizedError {
    case missingStarterAuthPath
    case missingEntityLinkPath
    case missingPurpose
    case missingInterests
    case invalidEntityLink
    case entityLinkDoesNotBindAgentIdentity
    case signatureVerificationFailed

    var errorDescription: String? {
        switch self {
        case .missingStarterAuthPath:
            return "Config scaffold.starterAuthPath is missing."
        case .missingEntityLinkPath:
            return "Config scaffold.entityLinkPath is missing."
        case .missingPurpose:
            return "Config scaffold.purpose is missing."
        case .missingInterests:
            return "Config scaffold.interests is empty."
        case .invalidEntityLink:
            return "Configured entity-link does not verify mutual signatures."
        case .entityLinkDoesNotBindAgentIdentity:
            return "Configured entity-link does not bind the local agent identity."
        case .signatureVerificationFailed:
            return "Refreshed starter auth signature did not verify."
        }
    }
}
