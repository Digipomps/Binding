import Foundation
import CellBase

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

        components.host = nil
        components.port = nil
        components.path = "/" + normalizedPath
        return components.string ?? endpoint
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
        let isLocal = host == nil || host?.isEmpty == true || host?.lowercased() == "localhost"
        guard isLocal else { return endpoint }

        components.host = origin.host
        components.port = origin.port
        components.path = "/" + normalizedPath
        return components.string ?? endpoint
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
