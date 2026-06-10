import Foundation
import HavenRuntimeBootstrap

public enum CodexPromptQueueContract {
    public static let requiredActionKey = "haven.agent.codex.start_prompt"
    public static let queuedDirectoryName = "CodexPromptRequests"
    public static let startedDirectoryName = "CodexPromptStarted"
    public static let completedDirectoryName = "CodexPromptDone"
}

public enum CodexPromptRequestStatus: String, Codable, Equatable, Sendable {
    case queued
    case started
    case done
    case blocked
    case failed
}

public struct CodexPromptRequest: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var requestId: String?
    public var conversationId: String
    public var jobId: String?
    public var participantId: String?
    public var deviceId: String?
    public var ticketId: String?
    public var title: String?
    public var message: String?
    public var prompt: String
    public var purpose: String?
    public var purposeDescription: String?
    public var interests: [String]
    public var workspacePath: String?
    public var preferredAssistant: String?
    public var areaContext: String?
    public var timeOfDayLabel: String?
    public var source: String
    public var sourceActionKey: String?
    public var status: CodexPromptRequestStatus
    public var claimedBy: String?
    public var claimNote: String?
    public var resultSummary: String?
    public var resultError: String?
    public var createdAt: String
    public var updatedAt: String
    public var startedAt: String?
    public var completedAt: String?

    public init(
        id: String = UUID().uuidString.lowercased(),
        requestId: String? = nil,
        conversationId: String,
        jobId: String? = nil,
        participantId: String? = nil,
        deviceId: String? = nil,
        ticketId: String? = nil,
        title: String? = nil,
        message: String? = nil,
        prompt: String,
        purpose: String? = nil,
        purposeDescription: String? = nil,
        interests: [String] = [],
        workspacePath: String? = nil,
        preferredAssistant: String? = nil,
        areaContext: String? = nil,
        timeOfDayLabel: String? = nil,
        source: String = "manual",
        sourceActionKey: String? = nil,
        status: CodexPromptRequestStatus = .queued,
        claimedBy: String? = nil,
        claimNote: String? = nil,
        resultSummary: String? = nil,
        resultError: String? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        updatedAt: String = ISO8601DateFormatter().string(from: Date()),
        startedAt: String? = nil,
        completedAt: String? = nil
    ) {
        self.id = id
        self.requestId = requestId
        self.conversationId = conversationId
        self.jobId = jobId
        self.participantId = participantId
        self.deviceId = deviceId
        self.ticketId = ticketId
        self.title = title
        self.message = message
        self.prompt = prompt
        self.purpose = purpose
        self.purposeDescription = purposeDescription
        self.interests = interests
        self.workspacePath = workspacePath
        self.preferredAssistant = preferredAssistant
        self.areaContext = areaContext
        self.timeOfDayLabel = timeOfDayLabel
        self.source = source
        self.sourceActionKey = sourceActionKey
        self.status = status
        self.claimedBy = claimedBy
        self.claimNote = claimNote
        self.resultSummary = resultSummary
        self.resultError = resultError
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    public init(conversationPrompt prompt: AgentConversationPrompt) {
        let id = Self.normalizedNonEmpty(prompt.requestId)
            ?? Self.normalizedNonEmpty(prompt.id)
            ?? UUID().uuidString.lowercased()
        let receivedAt = Self.normalizedNonEmpty(prompt.receivedAt)
            ?? ISO8601DateFormatter().string(from: Date())
        self.init(
            id: id,
            requestId: prompt.requestId ?? prompt.id,
            conversationId: prompt.conversationId,
            jobId: prompt.jobId,
            participantId: prompt.participantId,
            deviceId: prompt.deviceId,
            ticketId: prompt.ticketId,
            title: prompt.title,
            message: prompt.message,
            prompt: prompt.prompt,
            purpose: prompt.purpose,
            purposeDescription: prompt.purposeDescription,
            interests: prompt.interests,
            workspacePath: prompt.workspacePath,
            preferredAssistant: prompt.preferredAssistant,
            areaContext: prompt.areaContext,
            timeOfDayLabel: prompt.timeOfDayLabel,
            source: "agent-conversation-inbox",
            sourceActionKey: prompt.requiredActionKey,
            status: .queued,
            createdAt: receivedAt,
            updatedAt: receivedAt
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

public struct CodexPromptRequestRecord: Codable, Equatable, Sendable {
    public var queue: String
    public var filePath: String
    public var request: CodexPromptRequest

    public init(queue: String, filePath: String, request: CodexPromptRequest) {
        self.queue = queue
        self.filePath = filePath
        self.request = request
    }
}

public enum CodexPromptQueueError: Error, LocalizedError, Equatable, Sendable {
    case requestNotFound(String)
    case requestAlreadyCompleted(String)
    case invalidPrompt(String)

    public var errorDescription: String? {
        switch self {
        case .requestNotFound(let id):
            return "Codex prompt request was not found: \(id)"
        case .requestAlreadyCompleted(let id):
            return "Codex prompt request is already completed: \(id)"
        case .invalidPrompt(let message):
            return message
        }
    }
}

public struct CodexPromptQueue {
    private let paths: RuntimePaths
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(paths: RuntimePaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func bootstrap() throws {
        for directory in [
            queuedDirectoryURL(),
            startedDirectoryURL(),
            completedDirectoryURL()
        ] {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    @discardableResult
    public func enqueue(_ request: CodexPromptRequest) throws -> CodexPromptRequestRecord {
        try bootstrap()
        var queuedRequest = request
        queuedRequest.status = .queued
        queuedRequest.updatedAt = iso8601String(Date())
        let fileURL = queuedDirectoryURL().appendingPathComponent("\(sanitizedFileComponent(queuedRequest.id)).json")
        try writeJSON(queuedRequest, to: fileURL)
        return CodexPromptRequestRecord(queue: "queued", filePath: fileURL.path, request: queuedRequest)
    }

    @discardableResult
    public func enqueue(conversationPrompt prompt: AgentConversationPrompt) throws -> CodexPromptRequestRecord? {
        guard prompt.requiredActionKey == CodexPromptQueueContract.requiredActionKey else {
            return nil
        }
        guard prompt.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw CodexPromptQueueError.invalidPrompt("Codex prompt request requires a non-empty prompt.")
        }
        return try enqueue(CodexPromptRequest(conversationPrompt: prompt))
    }

    public func queuedRecords() -> [CodexPromptRequestRecord] {
        records(in: queuedDirectoryURL(), queue: "queued")
    }

    public func startedRecords() -> [CodexPromptRequestRecord] {
        records(in: startedDirectoryURL(), queue: "started")
    }

    public func completedRecords() -> [CodexPromptRequestRecord] {
        records(in: completedDirectoryURL(), queue: "completed")
    }

    public func allRecords() -> [CodexPromptRequestRecord] {
        queuedRecords() + startedRecords() + completedRecords()
    }

    public func nextQueuedRecord(
        workspacePath: String? = nil,
        purpose: String? = nil,
        interest: String? = nil,
        preferredAssistant: String? = nil
    ) -> CodexPromptRequestRecord? {
        queuedRecords().first { record in
            matches(record.request, workspacePath: workspacePath, purpose: purpose, interest: interest, preferredAssistant: preferredAssistant)
        }
    }

    @discardableResult
    public func markStarted(
        id: String,
        assistant: String? = nil,
        workspacePath: String? = nil,
        note: String? = nil
    ) throws -> CodexPromptRequestRecord {
        try bootstrap()
        let located = try locateMutableRequest(id: id)
        guard located.queue != "completed" else {
            throw CodexPromptQueueError.requestAlreadyCompleted(id)
        }

        var request = located.request
        let now = iso8601String(Date())
        request.status = .started
        request.startedAt = request.startedAt ?? now
        request.updatedAt = now
        request.claimedBy = normalizedNonEmpty(assistant) ?? request.claimedBy
        request.claimNote = normalizedNonEmpty(note) ?? request.claimNote
        request.workspacePath = normalizedNonEmpty(workspacePath) ?? request.workspacePath

        let targetURL = startedDirectoryURL().appendingPathComponent(located.fileURL.lastPathComponent)
        try writeJSON(request, to: targetURL)
        if located.fileURL != targetURL, fileManager.fileExists(atPath: located.fileURL.path) {
            try fileManager.removeItem(at: located.fileURL)
        }
        return CodexPromptRequestRecord(queue: "started", filePath: targetURL.path, request: request)
    }

    @discardableResult
    public func markCompleted(
        id: String,
        status: CodexPromptRequestStatus,
        summary: String? = nil,
        error: String? = nil
    ) throws -> CodexPromptRequestRecord {
        try bootstrap()
        let located = try locateMutableRequest(id: id)
        guard located.queue != "completed" else {
            throw CodexPromptQueueError.requestAlreadyCompleted(id)
        }
        guard status == .done || status == .blocked || status == .failed else {
            throw CodexPromptQueueError.invalidPrompt("Completion status must be done, blocked, or failed.")
        }

        var request = located.request
        let now = iso8601String(Date())
        request.status = status
        request.resultSummary = normalizedNonEmpty(summary)
        request.resultError = normalizedNonEmpty(error)
        request.completedAt = now
        request.updatedAt = now

        let targetURL = completedDirectoryURL().appendingPathComponent(located.fileURL.lastPathComponent)
        try writeJSON(request, to: targetURL)
        if located.fileURL != targetURL, fileManager.fileExists(atPath: located.fileURL.path) {
            try fileManager.removeItem(at: located.fileURL)
        }
        return CodexPromptRequestRecord(queue: "completed", filePath: targetURL.path, request: request)
    }

    public func queuedDirectoryURL() -> URL {
        paths.inboxDirectory.appendingPathComponent(CodexPromptQueueContract.queuedDirectoryName, isDirectory: true)
    }

    public func startedDirectoryURL() -> URL {
        paths.inboxDirectory.appendingPathComponent(CodexPromptQueueContract.startedDirectoryName, isDirectory: true)
    }

    public func completedDirectoryURL() -> URL {
        paths.inboxDirectory.appendingPathComponent(CodexPromptQueueContract.completedDirectoryName, isDirectory: true)
    }

    private struct LocatedRequest {
        var queue: String
        var fileURL: URL
        var request: CodexPromptRequest
    }

    private func locateMutableRequest(id: String) throws -> LocatedRequest {
        let sanitizedID = sanitizedFileComponent(id)
        for (queue, directory) in [
            ("queued", queuedDirectoryURL()),
            ("started", startedDirectoryURL()),
            ("completed", completedDirectoryURL())
        ] {
            let exactURL = directory.appendingPathComponent("\(sanitizedID).json")
            if let request = load(CodexPromptRequest.self, from: exactURL) {
                return LocatedRequest(queue: queue, fileURL: exactURL, request: request)
            }
            if let record = records(in: directory, queue: queue).first(where: { $0.request.id == id }) {
                return LocatedRequest(queue: queue, fileURL: URL(fileURLWithPath: record.filePath), request: record.request)
            }
        }
        throw CodexPromptQueueError.requestNotFound(id)
    }

    private func records(in directory: URL, queue: String) -> [CodexPromptRequestRecord] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { fileURL -> CodexPromptRequestRecord? in
                guard let request = load(CodexPromptRequest.self, from: fileURL) else {
                    return nil
                }
                return CodexPromptRequestRecord(queue: queue, filePath: fileURL.path, request: request)
            }
            .sorted {
                $0.request.createdAt.localizedStandardCompare($1.request.createdAt) == .orderedAscending
            }
    }

    private func matches(
        _ request: CodexPromptRequest,
        workspacePath: String?,
        purpose: String?,
        interest: String?,
        preferredAssistant: String?
    ) -> Bool {
        if let workspacePath = normalizedNonEmpty(workspacePath),
           request.workspacePath != workspacePath {
            return false
        }
        if let purpose = normalizedNonEmpty(purpose),
           request.purpose != purpose {
            return false
        }
        if let interest = normalizedNonEmpty(interest),
           !request.interests.contains(interest) {
            return false
        }
        if let preferredAssistant = normalizedNonEmpty(preferredAssistant),
           let requestAssistant = normalizedNonEmpty(request.preferredAssistant),
           requestAssistant != preferredAssistant {
            return false
        }
        return true
    }

    private func load<T: Decodable>(_ type: T.Type, from fileURL: URL) -> T? {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = fileManager.contents(atPath: fileURL.path) else {
            return nil
        }
        return try? decoder.decode(type, from: data)
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

    private func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalarView = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalarView)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? UUID().uuidString.lowercased() : sanitized
    }

    private func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
