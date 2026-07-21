import Testing
import Foundation
@testable import Binding

@MainActor
struct NotificationCallbackClientTests {
    @Test
    func resolveAndSubmitRemainFailClosed() async {
        await #expect(throws: NotificationCallbackOperationError.deviceIngressV3CompositionUnavailable) {
            try await NotificationCallbackClient.shared.resolveTicket(
                participantId: "participant-1",
                deviceId: "device-1",
                ticketId: "ticket-1"
            )
        }
        await #expect(throws: NotificationCallbackOperationError.deviceIngressV3CompositionUnavailable) {
            try await NotificationCallbackClient.shared.submitTicketResult(
                participantId: "participant-1",
                deviceId: "device-1",
                ticketId: "ticket-1",
                result: [:]
            )
        }
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
