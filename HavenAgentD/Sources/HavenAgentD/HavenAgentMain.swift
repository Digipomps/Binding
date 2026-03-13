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
    case run(configPath: String?, once: Bool, rootPath: String?)
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

            case .run(let configPath, let once, let rootPath):
                let paths = try resolvePaths(rootPath)
                let configURL = resolveConfigURL(configPath, paths: paths)
                let config = try AgentConfig.load(from: configURL)
                let cellRuntimeHost = AgentCellRuntimeHost(paths: paths)
                let runtime = AgentRuntime(paths: paths)
                do {
                    let snapshot = try await cellRuntimeHost.start(instanceName: config.instanceName)
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
        case "run":
            let remaining = Array(arguments.dropFirst())
            return .run(
                configPath: argumentValue(for: "--config", in: remaining),
                once: remaining.contains("--once"),
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
          haven-agentd run [--config /path/to/config.json] [--once] [--root /path/to/dev-root]
          haven-agentd list-cell-blueprints
          haven-agentd smoke-test [--root /path/to/dev-root]
        """
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
