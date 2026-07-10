import Foundation
import HavenMacAutomation

public enum ScheduledEventRepeatMode: String, Codable, CaseIterable, Sendable {
    case once
    case count
    case untilStopped
}

public struct ScheduledEventDefinition: Codable, Equatable, Sendable {
    public var id: String
    public var firstFireAt: String
    public var repeatMode: ScheduledEventRepeatMode
    public var repeatCount: Int?
    public var intervalSeconds: Int?
    public var action: AutomationActionRequest

    public init(
        id: String,
        firstFireAt: String,
        repeatMode: ScheduledEventRepeatMode = .once,
        repeatCount: Int? = nil,
        intervalSeconds: Int? = nil,
        action: AutomationActionRequest
    ) {
        self.id = id
        self.firstFireAt = firstFireAt
        self.repeatMode = repeatMode
        self.repeatCount = repeatCount
        self.intervalSeconds = intervalSeconds
        self.action = action
    }
}

public enum ScheduledEventStatus: String, Codable, Sendable {
    case scheduled
    case running
    case completed
    case stopped
}

public struct ScheduledEventRecord: Codable, Equatable, Sendable {
    public var definition: ScheduledEventDefinition
    public var status: ScheduledEventStatus
    public var runCount: Int
    public var nextFireAt: String?
    public var lastStartedAt: String?
    public var lastFinishedAt: String?
    public var lastOutput: String?
    public var lastError: String?

    public init(
        definition: ScheduledEventDefinition,
        status: ScheduledEventStatus = .scheduled,
        runCount: Int = 0,
        nextFireAt: String? = nil,
        lastStartedAt: String? = nil,
        lastFinishedAt: String? = nil,
        lastOutput: String? = nil,
        lastError: String? = nil
    ) {
        self.definition = definition
        self.status = status
        self.runCount = runCount
        self.nextFireAt = nextFireAt ?? definition.firstFireAt
        self.lastStartedAt = lastStartedAt
        self.lastFinishedAt = lastFinishedAt
        self.lastOutput = lastOutput
        self.lastError = lastError
    }
}

public enum ScheduledEventError: Error, Equatable, LocalizedError, Sendable {
    case duplicateID(String)
    case invalidFirstFireAt(String)
    case invalidRepeatCount(String)
    case missingInterval(String)
    case unknownEvent(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateID(let id): return "Duplicate scheduled event id: \(id)"
        case .invalidFirstFireAt(let id): return "Scheduled event '\(id)' has an invalid firstFireAt timestamp."
        case .invalidRepeatCount(let id): return "Scheduled event '\(id)' requires repeatCount greater than zero."
        case .missingInterval(let id): return "Repeating scheduled event '\(id)' requires intervalSeconds greater than zero."
        case .unknownEvent(let id): return "Unknown scheduled event: \(id)"
        }
    }
}

public actor ScheduledEventStore {
    private let fileURL: URL
    private let encoder: JSONEncoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    public func load() throws -> [ScheduledEventRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([ScheduledEventRecord].self, from: Data(contentsOf: fileURL))
    }

    public func write(_ records: [ScheduledEventRecord]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try encoder.encode(records).write(to: fileURL, options: [.atomic])
    }
}

