import Foundation
import HavenMacAutomation

public struct PersonalButlerDaemonPreferences: Codable, Equatable, Sendable {
    public static let schema = "haven.personal-butler-daemon-preferences.v1"
    public static let defaultMinimumIntervalHours = 72

    public var schema: String
    public var ownerApproved: Bool
    public var enabled: Bool
    public var minimumIntervalHours: Int
    public var quietHoursEnabled: Bool
    public var quietHoursStart: Int
    public var quietHoursEnd: Int
    public var appLaunchEnabled: Bool
    public var taskCompletionEnabled: Bool
    public var userScheduleEnabled: Bool
    public var userScheduleKind: String
    public var userScheduleLocalTime: String
    public var userScheduleWeekday: Int
    public var stagingWakeEnabled: Bool
    public var lastOfferedAt: String?
    public var snoozedUntil: String?
    public var sourceDeviceID: String?
    public var approvedByIdentityUUID: String?
    public var approvedBySigningKeyFingerprint: String?
    public var updatedAt: String

    public init(
        schema: String = Self.schema,
        ownerApproved: Bool = false,
        enabled: Bool = false,
        minimumIntervalHours: Int = Self.defaultMinimumIntervalHours,
        quietHoursEnabled: Bool = true,
        quietHoursStart: Int = 22,
        quietHoursEnd: Int = 8,
        appLaunchEnabled: Bool = true,
        taskCompletionEnabled: Bool = true,
        userScheduleEnabled: Bool = false,
        userScheduleKind: String = "weekdays",
        userScheduleLocalTime: String = "09:00",
        userScheduleWeekday: Int = 2,
        stagingWakeEnabled: Bool = false,
        lastOfferedAt: String? = nil,
        snoozedUntil: String? = nil,
        sourceDeviceID: String? = nil,
        approvedByIdentityUUID: String? = nil,
        approvedBySigningKeyFingerprint: String? = nil,
        updatedAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.schema = schema
        self.ownerApproved = ownerApproved
        self.enabled = enabled
        self.minimumIntervalHours = minimumIntervalHours
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.appLaunchEnabled = appLaunchEnabled
        self.taskCompletionEnabled = taskCompletionEnabled
        self.userScheduleEnabled = userScheduleEnabled
        self.userScheduleKind = userScheduleKind
        self.userScheduleLocalTime = userScheduleLocalTime
        self.userScheduleWeekday = userScheduleWeekday
        self.stagingWakeEnabled = stagingWakeEnabled
        self.lastOfferedAt = lastOfferedAt
        self.snoozedUntil = snoozedUntil
        self.sourceDeviceID = sourceDeviceID
        self.approvedByIdentityUUID = approvedByIdentityUUID
        self.approvedBySigningKeyFingerprint = approvedBySigningKeyFingerprint
        self.updatedAt = updatedAt
    }

    public func validated(now: Date = Date()) -> Self {
        var copy = self
        copy.schema = Self.schema
        copy.minimumIntervalHours = min(720, max(24, minimumIntervalHours))
        copy.quietHoursStart = min(23, max(0, quietHoursStart))
        copy.quietHoursEnd = min(23, max(0, quietHoursEnd))
        copy.userScheduleKind = ["daily", "weekdays", "weekly"].contains(userScheduleKind)
            ? userScheduleKind
            : "weekdays"
        copy.userScheduleLocalTime = Self.normalizedLocalTime(userScheduleLocalTime) ?? "09:00"
        copy.userScheduleWeekday = min(7, max(1, userScheduleWeekday))
        copy.lastOfferedAt = Self.validTimestamp(lastOfferedAt)
        copy.snoozedUntil = Self.validTimestamp(snoozedUntil)
        copy.sourceDeviceID = Self.trimmed(sourceDeviceID, maximumLength: 128)
        copy.approvedByIdentityUUID = Self.trimmed(approvedByIdentityUUID, maximumLength: 128)
        copy.approvedBySigningKeyFingerprint = Self.trimmed(
            approvedBySigningKeyFingerprint,
            maximumLength: 256
        )
        copy.updatedAt = ISO8601DateFormatter().string(from: now)
        return copy
    }

    private static func normalizedLocalTime(_ raw: String) -> String? {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), (0...23).contains(hour),
              let minute = Int(parts[1]), (0...59).contains(minute) else {
            return nil
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    private static func validTimestamp(_ raw: String?) -> String? {
        guard let raw, ISO8601DateFormatter().date(from: raw) != nil else { return nil }
        return raw
    }

    private static func trimmed(_ raw: String?, maximumLength: Int) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { return nil }
        return String(value.prefix(maximumLength))
    }
}

public struct PersonalButlerDaemonState: Codable, Equatable, Sendable {
    public static let schema = "haven.personal-butler-daemon-state.v1"

