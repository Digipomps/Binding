// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Vapor
@preconcurrency import CellBase

public enum AdminControlPlaneMode: String, Codable, Sendable {
    case localWorkbench = "local_workbench"
    case remoteAdminScaffold = "remote_admin_scaffold"
}

public enum AdminControlPlaneConfigurationError: Error, LocalizedError, Equatable {
    case invalidMode(String)
    case localWorkbenchNotAllowedInProduction
    case invalidWebSocketEndpoint(String)
    case missingPublicOrigin
    case invalidPublicOrigin(String)
    case missingBridgeClientCredential
    case invalidBridgeClientCredential
    case legacyBridgeConfiguration(String)
    case invalidConnectionSharing(String)

    public var errorDescription: String? {
        switch self {
        case .invalidMode(let value):
            return "Invalid ADMIN_CONTROL_PLANE_MODE: \(value)"
        case .localWorkbenchNotAllowedInProduction:
            return "ADMIN_CONTROL_PLANE_MODE=local_workbench is not allowed in production. Configure a remote AdminScaffold."
        case .invalidWebSocketEndpoint(let value):
            return "Invalid ADMIN_SCAFFOLD_WEBSOCKET_ENDPOINT: \(value)"
        case .missingPublicOrigin:
            return "ADMIN_SCAFFOLD_PUBLIC_ORIGIN is required for a remote AdminScaffold."
        case .invalidPublicOrigin(let value):
            return "Invalid ADMIN_SCAFFOLD_PUBLIC_ORIGIN: \(value)"
        case .missingBridgeClientCredential:
            return "ADMIN_SCAFFOLD_BRIDGE_CLIENT_CREDENTIAL_PATH is required in production and must contain haven.admin.bridge.client-credential.v1."
        case .invalidBridgeClientCredential:
            return "AdminScaffold bridge client credential is invalid."
        case .legacyBridgeConfiguration(let key):
            return "Legacy AdminScaffold bridge configuration is forbidden: \(key)"
        case .invalidConnectionSharing(let value):
            return "Invalid ADMIN_SCAFFOLD_BRIDGE_CONNECTION_SHARING: \(value). Use dedicated or multiplexed_v2."
        }
    }
}

public struct AdminControlPlaneRouting: Sendable, Equatable {
    public enum WebSocketScheme: String, Sendable {
        case ws
        case wss
    }

    public let mode: AdminControlPlaneMode
    public let host: String?
    public let port: Int?
    public let websocketEndpoint: String
    public let websocketScheme: WebSocketScheme
    public let bridgeCredential: AdminBridgeClientCredential?

    /// Opt-in protocol v2 multiplexing towards a remote AdminScaffold. Defaults to
    /// `.dedicated` — one physical WebSocket per remote bridge — because the host
    /// must expose `/<websocketEndpoint>/session` before sharing is safe.
    public let connectionSharing: RemoteCellHostRoute.ConnectionSharing

    public init(
        mode: AdminControlPlaneMode,
        host: String?,
        port: Int?,
        websocketEndpoint: String,
        websocketScheme: WebSocketScheme,
        bridgeCredential: AdminBridgeClientCredential?,
        connectionSharing: RemoteCellHostRoute.ConnectionSharing = .dedicated
    ) {
        self.mode = mode
        self.host = host
        self.port = port
        self.websocketEndpoint = websocketEndpoint
        self.websocketScheme = websocketScheme
        self.bridgeCredential = bridgeCredential
        self.connectionSharing = connectionSharing
    }

    static func connectionSharing(
        from environment: [String: String]
    ) throws -> RemoteCellHostRoute.ConnectionSharing {
        guard let raw = normalized(environment["ADMIN_SCAFFOLD_BRIDGE_CONNECTION_SHARING"])?.lowercased() else {
            return .dedicated
        }
        switch raw.replacingOccurrences(of: "-", with: "_") {
        case "dedicated":
            return .dedicated
        case "multiplexed_v2", "multiplexedv2", "multiplexed":
            return .multiplexedV2
        default:
            throw AdminControlPlaneConfigurationError.invalidConnectionSharing(raw)
        }
    }

    public static func adminScaffoldSurfaceRouting(
        publicOrigin: AdminBridgePublicOrigin,
        websocketEndpoint: String
    ) -> AdminControlPlaneRouting {
        let components = URLComponents(string: publicOrigin.httpsOrigin)
        return AdminControlPlaneRouting(
            mode: .remoteAdminScaffold,
            host: components?.host?.lowercased(),
            port: components?.port,
            websocketEndpoint: websocketEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            websocketScheme: .wss,
            bridgeCredential: nil
        )
    }

