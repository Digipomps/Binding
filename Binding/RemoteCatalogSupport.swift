import Foundation
import CellBase

enum RemoteCatalogSupport {
    static let stagingHost = "staging.haven.digipomps.org"
    private static let localCatalogEndpoint = "cell:///ConfigurationCatalog"
    private static let defaultRemoteRoute = RemoteCellHostRoute(
        websocketEndpoint: "publishersws",
        schemePreference: .automatic
    )
    private static let stagingRemoteRoute = RemoteCellHostRoute(
        websocketEndpoint: "bridgehead",
        schemePreference: .wss
    )

    static func orderedCatalogCandidateEndpoints(from endpoints: [String]) -> [String] {
        var seen = Set<String>()
        var remoteCandidates: [String] = []
        var localCandidates: [String] = []

        for endpoint in endpoints.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !endpoint.isEmpty {
            let key = endpoint.lowercased()
            guard seen.insert(key).inserted else { continue }
            if isLocalCatalogEndpoint(endpoint) {
                localCandidates.append(endpoint)
            } else {
                remoteCandidates.append(endpoint)
            }
        }

        if !seen.contains(localCatalogEndpoint.lowercased()) {
            localCandidates.append(localCatalogEndpoint)
        }

        return remoteCandidates + localCandidates
    }

    static func shouldSyncCatalogBeforeQuery(for endpoint: String) -> Bool {
        isLocalCatalogEndpoint(endpoint)
    }

    static func shouldAttemptAdmission(for endpoint: String) -> Bool {
        !isLocalCatalogEndpoint(endpoint) && catalogOrigin(from: endpoint) != nil
    }

    static func registerRemoteRouteIfNeeded(for endpoint: String, resolver: CellResolver) {
        guard let origin = catalogOrigin(from: endpoint) else { return }
        let host = origin.host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty, host != "localhost" else { return }

        let snapshot = resolver.remoteCellHostRoutesSnapshot()
        if let existing = snapshot[host], routesMatch(existing, origin.route) {
            return
        }

        resolver.registerRemoteCellHost(host, route: origin.route)
    }

    private static func isLocalCatalogEndpoint(_ endpoint: String) -> Bool {
        guard let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell"
        else {
            return false
        }

        let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return host.isEmpty && path == "configurationcatalog"
    }

    private static func catalogOrigin(from endpoint: String) -> CatalogOrigin? {
        guard let components = URLComponents(string: endpoint),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty
        else {
            return nil
        }

        switch scheme {
        case "cell":
            return CatalogOrigin(host: host, route: route(forHost: host))
        case "ws", "wss":
            let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let routePath: String
            if normalizedPath.isEmpty {
                routePath = ""
            } else {
                let parts = normalizedPath.split(separator: "/")
                routePath = parts.dropLast().joined(separator: "/")
            }
            let schemePreference: RemoteCellHostRoute.SchemePreference = scheme == "ws" ? .ws : .wss
            return CatalogOrigin(
                host: host,
                route: RemoteCellHostRoute(websocketEndpoint: routePath, schemePreference: schemePreference)
            )
        default:
            return nil
        }
    }

    private static func route(forHost host: String) -> RemoteCellHostRoute {
        if host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == stagingHost {
            return stagingRemoteRoute
        }
        return defaultRemoteRoute
    }

    private static func routesMatch(_ lhs: RemoteCellHostRoute, _ rhs: RemoteCellHostRoute) -> Bool {
        let lhsPath = lhs.websocketEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let rhsPath = rhs.websocketEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        guard lhsPath == rhsPath else { return false }
        return schemePreferenceLabel(lhs.schemePreference) == schemePreferenceLabel(rhs.schemePreference)
    }

    private static func schemePreferenceLabel(_ preference: RemoteCellHostRoute.SchemePreference) -> String {
        switch preference {
        case .automatic: return "automatic"
        case .ws: return "ws"
        case .wss: return "wss"
        }
    }

    private struct CatalogOrigin {
        let host: String
        let route: RemoteCellHostRoute
    }
}
