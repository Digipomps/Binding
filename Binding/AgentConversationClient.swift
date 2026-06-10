import Foundation
import CellBase

@MainActor
final class AgentConversationClient {
    static let shared = AgentConversationClient()

    nonisolated static let requiredActionKey = "haven.agent.followup.prompt"
    nonisolated static let codexStartPromptActionKey = "haven.agent.codex.start_prompt"
    nonisolated static let defaultEndpoint = "cell://staging.haven.digipomps.org/AgentConversationInbox"
    static var endpointOverrideForTesting: String?

    private init() {}

    func postPrompt(action: PendingDeviceAction, prompt: String) async throws {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPrompt.isEmpty == false else {
            throw AgentConversationClientError.emptyPrompt
        }

        try await postResponse(
            action: action,
            prompt: trimmedPrompt,
            responseKind: "prompt",
            decision: nil,
            note: nil
        )
    }

    func postDecision(
        action: PendingDeviceAction,
        decision: AgentConversationDecision,
        note: String? = nil
    ) async throws {
        let normalizedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = Self.decisionPrompt(decision: decision, note: normalizedNote)
        try await postResponse(
            action: action,
            prompt: prompt,
            responseKind: "decision",
            decision: decision.rawValue,
            note: normalizedNote
        )
    }

    func postCodexPrompt(
        prompt: String,
        title: String? = nil,
        message: String? = nil,
        purpose: String? = nil,
        purposeDescription: String? = nil,
        interests: [String] = [],
        workspacePath: String? = nil,
        preferredAssistant: String? = "codex",
        areaContext: String? = nil,
        timeOfDayLabel: String? = nil
    ) async throws {
        let manager = NotificationEnrollmentManager.shared
        manager.bootstrapIfNeeded()
        guard let participantId = manager.currentParticipantID(),
              let deviceId = manager.currentDeviceID() else {
            throw AgentConversationClientError.missingIdentity
        }

        let payload = Self.codexPromptPayload(
            participantId: participantId,
            deviceId: deviceId,
            prompt: prompt,
            title: title,
            message: message,
            purpose: purpose,
            purposeDescription: purposeDescription,
            interests: interests,
            workspacePath: workspacePath,
            preferredAssistant: preferredAssistant,
            areaContext: areaContext,
            timeOfDayLabel: timeOfDayLabel
        )
        try await postPayload(payload)
    }

    private func postResponse(
        action: PendingDeviceAction,
        prompt: String,
        responseKind: String,
        decision: String?,
        note: String?
    ) async throws {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPrompt.isEmpty == false else {
            throw AgentConversationClientError.emptyPrompt
        }

        try await postPayload(
            Self.postPromptPayload(
                action: action,
                prompt: trimmedPrompt,
                responseKind: responseKind,
                decision: decision,
                note: note
            )
        )
    }

    private func postPayload(_ payload: [String: JSONValue]) async throws {
        let endpoint = Self.endpointOverrideForTesting ?? Self.endpoint()
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
            value: .object(
                payload.mapValues(\.valueType)
            ),
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
        prompt: String,
        responseKind: String = "prompt",
        decision: String? = nil,
        note: String? = nil
    ) -> [String: JSONValue] {
        var payload: [String: JSONValue] = [
            "participantId": .string(action.participantId),
            "deviceId": .string(action.deviceId),
            "ticketId": .string(action.ticketId),
            "requiredActionKey": .string(action.requiredActionKey),
            "prompt": .string(prompt),
            "responseKind": .string(responseKind)
        ]

        if let decision {
            payload["decision"] = .string(decision)
        }
        if let note, note.isEmpty == false {
            payload["note"] = .string(note)
        }

        if let conversationId = stringValue(action.payload["conversationId"]) {
            payload["conversationId"] = .string(conversationId)
        }
        if let requestId = stringValue(action.payload["requestId"]) {
            payload["requestId"] = .string(requestId)
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

    nonisolated static func codexPromptPayload(
        id: String = UUID().uuidString.lowercased(),
        participantId: String,
        deviceId: String,
        prompt: String,
        title: String? = nil,
        message: String? = nil,
        purpose: String? = nil,
        purposeDescription: String? = nil,
        interests: [String] = [],
        workspacePath: String? = nil,
        preferredAssistant: String? = "codex",
        areaContext: String? = nil,
        timeOfDayLabel: String? = nil
    ) -> [String: JSONValue] {
        var payload: [String: JSONValue] = [
            "id": .string(id),
            "requestId": .string(id),
            "conversationId": .string(id),
            "jobId": .string(id),
            "participantId": .string(participantId),
            "deviceId": .string(deviceId),
            "ticketId": .string(id),
            "requiredActionKey": .string(codexStartPromptActionKey),
            "responseKind": .string("prompt"),
            "prompt": .string(prompt)
        ]

        if let title = normalizedNonEmpty(title) {
            payload["title"] = .string(title)
        }
        if let message = normalizedNonEmpty(message) {
            payload["message"] = .string(message)
        }
        if let purpose = normalizedNonEmpty(purpose) {
            payload["purpose"] = .string(purpose)
        }
        if let purposeDescription = normalizedNonEmpty(purposeDescription) {
            payload["purposeDescription"] = .string(purposeDescription)
        }
        let normalizedInterests = interests
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !normalizedInterests.isEmpty {
            payload["interests"] = .array(normalizedInterests.map(JSONValue.string))
        }
        if let workspacePath = normalizedNonEmpty(workspacePath) {
            payload["workspacePath"] = .string(workspacePath)
        }
        if let preferredAssistant = normalizedNonEmpty(preferredAssistant) {
            payload["preferredAssistant"] = .string(preferredAssistant)
        }
        if let areaContext = normalizedNonEmpty(areaContext) {
            payload["areaContext"] = .string(areaContext)
        }
        if let timeOfDayLabel = normalizedNonEmpty(timeOfDayLabel) {
            payload["timeOfDayLabel"] = .string(timeOfDayLabel)
        }
        return payload
    }

    nonisolated static func postDecisionPayload(
        action: PendingDeviceAction,
        decision: AgentConversationDecision,
        note: String? = nil
    ) -> [String: JSONValue] {
        let normalizedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return postPromptPayload(
            action: action,
            prompt: decisionPrompt(decision: decision, note: normalizedNote),
            responseKind: "decision",
            decision: decision.rawValue,
            note: normalizedNote
        )
    }

    private func registerRemoteHostIfNeeded(for endpoint: String) {
        guard let url = URL(string: endpoint),
              let host = url.host,
              host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }
        let resolver = CellResolver.sharedInstance
        let route = RemoteCellHostRoute(
            websocketEndpoint: "bridgehead",
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

    private nonisolated static func decisionPrompt(
        decision: AgentConversationDecision,
        note: String?
    ) -> String {
        if let note, note.isEmpty == false {
            return note
        }
        switch decision {
        case .approved:
            return "Approved"
        case .rejected:
            return "Rejected"
        }
    }

    private nonisolated static func stringValue(_ value: JSONValue?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum AgentConversationDecision: String {
    case approved
    case rejected
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
