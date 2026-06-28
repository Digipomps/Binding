import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@preconcurrency import CellBase
import HavenRuntimeBootstrap

public enum RelayJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: RelayJSONValue])
    case array([RelayJSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let object = try? container.decode([String: RelayJSONValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([RelayJSONValue].self) {
            self = .array(array)
        } else {
            throw RelayJSONValueError.unsupportedValue
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    static func from(any value: Any) -> RelayJSONValue? {
        switch value {
        case let string as String:
            return .string(string)
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .number(Double(int))
        case let double as Double:
            return .number(double)
        case let float as Float:
            return .number(Double(float))
        case let dictionary as [String: Any]:
            let object = dictionary.reduce(into: [String: RelayJSONValue]()) { partialResult, entry in
                guard let converted = RelayJSONValue.from(any: entry.value) else {
                    return
                }
                partialResult[entry.key] = converted
            }
            return .object(object)
        case let array as [Any]:
            return .array(array.compactMap(RelayJSONValue.from(any:)))
        default:
            return nil
        }
    }

    var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
    }
}

private enum RelayJSONValueError: Error {
    case unsupportedValue
}

public enum DeviceActionResponseMode: String, Codable, Equatable, Sendable {
    case prompt
    case approval
}

private enum DeviceActionRelayContract {
    static let defaultNotificationOutboxEndpoint = "https://staging.haven.digipomps.org/conference-mvp/api/agent/device-action"
    static let defaultPromptTriggerEvent = "workflow.remote.prompt.requested"
    static let defaultApprovalTriggerEvent = "workflow.review.pending"
    static let defaultTTLSeconds = 900
    static let minimumTTLSeconds = 60
    static let maximumTTLSeconds = 24 * 3600
}

public struct DeviceActionRelayConfig: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var notificationOutboxEndpoint: String
    public var defaultParticipantID: String?
    public var defaultDeviceID: String?
    public var defaultTTLSeconds: Int
    public var requestsDirectoryName: String
    public var processedDirectoryName: String
    public var failedDirectoryName: String
    public var repliesDirectoryName: String
    public var conversationEndpoint: String

    enum CodingKeys: String, CodingKey {
        case enabled
        case notificationOutboxEndpoint
        case publishURL
        case defaultParticipantID
        case defaultDeviceID
        case defaultTTLSeconds
        case requestsDirectoryName
        case processedDirectoryName
        case failedDirectoryName
        case repliesDirectoryName
        case conversationEndpoint
    }

    public init(
        enabled: Bool = false,
        notificationOutboxEndpoint: String = "https://staging.haven.digipomps.org/conference-mvp/api/agent/device-action",
        defaultParticipantID: String? = nil,
        defaultDeviceID: String? = nil,
        defaultTTLSeconds: Int = 900,
        requestsDirectoryName: String = "Requests",
        processedDirectoryName: String = "Processed",
        failedDirectoryName: String = "Failed",
        repliesDirectoryName: String = "Replies",
        conversationEndpoint: String = AgentConversationFlowContract.defaultEndpoint
    ) {
        self.enabled = enabled
        self.notificationOutboxEndpoint = Self.normalizedNotificationOutboxEndpoint(
            notificationOutboxEndpoint,
            legacyPublishURL: nil
        )
        self.defaultParticipantID = defaultParticipantID
        self.defaultDeviceID = defaultDeviceID
        self.defaultTTLSeconds = Self.clampedTTLSeconds(defaultTTLSeconds)
        self.requestsDirectoryName = requestsDirectoryName
        self.processedDirectoryName = processedDirectoryName
        self.failedDirectoryName = failedDirectoryName
        self.repliesDirectoryName = repliesDirectoryName
        self.conversationEndpoint = conversationEndpoint
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        notificationOutboxEndpoint = Self.normalizedNotificationOutboxEndpoint(
            try container.decodeIfPresent(String.self, forKey: .notificationOutboxEndpoint),
            legacyPublishURL: try container.decodeIfPresent(String.self, forKey: .publishURL)
        )
        defaultParticipantID = try container.decodeIfPresent(String.self, forKey: .defaultParticipantID)
        defaultDeviceID = try container.decodeIfPresent(String.self, forKey: .defaultDeviceID)
        defaultTTLSeconds = Self.clampedTTLSeconds(
            try container.decodeIfPresent(Int.self, forKey: .defaultTTLSeconds)
                ?? DeviceActionRelayContract.defaultTTLSeconds
        )
        requestsDirectoryName = try container.decodeIfPresent(String.self, forKey: .requestsDirectoryName) ?? "Requests"
        processedDirectoryName = try container.decodeIfPresent(String.self, forKey: .processedDirectoryName) ?? "Processed"
        failedDirectoryName = try container.decodeIfPresent(String.self, forKey: .failedDirectoryName) ?? "Failed"
        repliesDirectoryName = try container.decodeIfPresent(String.self, forKey: .repliesDirectoryName) ?? "Replies"
        conversationEndpoint = try container.decodeIfPresent(String.self, forKey: .conversationEndpoint)
            ?? AgentConversationFlowContract.defaultEndpoint
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(notificationOutboxEndpoint, forKey: .notificationOutboxEndpoint)
        try container.encodeIfPresent(defaultParticipantID, forKey: .defaultParticipantID)
        try container.encodeIfPresent(defaultDeviceID, forKey: .defaultDeviceID)
        try container.encode(defaultTTLSeconds, forKey: .defaultTTLSeconds)
        try container.encode(requestsDirectoryName, forKey: .requestsDirectoryName)
        try container.encode(processedDirectoryName, forKey: .processedDirectoryName)
        try container.encode(failedDirectoryName, forKey: .failedDirectoryName)
        try container.encode(repliesDirectoryName, forKey: .repliesDirectoryName)
        try container.encode(conversationEndpoint, forKey: .conversationEndpoint)
    }

    private static func normalizedNotificationOutboxEndpoint(
        _ notificationOutboxEndpoint: String?,
        legacyPublishURL: String?
    ) -> String {
        if let endpoint = normalizedNonEmpty(notificationOutboxEndpoint) {
            return endpoint
        }
        if let legacyValue = normalizedNonEmpty(legacyPublishURL) {
            if legacyValue.lowercased().hasPrefix("cell://") {
                return legacyValue
            }
            if legacyValue.lowercased().hasPrefix("http://") || legacyValue.lowercased().hasPrefix("https://") {
                return legacyValue
            }
            if let url = URL(string: legacyValue),
               let host = normalizedNonEmpty(url.host) {
                return "cell://\(host)/NotificationOutbox"
            }
        }
        return DeviceActionRelayContract.defaultNotificationOutboxEndpoint
    }

    private static func clampedTTLSeconds(_ value: Int) -> Int {
        max(
            DeviceActionRelayContract.minimumTTLSeconds,
            min(DeviceActionRelayContract.maximumTTLSeconds, value)
        )
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct DeviceActionRequest: Codable, Equatable, Sendable, Identifiable {
    public static let approvalActionKey = "haven.agent.followup.approval"

    public var id: String
    public var participantId: String?
    public var deviceId: String?
    public var ticketId: String?
    public var requiredActionKey: String?
    public var responseMode: DeviceActionResponseMode
    public var title: String
    public var message: String
    public var purpose: String?
    public var purposeDescription: String?
    public var interests: [String]
    public var naturalLanguageIntent: String?
    public var conversationId: String?
    public var jobId: String?
    public var sourceCellEndpoint: String?
    public var sourceEventPath: String?
    public var sourceEventTopic: String?
    public var triggerEvent: String?
    public var ttlSeconds: Int?
    public var payload: [String: RelayJSONValue]
    public var createdAt: String

    public init(
        id: String = UUID().uuidString,
        participantId: String? = nil,
        deviceId: String? = nil,
        ticketId: String? = nil,
        requiredActionKey: String? = nil,
        responseMode: DeviceActionResponseMode = .prompt,
        title: String,
        message: String,
        purpose: String? = nil,
        purposeDescription: String? = nil,
        interests: [String] = [],
        naturalLanguageIntent: String? = nil,
        conversationId: String? = nil,
        jobId: String? = nil,
        sourceCellEndpoint: String? = nil,
        sourceEventPath: String? = nil,
        sourceEventTopic: String? = nil,
        triggerEvent: String? = nil,
        ttlSeconds: Int? = nil,
        payload: [String: RelayJSONValue] = [:],
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.participantId = participantId
        self.deviceId = deviceId
        self.ticketId = ticketId
        self.requiredActionKey = requiredActionKey
        self.responseMode = responseMode
        self.title = title
        self.message = message
        self.purpose = purpose
        self.purposeDescription = purposeDescription
        self.interests = interests
        self.naturalLanguageIntent = naturalLanguageIntent
        self.conversationId = conversationId
        self.jobId = jobId
        self.sourceCellEndpoint = sourceCellEndpoint
        self.sourceEventPath = sourceEventPath
        self.sourceEventTopic = sourceEventTopic
        self.triggerEvent = triggerEvent
        self.ttlSeconds = ttlSeconds
        self.payload = payload
        self.createdAt = createdAt
    }
}

public struct PublishedDeviceAction: Codable, Equatable, Sendable {
    public var version: String
    public var id: String
    public var participantId: String
    public var deviceId: String?
    public var ticketId: String
    public var triggerEvent: String
    public var ttlSeconds: Int
    public var requiredActionKey: String
    public var responseMode: String
    public var title: String
    public var message: String
    public var purpose: String?
    public var purposeDescription: String?
    public var interests: [String]
    public var naturalLanguageIntent: String?
    public var conversationId: String?
    public var jobId: String?
    public var sourceCellEndpoint: String?
    public var sourceEventPath: String?
    public var sourceEventTopic: String?
    public var payload: [String: RelayJSONValue]
    public var createdAt: String

    public init(
        version: String = "1.0",
        id: String,
        participantId: String,
        deviceId: String?,
        ticketId: String,
        triggerEvent: String,
        ttlSeconds: Int,
        requiredActionKey: String,
        responseMode: String,
        title: String,
        message: String,
        purpose: String?,
        purposeDescription: String?,
        interests: [String],
        naturalLanguageIntent: String?,
        conversationId: String?,
        jobId: String?,
        sourceCellEndpoint: String?,
        sourceEventPath: String?,
        sourceEventTopic: String?,
        payload: [String: RelayJSONValue],
        createdAt: String
    ) {
        self.version = version
        self.id = id
        self.participantId = participantId
        self.deviceId = deviceId
        self.ticketId = ticketId
        self.triggerEvent = triggerEvent
        self.ttlSeconds = ttlSeconds
        self.requiredActionKey = requiredActionKey
        self.responseMode = responseMode
        self.title = title
        self.message = message
        self.purpose = purpose
        self.purposeDescription = purposeDescription
        self.interests = interests
        self.naturalLanguageIntent = naturalLanguageIntent
        self.conversationId = conversationId
        self.jobId = jobId
        self.sourceCellEndpoint = sourceCellEndpoint
        self.sourceEventPath = sourceEventPath
        self.sourceEventTopic = sourceEventTopic
        self.payload = payload
        self.createdAt = createdAt
    }
}

public struct DeviceActionPublishReceipt: Codable, Equatable, Sendable {
    public var ticketId: String
    public var publishedAt: String
    public var response: [String: RelayJSONValue]?

    public init(
        ticketId: String,
        publishedAt: String = ISO8601DateFormatter().string(from: Date()),
        response: [String: RelayJSONValue]? = nil
    ) {
        self.ticketId = ticketId
        self.publishedAt = publishedAt
        self.response = response
    }
}

public struct DeviceActionDispatchRecord: Codable, Equatable, Sendable {
    public var requestFileName: String
    public var action: PublishedDeviceAction
    public var receipt: DeviceActionPublishReceipt
}

public struct DeviceActionFailureRecord: Codable, Equatable, Sendable {
    public var requestFileName: String
    public var request: DeviceActionRequest?
    public var rawRequest: String?
    public var failedAt: String
    public var errorMessage: String
}

public protocol DeviceActionPublishing: Sendable {
    func publish(_ action: PublishedDeviceAction, requester: Identity) async throws -> DeviceActionPublishReceipt
}

public enum DeviceActionRelayError: Error, LocalizedError, Equatable, Sendable {
    case invalidNotificationOutboxEndpoint(String)
    case publishRejected(String)
    case missingParticipantID
    case requesterUnavailable
    case resolverUnavailable
    case targetNotWritable

    public var errorDescription: String? {
        switch self {
        case .invalidNotificationOutboxEndpoint(let value):
            return "Device action relay NotificationOutbox endpoint is invalid: \(value)"
        case .publishRejected(let message):
            return "Device action relay publish failed: \(message)"
        case .missingParticipantID:
            return "Device action relay needs a participantId in the request or relay config."
        case .requesterUnavailable:
            return "Device action relay could not load the local agent identity for conversation replies."
        case .resolverUnavailable:
            return "Device action relay needs a configured CellResolver before it can contact staging."
        case .targetNotWritable:
            return "Device action relay could not open NotificationOutbox as a writable cell."
        }
    }
}

public struct NotificationOutboxDeviceActionPublisher: DeviceActionPublishing {
    private let notificationOutboxEndpoint: String

    public init(config: DeviceActionRelayConfig) {
        self.notificationOutboxEndpoint = config.notificationOutboxEndpoint
    }

    public func publish(_ action: PublishedDeviceAction, requester: Identity) async throws -> DeviceActionPublishReceipt {
        guard let url = URL(string: notificationOutboxEndpoint),
              let scheme = url.scheme?.lowercased() else {
            throw DeviceActionRelayError.invalidNotificationOutboxEndpoint(notificationOutboxEndpoint)
        }

        switch scheme {
        case "cell":
            return try await publishToCell(action, requester: requester)
        case "http", "https":
            return try await publishToHTTP(action, url: url)
        default:
            throw DeviceActionRelayError.invalidNotificationOutboxEndpoint(notificationOutboxEndpoint)
        }
    }

    private func publishToCell(_ action: PublishedDeviceAction, requester: Identity) async throws -> DeviceActionPublishReceipt {
        Self.registerRemoteHostIfNeeded(for: notificationOutboxEndpoint)

        guard let resolver = CellBase.defaultCellResolver else {
            throw DeviceActionRelayError.resolverUnavailable
        }

        let cell: any Emit
        do {
            cell = try await resolver.cellAtEndpoint(endpoint: notificationOutboxEndpoint, requester: requester)
        } catch {
            throw DeviceActionRelayError.publishRejected(
                "Could not resolve NotificationOutbox at \(notificationOutboxEndpoint): \(error.localizedDescription)"
            )
        }
        guard let meddle = cell as? Meddle else {
            throw DeviceActionRelayError.targetNotWritable
        }

        let response: ValueType?
        do {
            response = try await meddle.set(
                keypath: "createTicket",
                value: action.notificationOutboxValue,
                requester: requester
            )
        } catch {
            throw DeviceActionRelayError.publishRejected(
                "NotificationOutbox createTicket failed at \(notificationOutboxEndpoint): \(error.localizedDescription)"
            )
        }

        if case let .string(message)? = response {
            throw DeviceActionRelayError.publishRejected(message)
        }

        guard case let .object(object)? = response else {
            throw DeviceActionRelayError.publishRejected(
                "NotificationOutbox returned an unexpected response: \(String(describing: response))"
            )
        }

        let responseObject = Self.decodeJSONObject(from: object)
        return try Self.receipt(from: responseObject, fallbackTicketID: action.ticketId)
    }

    private func publishToHTTP(_ action: PublishedDeviceAction, url: URL) async throws -> DeviceActionPublishReceipt {
        guard let token = Self.agentRelayToken() else {
            throw DeviceActionRelayError.publishRejected(
                "HTTP relay requires HAVEN_AGENT_RELAY_TOKEN or AGENT_NOTIFICATION_RELAY_TOKEN."
            )
        }

        guard case let .object(object) = action.notificationOutboxValue else {
            throw DeviceActionRelayError.publishRejected("Device action could not be encoded for HTTP relay.")
        }

        let body = Self.decodeJSONObject(from: object)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw DeviceActionRelayError.publishRejected(
                "HTTP relay request to \(url.absoluteString) failed: \(error.localizedDescription)"
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeviceActionRelayError.publishRejected("HTTP relay returned a non-HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data.prefix(512), encoding: .utf8) ?? ""
            throw DeviceActionRelayError.publishRejected(
                "HTTP relay returned \(httpResponse.statusCode): \(responseBody)"
            )
        }

        let responseObject: [String: RelayJSONValue]
        do {
            responseObject = try JSONDecoder().decode([String: RelayJSONValue].self, from: data)
        } catch {
            throw DeviceActionRelayError.publishRejected(
                "HTTP relay returned invalid JSON: \(error.localizedDescription)"
            )
        }

        return try Self.receipt(from: responseObject, fallbackTicketID: action.ticketId)
    }

    private static func receipt(
        from responseObject: [String: RelayJSONValue],
        fallbackTicketID: String
    ) throws -> DeviceActionPublishReceipt {
        if responseObject["status"]?.stringValue == "failed" {
            let message = responseObject["diagnosticMessage"]?.stringValue
                ?? responseObject["message"]?.stringValue
                ?? "NotificationOutbox created a failed ticket."
            throw DeviceActionRelayError.publishRejected(message)
        }

        let resolvedTicketID = responseObject["id"]?.stringValue
            ?? responseObject["ticketId"]?.stringValue
            ?? fallbackTicketID
        return DeviceActionPublishReceipt(
            ticketId: resolvedTicketID,
            response: responseObject
        )
    }

    private static func agentRelayToken() -> String? {
        let environment = ProcessInfo.processInfo.environment
        return normalizedNonEmpty(environment["HAVEN_AGENT_RELAY_TOKEN"])
            ?? normalizedNonEmpty(environment["AGENT_NOTIFICATION_RELAY_TOKEN"])
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    static func registerRemoteHostIfNeeded(for endpoint: String) {
        guard let url = URL(string: endpoint),
              let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              host.isEmpty == false else {
            return
        }

        let resolver = CellResolver.sharedInstance
        let route = RemoteCellHostRoute(
            websocketEndpoint: "bridgehead",
            schemePreference: .automatic
        )
        let normalizedHost = host.lowercased()
        let existing = resolver.remoteCellHostRoutesSnapshot()[normalizedHost]
        if existing == nil {
            resolver.registerRemoteCellHost(host, route: route)
        }
    }

    private static func decodeJSONObject(from object: [String: ValueType]) -> [String: RelayJSONValue] {
        object.reduce(into: [String: RelayJSONValue]()) { partialResult, entry in
            guard let converted = RelayJSONValue.from(valueType: entry.value) else {
                return
            }
            partialResult[entry.key] = converted
        }
    }
}

private extension RelayJSONValue {
    static func from(valueType: ValueType) -> RelayJSONValue? {
        switch valueType {
        case .null:
            return .null
        case .string(let value):
            return .string(value)
        case .number(let value):
            return .number(Double(value))
        case .integer(let value):
            return .number(Double(value))
        case .float(let value):
            return .number(value)
        case .bool(let value):
            return .bool(value)
        case .object(let value):
            return .object(value.compactMapValues(RelayJSONValue.from(valueType:)))
        case .list(let value):
            return .array(value.compactMap(RelayJSONValue.from(valueType:)))
        default:
            return nil
        }
    }

    var valueType: ValueType {
        switch self {
        case .string(let value):
            return .string(value)
        case .number(let value):
            return .float(value)
        case .bool(let value):
            return .bool(value)
        case .object(let value):
            return .object(value.mapValues(\.valueType))
        case .array(let value):
            return .list(value.map(\.valueType))
        case .null:
            return .null
        }
    }
}

private extension PublishedDeviceAction {
    var notificationOutboxValue: ValueType {
        .object([
            "participantId": .string(participantId),
            "deviceId": deviceId.map(ValueType.string) ?? .null,
            "triggerEvent": .string(triggerEvent),
            "requiredActionKey": .string(requiredActionKey),
            "platform": .string("ios"),
            "ttlSeconds": .integer(ttlSeconds),
            "payload": .object(payload.mapValues(\.valueType))
        ])
    }
}

public actor DeviceActionRelay {
    private let paths: RuntimePaths
    private let config: DeviceActionRelayConfig
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let publisher: any DeviceActionPublishing
    private let conversationSubscriber: AgentConversationFlowSubscriber
    private let requesterProvider: (@Sendable () async throws -> Identity)?

    public init(
        paths: RuntimePaths,
        config: DeviceActionRelayConfig,
        publisher: (any DeviceActionPublishing)? = nil,
        fileManager: FileManager = .default,
        requesterProvider: (@Sendable () async throws -> Identity)? = nil
    ) {
        self.paths = paths
        self.config = config
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
        self.publisher = publisher ?? NotificationOutboxDeviceActionPublisher(config: config)
        self.conversationSubscriber = AgentConversationFlowSubscriber()
        self.requesterProvider = requesterProvider
    }

    public func bootstrap() throws {
        for directory in [
            requestsDirectoryURL(),
            processedDirectoryURL(),
            failedDirectoryURL(),
            repliesDirectoryURL(),
            CodexPromptQueue(paths: paths, fileManager: fileManager).queuedDirectoryURL(),
            CodexPromptQueue(paths: paths, fileManager: fileManager).startedDirectoryURL(),
            CodexPromptQueue(paths: paths, fileManager: fileManager).completedDirectoryURL()
        ] {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    public func connectConversationReplies() async throws {
        try bootstrap()
        await conversationSubscriber.setPromptHandler { prompt in
            try? await self.recordConversationReply(prompt)
        }
        let requester = try await resolvedRequesterIdentity()
        NotificationOutboxDeviceActionPublisher.registerRemoteHostIfNeeded(for: config.conversationEndpoint)
        try await conversationSubscriber.connect(
            endpoint: config.conversationEndpoint,
            requester: requester
        )
    }

    public func stop() async {
        await conversationSubscriber.disconnect()
        await conversationSubscriber.setPromptHandler(nil)
    }

    public func scanPendingRequests() async throws -> [DeviceActionDispatchRecord] {
        try bootstrap()
        let requestFiles = try pendingRequestFiles()
        var records: [DeviceActionDispatchRecord] = []
        for fileURL in requestFiles {
            if let record = try await processRequestFile(fileURL) {
                records.append(record)
            }
        }
        return records
    }

    public func recordConversationReply(_ prompt: AgentConversationPrompt) throws {
        try bootstrap()
        if prompt.requiredActionKey == CodexPromptQueueContract.requiredActionKey {
            _ = try CodexPromptQueue(paths: paths, fileManager: fileManager)
                .enqueue(conversationPrompt: prompt)
            return
        }
        let fileURL = repliesDirectoryURL().appendingPathComponent("\(sanitizedFileComponent(prompt.id)).json")
        try writeJSON(prompt, to: fileURL)
    }

    public nonisolated func requestsDirectoryURL() -> URL {
        paths.inboxDirectory.appendingPathComponent(config.requestsDirectoryName, isDirectory: true)
    }

    public nonisolated func processedDirectoryURL() -> URL {
        paths.inboxDirectory.appendingPathComponent(config.processedDirectoryName, isDirectory: true)
    }

    public nonisolated func failedDirectoryURL() -> URL {
        paths.inboxDirectory.appendingPathComponent(config.failedDirectoryName, isDirectory: true)
    }

    public nonisolated func repliesDirectoryURL() -> URL {
        paths.inboxDirectory.appendingPathComponent(config.repliesDirectoryName, isDirectory: true)
    }

    private func pendingRequestFiles() throws -> [URL] {
        let directory = requestsDirectoryURL()
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func processRequestFile(_ fileURL: URL) async throws -> DeviceActionDispatchRecord? {
        let rawData = try Data(contentsOf: fileURL)

        do {
            let request = try decoder.decode(DeviceActionRequest.self, from: rawData)
            let action = try publishedAction(from: request)
            let requester = try await resolvedRequesterIdentity()
            let receipt = try await publisher.publish(action, requester: requester)
            var dispatchedAction = action
            dispatchedAction.ticketId = receipt.ticketId
            let record = DeviceActionDispatchRecord(
                requestFileName: fileURL.lastPathComponent,
                action: dispatchedAction,
                receipt: receipt
            )
            try writeJSON(
                record,
                to: processedDirectoryURL().appendingPathComponent(fileURL.lastPathComponent)
            )
            try fileManager.removeItem(at: fileURL)
            return record
        } catch {
            let rawRequest = String(data: rawData, encoding: .utf8)
            let request = try? decoder.decode(DeviceActionRequest.self, from: rawData)
            let failure = DeviceActionFailureRecord(
                requestFileName: fileURL.lastPathComponent,
                request: request,
                rawRequest: rawRequest,
                failedAt: iso8601String(Date()),
                errorMessage: error.localizedDescription
            )
            try writeJSON(
                failure,
                to: failedDirectoryURL().appendingPathComponent(fileURL.lastPathComponent)
            )
            try fileManager.removeItem(at: fileURL)
            return nil
        }
    }

    private func publishedAction(from request: DeviceActionRequest) throws -> PublishedDeviceAction {
        guard let participantId = trimmed(request.participantId) ?? trimmed(config.defaultParticipantID) else {
            throw DeviceActionRelayError.missingParticipantID
        }

        let resolvedDeviceID = trimmed(request.deviceId) ?? trimmed(config.defaultDeviceID)
        let resolvedTicketID = trimmed(request.ticketId) ?? request.id
        let resolvedConversationID = trimmed(request.conversationId) ?? request.id
        let resolvedJobID = trimmed(request.jobId) ?? request.id
        let resolvedSourceCellEndpoint = trimmed(request.sourceCellEndpoint) ?? trimmed(config.conversationEndpoint)
        let requiredActionKey = trimmed(request.requiredActionKey) ?? defaultRequiredActionKey(for: request.responseMode)
        let triggerEvent = trimmed(request.triggerEvent) ?? defaultTriggerEvent(for: request.responseMode)
        let ttlSeconds = clampedTTLSeconds(request.ttlSeconds ?? config.defaultTTLSeconds)

        var payload = request.payload
        payload["requestId"] = .string(request.id)
        payload["title"] = .string(request.title)
        payload["message"] = .string(request.message)
        payload["responseMode"] = .string(request.responseMode.rawValue)
        payload["conversationId"] = .string(resolvedConversationID)
        payload["jobId"] = .string(resolvedJobID)
        payload["triggerEvent"] = .string(triggerEvent)
        if let resolvedSourceCellEndpoint {
            payload["sourceCellEndpoint"] = .string(resolvedSourceCellEndpoint)
        }
        if let resolvedDeviceID {
            payload["deviceId"] = .string(resolvedDeviceID)
        }
        if let purpose = trimmed(request.purpose) {
            payload["purpose"] = .string(purpose)
        }
        if let purposeDescription = trimmed(request.purposeDescription) {
            payload["purposeDescription"] = .string(purposeDescription)
        }
        if let naturalLanguageIntent = trimmed(request.naturalLanguageIntent) {
            payload["naturalLanguageIntent"] = .string(naturalLanguageIntent)
        }
        if request.interests.isEmpty == false {
            payload["interests"] = .array(request.interests.map(RelayJSONValue.string))
        }

        return PublishedDeviceAction(
            id: request.id,
            participantId: participantId,
            deviceId: resolvedDeviceID,
            ticketId: resolvedTicketID,
            triggerEvent: triggerEvent,
            ttlSeconds: ttlSeconds,
            requiredActionKey: requiredActionKey,
            responseMode: request.responseMode.rawValue,
            title: request.title,
            message: request.message,
            purpose: trimmed(request.purpose),
            purposeDescription: trimmed(request.purposeDescription),
            interests: request.interests,
            naturalLanguageIntent: trimmed(request.naturalLanguageIntent),
            conversationId: resolvedConversationID,
            jobId: resolvedJobID,
            sourceCellEndpoint: resolvedSourceCellEndpoint,
            sourceEventPath: trimmed(request.sourceEventPath),
            sourceEventTopic: trimmed(request.sourceEventTopic),
            payload: payload,
            createdAt: request.createdAt
        )
    }

    private func resolvedRequesterIdentity() async throws -> Identity {
        if let requesterProvider {
            return try await requesterProvider()
        }
        return try await requesterIdentity()
    }

    private func requesterIdentity() async throws -> Identity {
        guard let descriptor = await AgentRuntimeBridge.shared.agentIdentityDescriptorSnapshot(),
              let vault = CellBase.defaultIdentityVault else {
            throw DeviceActionRelayError.requesterUnavailable
        }

        if let identity = await vault.identity(for: descriptor.identityContext, makeNewIfNotFound: false) {
            return identity
        }

        if let identity = await vault.identity(for: descriptor.identityUUID, makeNewIfNotFound: false) {
            return identity
        }

        throw DeviceActionRelayError.requesterUnavailable
    }

    private func writeJSON<T: Encodable>(_ value: T, to fileURL: URL) throws {
        let data = try encoder.encode(value)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: fileURL, options: [.atomic])
    }

    private func defaultRequiredActionKey(for responseMode: DeviceActionResponseMode) -> String {
        switch responseMode {
        case .prompt:
            return AgentConversationFlowContract.requiredActionKey
        case .approval:
            return DeviceActionRequest.approvalActionKey
        }
    }

    private func defaultTriggerEvent(for responseMode: DeviceActionResponseMode) -> String {
        switch responseMode {
        case .prompt:
            return DeviceActionRelayContract.defaultPromptTriggerEvent
        case .approval:
            return DeviceActionRelayContract.defaultApprovalTriggerEvent
        }
    }

    private func clampedTTLSeconds(_ value: Int) -> Int {
        max(
            DeviceActionRelayContract.minimumTTLSeconds,
            min(DeviceActionRelayContract.maximumTTLSeconds, value)
        )
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalarView = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalarView)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? UUID().uuidString.lowercased() : sanitized
    }

    private func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
