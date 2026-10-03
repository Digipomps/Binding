// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Vapor
import CellBase
import CellVapor

private actor AdminScaffoldBridgeConnectionRegistry {
    private var activeBridgeIDs = Set<String>()

    func reserve(bridgeID: String, maximum: Int) -> Bool {
        guard activeBridgeIDs.count < maximum else {
            return false
        }
        return activeBridgeIDs.insert(bridgeID).inserted
    }

    func release(bridgeID: String) {
        activeBridgeIDs.remove(bridgeID)
    }
}

/// Tracks the physical multiplex sessions this process has accepted, and the
/// per-channel Cells each session registered. The session is retained here so a
/// closed WebSocket can tear down every logical channel it carried, not just the
/// session delegate the transport happens to know about.
private actor AdminScaffoldMultiplexSessionRegistry {
    private var activeSessionIDs = Set<String>()
    private var sessions: [String: BridgeMultiplexServerSession] = [:]
    private var channelCellUUIDs: [String: Set<String>] = [:]

    func reserve(sessionID: String, maximum: Int) -> Bool {
        guard activeSessionIDs.count < maximum else {
            return false
        }
        return activeSessionIDs.insert(sessionID).inserted
    }

    func attach(_ session: BridgeMultiplexServerSession, to sessionID: String) {
        guard activeSessionIDs.contains(sessionID) else { return }
        sessions[sessionID] = session
    }

    func noteChannelCell(uuid: String, sessionID: String) -> Bool {
        guard activeSessionIDs.contains(sessionID) else { return false }
        channelCellUUIDs[sessionID, default: []].insert(uuid)
        return true
    }

    func release(sessionID: String) -> (session: BridgeMultiplexServerSession?, channelCellUUIDs: Set<String>) {
        activeSessionIDs.remove(sessionID)
        let session = sessions.removeValue(forKey: sessionID)
        let uuids = channelCellUUIDs.removeValue(forKey: sessionID) ?? []
        return (session, uuids)
    }

    func activeSessionCount() -> Int {
        activeSessionIDs.count
    }
}

public enum AdminScaffoldPublishedSurfacePolicy {
    public static let allowedCellNames: Set<String> = [
        "AdminEntry",
        "AdminAccessRequests",
        "AdminResolverStats",
        "AdminStorageStats",
        "AdminHostMetrics",
        "AdminMetricsHistory",
        "AdminCellLifecycle",
        "AdminProcesses",
        "AdminOverview",
        "AdminNodeFleet",
        "AdminDeploymentSupervisor",
        "AdminRoleEnrollment",
        "AdminSecurityPolicy"
    ]
}

struct AdminScaffoldBridgeRoutes: RouteCollection {
    static let allowedCellNames = AdminScaffoldPublishedSurfacePolicy.allowedCellNames

    private let websocketEndpointComponents: [String]
    private let connections = AdminScaffoldBridgeConnectionRegistry()
    private let multiplexSessions = AdminScaffoldMultiplexSessionRegistry()

    /// Ceiling on logical channels per physical session. Kept below the
    /// CellProtocol default (128) so one client cannot exhaust the host by
    /// opening channels on a single socket.
    static let maximumMultiplexChannelsPerSession = 64

    init(configuration: AdminScaffoldConfiguration) {
        self.websocketEndpointComponents = configuration.websocketEndpointComponents
    }

