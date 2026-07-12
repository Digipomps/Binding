import Foundation
#if os(macOS)
import Darwin
#endif
import CellBase

enum AgentLocalControlBridgeEndpointSupport {
    private struct ControlBridgeConfiguration {
        var enabled: Bool
        var host: String
        var port: Int
        var accessToken: String?
        var routeNamesByTarget: [String: String]
    }

    private static let defaultRoutesByTarget: [String: String] = [
        "agent/identity": "agent-identity",
        "agent/supervisor": "agent-supervisor",
        "agent/intents/inbox": "intent-inbox",
        "agent/intents/review": "intent-review",
        "agent/network/sentinel": "network-sentinel",
        "agent/email/outbox": "email-outbox"
    ]

    private static let runtimeAccessBookmarkKey = "Binding.AgentRuntimeAccess.applicationSupportBookmark"
    private static let runtimeAccessLock = NSLock()
    nonisolated(unsafe) private static var runtimeAccessURL: URL?
    nonisolated(unsafe) private static var runtimeAccessStarted = false

    static func rewriteEndpoint(_ endpoint: String) -> String? {
        guard let configJSON = readDefaultConfigJSON() else {
            return nil
        }
        return rewriteEndpoint(endpoint, configJSON: configJSON)
    }

    static func rewriteEndpoint(_ endpoint: String, configJSON: [String: Any]) -> String? {
        guard let targetCellReference = localAgentTargetCellReference(from: endpoint) else {
            return nil
        }
        return bridgeEndpoint(forTargetCellReference: targetCellReference, configJSON: configJSON)
    }

    static func bridgeEndpoint(forTargetCellReference targetCellReference: String, configJSON: [String: Any]) -> String? {
        let configuration = controlBridgeConfiguration(configJSON: configJSON)
        guard configuration.enabled,
              isLoopbackHost(configuration.host),
              let routeName = configuration.routeNamesByTarget[targetCellReference] else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "ws"
        components.host = configuration.host
        components.port = configuration.port
        components.path = "/bridgehead/\(routeName)"
        if let accessToken = configuration.accessToken, accessToken.isEmpty == false {
            components.queryItems = [URLQueryItem(name: "token", value: accessToken)]
        }
        return components.url?.absoluteString
    }

    private static func localAgentTargetCellReference(from endpoint: String) -> String? {
        guard let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell" else {
            return nil
        }

        guard isLoopbackOrEmptyHost(components.host) else { return nil }

