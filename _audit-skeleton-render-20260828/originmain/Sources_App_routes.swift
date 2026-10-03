// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Vapor
import CellBase

private func safePostLoginPath(_ candidate: String?) -> String? {
    guard let candidate else { return nil }
    let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard trimmed.hasPrefix("/") else { return nil }
    guard !trimmed.hasPrefix("//") else { return nil }
    return trimmed
}

private func canonicalLocalPasskeyLoginRedirect(for req: Request) -> Response? {
    guard !RuntimeDeploymentMode.isProductionLike(req.application.environment),
          let hostHeader = req.headers.first(name: .host),
          let requestOrigin = URLComponents(string: "http://\(hostHeader)"),
          let requestHost = requestOrigin.host,
          requestHost == "127.0.0.1" || requestHost == "::1",
          var target = URLComponents(string: req.application.webAuthnRelyingPartyOrigin),
          target.host?.lowercased() == "localhost" else {
        return nil
    }

    target.path = req.url.path
    target.percentEncodedQuery = req.url.query
    guard let location = target.string else { return nil }
    return req.redirect(to: location)
}

private func safePortholeQuery(_ candidate: String?) -> String? {
    guard let candidate, candidate.isEmpty == false,
          let components = URLComponents(string: "https://porthole.invalid/?\(candidate)") else {
        return nil
    }

    let allowedKeys = Set([
        PortholeWebSessionSupport.conferencePersonaQueryKey,
        PortholeWebSessionSupport.configurationNameQueryKey,
        PortholeWebSessionSupport.configurationEndpointQueryKey,
        PortholeWebSessionSupport.configurationUUIDQueryKey,
        PortholeWebSessionSupport.surfaceIDQueryKey,
        PortholeWebSessionSupport.showProductChromeQueryKey
    ])

    let forwardedItems = (components.queryItems ?? []).compactMap { item -> URLQueryItem? in
        guard allowedKeys.contains(item.name) else {
            return nil
        }
        return URLQueryItem(name: item.name, value: item.value)
    }

    guard forwardedItems.isEmpty == false else {
        return nil
    }

    var forwardedComponents = URLComponents()
    forwardedComponents.queryItems = forwardedItems
    return forwardedComponents.percentEncodedQuery
}

private func defaultPortholePath(for req: Request) -> String {
    guard let forwardedQuery = safePortholeQuery(req.url.query) else {
        return "/porthole"
    }
    return "/porthole?\(forwardedQuery)"
}

private func loginPathPreservingWorkbenchInvite(_ token: String) -> String {
    var components = URLComponents()
    components.path = "/login"
    components.queryItems = [
        URLQueryItem(name: "next", value: "/workbench/access/\(token)")
    ]
    return components.string ?? "/login"
}

private func portholeRequesterIdentity(for req: Request) async throws -> Identity {
    let user = try req.auth.require(FidoUser.self)
    guard let identityDomain = user.id?.uuidString else {
        throw Abort(.internalServerError, reason: "Authenticated user has no identity domain.")
    }

    let identityVault = BrowserClientIdentityVault(identityDomain: identityDomain)
    let previousIdentityID = user.identityId
    let requester = try await PortholeWebSessionSupport.resolveRequesterIdentity(
        for: user,
        identityVault: identityVault,
        activeConferencePersonaID: nil
    )
    if user.identityId != previousIdentityID {
        try await user.save(on: req.db)
    }
    await PortholeWebSessionSupport.registerPublicRequesterIdentity(requester)
    return requester
}