    func boot(routes: RoutesBuilder) throws {
        routes.get("health", "live") { _ async throws -> Response in
            try jsonResponse(
                status: .ok,
                value: .object([
                    "schemaVersion": .string("admin.scaffold.health.v1"),
                    "status": .string("live"),
                    "service": .string("AdminScaffold")
                ])
            )
        }

        routes.get("health", "startup") { request async throws -> Response in
            let initialized = request.application.adminScaffoldRuntimeContext != nil
                && CellBase.defaultCellResolver != nil
                && CellBase.defaultIdentityVault != nil
            return try jsonResponse(
                status: initialized ? .ok : .serviceUnavailable,
                value: .object([
                    "schemaVersion": .string("admin.scaffold.health.v1"),
                    "status": .string(initialized ? "started" : "not_started"),
                    "service": .string("AdminScaffold")
                ])
            )
        }

        routes.get("health", "build") { _ async throws -> Response in
            let data = try JSONEncoder().encode(BuildInfoService().runtimeInfo())
            return Response(
                status: .ok,
                headers: securityHeaders(contentType: "application/json; charset=utf-8"),
                body: .init(data: data)
            )
        }

        routes.get("health", "ready") { request async throws -> Response in
            guard let context = request.application.adminScaffoldRuntimeContext,
                  CellBase.defaultCellResolver != nil,
                  CellBase.defaultIdentityVault != nil else {
                return try jsonResponse(
                    status: .serviceUnavailable,
                    value: .object([
                        "schemaVersion": .string("admin.scaffold.health.v1"),
                        "status": .string("not_ready"),
                        "reason": .string("runtime_not_initialized")
                    ])
                )
            }

            let store = AdminNodeSnapshotStore.shared.stateObject()
            let activeTrustedKeyCount = integerValue(store["activeTrustedAgentKeyCount"]) ?? 0
            let freshRecordCount = integerValue(store["freshRecordCount"]) ?? 0
            let persistenceReady = stringValue(store["persistenceStatus"]) != "error"
            let keyRegistryReady = !context.configuration.requireTrustedAgentKey || activeTrustedKeyCount > 0
            let snapshotReady = !context.configuration.requireFreshSnapshotForReadiness || freshRecordCount > 0
            let build = BuildInfoService().runtimeInfo()
            let buildMetadataReady = !context.configuration.requireBuildMetadata
                || (build.app_revision != "unknown" && build.build_timestamp != "unknown")
            let publicOriginReady = !context.configuration.requirePublicOriginAuthority
                || AdminBridgePublicOrigin.normalizedAuthority(
                    fromHostHeader: request.headers.first(name: .host)
                ) == context.configuration.publicOrigin.authority
            let snapshotAgeSeconds = latestSnapshotTimestamp(in: store, key: "observedAt")
                .map { max(0, Date().timeIntervalSince1970 - $0) }
            let ready = keyRegistryReady
                && snapshotReady
                && persistenceReady
                && buildMetadataReady
                && publicOriginReady
            let reasons: [ValueType] = [
                keyRegistryReady ? nil : .string("trusted_agent_key_registry_empty"),
                snapshotReady ? nil : .string("no_fresh_node_snapshot"),
                persistenceReady ? nil : .string("snapshot_store_persistence_error"),
                buildMetadataReady ? nil : .string("build_metadata_missing"),
                publicOriginReady ? nil : .string("public_origin_mismatch")
            ].compactMap { $0 }
            return try jsonResponse(
                status: ready ? .ok : .serviceUnavailable,
                value: .object([
                    "schemaVersion": .string("admin.scaffold.health.v1"),
                    "status": .string(ready ? "ready" : "not_ready"),
                    "service": .string("AdminScaffold"),
                    "controlPlaneProfile": .string("dedicated"),
                    "trustedAgentKeyPolicy": .string(context.configuration.requireTrustedAgentKey ? "required" : "optional"),
                    "activeTrustedAgentKeyCount": .integer(activeTrustedKeyCount),
                    "freshSnapshotPolicy": .string(context.configuration.requireFreshSnapshotForReadiness ? "required" : "optional"),
                    "freshRecordCount": .integer(freshRecordCount),
                    "buildMetadataReady": .bool(buildMetadataReady),
                    "snapshotAgeSeconds": snapshotAgeSeconds.map(ValueType.float) ?? .null,
                    "publicOriginReady": .bool(publicOriginReady),
                    "persistenceStatus": store["persistenceStatus"] ?? .string("unknown"),
                    "reasons": .list(reasons)
                ])
            )
        }

        // Deliberately excluded from the public nginx allowlist. This bounded,
        // bearer-protected view lets an isolated restore drill prove that the
        // owner, trust registry, revocation ledger and snapshot store loaded.
        routes.get("health", "restore-audit") { request async throws -> Response in
            guard let context = request.application.adminScaffoldRuntimeContext else {
                throw Abort(.serviceUnavailable)
            }
            guard metricsRequestIsAuthorized(request, expectedToken: context.configuration.metricsBearerToken) else {
                var headers = HTTPHeaders()
                headers.replaceOrAdd(name: .wwwAuthenticate, value: "Bearer")
                headers.replaceOrAdd(name: .cacheControl, value: "no-store")
                return Response(status: .unauthorized, headers: headers)
            }
            let store = AdminNodeSnapshotStore.shared.stateObject()
            guard let ownerSigningKeyFingerprint = Self.deploymentOwnerSigningKeyFingerprint(
                from: context.owner.signingPublicKeyFingerprint
            ) else {
                throw Abort(.serviceUnavailable)
            }
            return try jsonResponse(
                status: .ok,
                value: .object([
                    "schemaVersion": .string("haven.admin.restore-audit.v1"),
                    "ownerUUID": .string(context.owner.uuid),
                    "ownerSigningKeyFingerprint": .string(ownerSigningKeyFingerprint),
                    "activeTrustedAgentKeyCount": .integer(integerValue(store["activeTrustedAgentKeyCount"]) ?? 0),
                    "revokedCredentialCount": .integer(AdminCredentialRuntimeInventory.shared.revokedCount()),
                    "latestSnapshotAcceptedAt": latestSnapshotTimestamp(in: store, key: "acceptedAt").map(ValueType.float) ?? .null,
                    "persistenceStatus": store["persistenceStatus"] ?? .string("unknown")
                ])
            )
        }

        routes.get("metrics") { request async throws -> Response in
            guard let context = request.application.adminScaffoldRuntimeContext else {
                throw Abort(.serviceUnavailable)
            }
            guard metricsRequestIsAuthorized(request, expectedToken: context.configuration.metricsBearerToken) else {
                var headers = HTTPHeaders()
                headers.replaceOrAdd(name: .wwwAuthenticate, value: "Bearer")
                headers.replaceOrAdd(name: .cacheControl, value: "no-store")
                return Response(status: .unauthorized, headers: headers)
            }
            let body = await context.operations.metrics.prometheus(
                storeState: AdminNodeSnapshotStore.shared.stateObject(),
                configuration: context.configuration,
                credentialsExpiring: AdminCredentialRuntimeInventory.shared.expiringCount()
            )
            var headers = securityHeaders(contentType: "text/plain; version=0.0.4; charset=utf-8")
            return Response(status: .ok, headers: headers, body: .init(string: body))
        }

        routes.post("v1", "node-snapshots") { request async throws -> Response in
            guard let context = request.application.adminScaffoldRuntimeContext else {
                throw Abort(.serviceUnavailable, reason: "AdminScaffold runtime is unavailable")
            }
            let requestAllowed = await context.operations.limiter.allow(
                key: context.operations.sourceKey(for: request, purpose: "snapshot"),
                limit: context.configuration.maximumSnapshotRequestsPerMinute
            )
            guard requestAllowed else {
                await context.operations.metrics.recordSnapshotRateLimited()
                var response = try jsonResponse(
                    status: .tooManyRequests,
                    value: .object([
                        "schemaVersion": .string(AdminNodeSnapshotStore.schemaVersion),
                        "status": .string("rejected"),
                        "reason": .string("request_rate_limit_exceeded")
                    ])
                )
                response.headers.replaceOrAdd(name: .retryAfter, value: "60")
                return response
            }
            guard request.headers.first(name: .contentType)?
                .lowercased()
                .hasPrefix("application/json") == true else {
                throw Abort(.unsupportedMediaType, reason: "application/json is required")
            }
            guard var body = request.body.data else {
                throw Abort(.badRequest, reason: "Snapshot envelope body is required")
            }
            guard body.readableBytes <= context.configuration.maximumSnapshotBodyBytes else {
                throw Abort(.payloadTooLarge, reason: "Snapshot envelope exceeds configured limit")
            }
            guard let data = body.readData(length: body.readableBytes) else {
                throw Abort(.badRequest, reason: "Snapshot envelope body is unreadable")
            }

            let envelope: ValueType
            do {
                envelope = try JSONDecoder().decode(ValueType.self, from: data)
            } catch {
                throw Abort(.badRequest, reason: "Snapshot envelope is not valid CellProtocol JSON")
            }
            let result = AdminNodeSnapshotStore.shared.ingestTrustedRemote(envelopeValue: envelope)
            let accepted = stringValue(result["status"]) == "accepted"
            await context.operations.metrics.recordSnapshot(accepted: accepted)
            var response: Object = [
                "schemaVersion": .string(AdminNodeSnapshotStore.schemaVersion),
                "status": result["status"] ?? .string("rejected")
            ]
            if let acceptedAt = result["acceptedAt"] {
                response["acceptedAt"] = acceptedAt
            }
            if let record = result["record"] {
                response["record"] = record
            }
            if let reason = result["reason"] {
                response["reason"] = reason
            }
            request.logger.log(
                level: accepted ? .info : .warning,
                "NodeAdminAgent snapshot \(accepted ? "accepted" : "rejected")"
            )
            return try jsonResponse(
                status: accepted ? .accepted : .unprocessableEntity,
                value: .object(response)
            )
        }

        let bridgeRoutes = routes.grouped(websocketEndpointComponents.map(PathComponent.constant))

        registerMultiplexSessionRoute(on: bridgeRoutes)

        bridgeRoutes.webSocket(
            [.parameter("cellName"), .parameter("bridgeID")],
            maxFrameSize: 65_536,
            shouldUpgrade: { request async throws -> HTTPHeaders? in
                guard let context = request.application.adminScaffoldRuntimeContext else {
                    return nil
                }
                let allowed = await context.operations.limiter.allow(
                    key: context.operations.sourceKey(for: request, purpose: "bridge"),
                    limit: context.configuration.maximumBridgeHandshakesPerMinute
                )
                guard allowed else {
                    await context.operations.metrics.recordBridgeRateLimited()
                    request.logger.warning("Rejected AdminScaffold bridge handshake: rate limited")
                    return nil
                }
                do {
                    let cellName = try request.parameters.require("cellName")
                    let bridgeID = try request.parameters.require("bridgeID")
                    guard AdminScaffoldPublishedSurfacePolicy.allowedCellNames.contains(cellName), UUID(uuidString: bridgeID) != nil else {
                        throw AdminBridgeHandshakeValidationError.invalidSignature
                    }
                    try await context.operations.handshakeVerifier.validate(request: request)
                    await context.operations.metrics.recordBridgeHandshake(accepted: true)
                    return securityHeaders()
                } catch {
                    await context.operations.metrics.recordBridgeHandshake(accepted: false)
                    request.logger.warning("Rejected AdminScaffold bridge handshake")
                    return nil
                }
            }
        ) { request, webSocket async in
            guard let context = request.application.adminScaffoldRuntimeContext,
                  let resolver = CellBase.defaultCellResolver else {
                try? await webSocket.close(code: .unexpectedServerError)
                return
            }

            do {
                let cellName = try request.parameters.require("cellName")
                let bridgeID = try request.parameters.require("bridgeID")
                guard AdminScaffoldPublishedSurfacePolicy.allowedCellNames.contains(cellName),
                      UUID(uuidString: bridgeID) != nil else {
                    request.logger.warning("Rejected AdminScaffold bridge path")
                    try? await webSocket.close(code: .policyViolation)
                    return
                }
                guard let targetPublisherUUID = await resolver.cellUUID(for: cellName) else {
                    request.logger.error("AdminScaffold bridge target is missing from the validated runtime manifest")
                    try? await webSocket.close(code: .unexpectedServerError)
                    return
                }
                guard await connections.reserve(
                    bridgeID: bridgeID,
                    maximum: context.configuration.maximumBridgeConnections
                ) else {
                    request.logger.warning("Rejected AdminScaffold bridge because the connection limit was reached")
                    try? await webSocket.close(code: .policyViolation)
                    return
                }

                webSocket.onClose.whenComplete { _ in
                    Task {
                        await connections.release(bridgeID: bridgeID)
                        await context.operations.metrics.bridgeClosed()
                    }
                }
                await context.operations.metrics.bridgeOpened()

                let transport = VaporBridgeTransport(webSocket: webSocket)
                let bridge = try await BridgeBase(
                    BridgeBase.Config(
                        owner: context.owner,
                        contractTemplate: Agreement(owner: context.owner),
                        identityDomain: "admin-scaffold-bridge:\(bridgeID)",
                        transport: transport,
                        connection: .inbound(publisherUuid: targetPublisherUUID),
                        inboundPublisherLookupIdentity: context.owner
                    )
                )
                try await bridge.setTransport(
                    transport,
                    connection: .inbound(publisherUuid: targetPublisherUUID)
                )
                try await resolver.registerNamedEmitCell(
                    name: "admin-bridge-\(bridgeID)",
                    emitCell: bridge,
                    scope: .template,
                    identity: context.owner
                )
                let ready = BridgeCommand(cmd: "ready", payload: .string(cellName), cid: 0)
                try await transport.sendData(JSONEncoder().encode(ready))
            } catch {
                request.logger.error("AdminScaffold bridge upgrade failed: \(error.localizedDescription)")
                try? await webSocket.close(code: .policyViolation)
            }
        }
    }

