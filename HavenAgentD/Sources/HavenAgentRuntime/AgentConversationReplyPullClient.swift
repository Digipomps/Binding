import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@preconcurrency import CellBase

public struct AgentConversationReplyPullFilter: Codable, Equatable, Sendable {
    public var requestId: String?
    public var conversationId: String?
    public var jobId: String?
    public var ticketId: String?
    public var status: String?
    public var limit: Int

    public init(
        requestId: String? = nil,
        conversationId: String? = nil,
        jobId: String? = nil,
        ticketId: String? = nil,
        status: String? = "prompt_received",
        limit: Int = 1
    ) {
        self.requestId = Self.normalized(requestId)
        self.conversationId = Self.normalized(conversationId)
        self.jobId = Self.normalized(jobId)
        self.ticketId = Self.normalized(ticketId)
        self.status = Self.normalized(status)
        self.limit = max(1, min(limit, 50))
    }

    var hasSelector: Bool {
        requestId != nil || conversationId != nil || jobId != nil || ticketId != nil
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum AgentConversationReplyPullError: Error, LocalizedError, Equatable, Sendable {
    case disabled
    case missingSelector
    case missingRelayToken
    case invalidEndpoint(String)
    case httpStatus(Int, String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .disabled:
            return "Agent conversation reply pull fallback is not configured for this relay."
        case .missingSelector:
            return "Agent conversation reply pull requires requestId, conversationId, jobId, or ticketId."
        case .missingRelayToken:
            return "Agent conversation reply pull requires HAVEN_AGENT_RELAY_TOKEN, AGENT_NOTIFICATION_RELAY_TOKEN, or deviceActionRelay.agentRelayTokenPath."
        case .invalidEndpoint(let endpoint):
            return "Agent conversation reply pull endpoint is invalid: \(endpoint)"
        case .httpStatus(let status, let body):
            return "Agent conversation reply pull returned HTTP \(status): \(body)"
        case .invalidResponse(let message):
            return "Agent conversation reply pull returned invalid JSON: \(message)"
        }
    }
}

public struct AgentConversationReplyPullClient: Sendable {
    private struct PullResponse: Decodable {
        var status: String?
        var matched: Bool?
        var count: Int?
        var records: [[String: RelayJSONValue]]
    }

    private let config: DeviceActionRelayConfig

    public init(config: DeviceActionRelayConfig) {
        self.config = config
    }

    public func pullLatestMatchingReply(filter: AgentConversationReplyPullFilter) async throws -> AgentConversationPrompt? {
        guard filter.hasSelector else {
            throw AgentConversationReplyPullError.missingSelector
        }
        guard let endpoint = config.conversationRepliesEndpoint else {
            throw AgentConversationReplyPullError.disabled
        }
        guard let token = NotificationOutboxDeviceActionPublisher.agentRelayToken(tokenFilePath: config.agentRelayTokenPath) else {
            throw AgentConversationReplyPullError.missingRelayToken
        }
        guard let url = Self.url(endpoint: endpoint, filter: filter) else {
            throw AgentConversationReplyPullError.invalidEndpoint(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AgentConversationReplyPullError.invalidResponse(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentConversationReplyPullError.invalidResponse("Non-HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data.prefix(512), encoding: .utf8) ?? ""
            throw AgentConversationReplyPullError.httpStatus(httpResponse.statusCode, body)
        }

        let envelope: PullResponse
        do {
            envelope = try JSONDecoder().decode(PullResponse.self, from: data)
        } catch {
            throw AgentConversationReplyPullError.invalidResponse(error.localizedDescription)
        }
        guard envelope.matched == true || (envelope.count ?? 0) > 0 else {
            return nil
        }
        return envelope.records.compactMap(Self.prompt(from:)).first
    }

    static func url(endpoint: String, filter: AgentConversationReplyPullFilter) -> URL? {
        guard var components = URLComponents(string: endpoint) else {
            return nil
        }
        var queryItems: [URLQueryItem] = []
        if let value = filter.requestId {
            queryItems.append(URLQueryItem(name: "requestId", value: value))
        }
        if let value = filter.conversationId {
            queryItems.append(URLQueryItem(name: "conversationId", value: value))
        }
        if let value = filter.jobId {
            queryItems.append(URLQueryItem(name: "jobId", value: value))
        }
        if let value = filter.ticketId {
            queryItems.append(URLQueryItem(name: "ticketId", value: value))
        }
        if let value = filter.status {
            queryItems.append(URLQueryItem(name: "status", value: value))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(filter.limit)"))
        components.queryItems = queryItems
        return components.url
    }

    public static func prompt(from record: [String: RelayJSONValue]) -> AgentConversationPrompt? {
        let object = record.mapValues(valueType)
        var event = FlowElement(
            title: AgentConversationFlowContract.promptReceivedEvent,
            content: .object(object),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        event.topic = AgentConversationFlowContract.flowTopic
        return AgentConversationFlowSubscriber.parsePrompt(from: event)
    }

    private static func valueType(from relayValue: RelayJSONValue) -> ValueType {
        switch relayValue {
        case .string(let value):
            return .string(value)
        case .number(let value):
            return .float(value)
        case .bool(let value):
            return .bool(value)
        case .object(let value):
            return .object(value.mapValues(valueType))
        case .array(let value):
            return .list(value.map(valueType))
        case .null:
            return .null
        }
    }
}