private func stringValue(_ value: ValueType?, key: String) -> String? {
    guard case let .object(object)? = value else { return nil }
    guard case let .string(string)? = object[key] else { return nil }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private struct HealthReadyResponse: Content {
    var status: String
    var mode: String
    var acceptsNewTraffic: Bool
    var reason: String?
    var deploymentID: String?
    var updatedAt: Double
    var drainStartedAt: Double?
    var drainDeadlineAt: Double?
    var runtimeDiagnostics: [String]
    var runtimeAdvisories: [String]
}

func routes(_ app: Application) throws {
//    app.get { req in
//        return "2023-06-22 22:01"
//    }
    let sessionRoutes = app.grouped(FidoUser.sessionAuthenticator(), FidoUser.jwtAccessAuthenticator())
    let protected = sessionRoutes.grouped(FidoUser.redirectMiddleware(makePath: { req in
        let querySuffix = safePortholeQuery(req.url.query).map { "?\($0)" } ?? ""
        return "/login\(querySuffix)"
    }))

    sessionRoutes.get { req async throws -> Response in
        if let redirect = canonicalLocalPasskeyLoginRedirect(for: req) {
            return redirect
        }
        if req.auth.get(FidoUser.self) != nil {
            let requestedNext = req.query[String.self, at: "next"]
            return req.redirect(to: safePostLoginPath(requestedNext) ?? defaultPortholePath(for: req))
        }
        return try await req.view.render("porthole_login", ["title": "Open Porthole"]).encodeResponse(for: req)
    }

    sessionRoutes.get("login") { req async throws -> Response in
        if let redirect = canonicalLocalPasskeyLoginRedirect(for: req) {
            return redirect
        }
        if req.auth.get(FidoUser.self) != nil {
            let requestedNext = req.query[String.self, at: "next"]
            return req.redirect(to: safePostLoginPath(requestedNext) ?? defaultPortholePath(for: req))
        }
        return try await req.view.render("porthole_login", ["title": "Sign in"]).encodeResponse(for: req)
    }

    protected.get("porthole") { req -> Response in
        let querySuffix = safePortholeQuery(req.url.query).map { "?\($0)" } ?? ""
        return req.redirect(to: "/browserhead/webo\(querySuffix)")
    }

    sessionRoutes.get("workbench", "access", ":token") { req async throws -> Response in
        guard let token = req.parameters.get("token")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              token.isEmpty == false else {
            throw Abort(.badRequest, reason: "Missing workbench invitation token.")
        }

        guard req.auth.get(FidoUser.self) != nil else {
            return req.redirect(to: loginPathPreservingWorkbenchInvite(token))
        }

        let requester = try await portholeRequesterIdentity(for: req)
        guard let resolver = CellBase.defaultCellResolver else {
            throw Abort(.internalServerError, reason: "Cell resolver is not available.")
        }
        guard let accessCell = try await resolver.cellAtEndpoint(
            endpoint: WorkbenchAccessGrantCell.endpoint,
            requester: requester
        ) as? WorkbenchAccessGrantCell else {
            throw Abort(.internalServerError, reason: "Workbench access grant cell is not available.")
        }

        let result = await accessCell.acceptInvite(token: token, requester: requester)
        let status = stringValue(result, key: "status")
        if status == "accepted" || status == "already-accepted" {
            return req.redirect(to: stringValue(result, key: "launchPath") ?? WorkbenchAccessGrantCell.sharedWorkbenchLaunchPath())
        }
        return req.redirect(to: WorkbenchAccessGrantCell.accessGrantPortholePath())
    }

    app.get(".well-known", "apple-app-site-association") { req -> Response in
        let appIdentifier = "5UT5HQTCV9.org.digipomps.haven"
        let responseString =
            """
            {
                "applinks": {
                    "details": [
                        {
                            "appIDs": [
                                "\(appIdentifier)"
                            ],
                            "components": [
                                {
                                    "/": "/arendalsuka*",
                                    "comment": "Open the public Arendalsuka program and its authenticated continuation in HAVEN."
                                }
                            ]
                        }
                    ]
                },
                "webcredentials": {
                    "apps": [
                        "\(appIdentifier)"
                    ]
                }
            }
            """
        let response = try await responseString.encodeResponse(for: req)
        response.headers.contentType = HTTPMediaType(type: "application", subType: "json")
        return response
    }

    app.get("privacy", "haven") { req -> Response in
        req.redirect(to: "/haven-privacy.html")
    }
    
    app.get("hello") { req -> String in
        return "Hello, world!"
    }

    app.get("health") { _ -> [String: String] in
        ["status": "ok"]
    }

    app.get("health", "live") { _ -> [String: String] in
        ["status": "ok"]
    }

    app.get("health", "ready") { req async throws -> Response in
        let snapshot = ScaffoldDeploymentSupervisorStore.shared.snapshot()
        let canonicalRuntime = CanonicalCellRuntimeReadinessStore.shared.snapshot()
        let acceptsNewTraffic = snapshot.acceptsNewTraffic && canonicalRuntime.ready
        let status = snapshot.acceptsNewTraffic
            ? (canonicalRuntime.ready ? snapshot.status : "not_ready")
            : snapshot.status
        let reason = snapshot.acceptsNewTraffic
            ? (canonicalRuntime.reason ?? snapshot.reason)
            : snapshot.reason
        let payload = HealthReadyResponse(
            status: status,
            mode: snapshot.mode,
            acceptsNewTraffic: acceptsNewTraffic,
            reason: reason,
            deploymentID: snapshot.deploymentID,
            updatedAt: snapshot.updatedAt,
            drainStartedAt: snapshot.drainStartedAt,
            drainDeadlineAt: snapshot.drainDeadlineAt,
            runtimeDiagnostics: canonicalRuntime.diagnostics,
            runtimeAdvisories: canonicalRuntime.advisories
        )
        let response = try await payload.encodeResponse(for: req)
        response.status = acceptsNewTraffic ? .ok : .serviceUnavailable
        if acceptsNewTraffic == false {
            response.headers.replaceOrAdd(name: HTTPHeaders.Name("Retry-After"), value: "30")
        }
        return response
    }

    app.get("health", "build") { _ -> BuildRuntimeInfo in
        BuildInfoService().runtimeInfo()
    }
    
//    app.webSocket("bridgehead", ":pubId") { request, websocket in
//        print("got ws bridgehead")
//    }
    
    
    try app.register(collection: VaporBrowserhead())
    try app.register(collection: VaporBrowserGatekeeper())
    try app.register(collection: VaporJWTAuth())
    try app.register(collection: VaporConferenceMVP())
    try app.register(collection: VaporRestaurantMVP())
    try app.register(collection: VaporPalazzoCommunale())
    try app.register(collection: VaporChatMVP())
    try app.register(collection: VaporTopUpCheckout())
    try app.register(collection: VaporPaymentResolution())
    try app.register(collection: VaporMicropaymentsAudit())
    try app.register(collection: VaporPaidAIUsageCanary())
    try app.register(collection: VaporAdminMVP())
    try app.register(collection: VaporScaffoldRuntimeAdmin())
    try app.register(collection: VaporTodoMVP())
    try app.register(collection: VaporMicropaymentsMVP())
    try app.register(collection: VaporPaymentProofDoorMVP(enabled: app.environment == .testing))
    try app.register(collection: VaporButterpopStudio())
    try app.register(collection: VaporAgeProofDoorMVP(enabled: app.environment == .testing))
    try app.register(collection: VaporDeviceCallback())
    try app.register(collection: VaporAgentDeviceActionRelay())
    try app.register(collection: VaporAlertmanagerNotificationRelay())
    try app.register(collection: VaporAgentConversationReplies())
    try app.register(collection: VaporAssistantCorrespondence())
    try app.register(collection: VaporLeadVault())
    try app.register(collection: VaporVaultMVP())
    try app.register(collection: VaporBookReference())
    try app.register(collection: VaporDocumentationWorkbench())
    try app.register(collection: VaporDiMyMint())
    try app.register(collection: VaporRAGMVP())
    try app.register(collection: VaporEventPlatform())
    try app.register(collection: VaporSproutResolver())
    try app.register(collection: VaporSproutBridgeDiscovery())
    try app.register(collection: VaporSproutExecutableCatalog())
    try app.register(collection: VaporEntityAnchorDataContract())
    try app.register(collection: VaporAgentActionCapabilityCatalog())
    try app.register(collection: VaporEntityAtlas())
    try app.register(collection: VaporSkeletonParity())
    try app.register(collection: VaporPersonalCopilot())
    try app.register(collection: VaporQuestionnaireCampaign())
    try app.register(collection: VaporProductControl())
}
