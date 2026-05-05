import Foundation
import Darwin
import HavenRuntimeBootstrap

private struct HavenAgentMCPLaunchConfiguration {
    let paths: RuntimePaths
    let configURL: URL
}

private final class HavenAgentMCPServer {
    private let service: HavenAgentMCPService
    private let protocolVersion = "2025-11-25"
    private var hasRespondedToInitialize = false
    private var hasReceivedInitializedNotification = false

    init(service: HavenAgentMCPService) {
        self.service = service
    }

    func run() async throws {
        while let line = readLine(strippingNewline: true) {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            if let response = await handle(rawLine: line) {
                try write(response: response)
            }
        }
    }

    private func handle(rawLine: String) async -> JSONObject? {
        let decoded: Any
        do {
            decoded = try decodeJSONLine(rawLine)
        } catch {
            return makeJSONRPCError(
                id: nil,
                code: JSONRPCErrorCode.parseError,
                message: "Parse error"
            )
        }

        let requestID = extractID(from: decoded)
        let request: MCPRequest
        do {
            request = try MCPRequest(jsonObject: decoded)
        } catch {
            if requestID == nil {
                return makeJSONRPCError(
                    id: nil,
                    code: JSONRPCErrorCode.invalidRequest,
                    message: error.localizedDescription
                )
            }
            return makeJSONRPCError(
                id: requestID,
                code: JSONRPCErrorCode.invalidRequest,
                message: error.localizedDescription
            )
        }

        return await handle(request: request)
    }

    private func handle(request: MCPRequest) async -> JSONObject? {
        if !hasRespondedToInitialize && request.method != "initialize" && request.method != "ping" {
            if request.isNotification {
                return nil
            }
            return makeJSONRPCError(
                id: request.id,
                code: JSONRPCErrorCode.invalidRequest,
                message: "The initialize request must be the first non-ping interaction."
            )
        }

        switch request.method {
        case "initialize":
            hasRespondedToInitialize = true
            if request.isNotification {
                return nil
            }
            return makeJSONRPCResult(id: request.id as Any, result: [
                "protocolVersion": protocolVersion,
                "capabilities": [
                    "resources": [
                        "subscribe": false,
                        "listChanged": false
                    ],
                    "tools": [
                        "listChanged": false
                    ]
                ],
                "serverInfo": [
                    "name": "haven-agentd-mcp",
                    "title": "HAVENAgentD MCP",
                    "version": "0.1.0",
                    "description": "Local MCP adapter for safe HAVENAgentD runtime inspection and review operations."
                ],
                "instructions": "This server exposes a safe local subset of HAVENAgentD over MCP stdio. Sensitive tools should remain user-confirmed."
            ])

        case "notifications/initialized":
            hasReceivedInitializedNotification = true
            return nil

        case "ping":
            guard let id = request.id else {
                return nil
            }
            return makeJSONRPCResult(id: id, result: [:])

        case "resources/list":
            guard let id = request.id else {
                return nil
            }
            return makeJSONRPCResult(id: id, result: [
                "resources": service.listResources()
            ])

        case "resources/templates/list":
            guard let id = request.id else {
                return nil
            }
            return makeJSONRPCResult(id: id, result: [
                "resourceTemplates": []
            ])

        case "resources/read":
            guard let id = request.id else {
                return nil
            }
            guard let uri = stringValue(request.params["uri"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !uri.isEmpty else {
                return makeJSONRPCError(
                    id: id,
                    code: JSONRPCErrorCode.invalidParams,
                    message: "resources/read requires a non-empty uri parameter."
                )
            }
            do {
                let result = try await service.readResource(uri: uri)
                return makeJSONRPCResult(id: id, result: result)
            } catch {
                return makeJSONRPCError(
                    id: id,
                    code: JSONRPCErrorCode.invalidParams,
                    message: error.localizedDescription
                )
            }

        case "tools/list":
            guard let id = request.id else {
                return nil
            }
            return makeJSONRPCResult(id: id, result: [
                "tools": service.listTools()
            ])

        case "tools/call":
            guard let id = request.id else {
                return nil
            }
            guard let name = stringValue(request.params["name"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                return makeJSONRPCError(
                    id: id,
                    code: JSONRPCErrorCode.invalidParams,
                    message: "tools/call requires a non-empty name parameter."
                )
            }
            let knownToolNames = service.listTools().compactMap { stringValue($0["name"]) }
            guard knownToolNames.contains(name) else {
                return makeJSONRPCError(
                    id: id,
                    code: JSONRPCErrorCode.invalidParams,
                    message: "Unknown tool: \(name)"
                )
            }
            let arguments = objectValue(request.params["arguments"]) ?? [:]
            let output = await service.callTool(name: name, arguments: arguments)
            var result: JSONObject = [
                "content": [textContent(output.text)],
                "isError": output.isError
            ]
            if let structuredContent = output.structuredContent {
                result["structuredContent"] = structuredContent
            }
            return makeJSONRPCResult(id: id, result: result)

        default:
            guard !request.isNotification else {
                return nil
            }
            return makeJSONRPCError(
                id: request.id,
                code: JSONRPCErrorCode.methodNotFound,
                message: "Method not found: \(request.method)"
            )
        }
    }

    private func write(response: JSONObject) throws {
        let line = try encodeJSONLine(response)
        print(line)
        fflush(stdout)
    }

    private func extractID(from jsonObject: Any) -> Any? {
        guard let object = jsonObject as? JSONObject else {
            return nil
        }
        return object["id"]
    }
}

@main
struct HavenAgentDMCPMain {
    static func main() async {
        do {
            guard let configuration = try parseLaunchConfiguration(arguments: Array(CommandLine.arguments.dropFirst())) else {
                return
            }

            let service = HavenAgentMCPService(
                paths: configuration.paths,
                configURL: configuration.configURL
            )
            let server = HavenAgentMCPServer(service: service)
            try await server.run()
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            Darwin.exit(1)
        }
    }

    private static func parseLaunchConfiguration(arguments: [String]) throws -> HavenAgentMCPLaunchConfiguration? {
        if arguments.contains("--help") || arguments.contains("-h") {
            FileHandle.standardError.write(Data("\(usage())\n".utf8))
            return nil
        }

        let rootPath = argumentValue(for: "--root", in: arguments)
        let configPath = argumentValue(for: "--config", in: arguments)
        let paths = try resolvePaths(rootPath: rootPath, configPath: configPath)
        let configURL = resolveConfigURL(configPath, paths: paths)
        return HavenAgentMCPLaunchConfiguration(paths: paths, configURL: configURL)
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
          haven-agentd-mcp [--config /path/to/config.json] [--root /path/to/dev-root]
        """
    }
}
