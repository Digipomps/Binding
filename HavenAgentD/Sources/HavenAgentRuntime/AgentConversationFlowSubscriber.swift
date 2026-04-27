import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif
@preconcurrency import CellBase

public enum AgentConversationFlowContract {
    public static let defaultEndpoint = "cell://staging.haven.digipomps.org/AgentConversationInbox"
    public static let flowTopic = "haven.agent.conversation"
    public static let promptReceivedEvent = "haven.agent.prompt.received"
    public static let requiredActionKey = "haven.agent.followup.prompt"
}

public struct AgentConversationPrompt: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var conversationId: String
    public var jobId: String?
    public var participantId: String?
    public var deviceId: String?
    public var ticketId: String?
    public var title: String?
    public var message: String?
    public var prompt: String
    public var receivedAt: String

    public init(
        id: String = UUID().uuidString,
        conversationId: String,
        jobId: String? = nil,
        participantId: String? = nil,
        deviceId: String? = nil,
        ticketId: String? = nil,
        title: String? = nil,
        message: String? = nil,
        prompt: String,
        receivedAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.conversationId = conversationId
        self.jobId = jobId
        self.participantId = participantId
        self.deviceId = deviceId
        self.ticketId = ticketId
        self.title = title
        self.message = message
        self.prompt = prompt
        self.receivedAt = receivedAt
    }
}

public enum AgentConversationFlowSubscriberError: Error, LocalizedError, Equatable, Sendable {
    case resolverUnavailable

    public var errorDescription: String? {
        switch self {
        case .resolverUnavailable:
            return "Agent conversation flow requires a configured CellResolver."
        }
    }
}

public actor AgentConversationFlowSubscriber {
    private var flowCancellable: AnyCancellable?
    private var currentRequester: Identity?
    private var currentEmit: Emit?
    private var prompts: [AgentConversationPrompt] = []
    private let maxPromptBufferSize: Int

    public init(maxPromptBufferSize: Int = 50) {
        self.maxPromptBufferSize = max(1, maxPromptBufferSize)
    }

    public func connect(
        endpoint: String = AgentConversationFlowContract.defaultEndpoint,
        requester: Identity
    ) async throws {
        guard let resolver = await runtimeResolver() else {
            throw AgentConversationFlowSubscriberError.resolverUnavailable
        }

        await disconnect()

        let remoteInbox = try await resolver.cellAtEndpoint(endpoint: endpoint, requester: requester)
        let publisher = try await remoteInbox.flow(requester: requester)
        let subscriber = self

        currentRequester = requester
        currentEmit = remoteInbox
        flowCancellable = publisher.sink(
            receiveCompletion: { _ in
                Task {
                    await subscriber.disconnect()
                }
            },
            receiveValue: { flowElement in
                Task {
                    await subscriber.consume(flowElement: flowElement)
                }
            }
        )
    }

    public func disconnect() async {
        flowCancellable?.cancel()
        flowCancellable = nil

        if let requester = currentRequester, let currentEmit {
            currentEmit.close(requester: requester)
        }

        currentRequester = nil
        currentEmit = nil
    }

    public func consume(flowElement: FlowElement) async {
        guard let prompt = Self.parsePrompt(from: flowElement) else {
            return
        }

        prompts.append(prompt)
        if prompts.count > maxPromptBufferSize {
            prompts.removeFirst(prompts.count - maxPromptBufferSize)
        }
    }

    public func promptSnapshot() -> [AgentConversationPrompt] {
        prompts
    }

    public func lastPromptSnapshot() -> AgentConversationPrompt? {
        prompts.last
    }

    public static func parsePrompt(from flowElement: FlowElement) -> AgentConversationPrompt? {
        guard flowElement.topic == AgentConversationFlowContract.flowTopic else {
            return nil
        }
        guard flowElement.title == AgentConversationFlowContract.promptReceivedEvent else {
            return nil
        }
        guard case let .object(object) = flowElement.content else {
            return nil
        }
        guard let prompt = stringValue(object["prompt"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              prompt.isEmpty == false else {
            return nil
        }

        let conversationId = stringValue(object["conversationId"])
            ?? stringValue(object["jobId"])
            ?? stringValue(object["id"])
            ?? UUID().uuidString

        return AgentConversationPrompt(
            id: stringValue(object["id"]) ?? UUID().uuidString,
            conversationId: conversationId,
            jobId: stringValue(object["jobId"]),
            participantId: stringValue(object["participantId"]),
            deviceId: stringValue(object["deviceId"]),
            ticketId: stringValue(object["ticketId"]),
            title: stringValue(object["title"]),
            message: stringValue(object["message"]),
            prompt: prompt,
            receivedAt: stringValue(object["updatedAt"]) ?? stringValue(object["createdAt"]) ?? ISO8601DateFormatter().string(from: Date())
        )
    }

    private func runtimeResolver() async -> CellResolver? {
        await MainActor.run {
            CellBase.defaultCellResolver as? CellResolver
        }
    }

    private static func stringValue(_ value: ValueType?) -> String? {
        guard let value else {
            return nil
        }

        switch value {
        case .string(let string):
            return string
        case .number(let number):
            return String(number)
        case .integer(let integer):
            return String(integer)
        case .float(let double):
            return String(double)
        case .bool(let bool):
            return String(bool)
        default:
            return nil
        }
    }
}
