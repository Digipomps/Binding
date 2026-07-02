import Foundation
@preconcurrency import CellBase
import CellVapor
import HavenAgentRuntime
import HavenRuntimeBootstrap
@preconcurrency import Vapor

private struct AgentControlBridgeRoutes: RouteCollection {
    let owner: Identity
    let routeLookup: [String: LocalControlBridgeRoute]
    let onboardingContext: AgentControlBridgeOnboardingContext?
    let expectedAccessToken: String?
    let mailDraftCommandHandler: (@Sendable (AgentMailDraftCommandRequest) async throws -> AgentMailDraftCommandResult)?
    let signStatementCommandHandler: (@Sendable (AgentSignStatementRequest) async throws -> AgentSignStatementResult)?
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

        routes.get("onboard") { req async throws -> Response in
            try authorize(req)
            _ = try requireOnboardingContext()
            let html = try AgentOnboardingAssetLoader.loadIndexHTML()
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "text/html; charset=utf-8")
            headers.add(name: "cache-control", value: "no-store")
            return Response(status: .ok, headers: headers, body: .init(string: html))
        }

        routes.get("onboard", "status.json") { req async throws -> Response in
            try authorize(req)
            let context = try requireOnboardingContext()
            let report = await AgentOnboardingStatusBuilder(
                paths: context.paths,
                configURL: context.configURL,
                owner: owner,
                routes: routeLookup.values.sorted { $0.name < $1.name },
                runtimeSnapshot: await context.runtimeSnapshotProvider()
            ).build()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json; charset=utf-8")
            headers.add(name: "cache-control", value: "no-store")
            return Response(status: .ok, headers: headers, body: .init(data: data))
        }

        routes.post("commands", "mail", "compose-draft") { req async throws -> Response in
            try authorize(req)
            guard let mailDraftCommandHandler else {
                throw Abort(.notFound, reason: "Mail draft command handler is not configured.")
            }
            let request = try req.content.decode(AgentMailDraftCommandRequest.self)
            let result = try await mailDraftCommandHandler(request)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(result)
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json; charset=utf-8")
            headers.add(name: "cache-control", value: "no-store")
            return Response(status: .ok, headers: headers, body: .init(data: data))
        }

        routes.post("commands", "identity", "sign-statement") { req async throws -> Response in
            try authorize(req)
            guard let signStatementCommandHandler else {
                throw Abort(.notFound, reason: "Identity sign-statement command handler is not configured.")
            }
            let request = try req.content.decode(AgentSignStatementRequest.self)
            let result = try await signStatementCommandHandler(request)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(result)
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json; charset=utf-8")
            headers.add(name: "cache-control", value: "no-store")
            return Response(status: .ok, headers: headers, body: .init(data: data))
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

    private func requireOnboardingContext() throws -> AgentControlBridgeOnboardingContext {
        guard let onboardingContext else {
            throw Abort(.notFound, reason: "Onboarding surface is not configured.")
        }
        return onboardingContext
    }
}

struct AgentControlBridgeOnboardingContext {
    var paths: RuntimePaths
    var configURL: URL
    var runtimeSnapshotProvider: @Sendable () async -> AgentCellRuntimeSnapshot?
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
        configuration: LocalControlBridgeConfig,
        paths: RuntimePaths? = nil,
        configURL: URL? = nil,
        mailDraftCommandHandler: (@Sendable (AgentMailDraftCommandRequest) async throws -> AgentMailDraftCommandResult)? = nil,
        signStatementCommandHandler: (@Sendable (AgentSignStatementRequest) async throws -> AgentSignStatementResult)? = nil,
        runtimeSnapshotProvider: (@Sendable () async -> AgentCellRuntimeSnapshot?)? = nil
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
            onboardingContext: paths.map { paths in
                AgentControlBridgeOnboardingContext(
                    paths: paths,
                    configURL: (configURL ?? paths.configFile).standardizedFileURL,
                    runtimeSnapshotProvider: runtimeSnapshotProvider ?? { nil }
                )
            },
            expectedAccessToken: configuration.accessToken,
            mailDraftCommandHandler: mailDraftCommandHandler,
            signStatementCommandHandler: signStatementCommandHandler,
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