        let target = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard target.hasPrefix("agent/") else { return nil }
        return target
    }

    private static func controlBridgeConfiguration(configJSON: [String: Any]) -> ControlBridgeConfiguration {
        guard let object = configJSON["localControlBridge"] as? [String: Any] else {
            return ControlBridgeConfiguration(
                enabled: false,
                host: "127.0.0.1",
                port: 43110,
                accessToken: nil,
                routeNamesByTarget: defaultRoutesByTarget
            )
        }

        let enabled = (object["enabled"] as? Bool) ?? false
        let host = stringValue(fromAny: object["host"]) ?? "127.0.0.1"
        let port = (object["port"] as? NSNumber)?.intValue ?? 43110
        let accessToken = stringValue(fromAny: object["accessToken"])
        let routes = (object["routes"] as? [[String: Any]])?.reduce(into: defaultRoutesByTarget) { partialResult, entry in
            guard let name = stringValue(fromAny: entry["name"]),
                  let targetCellReference = stringValue(fromAny: entry["targetCellReference"]) else {
                return
            }
            partialResult[targetCellReference] = name
        } ?? defaultRoutesByTarget

        return ControlBridgeConfiguration(
            enabled: enabled,
            host: host,
            port: port,
            accessToken: accessToken,
            routeNamesByTarget: routes
        )
    }

    private static func readDefaultConfigJSON() -> [String: Any]? {
        let applicationSupportDirectory = userHomeDirectory()
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        activatePersistedExternalRuntimeAccess(forRuntimeAccessDirectory: applicationSupportDirectory)
        let configURL = applicationSupportDirectory
            .appendingPathComponent("HAVENAgent", isDirectory: true)
            .appendingPathComponent("config.json")

        guard let data = try? Data(contentsOf: configURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func activatePersistedExternalRuntimeAccess(forRuntimeAccessDirectory runtimeAccessDirectory: URL) {
#if os(macOS)
        runtimeAccessLock.lock()
        defer { runtimeAccessLock.unlock() }

        if runtimeAccessStarted,
           runtimeAccessURL?.standardizedFileURL == runtimeAccessDirectory.standardizedFileURL {
            return
        }

        guard let bookmarkData = UserDefaults.standard.data(forKey: runtimeAccessBookmarkKey) else {
            return
        }

        var bookmarkIsStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &bookmarkIsStale
        ) else {
            return
        }

        guard resolvedURL.standardizedFileURL == runtimeAccessDirectory.standardizedFileURL else {
            return
        }

        if bookmarkIsStale,
           let refreshedBookmarkData = try? resolvedURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
           ) {
            UserDefaults.standard.set(refreshedBookmarkData, forKey: runtimeAccessBookmarkKey)
        }

        runtimeAccessURL = resolvedURL
        runtimeAccessStarted = resolvedURL.startAccessingSecurityScopedResource()
#else
        _ = runtimeAccessDirectory
#endif
    }

    private static func userHomeDirectory() -> URL {
#if os(macOS)
        if let entry = getpwuid(getuid()),
           let directory = entry.pointee.pw_dir,
           let resolvedHome = String(validatingUTF8: directory),
           !resolvedHome.isEmpty {
            return URL(fileURLWithPath: resolvedHome, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
#else
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
#endif
    }

    private static func isLoopbackHost(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "localhost"
            || normalized == "127.0.0.1"
            || normalized == "::1"
            || normalized == "[::1]"
    }

    private static func isLoopbackOrEmptyHost(_ host: String?) -> Bool {
        guard let host else { return true }
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty || isLoopbackHost(normalized)
    }

    private static func stringValue(fromAny value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }
}

enum CellConfigurationEndpointRetargeting {
    private static let stagingHost = "staging.haven.digipomps.org"
    private static let localVerifierFallbackCellNames: Set<String> = [
        "PersonalProfilePublisher",
        "PublicProfileDirectory",
        "PersonalMatchmaking",
        "PersonalMeetingCoordinator",
        "PersonalCopilotConfigurationCatalog"
    ]

    static func rewritingStagingPersonalCopilotEndpointsToLocalFallbacks(
        in configuration: CellConfiguration
    ) -> CellConfiguration {
        rewritingEndpoints(in: configuration) {
            rewriteStagingPersonalCopilotEndpointToLocalFallback($0)
        }
    }

    static func rewriteStagingPersonalCopilotEndpointToLocalFallback(_ endpoint: String) -> String {
        guard var components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell",
              components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == stagingHost
        else {
            return endpoint
        }

        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard localVerifierFallbackCellNames.contains(normalizedPath) else {
            return endpoint
        }

        return "cell:///\(normalizedPath)"
    }

    static func rewritingLocalCellEndpoints(
        in configuration: CellConfiguration,
        toScaffoldEndpoint scaffoldEndpoint: String
    ) -> CellConfiguration {
        guard let origin = RetargetOrigin(scaffoldEndpoint: scaffoldEndpoint) else {
            return configuration
        }

        return rewritingEndpoints(in: configuration) {
            rewriteLocalCellEndpoint($0, to: origin)
        }
    }

    static func rewritingLocalAgentBridgeEndpoints(
        in configuration: CellConfiguration
    ) -> CellConfiguration {
        rewritingEndpoints(in: configuration) {
            AgentLocalControlBridgeEndpointSupport.rewriteEndpoint($0) ?? $0
        }
    }

    static func rewritingLocalAgentBridgeEndpoints(
        in configuration: CellConfiguration,
        configJSON: [String: Any]
    ) -> CellConfiguration {
        rewritingEndpoints(in: configuration) {
            AgentLocalControlBridgeEndpointSupport.rewriteEndpoint($0, configJSON: configJSON) ?? $0
        }
    }

    static func rewriteLocalCellEndpoint(
        _ endpoint: String,
        toScaffoldEndpoint scaffoldEndpoint: String
    ) -> String {
        guard let origin = RetargetOrigin(scaffoldEndpoint: scaffoldEndpoint) else {
            return endpoint
        }
        return rewriteLocalCellEndpoint(endpoint, to: origin)
    }

    static func rewritingEndpoints(
        in configuration: CellConfiguration,
        transform: (String) -> String
    ) -> CellConfiguration {
        guard let data = try? JSONEncoder().encode(configuration),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let rewrittenObject = rewriteJSONValue(jsonObject, transform: transform),
              JSONSerialization.isValidJSONObject(rewrittenObject),
              let rewrittenData = try? JSONSerialization.data(withJSONObject: rewrittenObject),
              let rewrittenConfiguration = try? JSONDecoder().decode(CellConfiguration.self, from: rewrittenData)
        else {
            return configuration
        }

        return rewrittenConfiguration
    }

    private static func rewriteJSONValue(
        _ value: Any,
        transform: (String) -> String
    ) -> Any? {
        switch value {
        case let string as String:
            return rewriteStringIfEndpointLike(string, transform: transform)
        case let dictionary as [String: Any]:
            var rewritten: [String: Any] = [:]
            rewritten.reserveCapacity(dictionary.count)
            for (key, childValue) in dictionary {
                rewritten[key] = rewriteJSONValue(childValue, transform: transform) ?? childValue
            }
            return rewritten
        case let array as [Any]:
            return array.map { rewriteJSONValue($0, transform: transform) ?? $0 }
        default:
            return value
        }
    }

    private static func rewriteStringIfEndpointLike(
        _ value: String,
        transform: (String) -> String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("cell://") else {
            return value
        }

        let rewritten = transform(trimmed)
        guard rewritten != trimmed else {
            return value
        }

        let prefixLength = value.distance(
            from: value.startIndex,
            to: value.range(of: trimmed)?.lowerBound ?? value.startIndex
        )
        let suffixLength = value.distance(
            from: value.range(of: trimmed)?.upperBound ?? value.endIndex,
            to: value.endIndex
        )

        let prefix = value.prefix(prefixLength)
        let suffix = value.suffix(suffixLength)
        return "\(prefix)\(rewritten)\(suffix)"
    }

    private static func rewriteLocalCellEndpoint(
        _ endpoint: String,
        to origin: RetargetOrigin
    ) -> String {
        guard var components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell"
        else {
            return endpoint
        }

        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedPath.isEmpty else { return endpoint }

        let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isLoopbackOrEmptyCellHost(host) else { return endpoint }

        components.host = origin.host
        components.port = origin.port
        components.path = "/" + normalizedPath
        return components.string ?? endpoint
    }

    private static func isLoopbackOrEmptyCellHost(_ host: String?) -> Bool {
        let normalized = host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalized.isEmpty
            || normalized == "localhost"
            || normalized == "127.0.0.1"
            || normalized == "::1"
            || normalized == "[::1]"
    }

    private struct RetargetOrigin {
        let host: String
        let port: Int?

        init?(scaffoldEndpoint: String) {
            guard let components = URLComponents(string: scaffoldEndpoint),
                  let scheme = components.scheme?.lowercased(),
                  ["cell", "ws", "wss", "http", "https"].contains(scheme),
                  let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !host.isEmpty
            else {
                return nil
            }

            self.host = host
            self.port = components.port
        }
    }
}