    public var schema: String
    public var preferences: PersonalButlerDaemonPreferences
    public var lastScheduleSlot: String?
    public var lastScheduleOutcome: String?
    public var lastWakeReason: String?
    public var lastWakeAttemptAt: String?
    public var lastWakeSucceededAt: String?
    public var lastWakeError: String?
    public var lastRemoteIntentID: String?
    public var updatedAt: String

    public init(
        schema: String = Self.schema,
        preferences: PersonalButlerDaemonPreferences = .init(),
        lastScheduleSlot: String? = nil,
        lastScheduleOutcome: String? = nil,
        lastWakeReason: String? = nil,
        lastWakeAttemptAt: String? = nil,
        lastWakeSucceededAt: String? = nil,
        lastWakeError: String? = nil,
        lastRemoteIntentID: String? = nil,
        updatedAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.schema = schema
        self.preferences = preferences
        self.lastScheduleSlot = lastScheduleSlot
        self.lastScheduleOutcome = lastScheduleOutcome
        self.lastWakeReason = lastWakeReason
        self.lastWakeAttemptAt = lastWakeAttemptAt
        self.lastWakeSucceededAt = lastWakeSucceededAt
        self.lastWakeError = lastWakeError
        self.lastRemoteIntentID = lastRemoteIntentID
        self.updatedAt = updatedAt
    }
}

public enum PersonalButlerWakeOutcome: Equatable, Sendable {
    case notApplicable
    case launched
    case suppressed(String)
    case failed(String)
}

