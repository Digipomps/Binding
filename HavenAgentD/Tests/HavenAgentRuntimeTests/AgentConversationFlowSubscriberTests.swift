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
                "requestId": .string("request-1"),
                "conversationId": .string("conversation-1"),
                "jobId": .string("job-1"),
                "participantId": .string("participant-phone"),
                "deviceId": .string("device-phone"),
                "ticketId": .string("ticket-1"),
                "requiredActionKey": .string("haven.agent.followup.approval"),
                "title": .string("HAVENAgent trenger neste prompt"),
                "message": .string("Jobben er ferdig."),
                "responseKind": .string("decision"),
                "decision": .string("approved"),
                "note": .string("Looks good"),
                "purpose": .string("purpose://operate-local-haven-agent"),
                "purposeDescription": .string("Start or continue local coding work."),
                "interests": .list([.string("codex"), .string("automation")]),
                "workspacePath": .string("/tmp/haven"),
                "preferredAssistant": .string("codex"),
                "areaContext": .string("home-office"),
                "timeOfDayLabel": .string("arbeidstid"),
                "prompt": .string("Fortsett med neste steg"),
                "updatedAt": .string("2026-04-20T12:00:00Z")
            ]),
            properties: FlowElement.Properties(type: .content, contentType: .object)
        )
        var event = flowElement
        event.topic = AgentConversationFlowContract.flowTopic

        let prompt = AgentConversationFlowSubscriber.parsePrompt(from: event)

        #expect(prompt?.id == "record-1")
        #expect(prompt?.requestId == "request-1")
        #expect(prompt?.conversationId == "conversation-1")
        #expect(prompt?.jobId == "job-1")
        #expect(prompt?.participantId == "participant-phone")
        #expect(prompt?.deviceId == "device-phone")
        #expect(prompt?.ticketId == "ticket-1")
        #expect(prompt?.requiredActionKey == "haven.agent.followup.approval")
        #expect(prompt?.responseKind == "decision")
        #expect(prompt?.decision == "approved")
        #expect(prompt?.note == "Looks good")
        #expect(prompt?.purpose == "purpose://operate-local-haven-agent")
        #expect(prompt?.purposeDescription == "Start or continue local coding work.")
        #expect(prompt?.interests == ["codex", "automation"])
        #expect(prompt?.workspacePath == "/tmp/haven")
        #expect(prompt?.preferredAssistant == "codex")
        #expect(prompt?.areaContext == "home-office")
        #expect(prompt?.timeOfDayLabel == "arbeidstid")
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
    func consumeDeduplicatesReplayedPromptRecords() async {
        let subscriber = AgentConversationFlowSubscriber()
        let flowElement = makePromptFlowElement(id: "record-1", prompt: "Fortsett med neste steg")

        await subscriber.consume(flowElement: flowElement)
        await subscriber.consume(flowElement: flowElement)

        let prompts = await subscriber.promptSnapshot()
        #expect(prompts.count == 1)
        #expect(prompts.first?.id == "record-1")
    }

    @Test
    func parserRejectsUnrelatedTopics() {
        let flowElement = makePromptFlowElement(topic: "other.topic", prompt: "Ignorer denne")

        let prompt = AgentConversationFlowSubscriber.parsePrompt(from: flowElement)

        #expect(prompt == nil)
    }

    private func makePromptFlowElement(
        id: String? = nil,
        topic: String = AgentConversationFlowContract.flowTopic,
        prompt: String
    ) -> FlowElement {
        var content: [String: ValueType] = [
            "conversationId": .string("conversation-test"),
            "prompt": .string(prompt)
        ]
        if let id {
            content["id"] = .string(id)
        }
        let flowElement = FlowElement(
            title: AgentConversationFlowContract.promptReceivedEvent,
            content: .object(content),
            properties: FlowElement.Properties(type: .content, contentType: .object)
        )
        var event = flowElement
        event.topic = topic
        return event
    }
}
