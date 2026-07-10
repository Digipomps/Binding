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
    case status(configPath: String?, rootPath: String?, json: Bool)
    case setup(SetupOptions)
    case provisioningRequest(configPath: String?, rootPath: String?)
    case provisioningImport(packPath: String, configPath: String?, rootPath: String?)
    case validateConfig(configPath: String?, rootPath: String?)
    case bootstrapProbe(configPath: String?, rootPath: String?, runBootstrap: Bool)
    case refreshStarterAuth(configPath: String?, rootPath: String?, ttlSeconds: Int)
    case onboard(configPath: String?, rootPath: String?, openBrowser: Bool, bridgePort: Int?)
    case run(configPath: String?, once: Bool, rootPath: String?)
    case scheduleWorker(configPath: String?, rootPath: String?)
    case scheduleList(configPath: String?, rootPath: String?)
    case scheduleStop(configPath: String?, eventID: String, rootPath: String?)
    case reviewState(configPath: String?, rootPath: String?)
    case reviewApprove(configPath: String?, intentID: String, reviewer: String?, note: String?, rootPath: String?)
    case reviewReject(configPath: String?, intentID: String, reviewer: String?, note: String?, rootPath: String?)
    case listCellBlueprints
    case planAdvisors(AdvisorPanelCommandOptions)
    case spawnAdvisors(AdvisorPanelCommandOptions)
    case networkStatus(secondsToObserve: Int)
    case networkListen(minutes: Int)
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

struct SetupOptions {
    var configPath: String?
    var rootPath: String?
    var instanceName: String?
    var domain: String?
    var resolverBaseURL: String?
    var discoveryURL: String?
    var purpose: String?
    var sproutBinaryPath: String?
    var accessToken: String?
    var startupMode: String?
    var executablePath: String?
    var force: Bool
    var skipLaunchAgent: Bool
    var load: Bool
}

struct AdvisorPanelCommandOptions {
    var configPath: String?
    var rootPath: String?
    var profile: String?
    var topic: String?
    var purposeRef: String?
    var goal: String?
    var brief: String?
    var briefFile: String?
    var interests: [String]
    var constraints: [String]
    var sourceRefs: [String]
    var advisorSpecs: [String]
    var outDirectory: String?
    var json: Bool
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

            case .status(let configPath, let rootPath, let json):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let report = await StatusService(paths: paths, configURL: configURL).report(
                    options: AgentStatusOptions(
                        executablePath: resolveExecutablePath(override: nil),
                        rootPathArgument: rootPath,
                        configPathArgument: configPath
                    )
                )
                if json {
                    try printJSON(report)
                } else {
                    print(AgentStatusTextRenderer.render(report))
                }

            case .setup(let options):
                let paths = try resolvePaths(rootPath: options.rootPath, configPath: options.configPath)
                let configURL = resolveConfigURL(options.configPath, paths: paths)
                let startupMode = options.startupMode.flatMap { SproutStartupMode(rawValue: $0) }
                if let raw = options.startupMode, startupMode == nil {
                    throw UsageError.invalidArguments("Unknown --startup-mode '\(raw)'. Use disabled, plan, or join.")
                }
                let setupOptions = AgentSetupOptions(
                    instanceName: options.instanceName,
                    domain: options.domain,
                    resolverBaseURL: options.resolverBaseURL,
                    discoveryURL: options.discoveryURL,
                    purpose: options.purpose,
                    sproutBinaryPath: options.sproutBinaryPath.map { NSString(string: $0).expandingTildeInPath },
                    accessToken: options.accessToken,
                    startupMode: startupMode,
                    executablePath: resolveExecutablePath(override: options.executablePath),
                    force: options.force,
                    installLaunchAgent: !options.skipLaunchAgent,
                    loadLaunchAgent: options.load
                )
                let report = try await AgentSetupService(paths: paths, configURL: configURL).run(options: setupOptions)
                try printJSON(report)