    /// Protocol v2 multiplexing: one physical WebSocket carries many logical
    /// bridge channels. The path is `/<websocketEndpoint>/session`, which
    /// `CellResolver.remoteMultiplexSessionURL` builds on the client side.
    ///
    /// The route has one path component after the endpoint prefix, while the
    /// legacy route has two, so the two cannot collide in the router.
    ///
    /// Authorization is split in two: the session handshake proves the caller at
    /// upgrade time, and `channelFactory` decides per logical channel which Cell
    /// the caller may reach. Neither decision lives in the transport.
    private func registerMultiplexSessionRoute(on bridgeRoutes: RoutesBuilder) {
        let registry = multiplexSessions
        let maximumChannels = Self.maximumMultiplexChannelsPerSession

        bridgeRoutes.webSocket(
            "session",
            maxFrameSize: 65_536,
            shouldUpgrade: { request async throws -> HTTPHeaders? in
                guard let context = request.application.adminScaffoldRuntimeContext else {
                    return nil
                }
                let allowed = await context.operations.limiter.allow(
                    key: context.operations.sourceKey(for: request, purpose: "bridge"),
                    limit: context.configuration.maximumBridgeHandshakesPerMinute
                )
                guard allowed else {
                    await context.operations.metrics.recordBridgeRateLimited()
                    request.logger.warning("Rejected AdminScaffold multiplex handshake: rate limited")
                    return nil
                }
                do {
                    try await context.operations.handshakeVerifier.validate(request: request)
                    await context.operations.metrics.recordBridgeHandshake(accepted: true)
                    return securityHeaders()
                } catch {
                    await context.operations.metrics.recordBridgeHandshake(accepted: false)
                    request.logger.warning("Rejected AdminScaffold multiplex handshake")
                    return nil
                }
            }
        ) { request, webSocket async in
            guard let context = request.application.adminScaffoldRuntimeContext,
                  let resolver = CellBase.defaultCellResolver else {
                try? await webSocket.close(code: .unexpectedServerError)
                return
            }

            let sessionID = UUID().uuidString
            guard await registry.reserve(
                sessionID: sessionID,
                maximum: context.configuration.maximumBridgeConnections
            ) else {
                request.logger.warning("Rejected AdminScaffold multiplex session because the connection limit was reached")
                try? await webSocket.close(code: .policyViolation)
                return
            }

            webSocket.onClose.whenComplete { _ in
                Task {
                    let released = await registry.release(sessionID: sessionID)
                    for cellUUID in released.channelCellUUIDs {
                        await resolver.unregisterEmitCell(uuid: cellUUID)
                    }
                    await released.session?.close()
                    await context.operations.metrics.bridgeClosed()
                }
            }
            await context.operations.metrics.bridgeOpened()

            let owner = context.owner
            let transport = VaporBridgeTransport(webSocket: webSocket)
            let session = BridgeMultiplexServerSession(
                physicalTransport: transport,
                maximumChannels: maximumChannels
            ) { targetEndpoint, _, channelTransport in
                guard let cellName = AdminScaffoldBridgeRoutes.publishedCellName(from: targetEndpoint) else {
                    throw Abort(.forbidden, reason: "Requested surface is not published over the AdminScaffold bridge")
                }

                let channelID = UUID().uuidString
                let bridge = try await BridgeBase(
                    BridgeBase.Config(
                        owner: owner,
                        contractTemplate: Agreement(owner: owner),
                        identityDomain: "admin-scaffold-mux:\(sessionID):\(channelID)",
                        transport: channelTransport,
                        connection: .inbound(publisherUuid: cellName),
                        inboundPublisherLookupIdentity: owner
                    )
                )
                try await bridge.setTransport(
                    channelTransport,
                    connection: .inbound(publisherUuid: cellName)
                )
                try await resolver.registerNamedEmitCell(
                    name: "admin-mux-\(sessionID)-\(channelID)",
                    emitCell: bridge,
                    scope: .template,
                    identity: owner
                )
                // If the session was already released the socket is gone, so undo
                // the registration rather than leaking a Cell nothing will close.
                guard await registry.noteChannelCell(uuid: bridge.uuid, sessionID: sessionID) else {
                    await resolver.unregisterEmitCell(uuid: bridge.uuid)
                    throw Abort(.gone, reason: "AdminScaffold multiplex session is no longer active")
                }
                return bridge
            }

            await registry.attach(session, to: sessionID)
        }
    }

