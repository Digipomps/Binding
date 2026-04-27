import Foundation
@preconcurrency import CellBase
import Testing
@testable import HavenAgentRuntime

struct AgentConversationFlowSubscriberTests {
    @Test
    func parserAcceptsPromptReceivedEventOnConversationTopic() {
        let flowElement = FlowElement(
            title: AgentConversationFlowContract.promptReceivedEvent,
            content: .object([
                "id": .string("record-1"),
                "conversationId": .string("conversation-1"),
                "jobId": .string("job-1"),
                "participantId": .string("participant-phone"),
                "deviceId": .string("device-phone"),
                "ticketId": .string("ticket-1"),
                "title": .string("HAVENAgent trenger neste prompt"),
                "message": .string("Jobben er ferdig."),
                "prompt": .string("Fortsett med neste steg"),
                "updatedAt": .string("2026-04-20T12:00:00Z")
            ]),
            properties: FlowElement.Properties(type: .content, contentType: .object)
        )
        var event = flowElement
        event.topic = AgentConversationFlowContract.flowTopic

        let prompt = AgentConversationFlowSubscriber.parsePrompt(from: event)

        #expect(prompt?.id == "record-1")
        #expect(prompt?.conversationId == "conversation-1")
        #expect(prompt?.jobId == "job-1")
        #expect(prompt?.participantId == "participant-phone")
        #expect(prompt?.deviceId == "device-phone")
        #expect(prompt?.ticketId == "ticket-1")
        #expect(prompt?.prompt == "Fortsett med neste steg")
        #expect(prompt?.receivedAt == "2026-04-20T12:00:00Z")
    }

    @Test
    func consumeStoresPromptSnapshot() async {
        let subscriber = AgentConversationFlowSubscriber()
        let flowElement = makePromptFlowElement(prompt: "Kjør osascript og rapporter tilbake")

        await subscriber.consume(flowElement: flowElement)

        let prompts = await subscriber.promptSnapshot()
        #expect(prompts.count == 1)
        #expect(prompts.first?.prompt == "Kjør osascript og rapporter tilbake")
    }

    @Test
    func parserRejectsUnrelatedTopics() {
        let flowElement = makePromptFlowElement(topic: "other.topic", prompt: "Ignorer denne")

        let prompt = AgentConversationFlowSubscriber.parsePrompt(from: flowElement)

        #expect(prompt == nil)
    }

    private func makePromptFlowElement(
        topic: String = AgentConversationFlowContract.flowTopic,
        prompt: String
    ) -> FlowElement {
        let flowElement = FlowElement(
            title: AgentConversationFlowContract.promptReceivedEvent,
            content: .object([
                "conversationId": .string("conversation-test"),
                "prompt": .string(prompt)
            ]),
            properties: FlowElement.Properties(type: .content, contentType: .object)
        )
        var event = flowElement
        event.topic = topic
        return event
    }
}