    public var registersInfrastructureCellsLocally: Bool {
        mode == .localWorkbench
    }

    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment,
        productionLike: Bool
    ) throws -> AdminControlPlaneRouting {
        let defaultMode: AdminControlPlaneMode = productionLike ? .remoteAdminScaffold : .localWorkbench
        let mode: AdminControlPlaneMode
        if let rawMode = normalized(environment["ADMIN_CONTROL_PLANE_MODE"])?.lowercased() {
            switch rawMode.replacingOccurrences(of: "-", with: "_") {
            case "local", "local_workbench":
                mode = .localWorkbench
            case "remote", "remote_admin_scaffold", "admin_scaffold":
                mode = .remoteAdminScaffold
            default:
                throw AdminControlPlaneConfigurationError.invalidMode(rawMode)
            }
        } else {
            mode = defaultMode
        }

        if productionLike && mode == .localWorkbench {
            throw AdminControlPlaneConfigurationError.localWorkbenchNotAllowedInProduction
        }

        for legacyKey in [
            "ADMIN_SCAFFOLD_HOST",
            "ADMIN_SCAFFOLD_PORT",
            "ADMIN_SCAFFOLD_WEBSOCKET_SCHEME"
        ] where normalized(environment[legacyKey]) != nil {
            throw AdminControlPlaneConfigurationError.legacyBridgeConfiguration(legacyKey)
        }
        let websocketScheme = WebSocketScheme.wss

        let websocketEndpoint = normalized(environment["ADMIN_SCAFFOLD_WEBSOCKET_ENDPOINT"]) ?? "bridgehead"
        guard websocketEndpoint.rangeOfCharacter(from: CharacterSet(charactersIn: "?#")) == nil else {
            throw AdminControlPlaneConfigurationError.invalidWebSocketEndpoint(websocketEndpoint)
        }
        let normalizedEndpoint = websocketEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedEndpoint.isEmpty else {
            throw AdminControlPlaneConfigurationError.invalidWebSocketEndpoint(websocketEndpoint)
        }

        let connectionSharing = try connectionSharing(from: environment)

        guard mode == .remoteAdminScaffold else {
            return AdminControlPlaneRouting(
                mode: mode,
                host: nil,
                port: nil,
                websocketEndpoint: normalizedEndpoint,
                websocketScheme: websocketScheme,
                bridgeCredential: nil,
                connectionSharing: connectionSharing
            )
        }

        guard let rawPublicOrigin = normalized(environment["ADMIN_SCAFFOLD_PUBLIC_ORIGIN"]) else {
            throw AdminControlPlaneConfigurationError.missingPublicOrigin
        }
        let publicOrigin: AdminBridgePublicOrigin
        do {
            publicOrigin = try AdminBridgePublicOrigin(rawPublicOrigin)
        } catch {
            throw AdminControlPlaneConfigurationError.invalidPublicOrigin(rawPublicOrigin)
        }
        guard let components = URLComponents(string: publicOrigin.httpsOrigin),
              let rawHost = components.host else {
            throw AdminControlPlaneConfigurationError.invalidPublicOrigin(rawPublicOrigin)
        }
        let port = components.port

        let bridgeCredential: AdminBridgeClientCredential?
        do {
            bridgeCredential = try AdminSecretMaterial.bridgeClientCredential(
                environment: environment,
                pathKey: "ADMIN_SCAFFOLD_BRIDGE_CLIENT_CREDENTIAL_PATH",
                publicOrigin: publicOrigin
            )
        } catch AdminSecretMaterialError.legacyBridgeConfiguration(let key) {
            throw AdminControlPlaneConfigurationError.legacyBridgeConfiguration(key)
        } catch {
            throw AdminControlPlaneConfigurationError.invalidBridgeClientCredential
        }
        if productionLike && bridgeCredential == nil {
            throw AdminControlPlaneConfigurationError.missingBridgeClientCredential
        }

        return AdminControlPlaneRouting(
            mode: mode,
            host: rawHost.lowercased(),
            port: port,
            websocketEndpoint: normalizedEndpoint,
            websocketScheme: websocketScheme,
            bridgeCredential: bridgeCredential,
            connectionSharing: connectionSharing
        )
    }

    public func endpoint(for cellName: String) -> String {
        let normalizedCellName = cellName.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard mode == .remoteAdminScaffold, let host else {
            return "cell:///\(normalizedCellName)"
        }
        let authority = port.map { "\(host):\($0)" } ?? host
        return "cell://\(authority)/\(normalizedCellName)"
    }

    public func registerRemoteHost(on resolver: CellResolverProtocol) {
        guard mode == .remoteAdminScaffold, let host else { return }
        let schemePreference: RemoteCellHostRoute.SchemePreference = websocketScheme == .wss ? .wss : .ws
        resolver.registerRemoteCellHost(
            host,
            route: RemoteCellHostRoute(
                websocketEndpoint: websocketEndpoint,
                schemePreference: schemePreference,
                connectionSharing: connectionSharing
            )
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum AdminControlPlaneRuntime {
    static let lock = NSLock()
    static var routing = AdminControlPlaneRouting(
        mode: .localWorkbench,
        host: nil,
        port: nil,
        websocketEndpoint: "bridgehead",
        websocketScheme: .wss,
        bridgeCredential: nil
    )

    static func configure(_ value: AdminControlPlaneRouting) {
        lock.lock()
        routing = value
        lock.unlock()
    }

    static func current() -> AdminControlPlaneRouting {
        lock.lock()
        let value = routing
        lock.unlock()
        return value
    }
}

public extension AdminControlPlaneRouting {
    static var current: AdminControlPlaneRouting {
        AdminControlPlaneRuntime.current()
    }

    static func configureCurrent(_ routing: AdminControlPlaneRouting) {
        AdminControlPlaneRuntime.configure(routing)
        AdminBridgeClientCredential.configureCurrent(routing.bridgeCredential)
    }
}

public extension Application {
    private struct AdminControlPlaneRoutingKey: StorageKey {
        typealias Value = AdminControlPlaneRouting
    }

    var adminControlPlaneRouting: AdminControlPlaneRouting {
        get { storage[AdminControlPlaneRoutingKey.self] ?? .current }
        set { storage[AdminControlPlaneRoutingKey.self] = newValue }
    }
}
