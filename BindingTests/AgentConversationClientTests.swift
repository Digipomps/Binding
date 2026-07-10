import Foundation
import Testing
import CellBase
@testable import Binding

@MainActor
@Suite(.serialized)
struct AgentConversationClientTests {
    @Test
    func postPromptPayloadCarriesTicketAndCorrelationIDs() {
        let action = PendingDeviceAction(
            id: "ticket-1",
            participantId: "participant-1",
            deviceId: "phone-1",
            ticketId: "ticket-1",
            requiredActionKey: AgentConversationClient.requiredActionKey,
            payload: [
                "conversationId": .string("conversation-1"),
                "jobId": .string("job-1"),
                "title": .string("Agent completed"),
                "message": .string("What next?"),
                "sourceCellEndpoint": .string("cell:///AgentConversationInbox"),
                "purpose": .string("purpose://agent-operator-notification-test"),
                "purposeDescription": .string("End-to-end test."),
                "interests": .array([.string("codex"), .string("binding")])
            ],
            receivedAt: .init(timeIntervalSince1970: 0)
        )

        let payload = AgentConversationClient.postPromptPayload(
            action: action,
            prompt: "Open Safari and summarize the page."
        )

        #expect(payload["participantId"] == .string("participant-1"))
        #expect(payload["deviceId"] == .string("phone-1"))
        #expect(payload["ticketId"] == .string("ticket-1"))
        #expect(payload["conversationId"] == .string("conversation-1"))
        #expect(payload["jobId"] == .string("job-1"))
        #expect(payload["purpose"] == .string("purpose://agent-operator-notification-test"))
        #expect(payload["purposeDescription"] == .string("End-to-end test."))
        #expect(payload["interests"] == .array([.string("codex"), .string("binding")]))
        #expect(payload["prompt"] == .string("Open Safari and summarize the page."))
    }

    @Test
    func postPromptCanTargetAnotherEntityConversationCellEndpoint() async throws {
        let previousResolver = CellBase.defaultCellResolver
        let previousIdentityVault = CellBase.defaultIdentityVault
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        let resolver = CellResolver.sharedInstance
        let inboxName = "OtherEntityAgentConversationInbox\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let endpoint = "cell:///\(inboxName)"
        let identityVault = await BindingStartupIdentityVault.shared.initialize()
        CellBase.defaultCellResolver = resolver
        CellBase.defaultIdentityVault = identityVault
        CellBase.debugValidateAccessForEverything = true
        AgentConversationClient.endpointOverrideForTesting = endpoint
        defer {
            AgentConversationClient.endpointOverrideForTesting = nil
            AgentConversationClient.requesterOverrideForTesting = nil
            AgentConversationClient.resolverOverrideForTesting = nil
            CellBase.defaultCellResolver = previousResolver
            CellBase.defaultIdentityVault = previousIdentityVault
            CellBase.debugValidateAccessForEverything = previousDebugAccess
        }

        try await resolver.addCellResolve(
            name: inboxName,
            cellScope: .identityUnique,
            identityDomain: "private",
            type: OtherEntityAgentConversationInboxFixtureCell.self
        )
        let requester = try #require(
            await identityVault.identity(for: "private", makeNewIfNotFound: true)
        )
        AgentConversationClient.requesterOverrideForTesting = requester
        AgentConversationClient.resolverOverrideForTesting = resolver

        let action = PendingDeviceAction(
            id: "ticket-done-1",
            participantId: "participant-phone",
            deviceId: "device-phone",
            ticketId: "ticket-done-1",
            requiredActionKey: AgentConversationClient.requiredActionKey,
            payload: [
                "conversationId": .string("conversation-agent-1"),
                "jobId": .string("job-agent-1"),
                "title": .string("Jobben er ferdig"),
                "message": .string("Hva er neste steg?"),
                "sourceCellEndpoint": .string(endpoint)
            ],
            receivedAt: .init(timeIntervalSince1970: 0)
        )

        try await AgentConversationClient.shared.postPrompt(
            action: action,
            prompt: "Fortsett med neste trygge steg."
        )

