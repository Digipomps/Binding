import Foundation
@preconcurrency import CellBase

enum RemoteEndpointAuthorizationKind: Equatable {
    case none
    case scaffoldAdmission
    case liveControlAgreement
}

enum RemoteEndpointAccessSupport {
    static let stagingHost = "staging.haven.digipomps.org"
    static let localCatalogEndpoint = "cell:///ConfigurationCatalog"

    private static let defaultRemoteRoute = RemoteCellHostRoute(
        websocketEndpoint: "publishersws",
        schemePreference: .automatic
    )
    private static let stagingRemoteRoute = RemoteCellHostRoute(
        websocketEndpoint: "bridgehead",
        schemePreference: .wss
    )

    enum AccessError: Error, LocalizedError {
        case endpointDoesNotExposeMeddle(String)
        case contractRejected(String, String)

        var errorDescription: String? {
            switch self {
            case .endpointDoesNotExposeMeddle(let endpoint):
                return "Endpoint \(endpoint) does not expose a Meddle interface."
            case .contractRejected(let endpoint, let state):
                return "Endpoint \(endpoint) rejected the access contract (\(state))."
            }
        }
    }

    static func authorizationKind(for endpoint: String) -> RemoteEndpointAuthorizationKind {
        if isLiveControlBridgeEndpoint(endpoint) {
            return .liveControlAgreement
        }
        if shouldAttemptScaffoldAdmission(for: endpoint) {
            return .scaffoldAdmission
        }
        return .none
    }

    static func shouldAttemptScaffoldAdmission(for endpoint: String) -> Bool {
        guard !RemoteCatalogSupport.isLocalCatalogEndpoint(endpoint) else { return false }
        guard let origin = remoteOrigin(from: endpoint) else { return false }
        return !isLoopbackHost(origin.host)
    }

    static func registerRemoteRouteIfNeeded(for endpoint: String, resolver: CellResolver) {
        guard let origin = routeRegistrationOrigin(from: endpoint) else { return }
        let host = origin.host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty else { return }

        let snapshot = resolver.remoteCellHostRoutesSnapshot()
        if let existing = snapshot[host], routesMatch(existing, origin.route) {
            return
        }

        resolver.registerRemoteCellHost(host, route: origin.route)
    }

    static func resolveEmit(
        endpoint: String,
        resolver: CellResolver,
        requester: Identity,
        accessLabel: String
    ) async throws -> Emit {
        registerRemoteRouteIfNeeded(for: endpoint, resolver: resolver)
        let emit = try await resolver.cellAtEndpoint(endpoint: endpoint, requester: requester)
        try await authorizeIfNeeded(
            endpoint: endpoint,
            emit: emit,
            requester: requester,
            accessLabel: accessLabel
        )
        return emit
    }

    static func resolveMeddle(
        endpoint: String,
        resolver: CellResolver,
        requester: Identity,
        accessLabel: String
    ) async throws -> Meddle {
        let emit = try await resolveEmit(
            endpoint: endpoint,
            resolver: resolver,
            requester: requester,
            accessLabel: accessLabel
        )
        guard let meddle = emit as? Meddle else {
            throw AccessError.endpointDoesNotExposeMeddle(endpoint)
        }
        return meddle
    }

    static func authorizeIfNeeded(
        endpoint: String,
        emit: Emit,
        requester: Identity,
        accessLabel: String
    ) async throws {
        try await RemoteEndpointAccessAuthorizer.shared.authorizeIfNeeded(
            endpoint: endpoint,
            emit: emit,
            requester: requester,
            accessLabel: accessLabel,
            kind: authorizationKind(for: endpoint)
        )
    }

