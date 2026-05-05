import Foundation
@preconcurrency import CellBase
import CellVapor
import HavenAgentRuntime
@preconcurrency import Vapor

private struct AgentControlBridgeRoutes: RouteCollection {
    let owner: Identity
    let routeLookup: [String: LocalControlBridgeRoute]
    let expectedAccessToken: String?
    let trackWebSocket: @Sendable (WebSocket) async -> Void
    let untrackWebSocket: @Sendable (WebSocket) async -> Void

    private func authorize(_ req: Request) throws {
        guard let expectedAccessToken,
              expectedAccessToken.isEmpty == false else {
            return
        }
        let providedAccessToken = req.query[String.self, at: "token"] ?? ""
        guard providedAccessToken == expectedAccessToken else {
            throw Abort(.unauthorized, reason: "Local control bridge token missing or invalid.")
        }
    }

    func boot(routes: RoutesBuilder) throws {
        routes.get("health") { req async throws -> HTTPStatus in
            try authorize(req)
            return .ok
        }

        let bridgehead = routes.grouped("bridgehead")
        bridgehead.webSocket(":routeName", ":bridgeId") { req, ws async in
            do {
                try authorize(req)
                await trackWebSocket(ws)
                ws.onClose.whenComplete { _ in
                    Task {
                        await untrackWebSocket(ws)
                    }
                }
                let routeName = try req.parameters.require("routeName")
                guard let route = routeLookup[routeName] else {
                    throw Abort(.forbidden, reason: "Route is not allowlisted for the local control bridge.")
                }
                let bridgeID = try req.parameters.require("bridgeId")
                let transport = VaporBridgeTransport(webSocket: ws)
                let config = BridgeBase.Config(
                    owner: owner,
                    contractTemplate: await Agreement(),
                    transport: transport,
                    connection: .inbound(publisherUuid: route.targetCellReference)
                )
                let bridge = try await BridgeBase(config)
                try await bridge.setTransport(
                    transport,
                    connection: .inbound(publisherUuid: route.targetCellReference)
                )
                guard let resolver = CellBase.defaultCellResolver else {
                    throw Abort(.internalServerError, reason: "Cell resolver unavailable")
                }
                try await resolver.registerNamedEmitCell(
                    name: bridgeID,
                    emitCell: bridge,
                    scope: .template,
                    identity: owner
                )
                let readyCommand = BridgeCommand(
                    cmd: "ready",
                    payload: .string("local-control-bridge"),
                    cid: 0
                )
                let readyData = try JSONEncoder().encode(readyCommand)
                await transport.sendData(readyData)
            } catch {
                req.logger.error("Local control bridge upgrade failed: \(error.localizedDescription)")
                try? await ws.close(code: .policyViolation)
            }
        }
    }
}

enum AgentControlBridgeServerError: Error, LocalizedError {
    case nonLoopbackHost(String)

    var errorDescription: String? {
        switch self {
        case .nonLoopbackHost(let host):
            return "Local control bridge host '\(host)' is not loopback-only."
        }
    }
}

public actor AgentControlBridgeServer {
    private var application: Application?
    private var status: LocalControlBridgeStatus?
    private var activeWebSockets: [ObjectIdentifier: WebSocket] = [:]

    public init() {}

    public func start(
        owner: Identity,
        configuration: LocalControlBridgeConfig
    ) async throws -> LocalControlBridgeStatus {
        guard configuration.enabled else {
            let disabled = LocalControlBridgeStatus(configuration: configuration, phase: .disabled)
            status = disabled
            return disabled
        }
        guard configuration.loopbackOnly else {
            let error = AgentControlBridgeServerError.nonLoopbackHost(configuration.host)
            let failed = LocalControlBridgeStatus(
                configuration: configuration,
                phase: .failed,
                lastError: error.localizedDescription
            )
            status = failed
            throw error
        }

        await stop()

        let app = try await Application.make(.production)
        app.http.server.configuration.hostname = configuration.host
        app.http.server.configuration.port = configuration.port

        let routes = AgentControlBridgeRoutes(
            owner: owner,
            routeLookup: Dictionary(uniqueKeysWithValues: configuration.routes.map { ($0.name, $0) }),
            expectedAccessToken: configuration.accessToken,
            trackWebSocket: { [weak self] webSocket in
                await self?.track(webSocket: webSocket)
            },
            untrackWebSocket: { [weak self] webSocket in
                await self?.untrack(webSocket: webSocket)
            }
        )
        try app.register(collection: routes)

        do {
            try await app.asyncBoot()
            try await app.http.server.shared.start(address: nil)
            application = app
            let running = LocalControlBridgeStatus(configuration: configuration, phase: .running)
            status = running
            return running
        } catch {
            let failed = LocalControlBridgeStatus(
                configuration: configuration,
                phase: .failed,
                lastError: error.localizedDescription
            )
            status = failed
            try? await app.asyncShutdown()
            throw error
        }
    }

    public func stop() async {
        guard let application else {
            if let status, status.phase == .running {
                self.status = LocalControlBridgeStatus(
                    phase: .stopped,
                    host: status.host,
                    port: status.port,
                    websocketBaseURL: status.websocketBaseURL,
                    routes: status.routes,
                    lastError: status.lastError
                )
            }
            return
        }

        let webSockets = Array(activeWebSockets.values)
        activeWebSockets.removeAll()
        for webSocket in webSockets {
            try? await webSocket.close()
        }

        await application.http.server.shared.shutdown()
        try? await application.asyncShutdown()
        self.application = nil

        if let status {
            self.status = LocalControlBridgeStatus(
                phase: .stopped,
                host: status.host,
                port: status.port,
                websocketBaseURL: status.websocketBaseURL,
                routes: status.routes,
                lastError: status.lastError
            )
        }
    }

    public func snapshot() -> LocalControlBridgeStatus? {
        status
    }

    private func track(webSocket: WebSocket) {
        activeWebSockets[ObjectIdentifier(webSocket)] = webSocket
    }

    private func untrack(webSocket: WebSocket) {
        activeWebSockets.removeValue(forKey: ObjectIdentifier(webSocket))
    }
}