        let inbox = try #require(
            try await resolver.cellAtEndpoint(endpoint: endpoint, requester: requester) as? Meddle
        )
        let state = try #require(asObject(try await inbox.get(keypath: "state", requester: requester)))
        let posts = try #require(asList(state["posts"]))
        let firstPost = try #require(asObject(posts.first))

        #expect(asString(firstPost["prompt"]) == "Fortsett med neste trygge steg.")
        #expect(asString(firstPost["conversationId"]) == "conversation-agent-1")
        #expect(asString(firstPost["jobId"]) == "job-agent-1")
        #expect(asString(firstPost["ticketId"]) == "ticket-done-1")
        #expect(asString(firstPost["sourceCellEndpoint"]) == endpoint)
    }

    @Test
    func endpointDefaultsToStagingAgentConversationInbox() {
        #expect(
            AgentConversationClient.endpoint(environment: [:])
                == "cell://staging.haven.digipomps.org/AgentConversationInbox"
        )
    }

    @Test
    func agentConversationRegistersSecureStagingBridgeRoute() {
        let resolver = CellResolver.sharedInstance
        let stagingHost = "staging.haven.digipomps.org"
        let previousRoute = resolver.remoteCellHostRoutesSnapshot()[stagingHost]
        defer {
            if let previousRoute {
                resolver.registerRemoteCellHost(stagingHost, route: previousRoute)
            } else {
                resolver.unregisterRemoteCellHost(stagingHost)
            }
        }

        resolver.registerRemoteCellHost(
            stagingHost,
            route: RemoteCellHostRoute(websocketEndpoint: "bridgehead", schemePreference: .automatic)
        )

        AgentConversationClient.registerRemoteRouteIfNeeded(
            for: AgentConversationClient.defaultEndpoint,
            resolver: resolver
        )

        let repairedRoute = resolver.remoteCellHostRoutesSnapshot()[stagingHost]
        #expect(repairedRoute?.websocketEndpoint == "bridgehead")
        #expect(repairedRoute?.schemePreference == .wss)
        let usesEndpointFirstPath: Bool
        if case .some(.endpointThenPublisherUUID) = repairedRoute?.pathLayout {
            usesEndpointFirstPath = true
        } else {
            usesEndpointFirstPath = false
        }
        #expect(usesEndpointFirstPath)
    }

    @Test
    func postDecisionPayloadCarriesApprovalMetadata() {
        let action = PendingDeviceAction(
            id: "ticket-2",
            participantId: "participant-1",
            deviceId: "phone-1",
            ticketId: "ticket-2",
            requiredActionKey: "haven.agent.followup.approval",
            payload: [
                "conversationId": .string("conversation-2"),
                "jobId": .string("job-2"),
                "title": .string("Continue coding"),
                "message": .string("Approve if the assistant should continue.")
            ],
            receivedAt: .init(timeIntervalSince1970: 0)
        )

        let payload = AgentConversationClient.postDecisionPayload(
            action: action,
            decision: .approved
        )

        #expect(payload["participantId"] == .string("participant-1"))
        #expect(payload["deviceId"] == .string("phone-1"))
        #expect(payload["ticketId"] == .string("ticket-2"))
        #expect(payload["conversationId"] == .string("conversation-2"))
        #expect(payload["jobId"] == .string("job-2"))
        #expect(payload["responseKind"] == .string("decision"))
        #expect(payload["decision"] == .string("approved"))
        #expect(payload["prompt"] == .string("Approved"))
    }

    @Test
    func routeSelectionKeepsGenericNotificationTicketsOutOfAgentInbox() {
        let genericAction = PendingDeviceAction(
            id: "ticket-generic",
            participantId: "participant-1",
            deviceId: "phone-1",
            ticketId: "ticket-generic",
            requiredActionKey: "binding.notification.staging.test",
            payload: ["title": .string("HAVEN staging")],
            receivedAt: .init(timeIntervalSince1970: 0)
        )
        let agentAction = PendingDeviceAction(
            id: "ticket-agent",
            participantId: "participant-1",
            deviceId: "phone-1",
            ticketId: "ticket-agent",
            requiredActionKey: "haven.agent.followup.approval",
            payload: ["conversationId": .string("conversation-2")],
            receivedAt: .init(timeIntervalSince1970: 0)
        )

        #expect(!AgentConversationClient.shouldRouteToAgentInbox(action: genericAction))
        #expect(AgentConversationClient.shouldRouteToAgentInbox(action: agentAction))
    }

    @Test
    func codexPromptPayloadCarriesPhoneOriginatedPromptContext() {
        let payload = AgentConversationClient.codexPromptPayload(
            id: "codex-request-1",
            participantId: "participant-1",
            deviceId: "phone-1",
            prompt: "Start Codex and inspect status.",
            title: "Start Codex",
            message: "Use the safest available local coding assistant path.",
            purpose: "purpose://operate-local-haven-agent",
            purposeDescription: "Let the phone ask a local coding host to continue work.",
            interests: ["codex", "automation"],
            workspacePath: "/tmp/haven",
            preferredAssistant: "codex",
            areaContext: "home-office",
            timeOfDayLabel: "arbeidstid"
        )

        #expect(payload["id"] == .string("codex-request-1"))
        #expect(payload["requestId"] == .string("codex-request-1"))
        #expect(payload["conversationId"] == .string("codex-request-1"))
        #expect(payload["requiredActionKey"] == .string(AgentConversationClient.codexStartPromptActionKey))
        #expect(payload["prompt"] == .string("Start Codex and inspect status."))
        #expect(payload["purpose"] == .string("purpose://operate-local-haven-agent"))
        #expect(payload["interests"] == .array([.string("codex"), .string("automation")]))
        #expect(payload["workspacePath"] == .string("/tmp/haven"))
        #expect(payload["preferredAssistant"] == .string("codex"))
        #expect(payload["areaContext"] == .string("home-office"))
        #expect(payload["timeOfDayLabel"] == .string("arbeidstid"))
    }
}

private final class OtherEntityAgentConversationInboxFixtureCell: GeneralCell {
    nonisolated(unsafe) private var posts: [ValueType] = []

    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "postPrompt")
        await addInterceptForGet(requester: owner, key: "state") { [weak self] _, _ in
            .object([
                "posts": .list(self?.posts ?? [])
            ])
        }
        await addInterceptForSet(requester: owner, key: "postPrompt") { [weak self] _, value, _ in
            self?.posts.append(value)
            return .object([
                "status": .string("queued"),
                "received": value
            ])
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }
}

private func asObject(_ value: ValueType?) -> Object? {
    guard case let .object(object)? = value else { return nil }
    return object
}

private func asList(_ value: ValueType?) -> ValueTypeList? {
    guard case let .list(list)? = value else { return nil }
    return list
}

private func asString(_ value: ValueType?) -> String? {
    guard case let .string(text)? = value else { return nil }
    return text
}