            case .provisioningRequest(let configPath, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let request = try await ProvisioningPackImporter(paths: paths).makeRequest(configURL: configURL)
                try printJSON(request)

            case .provisioningImport(let packPath, let configPath, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let packURL = URL(fileURLWithPath: NSString(string: packPath).expandingTildeInPath)
                let report = try await ProvisioningPackImporter(paths: paths)
                    .performImport(packURL: packURL, configURL: configURL)
                try printJSON(report)

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

            case .onboard(let configPath, let rootPath, let openBrowser, let bridgePort):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                var config = try AgentConfig.load(from: configURL)
                if let bridgePort {
                    config.localControlBridge.port = bridgePort
                }
                try validateOnboardingBridgeConfiguration(config.localControlBridge)
                let url = try onboardingURL(for: config.localControlBridge)

                if await localControlBridgeIsHealthy(config.localControlBridge) {
                    print("Onboarding: \(url.absoluteString)")
                    if openBrowser {
                        try openBrowserURL(url)
                    }
                } else {
                    let host = AgentCellRuntimeHost(paths: paths)
                    let snapshot = try await host.start(
                        instanceName: config.instanceName,
                        configURL: configURL,
                        controlBridge: config.localControlBridge,
                        networkSentinel: config.networkSentinel,
                        automationPolicy: config.automationPolicy
                    )
                    guard snapshot.controlBridge?.phase == .running else {
                        let detail = snapshot.controlBridge?.lastError ?? "control bridge did not enter running state"
                        await host.stop()
                        throw UsageError.invalidArguments("Unable to start onboarding server: \(detail)")
                    }
                    print("Onboarding: \(url.absoluteString)")
                    print("Serving onboarding locally. Press Ctrl-C to stop.")
                    if openBrowser {
                        try openBrowserURL(url)
                    }
                    await AgentMonitorShutdown().wait()
                    await host.stop()
                }

            case .run(let configPath, let once, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let config = try AgentConfig.load(from: configURL)
                let cellRuntimeHost = AgentCellRuntimeHost(paths: paths)
                let runtime = AgentRuntime(paths: paths)
                do {
                    let snapshot = try await cellRuntimeHost.start(
                        instanceName: config.instanceName,
                        configURL: configURL,
                        controlBridge: once ? nil : config.localControlBridge,
                        networkSentinel: config.networkSentinel,
                        automationPolicy: config.automationPolicy
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

            case .scheduleWorker(let configPath, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let config = try AgentConfig.load(from: configURL)
                let service = ScheduledEventService(
                    fileURL: paths.stateDirectory.appendingPathComponent("scheduled-events.json")
                )
                try await service.start(
                    definitions: config.scheduledEvents ?? [],
                    policy: config.automationPolicy
                )
                FileHandle.standardError.write(Data("haven-agentd schedule-worker: running \((config.scheduledEvents ?? []).count) event(s). SIGTERM/Ctrl-C to stop.\n".utf8))
                await AgentMonitorShutdown().wait()
                await service.stop()

            case .scheduleList(let configPath, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let config = try AgentConfig.load(from: configURL)
                let service = ScheduledEventService(
                    fileURL: paths.stateDirectory.appendingPathComponent("scheduled-events.json")
                )
                try await service.start(
                    definitions: config.scheduledEvents ?? [],
                    policy: config.automationPolicy,
                    runWorker: false,
                    persistConfiguration: false
                )
                let records = await service.snapshot()
                await service.stop()
                try printJSON(records)

            case .scheduleStop(let configPath, let eventID, let rootPath):
                let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let config = try AgentConfig.load(from: configURL)
                let service = ScheduledEventService(
                    fileURL: paths.stateDirectory.appendingPathComponent("scheduled-events.json")
                )
                try await service.start(
                    definitions: config.scheduledEvents ?? [],
                    policy: config.automationPolicy,
                    runWorker: false
                )
                let record = try await service.stopEvent(id: eventID)
                await service.stop()
                try printJSON(record)

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

            case .planAdvisors(let options):
                guard options.outDirectory == nil else {
                    throw UsageError.invalidArguments("plan-advisors does not write files and does not accept --out-dir. Use spawn-advisors for a persisted artifact.")
                }
                let paths = try resolvePaths(rootPath: options.rootPath, configPath: options.configPath)
                let request = try advisorPanelRequest(from: options)
                let result = try AdvisorPanelSpawnService(paths: paths).plan(request)
                try printJSON(result)

            case .spawnAdvisors(let options):
                let paths = try resolvePaths(rootPath: options.rootPath, configPath: options.configPath)
                let request = try advisorPanelRequest(from: options)
                let outDirectory = options.outDirectory.map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath) }
                let record = try AdvisorPanelSpawnService(paths: paths).spawn(request, outDirectory: outDirectory)
                if options.json {
                    try printJSON(record)
                } else {
                    print("Spawned advisor panel: \(record.artifact.id)")
                    print("Artifact: \(record.filePath)")
                    print("Advisor tasks: \(record.artifact.tasks.count)")
                    print("Boundary: local artifact only; no providers, notifications, scripts, or Cell state mutations were run.")
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
                    configURL: configURL,
                    controlBridge: config.localControlBridge,
                    networkSentinel: config.networkSentinel,
                    automationPolicy: config.automationPolicy
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

            case .networkListen(let minutes):
                // Native windowed self-test: runs the sentinel engine standalone for N
                // minutes and prints the NetworkListenSummary (rate/volume/flood events).
                // No tshark — this is the in-cell measurement engine doing the listen.
                let captureDirectory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("haven-network-listen-captures", isDirectory: true)
                let service = NetworkSentinelService(captureDirectory: captureDirectory, captureEnabled: true)
                await service.start()
                let started = await service.runListen(minutes: minutes)
                FileHandle.standardError.write(Data((started + "\n").utf8))
                let deadline = Date().addingTimeInterval(Double(max(1, minutes)) * 60.0 + 30.0)
                var summary = await service.snapshot().listenSummary
                while Date() < deadline, summary?.status != "complete" {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    summary = await service.snapshot().listenSummary
                }
                await service.stop()
                if let summary {
                    try printJSON(summary)
                } else {
                    print("{\"status\":\"ingen oppsummering\"}")
                }

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
        case "status":
            let remaining = Array(arguments.dropFirst())
            return .status(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining),
                json: remaining.contains("--json")
            )
        case "setup":
            let remaining = Array(arguments.dropFirst())
            return .setup(SetupOptions(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining),
                instanceName: argumentValue(for: "--instance-name", in: remaining),
                domain: argumentValue(for: "--domain", in: remaining),
                resolverBaseURL: argumentValue(for: "--resolver-url", in: remaining),
                discoveryURL: argumentValue(for: "--discovery-url", in: remaining),
                purpose: argumentValue(for: "--purpose", in: remaining),
                sproutBinaryPath: argumentValue(for: "--sprout-path", in: remaining),
                accessToken: argumentValue(for: "--access-token", in: remaining),
                startupMode: argumentValue(for: "--startup-mode", in: remaining),
                executablePath: argumentValue(for: "--executable-path", in: remaining),
                force: remaining.contains("--force"),
                skipLaunchAgent: remaining.contains("--no-launch-agent"),
                load: remaining.contains("--load")
            ))
        case "provisioning-request":
            let remaining = Array(arguments.dropFirst())
            return .provisioningRequest(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining)
            )
        case "provisioning-import":
            let remaining = Array(arguments.dropFirst())
            guard let packPath = argumentValue(for: "--pack", in: remaining) else {
                throw UsageError.invalidArguments("provisioning-import requires --pack /path/to/pack.json")
            }
            return .provisioningImport(
                packPath: packPath,
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining)
            )
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
        case "onboard":
            let remaining = Array(arguments.dropFirst())
            return .onboard(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining),
                openBrowser: remaining.contains("--open"),
                bridgePort: intArgumentValue(for: "--bridge-port", in: remaining)
            )
        case "run":
            let remaining = Array(arguments.dropFirst())
            return .run(
                configPath: argumentValue(for: "--config", in: remaining),
                once: remaining.contains("--once"),
                rootPath: argumentValue(for: "--root", in: remaining)
            )
        case "schedule-worker":
            let remaining = Array(arguments.dropFirst())
            return .scheduleWorker(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining)
            )
        case "schedule-list":
            let remaining = Array(arguments.dropFirst())
            return .scheduleList(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining)
            )
        case "schedule-stop":
            let remaining = Array(arguments.dropFirst())
            guard let eventID = argumentValue(for: "--event-id", in: remaining) else {
                throw UsageError.invalidArguments("schedule-stop requires --event-id ID")
            }
            return .scheduleStop(
                configPath: argumentValue(for: "--config", in: remaining),
                eventID: eventID,
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
        case "plan-advisors":
            let remaining = Array(arguments.dropFirst())
            return .planAdvisors(AdvisorPanelCommandOptions(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining),
                profile: argumentValue(for: "--profile", in: remaining),
                topic: argumentValue(for: "--topic", in: remaining),
                purposeRef: argumentValue(for: "--purpose", in: remaining),
                goal: argumentValue(for: "--goal", in: remaining),
                brief: argumentValue(for: "--brief", in: remaining),
                briefFile: argumentValue(for: "--brief-file", in: remaining),
                interests: argumentValues(for: "--interest", in: remaining),
                constraints: argumentValues(for: "--constraint", in: remaining),
                sourceRefs: argumentValues(for: "--source-ref", in: remaining),
                advisorSpecs: argumentValues(for: "--advisor", in: remaining),
                outDirectory: argumentValue(for: "--out-dir", in: remaining),
                json: true
            ))
        case "spawn-advisors":
            let remaining = Array(arguments.dropFirst())
            return .spawnAdvisors(AdvisorPanelCommandOptions(
                configPath: argumentValue(for: "--config", in: remaining),
                rootPath: argumentValue(for: "--root", in: remaining),
                profile: argumentValue(for: "--profile", in: remaining),
                topic: argumentValue(for: "--topic", in: remaining),
                purposeRef: argumentValue(for: "--purpose", in: remaining),
                goal: argumentValue(for: "--goal", in: remaining),
                brief: argumentValue(for: "--brief", in: remaining),
                briefFile: argumentValue(for: "--brief-file", in: remaining),
                interests: argumentValues(for: "--interest", in: remaining),
                constraints: argumentValues(for: "--constraint", in: remaining),
                sourceRefs: argumentValues(for: "--source-ref", in: remaining),
                advisorSpecs: argumentValues(for: "--advisor", in: remaining),
                outDirectory: argumentValue(for: "--out-dir", in: remaining),
                json: remaining.contains("--json")
            ))
        case "network-status":
            let remaining = Array(arguments.dropFirst())
            return .networkStatus(secondsToObserve: intArgumentValue(for: "--seconds", in: remaining) ?? 6)
        case "network-listen":
            let remaining = Array(arguments.dropFirst())
            return .networkListen(minutes: intArgumentValue(for: "--minutes", in: remaining) ?? 30)
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

    private static func argumentValues(for flag: String, in arguments: [String]) -> [String] {
        arguments.indices.compactMap { index in
            guard arguments[index] == flag, arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
        }
    }

    private static func intArgumentValue(for flag: String, in arguments: [String]) -> Int? {
        guard let value = argumentValue(for: flag, in: arguments) else {
            return nil
        }
        return Int(value)
    }

    /// The absolute path the LaunchAgent should run. Defaults to the running
    /// binary (so a pkg-installed agent points at its libexec location), but an
    /// override is useful for dev runs and tests.
    private static func resolveExecutablePath(override: String?) -> String {
        if let override, !override.isEmpty {
            return NSString(string: override).expandingTildeInPath
        }
        if let executableURL = Bundle.main.executableURL {
            return executableURL.resolvingSymlinksInPath().path
        }
        return CommandLine.arguments.first ?? "haven-agentd"
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

    private static func advisorPanelRequest(from options: AdvisorPanelCommandOptions) throws -> AdvisorPanelSpawnRequest {
        let suppliedBrief: String?
        if let brief = options.brief {
            suppliedBrief = brief
        } else if let briefFile = options.briefFile {
            suppliedBrief = try loadTextFile(briefFile)
        } else {
            suppliedBrief = nil
        }
        let profile = options.profile?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var request: AdvisorPanelSpawnRequest

        switch profile ?? "binding-gui" {
        case "binding-gui", "binding-gui-quality", "arendalsuka-gui", "event-atlas-gui":
            request = AdvisorPanelSpawnRequest.bindingGUIQualityProfile(brief: suppliedBrief)
        case "custom", "none":
            request = AdvisorPanelSpawnRequest(
                topic: try requiredArgument(options.topic, name: "--topic"),
                purposeRef: try requiredArgument(options.purposeRef, name: "--purpose"),
                goal: try requiredArgument(options.goal, name: "--goal"),
                brief: try requiredArgument(suppliedBrief, name: "--brief or --brief-file")
            )
        default:
            throw UsageError.invalidArguments("Unknown --profile '\(options.profile ?? "")'. Use binding-gui, arendalsuka-gui, or custom.")
        }

        if let topic = normalizedNonEmpty(options.topic) {
            request.topic = topic
        }
        if let purposeRef = normalizedNonEmpty(options.purposeRef) {
            request.purposeRef = purposeRef
        }
        if let goal = normalizedNonEmpty(options.goal) {
            request.goal = goal
        }
        if let brief = normalizedNonEmpty(suppliedBrief) {
            request.brief = brief
        }
        request.interests += options.interests.compactMap(normalizedNonEmpty)
        request.constraints += options.constraints.compactMap(normalizedNonEmpty)
        request.sourceRefs += options.sourceRefs.compactMap(normalizedNonEmpty)
        if options.advisorSpecs.isEmpty == false {
            request.advisors = try options.advisorSpecs.map(parseAdvisorSpec)
        }
        return request
    }

    private static func parseAdvisorSpec(_ raw: String) throws -> AdvisorPanelSpec {
        let parts = raw
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.isEmpty == false else {
            throw UsageError.invalidArguments("--advisor requires a non-empty value.")
        }
        switch parts.count {
        case 5...:
            return AdvisorPanelSpec(
                id: try requiredArgument(parts[0], name: "--advisor id"),
                displayName: try requiredArgument(parts[1], name: "--advisor displayName"),
                role: try requiredArgument(parts[3], name: "--advisor role"),
                preferredBackend: normalizedNonEmpty(parts[2]) ?? "local_or_reviewed",
                focus: splitFocus(parts[4])
            )
        case 4:
            return AdvisorPanelSpec(
                id: try requiredArgument(parts[0], name: "--advisor id"),
                displayName: try requiredArgument(parts[1], name: "--advisor displayName"),
                role: try requiredArgument(parts[3], name: "--advisor role"),
                preferredBackend: normalizedNonEmpty(parts[2]) ?? "local_or_reviewed"
            )
        case 3:
            return AdvisorPanelSpec(
                id: try requiredArgument(parts[0], name: "--advisor id"),
                displayName: try requiredArgument(parts[1], name: "--advisor displayName"),
                role: try requiredArgument(parts[2], name: "--advisor role")
            )
        case 2:
            let displayName = try requiredArgument(parts[0], name: "--advisor displayName")
            return AdvisorPanelSpec(
                id: slug(displayName),
                displayName: displayName,
                role: try requiredArgument(parts[1], name: "--advisor role")
            )
        default:
            let displayName = try requiredArgument(parts[0], name: "--advisor displayName")
            return AdvisorPanelSpec(
                id: slug(displayName),
                displayName: displayName,
                role: "Review the task from this advisor's perspective."
            )
        }
    }

    private static func splitFocus(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .compactMap { normalizedNonEmpty(String($0)) }
    }

    private static func loadTextFile(_ path: String) throws -> String {
        let expanded = NSString(string: path).expandingTildeInPath
        return try String(contentsOf: URL(fileURLWithPath: expanded), encoding: .utf8)
    }

    private static func requiredArgument(_ value: String?, name: String) throws -> String {
        guard let value = normalizedNonEmpty(value) else {
            throw UsageError.invalidArguments("\(name) is required.")
        }
        return value
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let chars = value.lowercased().unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(chars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
        return collapsed.isEmpty ? UUID().uuidString.lowercased() : collapsed
    }

    private static func usage() -> String {
        """
        Usage:
          haven-agentd print-example-config [--root /path/to/dev-root]
          haven-agentd print-launch-agent [--root /path/to/dev-root]
          haven-agentd status [--config /path/to/config.json] [--root /path/to/dev-root] [--json]
          haven-agentd setup [--config /path/to/config.json] [--root /path/to/dev-root] [--domain d] [--resolver-url URL] [--discovery-url URL] [--purpose p] [--instance-name name] [--sprout-path /abs/sprout] [--access-token TOKEN] [--startup-mode disabled|plan|join] [--executable-path /abs/haven-agentd] [--force] [--no-launch-agent] [--load]
          haven-agentd provisioning-request [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd provisioning-import --pack /path/to/pack.json [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd validate-config [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd bootstrap-probe [--config /path/to/config.json] [--root /path/to/dev-root] [--run-bootstrap]
          haven-agentd refresh-starter-auth [--config /path/to/config.json] [--root /path/to/dev-root] [--ttl-seconds N]
          haven-agentd onboard [--config /path/to/config.json] [--root /path/to/dev-root] [--bridge-port N] [--open]
          haven-agentd run [--config /path/to/config.json] [--once] [--root /path/to/dev-root]
          haven-agentd schedule-worker [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd schedule-list [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd schedule-stop --event-id ID [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd review-state [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd review-approve --intent-id ID [--reviewer name] [--note text] [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd review-reject --intent-id ID [--reviewer name] [--note text] [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd list-cell-blueprints
          haven-agentd plan-advisors [--profile binding-gui|arendalsuka-gui|custom] [--topic text] [--purpose purposeRef] [--goal text] [--brief text | --brief-file /path/brief.md] [--interest text] [--constraint text] [--source-ref text] [--advisor "id|Display|backend|Role|focus,items"] [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd spawn-advisors [--profile binding-gui|arendalsuka-gui|custom] [--topic text] [--purpose purposeRef] [--goal text] [--brief text | --brief-file /path/brief.md] [--interest text] [--constraint text] [--source-ref text] [--advisor "id|Display|backend|Role|focus,items"] [--out-dir /path] [--json] [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd network-status [--seconds N]
          haven-agentd network-listen [--minutes N]
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

    private static func validateOnboardingBridgeConfiguration(_ bridge: LocalControlBridgeConfig) throws {
        guard bridge.enabled else {
            throw UsageError.invalidArguments("localControlBridge is disabled. Run `haven-agentd setup` or enable the bridge before using onboard.")
        }
        guard bridge.loopbackOnly else {
            throw UsageError.invalidArguments("localControlBridge.host must be loopback-only for onboard.")
        }
        guard let token = bridge.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              token.isEmpty == false else {
            throw UsageError.invalidArguments("localControlBridge.accessToken is missing. Run `haven-agentd setup --force` or set a token before using onboard.")
        }
    }

    private static func onboardingURL(for bridge: LocalControlBridgeConfig) throws -> URL {
        guard let token = bridge.accessToken, token.isEmpty == false else {
            throw UsageError.invalidArguments("localControlBridge.accessToken is missing.")
        }
        var components = URLComponents()
        components.scheme = "http"
        components.host = bridge.host
        components.port = bridge.port
        components.path = "/onboard"
        components.queryItems = [
            URLQueryItem(name: "token", value: token)
        ]
        guard let url = components.url else {
            throw UsageError.invalidArguments("Unable to build onboarding URL for \(bridge.host):\(bridge.port).")
        }
        return url
    }

    private static func healthURL(for bridge: LocalControlBridgeConfig) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = bridge.host
        components.port = bridge.port
        components.path = "/health"
        if let token = bridge.accessToken, token.isEmpty == false {
            components.queryItems = [
                URLQueryItem(name: "token", value: token)
            ]
        }
        return components.url
    }

    private static func localControlBridgeIsHealthy(_ bridge: LocalControlBridgeConfig) async -> Bool {
        guard let url = healthURL(for: bridge) else {
            return false
        }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private static func openBrowserURL(_ url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UsageError.invalidArguments("/usr/bin/open failed for \(url.absoluteString).")
        }
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
