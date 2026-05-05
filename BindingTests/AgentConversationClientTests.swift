import Foundation
import Testing
@testable import Binding

@MainActor
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
                "sourceCellEndpoint": .string("cell:///AgentConversationInbox")
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
        #expect(payload["prompt"] == .string("Open Safari and summarize the page."))
    }

    @Test
    func endpointDefaultsToStagingAgentConversationInbox() {
        #expect(
            AgentConversationClient.endpoint(environment: [:])
                == "cell://staging.haven.digipomps.org/AgentConversationInbox"
        )
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
}