    static func endpointIdentity(_ endpoint: String) -> String {
        endpoint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isLiveControlBridgeEndpoint(_ endpoint: String) -> Bool {
        guard let components = URLComponents(string: endpoint),
              let scheme = components.scheme?.lowercased(),
              ["ws", "wss", "cell"].contains(scheme),
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              isLoopbackHost(host)
        else {
            return false
        }

        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return normalizedPath == "bridgehead" || normalizedPath.hasPrefix("bridgehead/")
    }

    private static func isLoopbackHost(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "localhost" || normalized == "127.0.0.1"
    }

    private static func routeRegistrationOrigin(from endpoint: String) -> RemoteOrigin? {
        guard let origin = remoteOrigin(from: endpoint) else { return nil }
        guard let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell",
              !isLoopbackHost(origin.host)
        else {
            return nil
        }
        return origin
    }

    private static func remoteOrigin(from endpoint: String) -> RemoteOrigin? {
        guard let components = URLComponents(string: endpoint),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty
        else {
            return nil
        }

        switch scheme {
        case "cell":
            return RemoteOrigin(host: host, route: route(forHost: host))
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
            return RemoteOrigin(
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

    private struct RemoteOrigin {
        let host: String
        let route: RemoteCellHostRoute
    }
}

final class RemoteEndpointAccessAuthorizer {
    static let shared = RemoteEndpointAccessAuthorizer()

    private let stateQueue = DispatchQueue(label: "RemoteEndpointAccessAuthorizer.state")
    private var scaffoldAdmissionKeys: Set<String> = []
    private var liveControlKeys: Set<String> = []

    private init() {}

    func authorizeIfNeeded(
        endpoint: String,
        emit: Emit,
        requester: Identity,
        accessLabel: String,
        kind: RemoteEndpointAuthorizationKind
    ) async throws {
        switch kind {
        case .none:
            return
        case .scaffoldAdmission:
            let cacheKey = authorizationCacheKey(endpoint: endpoint, requester: requester)
            if stateQueue.sync(execute: { scaffoldAdmissionKeys.contains(cacheKey) }) {
                return
            }

            let connector = await GeneralCell(owner: requester)
            connector.doneInitializing()
            let connectState = try await connector.attach(
                emitter: emit,
                label: accessLabel,
                requester: requester
            )
            guard connectState == .connected else {
                throw RemoteEndpointAccessSupport.AccessError.contractRejected(endpoint, connectState.rawValue)
            }

            stateQueue.sync {
                scaffoldAdmissionKeys.insert(cacheKey)
            }
        case .liveControlAgreement:
            let cacheKey = authorizationCacheKey(endpoint: endpoint, requester: requester)
            if stateQueue.sync(execute: { liveControlKeys.contains(cacheKey) }) {
                return
            }

            try await LiveControlBridgeAuthorization.authorizeIfNeeded(emit, requester: requester)

            stateQueue.sync {
                liveControlKeys.insert(cacheKey)
            }
        }
    }

    private func authorizationCacheKey(endpoint: String, requester: Identity) -> String {
        "\(RemoteEndpointAccessSupport.endpointIdentity(endpoint))|\(requester.uuid.lowercased())"
    }
}

enum RemoteCatalogSupport {
    static let stagingHost = RemoteEndpointAccessSupport.stagingHost

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

        if !seen.contains(RemoteEndpointAccessSupport.localCatalogEndpoint.lowercased()) {
            localCandidates.append(RemoteEndpointAccessSupport.localCatalogEndpoint)
        }

        return remoteCandidates + localCandidates
    }

    static func shouldSyncCatalogBeforeQuery(for endpoint: String) -> Bool {
        isLocalCatalogEndpoint(endpoint)
    }

    static func shouldAttemptAdmission(for endpoint: String) -> Bool {
        RemoteEndpointAccessSupport.shouldAttemptScaffoldAdmission(for: endpoint)
    }

    static func registerRemoteRouteIfNeeded(for endpoint: String, resolver: CellResolver) {
        RemoteEndpointAccessSupport.registerRemoteRouteIfNeeded(for: endpoint, resolver: resolver)
    }

    static func isLocalCatalogEndpoint(_ endpoint: String) -> Bool {
        guard let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell"
        else {
            return false
        }

        let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return host.isEmpty && path == "configurationcatalog"
    }
}
