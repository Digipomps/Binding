import Foundation
import HavenAgentCells
import HavenAgentCellRuntime
import HavenAgentRuntime
import HavenRuntimeBootstrap
import Darwin

enum HavenAgentCommand {
    case printExampleConfig(rootPath: String?)
    case printLaunchAgent(rootPath: String?)
    case validateConfig(configPath: String?, rootPath: String?)
    case bootstrapProbe(configPath: String?, rootPath: String?, runBootstrap: Bool)
    case run(configPath: String?, once: Bool, rootPath: String?)
    case reviewState(configPath: String?, rootPath: String?)
    case reviewApprove(configPath: String?, intentID: String, reviewer: String?, note: String?, rootPath: String?)
    case reviewReject(configPath: String?, intentID: String, reviewer: String?, note: String?, rootPath: String?)
    case listCellBlueprints
    case smokeTest(rootPath: String?)
}

@main
struct HavenAgentMain {
    static func main() async {
        do {
            let command = try parse(arguments: Array(CommandLine.arguments.dropFirst()))

            switch command {
            case .printExampleConfig(let rootPath):
                let paths = try resolvePaths(rootPath)
                let config = AgentConfig.example(paths: paths)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(config)
                print(String(decoding: data, as: UTF8.self))

            case .printLaunchAgent(let rootPath):
                let paths = try resolvePaths(rootPath)
                let executablePath = paths.agentDirectory.appendingPathComponent("haven-agentd").path
                let plist = LaunchAgentTemplate.render(
                    executablePath: executablePath,
                    configPath: paths.configFile.path,
                    logDirectory: paths.logsDirectory.path
                )
                print(plist)

            case .validateConfig(let configPath, let rootPath):
                let paths = try resolvePaths(rootPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let runtime = AgentRuntime(paths: paths)
                _ = try await runtime.validate(configURL: configURL)
                print("Config OK: \(configURL.path)")

            case .bootstrapProbe(let configPath, let rootPath, let runBootstrap):
                let paths = try resolvePaths(rootPath)
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

            case .run(let configPath, let once, let rootPath):
                let paths = try resolvePaths(rootPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let config = try AgentConfig.load(from: configURL)
                let cellRuntimeHost = AgentCellRuntimeHost(paths: paths)
                let runtime = AgentRuntime(paths: paths)
                do {
                    let snapshot = try await cellRuntimeHost.start(
                        instanceName: config.instanceName,
                        controlBridge: once ? nil : config.localControlBridge
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
                let paths = try resolvePaths(rootPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let summary = try await ReviewCommandService(paths: paths, configURL: configURL).state()
                try printJSON(summary)

            case .reviewApprove(let configPath, let intentID, let reviewer, let note, let rootPath):
                let paths = try resolvePaths(rootPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let summary = try await ReviewCommandService(paths: paths, configURL: configURL)
                    .approve(intentID: intentID, reviewer: reviewer ?? "binding-operator", note: note)
                try printJSON(summary)

            case .reviewReject(let configPath, let intentID, let reviewer, let note, let rootPath):
                let paths = try resolvePaths(rootPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let summary = try await ReviewCommandService(paths: paths, configURL: configURL)
                    .reject(intentID: intentID, reviewer: reviewer ?? "binding-operator", note: note)
                try printJSON(summary)

            case .listCellBlueprints:
                for blueprint in AgentCellCatalog.defaultBlueprints {
                    print("\(blueprint.kind.rawValue): \(blueprint.suggestedCellName) - \(blueprint.purpose)")
                }

            case .smokeTest(let rootPath):
                let summary = try await SmokeTestHarness.run(rootPath: rootPath)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(summary)
                print(String(decoding: data, as: UTF8.self))
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
        case "smoke-test":
            return .smokeTest(rootPath: argumentValue(for: "--root", in: Array(arguments.dropFirst())))
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

    private static func resolveConfigURL(_ configPath: String?, paths: RuntimePaths) -> URL {
        guard let configPath else {
            return paths.configFile
        }
        let expanded = NSString(string: configPath).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    private static func resolvePaths(_ rootPath: String?) throws -> RuntimePaths {
        guard let rootPath, !rootPath.isEmpty else {
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
          haven-agentd run [--config /path/to/config.json] [--once] [--root /path/to/dev-root]
          haven-agentd review-state [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd review-approve --intent-id ID [--reviewer name] [--note text] [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd review-reject --intent-id ID [--reviewer name] [--note text] [--config /path/to/config.json] [--root /path/to/dev-root]
          haven-agentd list-cell-blueprints
          haven-agentd smoke-test [--root /path/to/dev-root]
        """
    }

    private static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        print(String(decoding: data, as: UTF8.self))
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
