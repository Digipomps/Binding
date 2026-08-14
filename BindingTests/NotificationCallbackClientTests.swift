import Testing
import Foundation
@_spi(HAVENRuntime) import CellBase
@testable import Binding

@MainActor
struct NotificationCallbackClientTests {
    @Test
    func disabledRolloutRejectsBeforeCallbackComposition() async {
        let callbackOperator = RecordingCallbackOperator()
        let client = NotificationCallbackClient.testing(
            rolloutEnabled: false,
            callbackOperator: callbackOperator
        )
        await #expect(throws: NotificationCallbackOperationError.deviceIngressV3CompositionUnavailable) {
            try await client.resolveTicket(
                participantId: "participant-1",
                deviceId: "device-1",
                ticketId: "ticket-1"
            )
        }
        await #expect(throws: NotificationCallbackOperationError.deviceIngressV3CompositionUnavailable) {
            try await client.submitTicketResult(
                participantId: "participant-1",
                deviceId: "device-1",
                ticketId: "ticket-1",
                result: [:]
            )
        }
        #expect(await callbackOperator.operations().isEmpty)
    }

    @Test
    func enabledRolloutForwardsResolveAndSubmitToV3Operator() async throws {
        let callbackOperator = RecordingCallbackOperator()
        let client = NotificationCallbackClient.testing(
            rolloutEnabled: true,
            callbackOperator: callbackOperator
        )

        let resolved = try await client.resolveTicket(
            participantId: "entity-pairwise:participant-1",
            deviceId: "device-1",
            ticketId: "ticket-1"
        )
        let submitted = try await client.submitTicketResult(
            participantId: "entity-pairwise:participant-1",
            deviceId: "device-1",
            ticketId: "ticket-1",
            result: ["decision": .string("approved")]
        )

        #expect(resolved == ["operation": .string("resolve")])
        #expect(submitted == ["operation": .string("submit")])
        #expect(await callbackOperator.operations() == [
            "resolve:entity-pairwise:participant-1:device-1:ticket-1",
            "submit:entity-pairwise:participant-1:device-1:ticket-1:approved"
        ])
    }

    @Test
    func dormantCallbackClientRejectsUnsupportedResultBeforeTransport() async throws {
        let vault = EphemeralIdentityVault()
        var identity = Identity(
            "22222222-2222-4222-8222-222222222222",
            displayName: DeviceIngressEnvelope.identityDomain,
            identityVault: vault
        )
        await vault.addIdentity(identity: &identity, for: DeviceIngressEnvelope.identityDomain)
        let descriptor = try #require(
            DeviceIngressIdentityDescriptor.publicDescriptor(for: identity)
        )
        let transport = CountingCallbackTransport()
        let client = DeviceIngressCallbackClient(
            authenticatedVault: .testing(vault),
            transport: transport,
            trust: DeviceIngressRegistrationTrustConfiguration(
                expectedAudience: "staging.haven.digipomps.org",
                expectedChallengeIssuer: descriptor
            )
        )

        await #expect(throws: NotificationCallbackOperationError.invalidResult) {
            try await client.submit(
                participantID: "entity-pairwise:fixture",
                deviceID: identity.uuid,
                ticketID: "ticket-1",
                result: ["prompt": .string("not in the server allowlist")]
            )
        }
        #expect(await transport.requestCount() == 0)
    }

    @Test
    func callbackHTTPSCarrierUsesOnlyCanonicalV3PathsAndWrapper() async throws {
        CallbackFixtureURLProtocol.install { request in
            switch request.url?.path {
            case "/conference-mvp/api/device/challenge":
                return (200, Data("challenge".utf8))
            case "/conference-mvp/api/device/callback/resolve":
                return (200, Data("resolve".utf8))
            case "/conference-mvp/api/device/callback/submit":
                return (200, Data("submit".utf8))
            default:
                return (404, Data())
            }
        }
        defer { CallbackFixtureURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CallbackFixtureURLProtocol.self]
        let transport = try URLSessionDeviceIngressCallbackTransport(
            origin: try #require(URL(string: "https://staging.haven.digipomps.org")),
            session: URLSession(configuration: configuration)
        )
        let vault = EphemeralIdentityVault()
        var identity = Identity(
            "33333333-3333-4333-8333-333333333333",
            displayName: DeviceIngressEnvelope.identityDomain,
            identityVault: vault
        )
        await vault.addIdentity(identity: &identity, for: DeviceIngressEnvelope.identityDomain)
        let subject = try #require(
            DeviceIngressIdentityDescriptor.publicDescriptor(for: identity)
        )

        #expect(try await transport.fetchChallenge(
            operation: .resolve,
            subject: subject
        ) == Data("challenge".utf8))
        #expect(try await transport.submit(
            operation: .resolve,
            canonicalChallengeData: Data("c".utf8),
            canonicalRequestData: Data("r".utf8),
            protectedBody: Data("b".utf8)
        ) == Data("resolve".utf8))
        #expect(try await transport.submit(
            operation: .submit,
            canonicalChallengeData: Data("c2".utf8),
            canonicalRequestData: Data("r2".utf8),
            protectedBody: Data("b2".utf8)
        ) == Data("submit".utf8))

        let requests = CallbackFixtureURLProtocol.capturedRequests()
        #expect(requests.map(\.path) == [
            "/conference-mvp/api/device/challenge",
            "/conference-mvp/api/device/callback/resolve",
            "/conference-mvp/api/device/callback/submit"
        ])
        let challenge = try #require(
            try JSONSerialization.jsonObject(with: requests[0].body) as? [String: Any]
        )
        #expect(challenge["schema"] as? String
            == "haven.device-ingress.callback-challenge-request.v1")
        #expect(challenge["operation"] as? String == "resolve")
        let wrapper = try #require(
            try JSONSerialization.jsonObject(with: requests[1].body) as? [String: Any]
        )
        #expect(wrapper["schema"] as? String == "haven.device-callback.transport.v3")
        #expect(wrapper["canonicalChallenge"] as? String
            == Data("c".utf8).base64EncodedString())
        #expect(wrapper["canonicalRequest"] as? String
            == Data("r".utf8).base64EncodedString())
        #expect(wrapper["protectedBody"] as? String
            == Data("b".utf8).base64EncodedString())
    }

    @Test
    func ticketDecisionResultCarriesGenericDeviceActionDecision() {
        let action = PendingDeviceAction(
            id: "ticket-1",
            participantId: "participant-1",
            deviceId: "phone-1",
            ticketId: "ticket-1",
            requiredActionKey: "binding.notification.staging.test",
            payload: [:],
            receivedAt: .init(timeIntervalSince1970: 0)
        )

        let result = NotificationCallbackClient.ticketDecisionResult(
            action: action,
            decision: .approved
        )

        #expect(result["requiredActionKey"] == .string("binding.notification.staging.test"))
        #expect(result["responseKind"] == .string("decision"))
        #expect(result["decision"] == .string("approved"))
        #expect(result["prompt"] == .string("Approved"))
    }

    @Test
    func ticketDecisionResultPreservesContactEndpointRoutingHints() {
        let action = PendingDeviceAction(
            id: "notification-ticket-1",
            participantId: "binding-participant",
            deviceId: "iphone-1",
            ticketId: "notification-ticket-1",
            requiredActionKey: "contact.ticket.review",
            payload: [
                "sourceCellEndpoint": .string("cell:///ContactEndpoint"),
                "endpointId": .string("binding-chat-invites"),
                "sourceTicketId": .string("contact-ticket-1"),
                "requestTopic": .string("contact.message")
            ],
            receivedAt: .init(timeIntervalSince1970: 0)
        )

        let result = NotificationCallbackClient.ticketDecisionResult(
            action: action,
            decision: .approved
        )

        #expect(result["sourceCellEndpoint"] == .string("cell:///ContactEndpoint"))
        #expect(result["endpointId"] == .string("binding-chat-invites"))
        #expect(result["sourceTicketId"] == .string("contact-ticket-1"))
        #expect(result["requestTopic"] == .string("contact.message"))
    }

    @Test
    func ticketDecisionResultPreservesAgentConversationRoutingContext() {
        let action = PendingDeviceAction(
            id: "notification-ticket-agent-1",
            participantId: "binding-participant",
            deviceId: "iphone-1",
            ticketId: "notification-ticket-agent-1",
            requiredActionKey: "haven.agent.followup.approval",
            payload: [
                "sourceCellEndpoint": .string("cell://staging.haven.digipomps.org/AgentConversationInbox"),
                "conversationId": .string("conversation-1"),
                "requestId": .string("request-1"),
                "jobId": .string("job-1"),
                "title": .string("Agenten venter"),
                "message": .string("Godkjenn neste steg."),
                "purpose": .string("purpose://operate-local-haven-agent"),
                "purposeDescription": .string("Fortsett trygg lokal agentjobb."),
                "interests": .array([.string("codex"), .string("binding")])
            ],
            receivedAt: .init(timeIntervalSince1970: 0)
        )

        let result = NotificationCallbackClient.ticketDecisionResult(
            action: action,
            decision: .approved
        )

        #expect(result["sourceCellEndpoint"] == .string("cell://staging.haven.digipomps.org/AgentConversationInbox"))
        #expect(result["conversationId"] == .string("conversation-1"))
        #expect(result["requestId"] == .string("request-1"))
        #expect(result["jobId"] == .string("job-1"))
        #expect(result["purpose"] == .string("purpose://operate-local-haven-agent"))
        #expect(result["purposeDescription"] == .string("Fortsett trygg lokal agentjobb."))
        #expect(result["interests"] == .array([.string("codex"), .string("binding")]))
    }

    @Test
    func ticketPromptResultPreservesContactEndpointRoutingHints() {
        let action = PendingDeviceAction(
            id: "notification-ticket-2",
            participantId: "binding-participant",
            deviceId: "iphone-1",
            ticketId: "notification-ticket-2",
            requiredActionKey: "contact.ticket.review",
            payload: [
                "sourceCellEndpoint": .string("cell:///ContactEndpoint"),
                "endpointId": .string("binding-chat-invites"),
                "sourceTicketId": .string("contact-ticket-2")
            ],
            receivedAt: .init(timeIntervalSince1970: 0)
        )

        let result = NotificationCallbackClient.ticketPromptResult(
            action: action,
            prompt: "Jeg vil starte chatten."
        )

        #expect(result["responseKind"] == .string("prompt"))
        #expect(result["sourceCellEndpoint"] == .string("cell:///ContactEndpoint"))
        #expect(result["endpointId"] == .string("binding-chat-invites"))
        #expect(result["sourceTicketId"] == .string("contact-ticket-2"))
    }

    @Test
    func callbackSubmitPayloadCopiesSourceRoutingHintsToTopLevel() {
        let payload = NotificationCallbackClient.callbackSubmitPayload(
            participantId: "binding-participant",
            deviceId: "iphone-1",
            ticketId: "notification-ticket-agent-1",
            result: [
                "sourceCellEndpoint": .string("cell://staging.haven.digipomps.org/AgentConversationInbox"),
                "notificationTicketId": .string("notification-ticket-agent-1"),
                "conversationId": .string("conversation-1"),
                "prompt": .string("Approved")
            ]
        )

        #expect(payload["participantId"] == .string("binding-participant"))
        #expect(payload["deviceId"] == .string("iphone-1"))
        #expect(payload["ticketId"] == .string("notification-ticket-agent-1"))
        #expect(payload["sourceCellEndpoint"] == .string("cell://staging.haven.digipomps.org/AgentConversationInbox"))
        #expect(payload["notificationTicketId"] == .string("notification-ticket-agent-1"))
        #expect(payload["result"] == .object([
            "sourceCellEndpoint": .string("cell://staging.haven.digipomps.org/AgentConversationInbox"),
            "notificationTicketId": .string("notification-ticket-agent-1"),
            "conversationId": .string("conversation-1"),
            "prompt": .string("Approved")
        ]))
    }

    @Test
    func notificationTicketIDFallsBackToNestedPayload() {
        let userInfo: [AnyHashable: Any] = [
            "payload": [
                "ticketId": "nested-ticket-1",
                "title": "Nested notification"
            ]
        ]

        #expect(NotificationCallbackClient.notificationTicketID(from: userInfo) == "nested-ticket-1")
    }

    @Test
    func notificationPayloadObjectParsesPayloadJSON() {
        let userInfo: [AnyHashable: Any] = [
            "payloadJSON": #"{"ticketId":"json-ticket-1","message":"Fallback JSON payload"}"#
        ]

        let payload = NotificationCallbackClient.notificationPayloadObject(from: userInfo)

        #expect(payload?["ticketId"] == .string("json-ticket-1"))
        #expect(payload?["message"] == .string("Fallback JSON payload"))
        #expect(NotificationCallbackClient.notificationTicketID(from: userInfo) == "json-ticket-1")
    }
}