public actor ScheduledEventService {
    public typealias Now = @Sendable () -> Date
    public typealias Sleep = @Sendable (UInt64) async throws -> Void

    private let store: ScheduledEventStore
    private let shortcutRunner: ShortcutRunner
    private let appleScriptRunner: AppleScriptRunner
    private let localTaskRunner: LocalTaskRunner
    private let now: Now
    private let sleep: Sleep
    private var policy = AutomationPolicy()
    private var records: [ScheduledEventRecord] = []
    private var worker: Task<Void, Never>?

    public init(
        fileURL: URL,
        processRunner: any ProcessRunning = FoundationProcessRunner(),
        now: @escaping Now = Date.init,
        sleep: @escaping Sleep = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.store = ScheduledEventStore(fileURL: fileURL)
        self.shortcutRunner = ShortcutRunner(processRunner: processRunner)
        self.appleScriptRunner = AppleScriptRunner(processRunner: processRunner)
        self.localTaskRunner = LocalTaskRunner(processRunner: processRunner)
        self.now = now
        self.sleep = sleep
    }

    public func start(
        definitions: [ScheduledEventDefinition],
        policy: AutomationPolicy,
        runWorker: Bool = true,
        persistConfiguration: Bool = true
    ) async throws {
        try Self.validate(definitions)
        self.policy = policy
        let persisted = try await store.load()
        let persistedByID = Dictionary(uniqueKeysWithValues: persisted.map { ($0.definition.id, $0) })
        records = definitions.map { definition in
            guard var prior = persistedByID[definition.id] else {
                return ScheduledEventRecord(definition: definition)
            }
            prior.definition = definition
            if prior.status == .running {
                prior.status = .scheduled
                prior.nextFireAt = prior.nextFireAt ?? definition.firstFireAt
                prior.lastError = "Worker stopped while the event was running; event returned to the schedule."
            }
            return prior
        }
        if persistConfiguration {
            try await persist()
        }
        guard runWorker else { return }
        guard worker == nil else { return }
        worker = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runDueEvents()
                do {
                    try await self?.sleep(1_000_000_000)
                } catch {
                    break
                }
            }
        }
    }

    public func stop() {
        worker?.cancel()
        worker = nil
    }

    public func stopEvent(id: String) async throws -> ScheduledEventRecord {
        guard let index = records.firstIndex(where: { $0.definition.id == id }) else {
            throw ScheduledEventError.unknownEvent(id)
        }
        records[index].status = .stopped
        records[index].nextFireAt = nil
        try await persist()
        return records[index]
    }

    public func snapshot() -> [ScheduledEventRecord] {
        records
    }

    public func runDueEvents() async {
        let current = now()
        let dueIDs = records.compactMap { record -> String? in
            guard record.status == .scheduled,
                  let nextFireAt = record.nextFireAt,
                  let fireDate = Self.parseDate(nextFireAt),
                  fireDate <= current else { return nil }
            return record.definition.id
        }
        for id in dueIDs {
            await runEvent(id: id)
        }
    }

    private func runEvent(id: String) async {
        guard let index = records.firstIndex(where: { $0.definition.id == id }),
              records[index].status == .scheduled else { return }
        let definition = records[index].definition
        records[index].status = .running
        records[index].lastStartedAt = Self.formatDate(now())
        try? await persist()

        do {
            let result = try await execute(definition.action)
            let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            records[index].lastOutput = output.isEmpty ? nil : String(output.prefix(4_000))
            records[index].lastError = nil
        } catch {
            records[index].lastError = error.localizedDescription
        }

        records[index].runCount += 1
        records[index].lastFinishedAt = Self.formatDate(now())
        switch definition.repeatMode {
        case .once:
            records[index].status = .completed
            records[index].nextFireAt = nil
        case .count:
            if records[index].runCount >= (definition.repeatCount ?? 1) {
                records[index].status = .completed
                records[index].nextFireAt = nil
            } else {
                scheduleNext(index: index, intervalSeconds: definition.intervalSeconds ?? 1)
            }
        case .untilStopped:
            scheduleNext(index: index, intervalSeconds: definition.intervalSeconds ?? 1)
        }
        try? await persist()
    }

    private func scheduleNext(index: Int, intervalSeconds: Int) {
        records[index].status = .scheduled
        records[index].nextFireAt = Self.formatDate(now().addingTimeInterval(TimeInterval(intervalSeconds)))
    }

    private func execute(_ action: AutomationActionRequest) async throws -> SubprocessResult {
        switch action.kind {
        case .shortcut:
            return try await shortcutRunner.run(
                ShortcutInvocation(id: action.id, origin: .local, inputPath: action.inputPath),
                policy: policy
            )
        case .appleScript:
            return try await appleScriptRunner.run(
                AppleScriptInvocation(id: action.id, origin: .local, arguments: action.arguments),
                policy: policy
            )
        case .localTask:
            return try await localTaskRunner.run(LocalTaskInvocation(id: action.id), policy: policy)
        }
    }

    private func persist() async throws {
        try await store.write(records)
    }

    private static func validate(_ definitions: [ScheduledEventDefinition]) throws {
        var ids = Set<String>()
        for definition in definitions {
            guard ids.insert(definition.id).inserted else { throw ScheduledEventError.duplicateID(definition.id) }
            guard parseDate(definition.firstFireAt) != nil else { throw ScheduledEventError.invalidFirstFireAt(definition.id) }
            if definition.repeatMode == .count, (definition.repeatCount ?? 0) <= 0 {
                throw ScheduledEventError.invalidRepeatCount(definition.id)
            }
            if definition.repeatMode != .once, (definition.intervalSeconds ?? 0) <= 0 {
                throw ScheduledEventError.missingInterval(definition.id)
            }
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