public actor PersonalButlerScheduleService {
    public static let remoteWakeActionID = "personal.butler.haven.wake"
    public static let remoteWakeTopic = "personal.butler.wake"
    public static let havenBundleIdentifier = "org.digipomps.havenplayground"

    public typealias Now = @Sendable () -> Date
    public typealias Sleep = @Sendable (UInt64) async throws -> Void

    private let fileURL: URL
    private let processRunner: any ProcessRunning
    private let now: Now
    private let sleep: Sleep
    private let calendar: Calendar
    private let pollIntervalNanoseconds: UInt64
    private var state = PersonalButlerDaemonState()
    private var worker: Task<Void, Never>?
    private var didLoad = false

    public init(
        fileURL: URL,
        processRunner: any ProcessRunning = FoundationProcessRunner(),
        calendar: Calendar = .current,
        pollIntervalNanoseconds: UInt64 = 60_000_000_000,
        now: @escaping Now = Date.init,
        sleep: @escaping Sleep = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.fileURL = fileURL
        self.processRunner = processRunner
        self.calendar = calendar
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
        self.now = now
        self.sleep = sleep
    }

    public func start(runWorker: Bool = true) async throws {
        try loadIfNeeded()
        guard runWorker, worker == nil else { return }
        worker = Task { [weak self] in
            while Task.isCancelled == false {
                await self?.evaluateSchedule()
                do {
                    guard let self else { break }
                    try await self.sleep(self.pollIntervalNanoseconds)
                } catch {
                    break
                }
            }
        }
    }

    public func stop() async {
        let activeWorker = worker
        worker = nil
        activeWorker?.cancel()
        await activeWorker?.value
    }

    @discardableResult
    public func configure(_ preferences: PersonalButlerDaemonPreferences) async throws -> PersonalButlerDaemonState {
        try loadIfNeeded()
        state.preferences = preferences.validated(now: now())
        state.updatedAt = Self.timestamp(now())
        try persist()
        return state
    }

    public func snapshot() -> PersonalButlerDaemonState {
        state
    }

    public func evaluateSchedule() async {
        do {
            try loadIfNeeded()
            guard let slot = dueScheduleSlot(at: now()) else { return }
            state.lastScheduleSlot = slot

            if let suppression = suppressionReason(for: .schedule, at: now()) {
                state.lastScheduleOutcome = "suppressed:\(suppression)"
                state.updatedAt = Self.timestamp(now())
                try persist()
                return
            }

            let outcome = await launchHAVEN(trigger: "user_schedule", reason: "daemon_schedule", slot: slot)
            state.lastScheduleOutcome = Self.outcomeLabel(outcome)
            state.updatedAt = Self.timestamp(now())
            try persist()
        } catch {
            state.lastScheduleOutcome = "failed:persistence"
            state.lastWakeError = error.localizedDescription
        }
    }

    public func handleRemoteWake(intent: QueuedRemoteIntent) async -> PersonalButlerWakeOutcome {
        guard intent.actionID == Self.remoteWakeActionID else { return .notApplicable }
        do {
            try loadIfNeeded()
            state.lastRemoteIntentID = intent.id
            if let suppression = suppressionReason(for: .remote, at: now()) {
                let outcome = PersonalButlerWakeOutcome.suppressed(suppression)
                state.lastWakeReason = "signed_staging_signal"
                state.lastWakeAttemptAt = Self.timestamp(now())
                state.lastWakeError = nil
                state.updatedAt = Self.timestamp(now())
                try persist()
                return outcome
            }

            // Remote arguments are deliberately ignored. A verified issuer may
            // request only this fixed local wake operation, never a URL or command.
            let outcome = await launchHAVEN(trigger: "app_launch", reason: "signed_staging_signal", slot: nil)
            state.updatedAt = Self.timestamp(now())
            try persist()
            return outcome
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private enum TriggerSource {
        case schedule
        case remote
    }

    private func suppressionReason(for source: TriggerSource, at date: Date) -> String? {
        let preferences = state.preferences
        guard preferences.ownerApproved else { return "owner_approval_missing" }
        guard preferences.enabled else { return "proactivity_disabled" }

        switch source {
        case .schedule:
            guard preferences.userScheduleEnabled else { return "user_schedule_disabled" }
        case .remote:
            guard preferences.stagingWakeEnabled else { return "staging_wake_disabled" }
            guard preferences.appLaunchEnabled else { return "app_launch_disabled" }
        }

        if let snoozedUntil = Self.parseTimestamp(preferences.snoozedUntil), snoozedUntil > date {
            return "snoozed"
        }
        if preferences.quietHoursEnabled {
            let hour = calendar.component(.hour, from: date)
            let start = preferences.quietHoursStart
            let end = preferences.quietHoursEnd
            let isQuiet = start == end
                ? true
                : (start < end ? (hour >= start && hour < end) : (hour >= start || hour < end))
            if isQuiet { return "quiet_hours" }
        }
        if let lastOfferedAt = Self.parseTimestamp(preferences.lastOfferedAt),
           date.timeIntervalSince(lastOfferedAt) < Double(preferences.minimumIntervalHours) * 3_600 {
            return "minimum_interval"
        }
        return nil
    }

    private func dueScheduleSlot(at date: Date) -> String? {
        let preferences = state.preferences
        guard preferences.ownerApproved,
              preferences.enabled,
              preferences.userScheduleEnabled else { return nil }
        let timeParts = preferences.userScheduleLocalTime.split(separator: ":").compactMap { Int($0) }
        guard timeParts.count == 2 else { return nil }
        let components = calendar.dateComponents(
            [.year, .month, .day, .weekday, .hour, .minute],
            from: date
        )
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute,
              (hour, minute) >= (timeParts[0], timeParts[1]) else {
            return nil
        }
        switch preferences.userScheduleKind {
        case "weekdays" where weekday == 1 || weekday == 7:
            return nil
        case "weekly" where weekday != preferences.userScheduleWeekday:
            return nil
        case "daily", "weekdays", "weekly":
            break
        default:
            return nil
        }
        let slot = String(
            format: "%@:%04d-%02d-%02d",
            preferences.userScheduleKind,
            year,
            month,
            day
        )
        return state.lastScheduleSlot == slot ? nil : slot
    }

    private func launchHAVEN(trigger: String, reason: String, slot: String?) async -> PersonalButlerWakeOutcome {
        let attemptDate = now()
        state.lastWakeReason = reason
        state.lastWakeAttemptAt = Self.timestamp(attemptDate)
        state.lastWakeError = nil

        guard let url = Self.wakeURL(trigger: trigger, slot: slot) else {
            state.lastWakeError = "Unable to construct the fixed HAVEN wake URL."
            return .failed(state.lastWakeError ?? "invalid_wake_url")
        }

        do {
            let result = try await processRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/open"),
                arguments: ["-b", Self.havenBundleIdentifier, url.absoluteString]
            )
            guard result.succeeded else {
                let message = result.standardError.isEmpty
                    ? "HAVEN launch failed with status \(result.terminationStatus)."
                    : String(result.standardError.prefix(1_000))
                state.lastWakeError = message
                return .failed(message)
            }
            state.lastWakeSucceededAt = Self.timestamp(now())
            return .launched
        } catch {
            state.lastWakeError = error.localizedDescription
            return .failed(error.localizedDescription)
        }
    }

    public static func wakeURL(trigger: String, slot: String?) -> URL? {
        var components = URLComponents()
        components.scheme = "haven"
        components.host = "butler"
        components.path = "/check-in"
        var queryItems = [
            URLQueryItem(name: "source", value: "havenagentd"),
            URLQueryItem(name: "trigger", value: trigger)
        ]
        if let slot { queryItems.append(URLQueryItem(name: "slot", value: slot)) }
        components.queryItems = queryItems
        return components.url
    }

    private func loadIfNeeded() throws {
        guard didLoad == false else { return }
        defer { didLoad = true }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        state = try JSONDecoder().decode(PersonalButlerDaemonState.self, from: data)
        state.schema = PersonalButlerDaemonState.schema
        state.preferences = state.preferences.validated(now: now())
    }

    private func persist() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: fileURL, options: [.atomic])
    }

    private static func outcomeLabel(_ outcome: PersonalButlerWakeOutcome) -> String {
        switch outcome {
        case .notApplicable: return "not_applicable"
        case .launched: return "launched"
        case .suppressed(let reason): return "suppressed:\(reason)"
        case .failed(let reason): return "failed:\(String(reason.prefix(200)))"
        }
    }

    private static func parseTimestamp(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