private actor RecordingCallbackOperator: DeviceIngressCallbackOperating {
    private var recordedOperations: [String] = []

    func resolve(
        participantID: String,
        deviceID: String,
        ticketID: String,
        now: Date
    ) -> [String: JSONValue] {
        _ = now
        recordedOperations.append(
            "resolve:\(participantID):\(deviceID):\(ticketID)"
        )
        return ["operation": .string("resolve")]
    }

    func submit(
        participantID: String,
        deviceID: String,
        ticketID: String,
        result: [String: JSONValue],
        now: Date
    ) -> [String: JSONValue] {
        _ = now
        let decision: String
        if case let .string(value)? = result["decision"] {
            decision = value
        } else {
            decision = "missing"
        }
        recordedOperations.append(
            "submit:\(participantID):\(deviceID):\(ticketID):\(decision)"
        )
        return ["operation": .string("submit")]
    }

    func operations() -> [String] { recordedOperations }
}

private actor CountingCallbackTransport: DeviceIngressCallbackTransport {
    private var requests = 0

    func fetchChallenge(
        operation: DeviceIngressOperation,
        subject: IdentityPublicKeyDescriptor
    ) throws -> Data {
        requests += 1
        throw NotificationCallbackOperationError.deviceIngressV3CompositionUnavailable
    }

    func submit(
        operation: DeviceIngressOperation,
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) throws -> Data {
        requests += 1
        throw NotificationCallbackOperationError.deviceIngressV3CompositionUnavailable
    }

    func requestCount() -> Int { requests }
}

private final class CallbackFixtureURLProtocol: URLProtocol, @unchecked Sendable {
    struct CapturedRequest: Sendable {
        let path: String
        let body: Data
    }

    typealias Handler = @Sendable (URLRequest) -> (status: Int, body: Data)
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?
    nonisolated(unsafe) private static var requests: [CapturedRequest] = []

    static func install(_ handler: @escaping Handler) {
        lock.withLock {
            self.handler = handler
            requests = []
        }
    }

    static func reset() {
        lock.withLock {
            handler = nil
            requests = []
        }
    }

    static func capturedRequests() -> [CapturedRequest] {
        lock.withLock { requests }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let handler = Self.lock.withLock({ Self.handler }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let body = Self.requestBody(request)
        Self.lock.withLock {
            Self.requests.append(CapturedRequest(path: url.path, body: body))
        }
        let result = handler(request)
        let response = HTTPURLResponse(
            url: url,
            statusCode: result.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: result.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func requestBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            body.append(buffer, count: count)
        }
        return body
    }
}
