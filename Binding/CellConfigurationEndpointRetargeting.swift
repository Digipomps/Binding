import Foundation
#if canImport(Darwin)
import Darwin
#endif
import CellBase

nonisolated enum AgentLocalControlBridgeEndpointSupport {
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

    static func portableEndpoint(_ endpoint: String) -> String? {
        guard let configJSON = readDefaultConfigJSON() else { return nil }
        return portableEndpoint(endpoint, configJSON: configJSON)
    }

    static func portableEndpoint(_ endpoint: String, configJSON: [String: Any]) -> String? {
        let configuration = controlBridgeConfiguration(configJSON: configJSON)
        guard let components = URLComponents(string: endpoint),
              ["ws", "wss"].contains(components.scheme?.lowercased() ?? ""),
              isLoopbackHost(components.host ?? ""),
              components.port == nil || components.port == configuration.port else {
            return nil
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard path.hasPrefix("bridgehead/") else { return nil }
        let routeName = String(path.dropFirst("bridgehead/".count))
        guard let target = configuration.routeNamesByTarget.first(where: { $0.value == routeName })?.key else {
            return nil
        }
        return "cell:///\(target)"
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

nonisolated enum CellConfigurationEndpointRetargeting {
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

    /// Remote owner-published configurations may reference their own local
    /// cell namespace, but they must never select Binding's loopback control
    /// plane or cause a local agent credential to be embedded into payloads.
    static func isSafeForRemoteOwnerPublication(
        _ configuration: CellConfiguration
    ) -> Bool {
        guard let data = try? JSONEncoder().encode(configuration),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return false
        }
        return !containsForbiddenRemoteLocalControlEndpoint(jsonObject)
    }

    static func isAllowedByHostTrustBoundary(
        _ configuration: CellConfiguration,
        mayUseLocalControlPlane: Bool
    ) -> Bool {
        mayUseLocalControlPlane || isSafeForRemoteOwnerPublication(configuration)
    }

    /// A file, clipboard payload, or other untrusted import has no publisher
    /// origin whose portable `cell:///...` namespace can be retargeted. Such
    /// references would otherwise resolve against Binding's ambient local
    /// requester and become a confused-deputy path into local Cells.
    static func isSafeForUntrustedImport(
        _ configuration: CellConfiguration
    ) -> Bool {
        guard let data = try? JSONEncoder().encode(configuration),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return false
        }
        return !containsUntrustedImportLocalEndpoint(jsonObject)
    }

    /// `intent=view` is a read-only host promise. Initializer writes and
    /// cross-target assignments must not be triggered by an external URL,
    /// even when the ambient requester already has a grant.
    static func isSideEffectFreeForExternalView(
        _ configuration: CellConfiguration
    ) -> Bool {
        (configuration.cellReferences ?? []).allSatisfy(isSideEffectFreeReference)
    }

    /// Converts host-local agent bridge URLs back to their portable cell:///
    /// form before persistence, source writes, clipboard export, or display.
    /// Runtime credentials consequently do not cross these externalization
    /// boundaries.
    static func removingRuntimeCredentials(
        from configuration: CellConfiguration
    ) -> CellConfiguration {
        rewritingAllStrings(in: configuration) { value in
            if let portable = AgentLocalControlBridgeEndpointSupport.portableEndpoint(value) {
                return portable
            }
            return redactedTextForDisplay(redactedEndpointForDisplay(value))
        }
    }

    static func redactedEndpointForDisplay(_ endpoint: String) -> String {
        guard var components = URLComponents(string: endpoint),
              components.scheme != nil else {
            return redactedTextForDisplay(endpoint)
        }
        components.user = nil
        components.password = nil
        let sensitiveNames = Set(["access_token", "authorization", "api_key", "apikey", "token"])
        components.queryItems = components.queryItems?.filter {
            !sensitiveNames.contains($0.name.lowercased())
        }
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }
        return redactedTextForDisplay(components.string ?? endpoint)
    }

    static func redactedTextForDisplay(_ text: String) -> String {
        var redacted = text.replacingOccurrences(
            of: #"(?i)(access_token|authorization|api_key|apikey|token)=([^\s&#\"']+)"#,
            with: "$1=<redacted>",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"(?i)([a-z][a-z0-9+.-]*://)[^/@\s]+@"#,
            with: "$1<redacted>@",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"(?i)(authorization\s*:\s*(?:bearer|basic)\s+)[^\s,;]+"#,
            with: "$1<redacted>",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"(?i)([\"']?(?:access_token|authorization|api_key|apikey|token)[\"']?\s*:\s*[\"'])[^\"']+([\"'])"#,
            with: "$1<redacted>$2",
            options: .regularExpression
        )
        return redacted
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

    private static func rewritingAllStrings(
        in configuration: CellConfiguration,
        transform: (String) -> String
    ) -> CellConfiguration {
        guard let data = try? JSONEncoder().encode(configuration),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let rewrittenObject = rewriteAllStringValues(jsonObject, transform: transform),
              JSONSerialization.isValidJSONObject(rewrittenObject),
              let rewrittenData = try? JSONSerialization.data(withJSONObject: rewrittenObject),
              let rewrittenConfiguration = try? JSONDecoder().decode(CellConfiguration.self, from: rewrittenData)
        else {
            return configuration
        }
        return rewrittenConfiguration
    }

    private static func rewriteAllStringValues(
        _ value: Any,
        transform: (String) -> String
    ) -> Any? {
        switch value {
        case let string as String:
            return transform(string)
        case let dictionary as [String: Any]:
            var rewritten: [String: Any] = [:]
            rewritten.reserveCapacity(dictionary.count)
            for (key, childValue) in dictionary {
                rewritten[key] = rewriteAllStringValues(childValue, transform: transform) ?? childValue
            }
            return rewritten
        case let array as [Any]:
            return array.map { rewriteAllStringValues($0, transform: transform) ?? $0 }
        default:
            return value
        }
    }

    private static func containsForbiddenRemoteLocalControlEndpoint(_ value: Any) -> Bool {
        switch value {
        case let string as String:
            return isForbiddenRemoteLocalControlEndpoint(string)
        case let dictionary as [String: Any]:
            return dictionary.values.contains(where: containsForbiddenRemoteLocalControlEndpoint)
        case let array as [Any]:
            return array.contains(where: containsForbiddenRemoteLocalControlEndpoint)
        default:
            return false
        }
    }

    private static func containsUntrustedImportLocalEndpoint(_ value: Any) -> Bool {
        switch value {
        case let string as String:
            return isUntrustedImportLocalEndpoint(string)
        case let dictionary as [String: Any]:
            return dictionary.values.contains(where: containsUntrustedImportLocalEndpoint)
        case let array as [Any]:
            return array.contains(where: containsUntrustedImportLocalEndpoint)
        default:
            return false
        }
    }

    private static func isUntrustedImportLocalEndpoint(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased() else {
            return false
        }
        if scheme == "ws" || scheme == "wss" {
            return isUnsafeLocalControlHost(components.host)
        }
        guard scheme == "cell" else { return false }
        let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return host.isEmpty || isUnsafeLocalControlHost(host)
    }

    private static func isForbiddenRemoteLocalControlEndpoint(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased() else {
            return false
        }
        let host = components.host
        let isExplicitLoopback = isUnsafeLocalControlHost(host)

        if scheme == "ws" || scheme == "wss" {
            return isExplicitLoopback
        }
        guard scheme == "cell" else { return false }
        if isExplicitLoopback {
            return true
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return (host ?? "").isEmpty && (path == "agent" || path.hasPrefix("agent/"))
    }

    private static func isSideEffectFreeReference(_ reference: CellReference) -> Bool {
        guard reference.setKeysAndValues.allSatisfy({ $0.value == nil && $0.target == nil }) else {
            return false
        }
        return reference.subscriptions.allSatisfy(isSideEffectFreeReference)
    }

    private static func isUnsafeLocalControlHost(_ host: String?) -> Bool {
        guard var normalized = host?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(), !normalized.isEmpty else {
            return false
        }
        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        while normalized.hasSuffix(".") {
            normalized.removeLast()
        }
        if normalized == "localhost" || normalized.hasSuffix(".localhost") {
            return true
        }
        // Scoped IPv6 literals are host-local by definition and must not be
        // selected by an untrusted portable configuration.
        if normalized.contains("%") {
            return true
        }

#if canImport(Darwin)
        if normalized.contains(":") {
            var address = in6_addr()
            let parsed = normalized.withCString { inet_pton(AF_INET6, $0, &address) }
            if parsed == 1 {
                let bytes = withUnsafeBytes(of: &address) { Array($0) }
                if bytes.allSatisfy({ $0 == 0 }) {
                    return true
                }
                if bytes.dropLast().allSatisfy({ $0 == 0 }), bytes.last == 1 {
                    return true
                }
                if bytes.prefix(10).allSatisfy({ $0 == 0 }),
                   bytes[10] == 0xff, bytes[11] == 0xff {
                    let ipv4 = (UInt32(bytes[12]) << 24)
                        | (UInt32(bytes[13]) << 16)
                        | (UInt32(bytes[14]) << 8)
                        | UInt32(bytes[15])
                    return isUnsafeIPv4(ipv4)
                }
                return false
            }
            // A numeric-looking IPv6 literal that the platform parser cannot
            // canonicalize is rejected rather than delegated to DNS.
            let numericIPv6Characters = CharacterSet(charactersIn: "0123456789abcdef:.")
            if normalized.unicodeScalars.allSatisfy(numericIPv6Characters.contains) {
                return true
            }
        }
#endif

#if canImport(Darwin)
        if !normalized.contains(":") {
            var address = in_addr()
            if inet_aton(normalized, &address) == 1 {
                return isUnsafeIPv4(UInt32(bigEndian: address.s_addr))
            }
        }
#endif

        let ipv4Fields = normalized.split(separator: ".", omittingEmptySubsequences: false)
        let looksDecimalIPv4 = normalized.unicodeScalars.allSatisfy(
            CharacterSet(charactersIn: "0123456789.").contains
        )
        if looksDecimalIPv4 {
            if ipv4Fields.contains(where: { $0.count > 1 && $0.first == "0" }) {
                return true
            }
            if let ipv4 = parseIPv4(normalized) {
                return isUnsafeIPv4(ipv4)
            }
            // Reject invalid/overflowing numeric forms (including legacy
            // single-component octal) instead of allowing resolver reinterpretation.
            return true
        }
        if ipv4Fields.contains(where: { $0.lowercased().hasPrefix("0x") }) {
            return true
        }
        if let ipv4 = parseIPv4(normalized) {
            return isUnsafeIPv4(ipv4)
        }
        return false
    }

    private static func isUnsafeIPv4(_ address: UInt32) -> Bool {
        let firstOctet = address >> 24
        return firstOctet == 0 || firstOctet == 127
    }

    private static func parseIPv4(_ host: String) -> UInt32? {
        let fields = host.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(fields.count) else { return nil }
        let values = fields.compactMap { UInt64($0, radix: 10) }
        guard values.count == fields.count else { return nil }

        let value: UInt64
        switch values.count {
        case 1:
            guard values[0] <= 0xffff_ffff else { return nil }
            value = values[0]
        case 2:
            guard values[0] <= 0xff, values[1] <= 0xff_ffff else { return nil }
            value = (values[0] << 24) | values[1]
        case 3:
            guard values[0] <= 0xff, values[1] <= 0xff, values[2] <= 0xffff else { return nil }
            value = (values[0] << 24) | (values[1] << 16) | values[2]
        case 4:
            guard values.allSatisfy({ $0 <= 0xff }) else { return nil }
            value = (values[0] << 24) | (values[1] << 16) | (values[2] << 8) | values[3]
        default:
            return nil
        }
        return UInt32(value)
    }

    private static func rewriteStringIfEndpointLike(
        _ value: String,
        transform: (String) -> String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        guard lowered.hasPrefix("cell://")
                || lowered.hasPrefix("ws://")
                || lowered.hasPrefix("wss://") else {
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
