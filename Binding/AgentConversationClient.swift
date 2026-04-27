import Foundation
import CellBase

@MainActor
final class AgentConversationClient {
    static let shared = AgentConversationClient()

    static let requiredActionKey = "haven.agent.followup.prompt"
    static let defaultEndpoint = "cell://staging.haven.digipomps.org/AgentConversationInbox"

    private init() {}

    func postPrompt(action: PendingDeviceAction, prompt: String) async throws {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPrompt.isEmpty == false else {
            throw AgentConversationClientError.emptyPrompt
        }

        let endpoint = Self.endpoint()
        registerRemoteHostIfNeeded(for: endpoint)
        guard let resolver = CellBase.defaultCellResolver else {
            throw AgentConversationClientError.missingResolver
        }

        let requester = try await requesterIdentity()
        let cell = try await resolver.cellAtEndpoint(endpoint: endpoint, requester: requester)
        let meddle = cell as? Meddle
        guard let meddle else {
            throw AgentConversationClientError.targetNotWritable
        }

        let response = try await meddle.set(
            keypath: "postPrompt",
            value: .object(Self.postPromptPayload(action: action, prompt: trimmedPrompt).mapValues(\.valueType)),
            requester: requester
        )
        if case let .string(message)? = response,
           message.hasPrefix("error:") || message == "denied" {
            throw AgentConversationClientError.remoteRejected(message)
        }
    }

    nonisolated static func endpoint(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let configured = environment["BINDING_AGENT_CONVERSATION_ENDPOINT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return configured?.isEmpty == false ? configured! : defaultEndpoint
    }

    nonisolated static func postPromptPayload(
        action: PendingDeviceAction,
        prompt: String
    ) -> [String: JSONValue] {
        var payload: [String: JSONValue] = [
            "participantId": .string(action.participantId),
            "deviceId": .string(action.deviceId),
            "ticketId": .string(action.ticketId),
            "requiredActionKey": .string(action.requiredActionKey),
            "prompt": .string(prompt)
        ]

        if let conversationId = stringValue(action.payload["conversationId"]) {
            payload["conversationId"] = .string(conversationId)
        }
        if let jobId = stringValue(action.payload["jobId"]) {
            payload["jobId"] = .string(jobId)
        }
        if let title = stringValue(action.payload["title"]) {
            payload["title"] = .string(title)
        }
        if let message = stringValue(action.payload["message"]) {
            payload["message"] = .string(message)
        }
        if let sourceCellEndpoint = stringValue(action.payload["sourceCellEndpoint"]) {
            payload["sourceCellEndpoint"] = .string(sourceCellEndpoint)
        }
        return payload
    }

    private func registerRemoteHostIfNeeded(for endpoint: String) {
        guard let url = URL(string: endpoint),
              let host = url.host,
              host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }
        let resolver = CellResolver.sharedInstance
        let route = RemoteCellHostRoute(
            websocketEndpoint: "publishersws",
            schemePreference: .automatic
        )
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let existing = resolver.remoteCellHostRoutesSnapshot()[normalizedHost]
        if existing == nil {
            resolver.registerRemoteCellHost(host, route: route)
        }
    }

    private func requesterIdentity() async throws -> Identity {
        if let vault = CellBase.defaultIdentityVault,
           let identity = await vault.identity(for: "private", makeNewIfNotFound: true) {
            return identity
        }
        if let participantID = NotificationEnrollmentManager.shared.currentParticipantID() {
            return Identity(participantID, displayName: "Binding Phone", identityVault: nil)
        }
        throw AgentConversationClientError.missingIdentity
    }

    private nonisolated static func stringValue(_ value: JSONValue?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum AgentConversationClientError: Error, LocalizedError {
    case emptyPrompt
    case missingResolver
    case missingIdentity
    case targetNotWritable
    case remoteRejected(String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Write a prompt before sending."
        case .missingResolver:
            return "Binding runtime is not ready to resolve staging cells."
        case .missingIdentity:
            return "No local Binding identity is available for staging."
        case .targetNotWritable:
            return "AgentConversationInbox is not writable over the staging bridge."
        case .remoteRejected(let message):
            return message
        }
    }
}

private extension JSONValue {
    var valueType: ValueType {
        switch self {
        case .string(let string):
            return .string(string)
        case .number(let number):
            return .float(number)
        case .bool(let bool):
            return .bool(bool)
        case .object(let object):
            return .object(object.mapValues(\.valueType))
        case .array(let array):
            return .list(array.map(\.valueType))
        case .null:
            return .null
        }
    }
}