    /// Maps a logical `targetEndpoint` from the client onto a published surface.
    /// The client sends the trimmed path of `cell://<host>/<CellName>`, so both
    /// a bare name and a full `cell://` reference must resolve to the same Cell.
    static func publishedCellName(from targetEndpoint: String) -> String? {
        let trimmed = targetEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let candidate: String
        if let url = URL(string: trimmed), url.scheme?.lowercased() == "cell" {
            candidate = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            candidate = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        guard candidate.isEmpty == false,
              candidate.contains("/") == false,
              allowedCellNames.contains(candidate) else {
            return nil
        }
        return candidate
    }

    static func deploymentOwnerSigningKeyFingerprint(from signingPublicKeyFingerprint: String?) -> String? {
        guard let signingPublicKeyFingerprint, signingPublicKeyFingerprint.isEmpty == false else {
            return nil
        }
        return NodeAdminAgentSnapshotTrust.sha256Base64URL(Data(signingPublicKeyFingerprint.utf8))
    }
}

private func jsonResponse(status: HTTPResponseStatus, value: ValueType) throws -> Response {
    let data = try JSONEncoder().encode(value)
    let headers = securityHeaders(contentType: "application/json; charset=utf-8")
    return Response(status: status, headers: headers, body: .init(data: data))
}

private func securityHeaders(contentType: String? = nil) -> HTTPHeaders {
    var headers = HTTPHeaders()
    if let contentType {
        headers.replaceOrAdd(name: .contentType, value: contentType)
    }
    headers.replaceOrAdd(name: .cacheControl, value: "no-store")
    headers.replaceOrAdd(name: "X-Content-Type-Options", value: "nosniff")
    headers.replaceOrAdd(name: "Referrer-Policy", value: "no-referrer")
    headers.replaceOrAdd(name: "Content-Security-Policy", value: "default-src 'none'; frame-ancestors 'none'")
    return headers
}

private func metricsRequestIsAuthorized(_ request: Request, expectedToken: String?) -> Bool {
    guard let expectedToken else { return true }
    guard let authorization = request.headers.bearerAuthorization?.token else { return false }
    let left = Array(expectedToken.utf8)
    let right = Array(authorization.utf8)
    guard left.count == right.count else { return false }
    var difference: UInt8 = 0
    for index in left.indices {
        difference |= left[index] ^ right[index]
    }
    return difference == 0
}

private func stringValue(_ value: ValueType?) -> String? {
    guard case let .string(string)? = value else {
        return nil
    }
    return string
}

private func integerValue(_ value: ValueType?) -> Int? {
    switch value {
    case .integer(let integer), .number(let integer):
        return integer
    case .float(let double):
        return Int(double)
    default:
        return nil
    }
}

private func latestSnapshotTimestamp(in store: Object, key: String) -> Double? {
    guard case let .list(records)? = store["records"] else { return nil }
    return records.compactMap { value -> Double? in
        guard case let .object(record) = value else { return nil }
        switch record[key] {
        case .float(let timestamp)?: return timestamp
        case .integer(let timestamp)?, .number(let timestamp)?: return Double(timestamp)
        default: return nil
        }
    }.max()
}
